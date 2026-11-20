#!/usr/bin/env python3
"""
Trixie Prompt Generator: Reusable art-direction prompt builder for consistent
Helltaker-meets-anime character concepts, 6-emotion portrait packs, 2.5D semi-chibi
in-game sprites, and kitchen/UI props on pure #FFFFFF backgrounds.
"""

from __future__ import annotations

import argparse
import sys

STYLE_CORE = (
    "2D digital anime illustration in the bold charismatic style of Helltaker mixed with vibrant fantasy anime, "
    "crisp closed dark ink outlines, cel-shaded colors with subtle warm rim highlights, expressive appealing curvy anatomy, "
    "stream-friendly suggestive ecchi aesthetic (no nudity, no NSFW explicit details)"
)

WHITE_BG_RULE = (
    "isolated on a completely pure solid white #FFFFFF background, zero background scenery, "
    "no floor cast shadow, closed dark outer silhouette contour so white eyes/teeth/highlights stay intact"
)

EMOTIONS: dict[str, str] = {
    "normal": "confident playful half-smile, relaxed alluring posture, bright expressive eyes",
    "confiada": "smug victorious grin, one hand on hip or winking playfully, sparkling aura",
    "nerviosa_sudando": "panicked wide eyes, anime sweat drops, flustered bitten lip, tense shoulders",
    "sonrojada_picante": "heavy rosy blush, teasing bedroom eyes, slight smirk, flirty dynamic pose",
    "hollin_derrota": "comical soot smudges on cheeks and clothes, messy disheveled hair, torn/askew hat or apron, dizzy spiral or shocked anime eyes, cute defeated pose",
    "cutin_habilidad": "ultra-dynamic anime special-attack cut-in framing, dramatic wind in hair, glowing arcane energy, intense confident gaze",
}


def build_concept_prompt(char_id: str, archetype: str, outfit: str) -> str:
    return (
        f"[CONCEPT SHEET :: {char_id}]\n"
        f"Full-body character design sheet of {archetype}, wearing {outfit}. "
        f"Clean front-3/4 standing hero pose showing full silhouette, proportions, and outfit details clearly from head to boots. "
        f"{STYLE_CORE}, {WHITE_BG_RULE}."
    )


def build_portrait_pack(char_id: str, archetype: str, outfit: str, framing: str) -> str:
    blocks = [f"[PORTRAIT PACK ({framing.upper()}) :: {char_id}]"]
    for emo_key, emo_desc in EMOTIONS.items():
        blocks.append(
            f"- {char_id}_{emo_key}.png:\n"
            f"  {framing} 2D anime portrait of {archetype}, wearing {outfit}. "
            f"Expression & pose: {emo_desc}. "
            f"{STYLE_CORE}, {WHITE_BG_RULE}."
        )
    return "\n\n".join(blocks)


def build_chibi_prompt(char_id: str, archetype: str, outfit: str) -> str:
    poses = {
        "idle": "standing ready idle pose with subtle cheerful bounce, facing slightly toward front-right",
        "move_a": "energetic mid-step running pose with hair and skirt/cape flowing back",
        "move_b": "alternate stride running pose, lively arms, matching scale and proportions",
        "action": "stirring/brewing magical gesture with hands raised forward",
    }
    blocks = [f"[2.5D SEMI-CHIBI IN-GAME SPRITES (~3 HEADS TALL) :: {char_id}]"]
    for pose_key, pose_desc in poses.items():
        blocks.append(
            f"- {char_id}_chibi_{pose_key}.png:\n"
            f"  2.5D top-down tilted 3/4 view game sprite of {archetype} in stylized semi-chibi ~3-head-tall proportions, "
            f"preserving attractive curvy waist and clear outfit cleavage/silhouette, wearing {outfit}. "
            f"Pose: {pose_desc}. Crisp bold outline readable at gameplay scale, {STYLE_CORE}, {WHITE_BG_RULE}."
        )
    return "\n\n".join(blocks)


def build_prop_prompt(prop_id: str, desc: str) -> str:
    return (
        f"[2.5D PROP / UI :: {prop_id}]\n"
        f"2.5D top-down tilted 3/4 view stylized fantasy alchemy asset: {desc}. "
        f"Hand-painted cozy-dark wooden/arcane aesthetic with crisp bold dark ink outline matching Helltaker/Cake Mania, "
        f"{WHITE_BG_RULE}."
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate standardized art prompts for Trixie.")
    parser.add_argument("--type", required=True, choices=["concept", "portraits", "chibi", "prop"])
    parser.add_argument("--id", required=True, help="Character or asset ID (e.g. trixie, sylvi, cauldron)")
    parser.add_argument("--archetype", default="curvy charming fantasy anime witch", help="Character/prop description")
    parser.add_argument("--outfit", default="corset-style witch dress with fitted waist and pointed hat", help="Outfit details")
    parser.add_argument("--framing", default="chest-up bust", help="Framing for portraits (chest-up bust / waist-up large portrait)")
    args = parser.parse_args()

    if args.type == "concept":
        print(build_concept_prompt(args.id, args.archetype, args.outfit))
    elif args.type == "portraits":
        print(build_portrait_pack(args.id, args.archetype, args.outfit, args.framing))
    elif args.type == "chibi":
        print(build_chibi_prompt(args.id, args.archetype, args.outfit))
    elif args.type == "prop":
        print(build_prop_prompt(args.id, args.archetype))
    return 0


if __name__ == "__main__":
    sys.exit(main())
