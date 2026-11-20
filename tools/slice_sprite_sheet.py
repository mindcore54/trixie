#!/usr/bin/env python3
"""
Trixie Asset Pipeline: Connected-Component Sprite Sheet Slicer & White-BG Cleaner.

Avoids brute-force rectangular grid slicing (which leaks overlapping hat tips / hair
from neighboring sprites). Instead:
1. Removes the exterior #FFFFFF background with process_white_bg.remove_white_background
   (preserving all enclosed internal white pixels like eyes, teeth, ivory gills, lace).
2. Runs 4-connected component labeling on opaque pixels (alpha > 15).
3. Picks the top-K main sprite bodies, merges nearby floating VFX satellites (sweat drops,
   sparkles) into their nearest sprite body, and renders each sprite using ONLY its own
   pixel mask so zero neighboring pixels can ever bleed into a cropped PNG.
"""

from __future__ import annotations

from collections import deque
from pathlib import Path
import sys
from typing import Sequence

from PIL import Image

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "tools"))
from process_white_bg import remove_white_background  # noqa: E402


def _label_components(rgba: Image.Image, alpha_thresh: int = 15) -> list[dict]:
    w, h = rgba.size
    buf = rgba.tobytes()
    visited = bytearray(w * h)
    comps: list[dict] = []

    for y in range(h):
        row = y * w
        for x in range(w):
            idx = row + x
            if visited[idx] or buf[idx * 4 + 3] <= alpha_thresh:
                continue
            visited[idx] = 1
            q: deque[int] = deque([idx])
            pixels: list[int] = []
            min_x = max_x = x
            min_y = max_y = y
            sum_x = 0
            sum_y = 0

            while q:
                cur = q.popleft()
                pixels.append(cur)
                cx = cur % w
                cy = cur // w
                sum_x += cx
                sum_y += cy
                if cx < min_x:
                    min_x = cx
                if cx > max_x:
                    max_x = cx
                if cy < min_y:
                    min_y = cy
                if cy > max_y:
                    max_y = cy

                if cx > 0:
                    n = cur - 1
                    if not visited[n] and buf[n * 4 + 3] > alpha_thresh:
                        visited[n] = 1
                        q.append(n)
                if cx + 1 < w:
                    n = cur + 1
                    if not visited[n] and buf[n * 4 + 3] > alpha_thresh:
                        visited[n] = 1
                        q.append(n)
                if cy > 0:
                    n = cur - w
                    if not visited[n] and buf[n * 4 + 3] > alpha_thresh:
                        visited[n] = 1
                        q.append(n)
                if cy + 1 < h:
                    n = cur + w
                    if not visited[n] and buf[n * 4 + 3] > alpha_thresh:
                        visited[n] = 1
                        q.append(n)

            area = len(pixels)
            comps.append({
                "pixels": pixels,
                "area": area,
                "bbox": (min_x, min_y, max_x, max_y),
                "cx": sum_x / area,
                "cy": sum_y / area,
            })
    return comps


def _bbox_dist(b1: tuple[int, int, int, int], b2: tuple[int, int, int, int]) -> float:
    dx = max(0, b1[0] - b2[2], b2[0] - b1[2])
    dy = max(0, b1[1] - b2[3], b2[1] - b1[3])
    return (dx * dx + dy * dy) ** 0.5


def _export_component(rgba: Image.Image, pixel_indices: list[int], out_path: Path, pad: int = 8) -> tuple[int, int]:
    w, h = rgba.size
    src = rgba.tobytes()
    min_x, min_y, max_x, max_y = w, h, 0, 0
    for idx in pixel_indices:
        x = idx % w
        y = idx // w
        if x < min_x:
            min_x = x
        if x > max_x:
            max_x = x
        if y < min_y:
            min_y = y
        if y > max_y:
            max_y = y

    x0 = max(0, min_x - pad)
    y0 = max(0, min_y - pad)
    x1 = min(w - 1, max_x + pad)
    y1 = min(h - 1, max_y + pad)
    cw = x1 - x0 + 1
    ch = y1 - y0 + 1

    out_buf = bytearray(cw * ch * 4)
    for idx in pixel_indices:
        x = idx % w
        y = idx // w
        s_off = idx * 4
        d_off = ((y - y0) * cw + (x - x0)) * 4
        out_buf[d_off : d_off + 4] = src[s_off : s_off + 4]

    out_img = Image.frombytes("RGBA", (cw, ch), bytes(out_buf))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_img.save(out_path, format="PNG")
    return cw, ch


