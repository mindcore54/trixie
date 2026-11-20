class_name WitchCharacterData
extends Resource
## Data-driven definition for playable witches and kindred archetypes (druids, shamans, dark alchemists).

@export var witch_id: StringName = &""
@export var display_name: String = ""
@export var archetype_title: String = ""
@export_multiline var short_bio: String = ""

@export_group("Stats")
@export var move_speed: float = 340.0
@export var brew_speed_mult: float = 1.0
@export var carry_capacity: int = 2
@export var max_stability_hearts: int = 3

@export_group("Abilities")
@export var passive_name: String = ""
@export_multiline var passive_description: String = ""
@export var active_name: String = ""
@export_multiline var active_description: String = ""
@export var active_cooldown_sec: float = 18.0
@export var unlock_essence_cost: int = 0

@export_group("Visual Assets")
@export var chibi_sprite_sheet: Texture2D
@export var portrait_normal: Texture2D
@export var portrait_confiada: Texture2D
@export var portrait_nerviosa: Texture2D
@export var portrait_sonrojada: Texture2D
@export var portrait_hollin: Texture2D
@export var cutin_illustration: Texture2D
