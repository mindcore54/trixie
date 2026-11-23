#!/usr/bin/env python3
"""
Trixie Prompt Generator: Reusable art-direction prompt builder for consistent
Helltaker-meets-anime character concepts (reference only), single-size portraits,
vertical frameless half-body illustrations, dedicated full-size illustrations,
and alchemy/UI props on pure #FFFFFF backgrounds.
"""

from __future__ import annotations

import argparse
import sys

STYLE_CORE = (
    "2D digital anime illustration in the bold charismatic style of Helltaker mixed with vibrant fantasy anime, "
    "crisp closed dark ink outlines, cel-shaded colors with subtle warm rim highlights, super sexy appealing curvy anatomy "
    "with bold alluring outfit styling (deep cleavage, underboob, sideboob, or sheer accents as fits the character)"
)

WHITE_BG_RULE = (
    "isolated on a completely pure solid white #FFFFFF background, zero background scenery, "
    "no frame or border around the character, no floor cast shadow, closed dark outer silhouette contour "
    "so white eyes/teeth/highlights stay intact"
)

HALFBODY_CORE_KEYS: list[str] = ["normal", "confiada", "nerviosa_sudando"]
HALFBODY_SECONDARY_KEYS: list[str] = ["sonrojada_picante", "hollin_derrota", "sorprendida"]

EMOTIONS: dict[str, str] = {
    "normal": "confident playful half-smile, relaxed alluring posture, bright expressive eyes",
    "confiada": "smug victorious grin, one hand on hip or winking playfully, sparkling aura",
    "nerviosa_sudando": "panicked wide eyes, anime sweat drops, flustered bitten lip, tense shoulders",
    "sonrojada_picante": "heavy rosy blush, teasing bedroom eyes, slight smirk, flirty dynamic pose",
    "hollin_derrota": "comical soot smudges on cheeks and clothes, messy disheveled hair, torn/askew hat or apron, dizzy spiral or shocked anime eyes, cute defeated pose",
    "sorprendida": "wide-eyed cute shock, raised hands or startled tilt, lively anime reaction",
}


def build_concept_prompt(char_id: str, archetype: str, outfit: str) -> str:
    return (
        f"[CONCEPT ART SHEET (REFERENCE ONLY — DO NOT USE AS IN-GAME FULLBODY) :: {char_id}]\n"
        f"Character design reference sheet titled '{char_id.capitalize()} - Concept Art' of {archetype}, wearing {outfit}. "
        f"Includes front full-body view, back full-body view, large expressive face close-up, and clear outfit/accessory callouts. "
        f"{STYLE_CORE}, {WHITE_BG_RULE}."
    )


def build_portrait_pack(char_id: str, archetype: str, outfit: str) -> str:
    blocks = [f"[PORTRAIT PACK (SINGLE STANDARD SIZE, HEAD & SHOULDERS) :: {char_id}]"]
    for emo_key, emo_desc in EMOTIONS.items():
        blocks.append(
            f"- {char_id}_portrait_{emo_key}.png:\n"
            f"  Head-and-shoulders 2D anime portrait of {archetype}, wearing {outfit}. "
            f"Expression: {emo_desc}. Clean silhouette with no frame. "
            f"{STYLE_CORE}, {WHITE_BG_RULE}."
        )
    return "\n\n".join(blocks)


def build_halfbody_pack(char_id: str, archetype: str, outfit: str) -> str:
    core_list = "\n".join(
        f"  {idx}. {k}: {EMOTIONS[k]}" for idx, k in enumerate(HALFBODY_CORE_KEYS, start=1)
    )
    sec_list = "\n".join(
        f"  {idx}. {k}: {EMOTIONS[k]}" for idx, k in enumerate(HALFBODY_SECONDARY_KEYS, start=1)
    )
    sheet_1 = (
        f"[HALF-BODY SHEET 1 — CORE GAMEPLAY (4:3, 3 FIGURES SIDE-BY-SIDE, FRAMELESS) :: {char_id}]\n"
        f"Aspect ratio 4:3 sheet showing 3 vertical waist-to-mid-thigh-up illustrations of {archetype}, wearing {outfit}, "
        f"arranged cleanly side-by-side with generous white spacing between them (no borders, no boxes, consistent art style across all 3):\n"
        f"{core_list}\n"
        f"Use the '{char_id.capitalize()} - Concept Art' sheet as strict visual reference. "
        f"{STYLE_CORE}, {WHITE_BG_RULE}."
    )
    sheet_2 = (
        f"[HALF-BODY SHEET 2 — SECONDARY REACTIONS (4:3, 3 FIGURES SIDE-BY-SIDE, FRAMELESS) :: {char_id}]\n"
        f"Aspect ratio 4:3 sheet showing 3 vertical waist-to-mid-thigh-up illustrations of {archetype}, wearing {outfit}, "
        f"arranged cleanly side-by-side with generous white spacing between them (no borders, no boxes, matching Sheet 1 style):\n"
        f"{sec_list}\n"
        f"Use the '{char_id.capitalize()} - Concept Art' sheet as strict visual reference. "
        f"{STYLE_CORE}, {WHITE_BG_RULE}."
    )
    return f"{sheet_1}\n\n{sheet_2}"


def build_fullbody_prompt(char_id: str, archetype: str, outfit: str) -> str:
    return (
        f"[DEDICATED FULL-SIZE ILLUSTRATION (9:16 VERTICAL, NOT CONCEPT ART) :: {char_id}]\n"
        f"- {char_id}_fullbody.png (aspect ratio 9:16):\n"
        f"  Dedicated 9:16 vertical full-body 2D anime key illustration of {archetype}, wearing {outfit}. "
        f"Intentional dynamic showcase pose from head to boots with strong personality, sexy appeal, and lively silhouette "
        f"(composed as finished in-game/menu illustration, NOT a neutral turnaround reference sheet). "
        f"Use the '{char_id.capitalize()} - Concept Art' sheet as strict visual reference. "
        f"{STYLE_CORE}, {WHITE_BG_RULE}."
    )


def build_prop_prompt(prop_id: str, desc: str) -> str:
    return (
        f"[ALCHEMY PROP / UI :: {prop_id}]\n"
        f"2.5D slightly tilted top-down stylized fantasy alchemy asset: {desc}. "
        f"Hand-painted cozy-dark wooden/arcane aesthetic with crisp bold dark ink outline matching Helltaker, "
        f"{WHITE_BG_RULE}."
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate standardized art prompts for Trixie.")
    parser.add_argument(
        "--type",
        required=True,
        choices=["concept", "portrait", "halfbody", "fullbody", "prop"],
        help="Asset type: concept (ref only), portrait, halfbody (vertical), fullbody (dedicated), prop",
    )
    parser.add_argument("--id", required=True, help="Character or asset ID (e.g. trixie, sylvi, cauldron)")
    parser.add_argument("--archetype", default="curvy charming fantasy anime witch", help="Character/prop description")
    parser.add_argument("--outfit", default="corset-style witch dress with fitted waist and pointed hat", help="Outfit details")
    args = parser.parse_args()

    if args.type == "concept":
        print(build_concept_prompt(args.id, args.archetype, args.outfit))
    elif args.type == "portrait":
        print(build_portrait_pack(args.id, args.archetype, args.outfit))
    elif args.type == "halfbody":
        print(build_halfbody_pack(args.id, args.archetype, args.outfit))
    elif args.type == "fullbody":
        print(build_fullbody_prompt(args.id, args.archetype, args.outfit))
    elif args.type == "prop":
        print(build_prop_prompt(args.id, args.archetype))
    return 0


if __name__ == "__main__":
    sys.exit(main())
