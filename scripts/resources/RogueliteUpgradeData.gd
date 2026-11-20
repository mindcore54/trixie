class_name RogueliteUpgradeData
extends Resource
## Data-driven roguelite card, relic, or familiar offered between shift waves.

enum UpgradeKind {
	RELIC_PASSIVE,
	FAMILIAR_SUMMON,
	ACTIVE_SKILL,
	STATION_UPGRADE,
	CURSED_PACT,
}

enum Rarity {
	COMMON,
	RARE,
	EPIC,
	BROKEN_SYNERGY,
}

@export var upgrade_id: StringName = &""
@export var display_name: String = ""
@export var kind: UpgradeKind = UpgradeKind.RELIC_PASSIVE
@export var rarity: Rarity = Rarity.COMMON
@export var synergy_tags: PackedStringArray = []
@export_multiline var description: String = ""
@export var icon_texture: Texture2D
@export var max_stacks: int = 3
@export var effect_params: Dictionary = {}
