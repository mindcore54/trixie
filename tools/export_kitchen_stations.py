"""Slice and export 1:1 Lanczos transparent 2.5D station sprites for Trixie (Godot 4.7).

Reads:
  - raw_assets/kitchen_assets1.png  (2x2 sheet: cauldron, mortar, bottling, vitrina)
  - raw_assets/kitchen_assets2a.png (unified 3-bin empty table + pallet + open recycling trash)
  - raw_assets/kitchen_assets2b.png (3 pixel-aligned ingredient fill piles)

Writes 10 exact 1:1 RGBA PNGs into assets/props/stations/:
  station_cauldron.png, station_mortar.png, station_bottling.png, station_vitrina.png,
  station_pallet.png, station_trash.png, station_bins_table_empty.png,
  station_ing_red.png, station_ing_blue.png, station_ing_green.png
"""

from __future__ import annotations

from pathlib import Path
from PIL import Image


def resize_by_height(im: Image.Image, target_h: int) -> Image.Image:
    w, h = im.size
    target_w = max(1, int(round(w * (target_h / max(1, h)))))
    return im.resize((target_w, target_h), Image.Resampling.LANCZOS)


def resize_by_scale(im: Image.Image, scale: float) -> Image.Image:
    w, h = im.size
    nw = max(1, int(round(w * scale)))
    nh = max(1, int(round(h * scale)))
    return im.resize((nw, nh), Image.Resampling.LANCZOS)


def export_all() -> None:
    root = Path(__file__).resolve().parent.parent
    raw_dir = root / "raw_assets"
    out_dir = root / "assets" / "props" / "stations"
    out_dir.mkdir(parents=True, exist_ok=True)

    # Remove obsolete split bin files if present
    for old_path in sorted(out_dir.glob("station_bin_*")):
        old_path.unlink()
        print(f"[cleanup] removed {old_path.name}")

    # 1. Sheet 1: Cauldron, Mortar, Bottling, Vitrina
    s1 = Image.open(raw_dir / "kitchen_assets1.png").convert("RGBA")
    sheet1_specs: list[tuple[str, tuple[int, int, int, int], int]] = [
        ("station_cauldron.png", (568, 107, 1121, 685), 182),
        ("station_mortar.png", (1745, 189, 2229, 633), 146),
        ("station_bottling.png", (496, 807, 1190, 1461), 186),
        ("station_vitrina.png", (1844, 785, 2193, 1463), 184),
    ]
    for fname, box, target_h in sheet1_specs:
        cropped = s1.crop(box)
        out = resize_by_height(cropped, target_h)
        out.save(out_dir / fname, "PNG", optimize=True)
        print(f"[export] {fname}: raw={cropped.size} -> 1:1={out.size}")

    # 2. Sheet 2a & 2b: Unified 3-bin table, Pallet, Trash, and 3 separated ingredient piles
    s2a = Image.open(raw_dir / "kitchen_assets2a.png").convert("RGBA")
    s2b = Image.open(raw_dir / "kitchen_assets2b.png").convert("RGBA")
    assert s2a.size == s2b.size, f"2a vs 2b canvas mismatch: {s2a.size} vs {s2b.size}"

    scale_2 = 0.80
    pallet_raw = s2a.crop((592, 91, 917, 254))
    pallet_out = resize_by_scale(pallet_raw, scale_2)
    pallet_out.save(out_dir / "station_pallet.png", "PNG", optimize=True)
    print(f"[export] station_pallet.png: raw={pallet_raw.size} -> 1:1={pallet_out.size}")

    trash_raw = s2a.crop((1014, 0, 1248, 279))
    trash_out = resize_by_height(trash_raw, 100)
    trash_out.save(out_dir / "station_trash.png", "PNG", optimize=True)
    print(f"[export] station_trash.png: raw={trash_raw.size} -> 1:1={trash_out.size}")

    # Untouched unified 3-bin empty wooden table
    table_box = (0, 66, 550, 258)
    table_raw = s2a.crop(table_box)
    table_out = resize_by_scale(table_raw, scale_2)
    table_out.save(out_dir / "station_bins_table_empty.png", "PNG", optimize=True)
    tcx = (table_box[0] + table_box[2]) * 0.5
    tcy = (table_box[1] + table_box[3]) * 0.5
    print(f"[export] station_bins_table_empty.png: raw={table_raw.size} -> 1:1={table_out.size}")

    # Only the 3 separated ingredient piles from kitchen_assets2b.png
    fill_boxes: dict[str, tuple[int, int, int, int]] = {
        "red": (14, 49, 188, 169),
        "blue": (197, 47, 360, 163),
        "green": (374, 73, 525, 163),
    }
    for col, fb in fill_boxes.items():
        ing_raw = s2b.crop(fb)
        ing_out = resize_by_scale(ing_raw, scale_2)
        fname = f"station_ing_{col}.png"
        ing_out.save(out_dir / fname, "PNG", optimize=True)
        icx = (fb[0] + fb[2]) * 0.5
        icy = (fb[1] + fb[3]) * 0.5
        dx = (icx - tcx) * scale_2
        dy = (icy - tcy) * scale_2
        print(f"[export] {fname}: raw={ing_raw.size} -> 1:1={ing_out.size} offset_from_table=({dx:+.2f}, {dy:+.2f})")


if __name__ == "__main__":
    export_all()
