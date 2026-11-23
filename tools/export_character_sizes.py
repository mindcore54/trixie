"""Export 1:1 Lanczos pre-scaled character illustrations for Trixie (Godot 4.7).

Current character art standard (3 image types, no multi-size portrait tiers, no chibis):
  1. Portrait (`portraits/`): single standard size for face/shoulders expressions.
  2. Half-body (`halfbody/`): vertical frameless waist/thigh-up illustrations.
  3. Full size (`fullbody/`): dedicated full-body illustration (NOT the concept art sheet).

Always backs up full-resolution transparent cutouts into raw_assets/hd_cutouts/<id>/
before writing 1:1 display-resolution PNGs into res://assets/.
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path
from PIL import Image

EXPRESSIONS = [
    "normal",
    "confiada",
    "nerviosa_sudando",
    "sonrojada_picante",
    "hollin_derrota",
    "sorprendida",
]

PORTRAIT_BOX: tuple[int, int] = (420, 420)
HALFBODY_BOX: tuple[int, int] = (560, 820)
FULLBODY_BOX: tuple[int, int] = (680, 980)


def fit_lanczos(img: Image.Image, max_w: int, max_h: int) -> Image.Image:
    w, h = img.size
    scale = min(max_w / max(1, w), max_h / max(1, h))
    nw = max(1, int(round(w * scale)))
    nh = max(1, int(round(h * scale)))
    return img.resize((nw, nh), Image.Resampling.LANCZOS)


def export_character(
    char_id: str,
    category: str,
    flip_horizontal: bool,
) -> None:
    root = Path(__file__).resolve().parent.parent
    asset_dir = root / "assets" / "characters" / category / char_id
    hd_dir = root / "raw_assets" / "hd_cutouts" / char_id
    hd_dir.mkdir(parents=True, exist_ok=True)

    # 1. Ensure HD backups exist (never overwrite an existing HD backup with a small file)
    if asset_dir.exists():
        for png in sorted(asset_dir.glob("*.png")):
            backup = hd_dir / png.name
            if not backup.exists():
                shutil.copy2(png, backup)
                print(f"[backup HD] {backup.relative_to(root)}")

    # 2. Export single-size Portraits (head & shoulders)
    portrait_out_dir = asset_dir / "portraits"
    for emo in EXPRESSIONS:
        src = hd_dir / f"{char_id}_portrait_{emo}.png"
        if not src.exists():
            src = hd_dir / f"{char_id}_{emo}.png"
        if not src.exists():
            continue
        im = Image.open(src).convert("RGBA")
        if flip_horizontal:
            im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        portrait_out_dir.mkdir(parents=True, exist_ok=True)
        out_img = fit_lanczos(im, PORTRAIT_BOX[0], PORTRAIT_BOX[1])
        out_path = portrait_out_dir / f"{char_id}_{emo}.png"
        out_img.save(out_path, "PNG", optimize=True)
        print(f"[portrait] {out_path.name} -> {out_img.size}")

    # 3. Export vertical frameless Half-Body illustrations
    halfbody_out_dir = asset_dir / "halfbody"
    for emo in EXPRESSIONS:
        src = hd_dir / f"{char_id}_halfbody_{emo}.png"
        if not src.exists():
            continue
        im = Image.open(src).convert("RGBA")
        if flip_horizontal:
            im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        halfbody_out_dir.mkdir(parents=True, exist_ok=True)
        out_img = fit_lanczos(im, HALFBODY_BOX[0], HALFBODY_BOX[1])
        out_path = halfbody_out_dir / f"{char_id}_halfbody_{emo}.png"
        out_img.save(out_path, "PNG", optimize=True)
        print(f"[halfbody] {out_path.name} -> {out_img.size}")

    # Also support a single base halfbody file if expressions aren't split yet
    hb_base = hd_dir / f"{char_id}_halfbody.png"
    if hb_base.exists():
        im = Image.open(hb_base).convert("RGBA")
        if flip_horizontal:
            im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        halfbody_out_dir.mkdir(parents=True, exist_ok=True)
        out_img = fit_lanczos(im, HALFBODY_BOX[0], HALFBODY_BOX[1])
        out_path = halfbody_out_dir / f"{char_id}_halfbody.png"
        out_img.save(out_path, "PNG", optimize=True)
        print(f"[halfbody] {out_path.name} -> {out_img.size}")

    # 4. Export dedicated Full-Size illustration (NOT concept art)
    fb_src = hd_dir / f"{char_id}_fullbody.png"
    if fb_src.exists():
        im = Image.open(fb_src).convert("RGBA")
        if flip_horizontal:
            im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        fb_out_dir = asset_dir / "fullbody"
        fb_out_dir.mkdir(parents=True, exist_ok=True)
        out_img = fit_lanczos(im, FULLBODY_BOX[0], FULLBODY_BOX[1])
        out_path = fb_out_dir / f"{char_id}_fullbody.png"
        out_img.save(out_path, "PNG", optimize=True)
        print(f"[fullbody] {out_path.name} -> {out_img.size}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Export 1:1 Lanczos character sizes for Godot.")
    parser.add_argument("--id", required=True, help="Character id (e.g. trixie, sylvi)")
    parser.add_argument("--category", default="playable", choices=["playable", "customers"])
    parser.add_argument("--flip-portraits", action="store_true", help="Mirror character horizontally (e.g. to face right)")
    args = parser.parse_args()
    export_character(args.id, args.category, args.flip_portraits)


if __name__ == "__main__":
    main()