def slice_grid_by_components(
    input_path: Path,
    out_dir: Path,
    names_row_major: Sequence[str],
    rows: int,
    cols: int,
    max_satellite_dist: float = 110.0,
    tolerance: int = 28,
    chroma_tol: int = 26,
    defringe: int = 2,
) -> list[Path]:
    expected = rows * cols
    assert len(names_row_major) == expected, "names count must equal rows * cols"
    with Image.open(input_path) as im:
        clean = remove_white_background(im, tolerance=tolerance, chroma_tolerance=chroma_tol, defringe_passes=defringe)

    comps = _label_components(clean, alpha_thresh=15)
    comps.sort(key=lambda c: c["area"], reverse=True)
    mains = comps[:expected]
    satellites = comps[expected:]

    # Merge nearby floating VFX (sweat drops, sparkles) into their nearest main sprite
    merged_pixels: list[list[int]] = [list(m["pixels"]) for m in mains]
    for sat in satellites:
        if sat["area"] < 12:
            continue
        best_i = -1
        best_d = max_satellite_dist
        for i, m in enumerate(mains):
            d = _bbox_dist(sat["bbox"], m["bbox"])
            if d < best_d:
                best_d = d
                best_i = i
        if best_i != -1:
            merged_pixels[best_i].extend(sat["pixels"])

    # Sort mains into exact row-major order (rows by cy, then cols by cx)
    indexed = list(range(expected))
    indexed.sort(key=lambda i: mains[i]["cy"])
    ordered: list[int] = []
    for r in range(rows):
        row_slice = indexed[r * cols : (r + 1) * cols]
        row_slice.sort(key=lambda i: mains[i]["cx"])
        ordered.extend(row_slice)

    written: list[Path] = []
    for name, comp_idx in zip(names_row_major, ordered):
        out_file = out_dir / f"{name}.png"
        cw, ch = _export_component(clean, merged_pixels[comp_idx], out_file, pad=8)
        print(f"[SLICE] {input_path.name} -> {out_file.relative_to(PROJECT_ROOT).as_posix()} ({cw}x{ch})")
        written.append(out_file)
    return written


def extract_fullbody_from_concept(
    concept_path: Path,
    out_path: Path,
    tolerance: int = 28,
    chroma_tol: int = 26,
    defringe: int = 2,
) -> Path:
    with Image.open(concept_path) as im:
        clean = remove_white_background(im, tolerance=tolerance, chroma_tolerance=chroma_tol, defringe_passes=defringe)
    w, h = clean.size
    comps = _label_components(clean, alpha_thresh=15)
    # Pick the largest component whose centroid is in the left 40% (Full-Body FRONT view)
    left_mains = [c for c in comps if c["cx"] < w * 0.40 and c["cy"] > h * 0.15]
    left_mains.sort(key=lambda c: c["area"], reverse=True)
    if not left_mains:
        raise RuntimeError("Could not locate front full-body component in concept sheet")
    front = left_mains[0]
    pixels = list(front["pixels"])
    # Include tiny potion steam/sparkles above her right hand, excluding "FRONT" text near feet and title at top
    fb = front["bbox"]
    front_h = fb[3] - fb[1]
    for c in comps:
        if c is front or c["area"] < 12 or c["area"] > front["area"] * 0.08:
            continue
        cb = c["bbox"]
        if cb[3] > fb[1] + front_h * 0.55 or cb[3] < h * 0.09:
            continue
        if _bbox_dist(cb, fb) < 95.0:
            pixels.extend(c["pixels"])

    cw, ch = _export_component(clean, pixels, out_path, pad=10)
    print(f"[FULLBODY] {concept_path.name} -> {out_path.relative_to(PROJECT_ROOT).as_posix()} ({cw}x{ch})")
    return out_path


def _clean_pure_white_hat_pockets(png_path: Path) -> None:
    """Remove enclosed pure-white (#F6F6F6+) background loops inside the hat tip curl (top 28% of sprite)."""
    with Image.open(png_path) as im:
        rgba = im.convert("RGBA")
        w, h = rgba.size
        buf = bytearray(rgba.tobytes())
        max_y = int(h * 0.30)
        changed = 0
        for y in range(max_y):
            row = y * w
            for x in range(w):
                off = (row + x) * 4
                r, g, b, a = buf[off], buf[off + 1], buf[off + 2], buf[off + 3]
                if a > 0 and min(r, g, b) >= 242 and (max(r, g, b) - min(r, g, b)) <= 12:
                    buf[off] = buf[off + 1] = buf[off + 2] = buf[off + 3] = 0
                    changed += 1
        if changed > 0:
            Image.frombytes("RGBA", (w, h), bytes(buf)).save(png_path, format="PNG")
            print(f"[POCKET-FIX] {png_path.name}: cleaned {changed} enclosed pure-white hat-curl pixels")


def main() -> int:
    out_dir = PROJECT_ROOT / "assets" / "characters" / "playable" / "trixie"
    slice_grid_by_components(
        PROJECT_ROOT / "raw_assets" / "trixie" / "trixie_expressions_v02.jpg",
        out_dir,
        [
            "trixie_normal",
            "trixie_confiada",
            "trixie_nerviosa_sudando",
            "trixie_sonrojada_picante",
            "trixie_hollin_derrota",
            "trixie_sorprendida",
        ],
        rows=2,
        cols=3,
    )
    chibi_files = slice_grid_by_components(
        PROJECT_ROOT / "raw_assets" / "trixie" / "trixie_chibi_v03.jpg",
        out_dir,
        [
            "trixie_chibi_down",
            "trixie_chibi_down_right",
            "trixie_chibi_up",
            "trixie_chibi_up_right",
        ],
        rows=2,
        cols=2,
    )
    for cf in chibi_files:
        _clean_pure_white_hat_pockets(cf)
    fb_file = extract_fullbody_from_concept(
        PROJECT_ROOT / "raw_assets" / "concepts" / "trixie_concept_v05_usergenerated.jpg",
        out_dir / "trixie_fullbody.png",
    )
    _clean_pure_white_hat_pockets(fb_file)
    return 0


if __name__ == "__main__":
    sys.exit(main())
