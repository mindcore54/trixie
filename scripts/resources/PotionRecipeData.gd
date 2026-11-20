class_name PotionRecipeData
extends Resource
## Data-driven definition of a potion recipe craftable in the kitchen.

@export var recipe_id: StringName = &""
@export var display_name: String = ""
@export var required_ingredients: Array[StringName] = []
@export var requires_mortar: bool = false
@export var base_brew_time_sec: float = 3.5
@export var overheat_grace_sec: float = 4.0
@export var base_gold_value: int = 35
@export var hot_bonus_multiplier: float = 1.5
@export var unlock_day: int = 1
@export var potion_color: Color = Color.MAGENTA
@export var icon_texture: Texture2D
