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

import argparse
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


def _export_component(
    rgba: Image.Image,
    pixel_indices: list[int],
    out_path: Path,
    pad: int = 8,
    padded_canvas: bool = False,
    flip_horizontal: bool = False,
) -> tuple[int, int]:
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

    if padded_canvas:
        cw = (max_x - min_x + 1) + 2 * pad
        ch = (max_y - min_y + 1) + 2 * pad
        ox = min_x - pad
        oy = min_y - pad
    else:
        ox = max(0, min_x - pad)
        oy = max(0, min_y - pad)
        x1 = min(w - 1, max_x + pad)
        y1 = min(h - 1, max_y + pad)
        cw = x1 - ox + 1
        ch = y1 - oy + 1

    out_buf = bytearray(cw * ch * 4)
    for idx in pixel_indices:
        x = idx % w
        y = idx // w
        s_off = idx * 4
        d_off = ((y - oy) * cw + (x - ox)) * 4
        out_buf[d_off : d_off + 4] = src[s_off : s_off + 4]

    out_img = Image.frombytes("RGBA", (cw, ch), bytes(out_buf))
    if flip_horizontal:
        out_img = out_img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_img.save(out_path, format="PNG")
    return cw, ch


def _export_component_padded(
    rgba: Image.Image,
    pixel_indices: list[int],
    out_path: Path,
    pad: int = 6,
    flip_horizontal: bool = False,
) -> tuple[int, int]:
    """Export isolated component onto a symmetric transparent canvas (safe near sheet edges)."""
    return _export_component(
        rgba,
        pixel_indices,
        out_path,
        pad=pad,
        padded_canvas=True,
        flip_horizontal=flip_horizontal,
    )


def _slice_rgba_components(
    rgba: Image.Image,
    source_name: str,
    out_dir: Path,
    names_row_major: Sequence[str],
    rows: int,
    cols: int,
    max_satellite_dist: float = 110.0,
    alpha_thresh: int = 15,
    min_satellite_area: int = 12,
    pad: int = 8,
    padded_canvas: bool = False,
    flip_horizontal: bool = False,
) -> list[Path]:
    expected = rows * cols
    assert len(names_row_major) == expected, "names count must equal rows * cols"

    comps = _label_components(rgba, alpha_thresh=alpha_thresh)
    if len(comps) < expected:
        raise RuntimeError(f"Expected at least {expected} components in {source_name}, found {len(comps)}")
    comps.sort(key=lambda c: c["area"], reverse=True)
    mains = comps[:expected]
    satellites = comps[expected:]

    # Merge nearby floating VFX (sweat drops, sparkles, smoke wisps) into their nearest main sprite
    merged_pixels: list[list[int]] = [list(m["pixels"]) for m in mains]
    for sat in satellites:
        if sat["area"] < min_satellite_area:
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
        cw, ch = _export_component(
            rgba,
            merged_pixels[comp_idx],
            out_file,
            pad=pad,
            padded_canvas=padded_canvas,
            flip_horizontal=flip_horizontal,
        )
        try:
            rel_label = out_file.resolve().relative_to(PROJECT_ROOT).as_posix()
        except ValueError:
            rel_label = out_file.as_posix()
        print(f"[SLICE] {source_name} -> {rel_label} ({cw}x{ch})")
        written.append(out_file)
    return written


