#!/usr/bin/env python3
"""
Trixie Asset Pipeline: White-Background to Transparent PNG Converter.

Removes pure/near-white (#FFFFFF) backgrounds using border-seeded 4-connected
flood-fill so internal white pixels (eyes, teeth, specular highlights, white
clothing) are NEVER perforated, then applies edge anti-aliasing & RGB color
decontamination (defringe) and outputs directly into Godot's res://assets/.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path
import sys
from typing import Iterable, Tuple

from PIL import Image, ImageDraw

PROJECT_ROOT = Path(__file__).resolve().parent.parent

CATEGORY_DIRS: dict[str, Path] = {
    "playable": PROJECT_ROOT / "assets" / "characters" / "playable",
    "customers": PROJECT_ROOT / "assets" / "characters" / "customers",
    "familiars": PROJECT_ROOT / "assets" / "characters" / "familiars",
    "stations": PROJECT_ROOT / "assets" / "props" / "stations",
    "items": PROJECT_ROOT / "assets" / "props" / "items",
    "hud": PROJECT_ROOT / "assets" / "ui" / "hud",
    "buttons": PROJECT_ROOT / "assets" / "ui" / "buttons",
    "menus": PROJECT_ROOT / "assets" / "ui" / "menus",
    "vfx": PROJECT_ROOT / "assets" / "vfx",
}

SUPPORTED_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}


def _is_white_bg(r: int, g: int, b: int, a: int, tol: int, chroma_tol: int) -> bool:
    if a <= 10:
        return True
    min_c = min(r, g, b)
    max_c = max(r, g, b)
    return min_c >= (255 - tol) and (max_c - min_c) <= chroma_tol


def remove_white_background(
    img: Image.Image,
    tolerance: int = 28,
    chroma_tolerance: int = 26,
    defringe_passes: int = 2,
    extra_seeds: Iterable[Tuple[int, int]] = (),
    trim: bool = False,
    pad: int = 8,
) -> Image.Image:
    """
    Convert an image with a white outer background to clean RGBA transparency.

    Uses a 4-connected BFS starting exclusively from the outer perimeter (plus
    optional user-specified enclosed-gap seeds) so enclosed interior white pixels
    remain 100% opaque.
    """
    rgba = img.convert("RGBA")
    w, h = rgba.size
    if w == 0 or h == 0:
        return rgba

    buf = bytearray(rgba.tobytes())
    total = w * h
    bg_mask = bytearray(total)
    queue: deque[int] = deque()

    def try_seed(px: int, py: int) -> None:
        if px < 0 or px >= w or py < 0 or py >= h:
            return
        idx = py * w + px
        if bg_mask[idx]:
            return
        off = idx * 4
        if _is_white_bg(buf[off], buf[off + 1], buf[off + 2], buf[off + 3], tolerance, chroma_tolerance):
            bg_mask[idx] = 1
            queue.append(idx)

    # Seed from all 4 outer borders
    for x in range(w):
        try_seed(x, 0)
        try_seed(x, h - 1)
    for y in range(1, h - 1):
        try_seed(0, y)
        try_seed(w - 1, y)

    # Optional explicit seeds for closed pockets (e.g. between arm and waist)
    for sx, sy in extra_seeds:
        try_seed(sx, sy)

    # 4-connected flood-fill (prevents diagonal leaks through thin 1px outlines)
    while queue:
        idx = queue.popleft()
        x = idx % w
        y = idx // w

        if x > 0:
            n = idx - 1
            if not bg_mask[n]:
                off = n * 4
                if _is_white_bg(buf[off], buf[off + 1], buf[off + 2], buf[off + 3], tolerance, chroma_tolerance):
                    bg_mask[n] = 1
                    queue.append(n)
        if x + 1 < w:
            n = idx + 1
            if not bg_mask[n]:
                off = n * 4
                if _is_white_bg(buf[off], buf[off + 1], buf[off + 2], buf[off + 3], tolerance, chroma_tolerance):
                    bg_mask[n] = 1
                    queue.append(n)
        if y > 0:
            n = idx - w
            if not bg_mask[n]:
                off = n * 4
                if _is_white_bg(buf[off], buf[off + 1], buf[off + 2], buf[off + 3], tolerance, chroma_tolerance):
                    bg_mask[n] = 1
                    queue.append(n)
        if y + 1 < h:
            n = idx + w
            if not bg_mask[n]:
                off = n * 4
                if _is_white_bg(buf[off], buf[off + 1], buf[off + 2], buf[off + 3], tolerance, chroma_tolerance):
                    bg_mask[n] = 1
                    queue.append(n)

    # Set exterior background pixels to fully transparent (alpha = 0)
    for idx in range(total):
        if bg_mask[idx]:
            off = idx * 4
            buf[off] = 0
            buf[off + 1] = 0
            buf[off + 2] = 0
            buf[off + 3] = 0

    # Defringe / halo decontamination along the outer silhouette boundary
    frontier = bytearray(bg_mask)
    soft_threshold = max(140, 255 - tolerance * 3)
    for _pass in range(max(0, defringe_passes)):
        next_frontier = bytearray(frontier)
        for y in range(h):
            row = y * w
            for x in range(w):
                idx = row + x
                if frontier[idx]:
                    continue
                touches_bg = (
                    (x > 0 and frontier[idx - 1])
                    or (x + 1 < w and frontier[idx + 1])
                    or (y > 0 and frontier[idx - w])
                    or (y + 1 < h and frontier[idx + w])
                )
                if not touches_bg:
                    continue

                off = idx * 4
                r, g, b, a = buf[off], buf[off + 1], buf[off + 2], buf[off + 3]
                if a == 0:
                    continue

                min_c = min(r, g, b)
                max_c = max(r, g, b)
                chroma = max_c - min_c
                lum = (r + g + b) / 3.0

                # Decontaminate semi-white outer anti-aliased pixels
                if chroma <= chroma_tolerance + 24 and lum >= soft_threshold:
                    # Smoothly ramp alpha down as pixel approaches pure white
                    whiteness = (lum - soft_threshold) / max(1.0, (255.0 - soft_threshold))
                    new_alpha = max(0.0, min(1.0, (1.0 - whiteness) * (a / 255.0)))
                    if new_alpha <= 0.04:
                        buf[off] = 0
                        buf[off + 1] = 0
                        buf[off + 2] = 0
                        buf[off + 3] = 0
                        next_frontier[idx] = 1
                    else:
                        # Unmix white background contribution: C_in = alpha * C_fg + (1 - alpha) * 255
                        buf[off] = int(max(0, min(255, round((r - (1.0 - new_alpha) * 255.0) / new_alpha))))
                        buf[off + 1] = int(max(0, min(255, round((g - (1.0 - new_alpha) * 255.0) / new_alpha))))
                        buf[off + 2] = int(max(0, min(255, round((b - (1.0 - new_alpha) * 255.0) / new_alpha))))
                        buf[off + 3] = int(round(new_alpha * 255.0))
        frontier = next_frontier

    out = Image.frombytes("RGBA", (w, h), bytes(buf))
    if trim:
        bbox = out.getbbox()
        if bbox:
            x0, y0, x1, y1 = bbox
            x0 = max(0, x0 - pad)
            y0 = max(0, y0 - pad)
            x1 = min(w, x1 + pad)
            y1 = min(h, y1 + pad)
            out = out.crop((x0, y0, x1, y1))
    return out


def _parse_seeds(seed_args: list[str] | None) -> list[Tuple[int, int]]:
    seeds: list[Tuple[int, int]] = []
    if not seed_args:
        return seeds
    for raw in seed_args:
        parts = raw.split(",")
        if len(parts) != 2:
            raise ValueError(f"Invalid --seed '{raw}'. Expected format X,Y")
        seeds.append((int(parts[0].strip()), int(parts[1].strip())))
    return seeds


def run_self_test() -> int:
    """Verify exterior white becomes alpha=0 while internal white eyes/apron remain alpha=255."""
    w, h = 128, 128
    img = Image.new("RGB", (w, h), (255, 255, 255))
    draw = ImageDraw.Draw(img)

    # Dark closed outline circle (head)
    draw.ellipse((24, 20, 104, 100), fill=(255, 220, 200), outline=(22, 16, 28), width=4)
    # White eyes (sclera) with dark pupils inside
    draw.ellipse((42, 46, 56, 62), fill=(255, 255, 255), outline=(22, 16, 28), width=2)
    draw.ellipse((72, 46, 86, 62), fill=(255, 255, 255), outline=(22, 16, 28), width=2)
    draw.ellipse((47, 51, 52, 57), fill=(30, 20, 50))
    draw.ellipse((77, 51, 82, 57), fill=(30, 20, 50))
    # Pure white apron rectangle inside another closed outline at bottom
    draw.rectangle((40, 96, 88, 120), fill=(255, 255, 255), outline=(22, 16, 28), width=3)

    result = remove_white_background(img, tolerance=28, defringe_passes=2)

    corner_a = result.getpixel((0, 0))[3]
    outer_a = result.getpixel((10, 10))[3]
    left_eye_white = result.getpixel((45, 50))
    right_eye_white = result.getpixel((75, 50))
    apron_white = result.getpixel((64, 108))
    outline_px = result.getpixel((64, 21))

    assert corner_a == 0, f"Corner must be transparent, got alpha={corner_a}"
    assert outer_a == 0, f"Outer white must be transparent, got alpha={outer_a}"
    assert left_eye_white == (255, 255, 255, 255), f"Left eye sclera perforated/modified: {left_eye_white}"
    assert right_eye_white == (255, 255, 255, 255), f"Right eye sclera perforated/modified: {right_eye_white}"
    assert apron_white == (255, 255, 255, 255), f"Internal white apron perforated/modified: {apron_white}"
    assert outline_px[3] == 255, f"Outline alpha unexpectedly eroded: {outline_px}"

    print("[PASS] process_white_bg self-test passed:")
    print(f"  - Exterior corner alpha: {corner_a}")
    print(f"  - Left/Right eye white RGBA: {left_eye_white} / {right_eye_white}")
    print(f"  - Internal white apron RGBA: {apron_white}")
    print(f"  - Outline pixel RGBA: {outline_px}")
    return 0


def process_path(
    input_path: Path,
    category: str,
    asset_id: str | None,
    tolerance: int,
    chroma_tol: int,
    defringe: int,
    seeds: list[Tuple[int, int]],
    trim: bool,
    pad: int,
) -> list[Path]:
    base_out = CATEGORY_DIRS[category]
    target_dir = base_out / asset_id if asset_id else base_out
    target_dir.mkdir(parents=True, exist_ok=True)

    if input_path.is_file():
        files = [input_path]
    elif input_path.is_dir():
        files = sorted(p for p in input_path.iterdir() if p.is_file() and p.suffix.lower() in SUPPORTED_EXTS)
    else:
        raise FileNotFoundError(f"Input path not found: {input_path}")

    if not files:
        raise FileNotFoundError(f"No supported image files found in: {input_path}")

    written: list[Path] = []
    for src in files:
        with Image.open(src) as im:
            clean = remove_white_background(
                im,
                tolerance=tolerance,
                chroma_tolerance=chroma_tol,
                defringe_passes=defringe,
                extra_seeds=seeds,
                trim=trim,
                pad=pad,
            )
        out_file = target_dir / f"{src.stem}.png"
        clean.save(out_file, format="PNG")
        rel = out_file.relative_to(PROJECT_ROOT).as_posix()
        print(f"[OK] {src.name} -> res://{rel} ({clean.width}x{clean.height})")
        written.append(out_file)
    return written


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert white-background art into transparent Godot PNG assets.")
    parser.add_argument("input", nargs="?", help="Input image file or directory (e.g. raw_assets/trixie/)")
    parser.add_argument(
        "--category",
        choices=sorted(CATEGORY_DIRS.keys()),
        help="Target res://assets/ category folder",
    )
    parser.add_argument("--id", dest="asset_id", default=None, help="Optional subfolder ID (e.g. trixie, sylvi)")
    parser.add_argument("--tolerance", type=int, default=28, help="White distance tolerance (0-100, default 28)")
    parser.add_argument("--chroma-tol", type=int, default=26, help="Max RGB channel spread for white detection (default 26)")
    parser.add_argument("--defringe", type=int, default=2, help="Edge halo decontamination passes (default 2)")
    parser.add_argument("--seed", action="append", help="Extra X,Y seed for closed outer loops (e.g. between arm and hip)")
    parser.add_argument("--trim", action="store_true", help="Auto-crop excess transparent margins")
    parser.add_argument("--pad", type=int, default=8, help="Padding pixels when --trim is active (default 8)")
    parser.add_argument("--self-test", action="store_true", help="Run built-in verification test and exit")

    args = parser.parse_args()
    if args.self_test:
        return run_self_test()

    if not args.input or not args.category:
        parser.error("Both <input> and --category are required unless --self-test is used.")

    seeds = _parse_seeds(args.seed)
    process_path(
        input_path=Path(args.input),
        category=args.category,
        asset_id=args.asset_id,
        tolerance=args.tolerance,
        chroma_tol=args.chroma_tol,
        defringe=args.defringe,
        seeds=seeds,
        trim=args.trim,
        pad=args.pad,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
