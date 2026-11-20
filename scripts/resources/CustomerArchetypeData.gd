class_name CustomerArchetypeData
extends Resource
## Data-driven definition for shop customers, their preferences, patience, and spicy dialogue pools.

@export var customer_id: StringName = &""
@export var display_name: String = ""
@export var species_archetype: String = ""
@export var is_vip_boss: bool = false

@export_group("Behavior")
@export var base_patience_sec: float = 28.0
@export var tip_generosity_mult: float = 1.0
@export var preferred_recipes: Array[StringName] = []

@export_group("Portraits")
@export var chibi_sprite: Texture2D
@export var portrait_normal: Texture2D
@export var portrait_happy: Texture2D
@export var portrait_impatient: Texture2D
@export var portrait_spicy_blush: Texture2D

@export_group("Dialogues")
@export var greeting_lines: PackedStringArray = []
@export var satisfied_lines: PackedStringArray = []
@export var spicy_affinity_lines: PackedStringArray = []
@export var impatient_lines: PackedStringArray = []
@export var display_tempted_lines: PackedStringArray = []