def _find_pure_white_pocket_seeds(
    rgba: Image.Image,
    min_rgb: int = 242,
    max_chroma: int = 12,
    min_area: int = 30,
) -> list[tuple[int, int]]:
    """Locate one seed (x, y) per enclosed pure-white background pocket (arm/hair/horn loops)."""
    w, h = rgba.size
    px = rgba.tobytes()
    visited = bytearray(w * h)
    seeds: list[tuple[int, int]] = []

    def is_pure_white(off: int) -> bool:
        a = px[off + 3]
        if a <= 15:
            return False
        r, g, b = px[off], px[off + 1], px[off + 2]
        return min(r, g, b) >= min_rgb and (max(r, g, b) - min(r, g, b)) <= max_chroma

    for y in range(h):
        row = y * w
        for x in range(w):
            idx = row + x
            if visited[idx] or not is_pure_white(idx * 4):
                continue
            visited[idx] = 1
            q: deque[int] = deque([idx])
            area = 0
            while q:
                cur = q.popleft()
                area += 1
                cx = cur % w
                cy = cur // w
                if cx > 0 and not visited[cur - 1] and is_pure_white((cur - 1) * 4):
                    visited[cur - 1] = 1
                    q.append(cur - 1)
                if cx + 1 < w and not visited[cur + 1] and is_pure_white((cur + 1) * 4):
                    visited[cur + 1] = 1
                    q.append(cur + 1)
                if cy > 0 and not visited[cur - w] and is_pure_white((cur - w) * 4):
                    visited[cur - w] = 1
                    q.append(cur - w)
                if cy + 1 < h and not visited[cur + w] and is_pure_white((cur + w) * 4):
                    visited[cur + w] = 1
                    q.append(cur + w)
            if area >= min_area:
                seeds.append((x, y))
    return seeds


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
    clean_pockets: bool = False,
    pad: int = 8,
    padded_canvas: bool = False,
    flip_horizontal: bool = False,
) -> list[Path]:
    with Image.open(input_path) as im:
        clean = remove_white_background(im, tolerance=tolerance, chroma_tolerance=chroma_tol, defringe_passes=defringe)
        if clean_pockets:
            seeds = _find_pure_white_pocket_seeds(clean)
            if seeds:
                print(f"[POCKET-SEEDS] {input_path.name}: detected {len(seeds)} enclosed pure-white pockets")
                clean = remove_white_background(
                    im,
                    tolerance=tolerance,
                    chroma_tolerance=chroma_tol,
                    defringe_passes=defringe,
                    extra_seeds=seeds,
                )
    return _slice_rgba_components(
        clean,
        input_path.name,
        out_dir,
        names_row_major,
        rows,
        cols,
        max_satellite_dist=max_satellite_dist,
        alpha_thresh=15,
        min_satellite_area=12,
        pad=pad,
        padded_canvas=padded_canvas,
        flip_horizontal=flip_horizontal,
    )


def slice_alpha_sheet_by_components(
    input_path: Path,
    out_dir: Path,
    names_row_major: Sequence[str],
    rows: int,
    cols: int,
    max_satellite_dist: float = 110.0,
    alpha_thresh: int = 1,
    min_satellite_area: int = 12,
    pad: int = 6,
    flip_horizontal: bool = False,
) -> list[Path]:
    """Slice a pre-transparent RGBA sprite sheet directly by connected components (no white-BG pass)."""
    with Image.open(input_path) as im:
        rgba = im.convert("RGBA")
    return _slice_rgba_components(
        rgba,
        input_path.name,
        out_dir,
        names_row_major,
        rows,
        cols,
        max_satellite_dist=max_satellite_dist,
        alpha_thresh=alpha_thresh,
        min_satellite_area=min_satellite_area,
        pad=pad,
        padded_canvas=True,
        flip_horizontal=flip_horizontal,
    )


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
    parser = argparse.ArgumentParser(description="Slice white-BG or pre-transparent RGBA sprite sheets by connected components.")
    parser.add_argument("--alpha-sheet", type=Path, default=None, help="Pre-transparent RGBA sprite sheet PNG to slice directly")
    parser.add_argument("--white-sheet", type=Path, default=None, help="Pure #FFFFFF background sprite sheet to clean and slice")
    parser.add_argument("--clean-pockets", action="store_true", help="Detect & remove enclosed #FFFFFF pockets (arms/hair/horns)")
    parser.add_argument("--out-dir", type=Path, default=None, help="Output directory for sliced PNGs")
    parser.add_argument("--names", default="", help="Comma-separated output file stems in row-major order")
    parser.add_argument("--rows", type=int, default=1, help="Grid rows (default: 1)")
    parser.add_argument("--cols", type=int, default=3, help="Grid cols (default: 3)")
    parser.add_argument("--pad", type=int, default=6, help="Transparent margin padding around each cutout (default: 6)")
    parser.add_argument("--flip-horizontal", action="store_true", help="Mirror each sliced sprite horizontally")
    args = parser.parse_args()

    if args.alpha_sheet is not None:
        if args.out_dir is None or not args.names.strip():
            parser.error("--out-dir and --names are required when using --alpha-sheet.")
        names = [n.strip() for n in args.names.split(",") if n.strip()]
        slice_alpha_sheet_by_components(
            input_path=args.alpha_sheet,
            out_dir=args.out_dir,
            names_row_major=names,
            rows=args.rows,
            cols=args.cols,
            pad=args.pad,
            flip_horizontal=args.flip_horizontal,
        )
        return 0

    if args.white_sheet is not None:
        if args.out_dir is None or not args.names.strip():
            parser.error("--out-dir and --names are required when using --white-sheet.")
        names = [n.strip() for n in args.names.split(",") if n.strip()]
        slice_grid_by_components(
            input_path=args.white_sheet,
            out_dir=args.out_dir,
            names_row_major=names,
            rows=args.rows,
            cols=args.cols,
            clean_pockets=args.clean_pockets,
            pad=args.pad,
            padded_canvas=True,
            flip_horizontal=args.flip_horizontal,
        )
        return 0

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
