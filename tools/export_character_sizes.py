"""Export 1:1 Lanczos pre-scaled character sprites & portraits for Trixie (Godot 4.7).

Always backs up full-resolution transparent cutouts into raw_assets/hd_cutouts/<id>/
before overwriting res://assets/ with exact 1:1 display-resolution PNGs so Godot
never introduces downscale shimmering/aliasing.
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

PORTRAIT_TIERS: dict[str, tuple[int, int]] = {
    "cutscene": (590, 510),
    "dialogue": (420, 370),
    "hud": (140, 140),
}

CHIBI_POSES = ["down", "down_right", "up", "up_right"]
CHIBI_HEIGHT = 216
FULLBODY_BOX = (300, 366)


def fit_lanczos(img: Image.Image, max_w: int, max_h: int) -> Image.Image:
    w, h = img.size
    scale = min(max_w / max(1, w), max_h / max(1, h))
    nw = max(1, int(round(w * scale)))
    nh = max(1, int(round(h * scale)))
    return img.resize((nw, nh), Image.Resampling.LANCZOS)


def height_lanczos(img: Image.Image, target_h: int) -> Image.Image:
    w, h = img.size
    scale = target_h / max(1, h)
    nw = max(1, int(round(w * scale)))
    return img.resize((nw, target_h), Image.Resampling.LANCZOS)


def crop_hud_square_lanczos(img: Image.Image, size: int = 140) -> Image.Image:
    """Create a tight face-focused square portrait crop (concept-art style) for the HUD bust.

    Zooms into the face & shoulders (allowing the tall hat tip / outer hair to crop cleanly)
    so facial expressions remain large and readable inside a 140x140 square frame.
    """
    w, h = img.size
    side = int(round(min(w, h) * 0.66))
    cx = int(round(w * 0.52))
    cy = int(round(h * 0.66))
    x0 = max(0, min(w - side, cx - side // 2))
    y0 = max(0, min(h - side, cy - side // 2))
    cropped = img.crop((x0, y0, x0 + side, y0 + side))
    return cropped.resize((size, size), Image.Resampling.LANCZOS)


def export_character(
    char_id: str,
    category: str,
    flip_portraits: bool,
    flip_chibi_diags: bool,
) -> None:
    root = Path(__file__).resolve().parent.parent
    asset_dir = root / "assets" / "characters" / category / char_id
    hd_dir = root / "raw_assets" / "hd_cutouts" / char_id
    hd_dir.mkdir(parents=True, exist_ok=True)

    # 1. Ensure HD backups exist (never overwrite an existing HD backup with a small file)
    for png in sorted(asset_dir.glob("*.png")):
        backup = hd_dir / png.name
        if not backup.exists():
            shutil.copy2(png, backup)
            print(f"[backup HD] {backup.relative_to(root)}")

    # 2. Export 3 exact portrait tiers (cutscene, dialogue, hud)
    for emo in EXPRESSIONS:
        src = hd_dir / f"{char_id}_{emo}.png"
        if not src.exists():
            print(f"[skip] missing {src.name}")
            continue
        im = Image.open(src).convert("RGBA")
        if flip_portraits:
            im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        for tier, (mw, mh) in PORTRAIT_TIERS.items():
            out_dir = asset_dir / "portraits" / tier
            out_dir.mkdir(parents=True, exist_ok=True)
            if tier == "hud":
                out_img = crop_hud_square_lanczos(im, mw)
            else:
                out_img = fit_lanczos(im, mw, mh)
            out_path = out_dir / f"{char_id}_{emo}.png"
            out_img.save(out_path, "PNG", optimize=True)
            print(f"[portrait/{tier}] {out_path.name} -> {out_img.size}")

        # Remove old unscaled root portrait so Godot doesn't import duplicate HD copies
        old_root = asset_dir / f"{char_id}_{emo}.png"
        if old_root.exists():
            old_root.unlink()
            old_imp = Path(str(old_root) + ".import")
            if old_imp.exists():
                old_imp.unlink()

    # 3. Export 1:1 Chibi 2.5D sprites (exact gameplay height)
    for pose in CHIBI_POSES:
        src = hd_dir / f"{char_id}_chibi_{pose}.png"
        if not src.exists():
            continue
        im = Image.open(src).convert("RGBA")
        if flip_chibi_diags and pose in ("down_right", "up_right"):
            im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        out_img = height_lanczos(im, CHIBI_HEIGHT)
        out_path = asset_dir / f"{char_id}_chibi_{pose}.png"
        out_img.save(out_path, "PNG", optimize=True)
        print(f"[chibi] {out_path.name} -> {out_img.size} (flipped={flip_chibi_diags and pose in ('down_right', 'up_right')})")

    # 4. Export 1:1 Full-body illustration for Build Screen
    fb_src = hd_dir / f"{char_id}_fullbody.png"
    if fb_src.exists():
        im = Image.open(fb_src).convert("RGBA")
        out_img = fit_lanczos(im, FULLBODY_BOX[0], FULLBODY_BOX[1])
        out_path = asset_dir / f"{char_id}_fullbody.png"
        out_img.save(out_path, "PNG", optimize=True)
        print(f"[fullbody] {out_path.name} -> {out_img.size}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Export 1:1 Lanczos character sizes for Godot.")
    parser.add_argument("--id", required=True, help="Character id (e.g. trixie)")
    parser.add_argument("--category", default="playable", choices=["playable", "customers"])
    parser.add_argument("--flip-portraits", action="store_true", help="Mirror portraits horizontally (e.g. to face right)")
    parser.add_argument("--flip-chibi-diags", action="store_true", help="Mirror down_right/up_right chibis horizontally")
    args = parser.parse_args()
    export_character(args.id, args.category, args.flip_portraits, args.flip_chibi_diags)


if __name__ == "__main__":
    main()
