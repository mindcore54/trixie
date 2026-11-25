@tool
class_name OrderBubble
extends Control
## Standalone parchment order bubble prefab displaying either a single target orb
## or a mixed-color orb with its two-ingredient recipe row.

@onready var _bg_tex: TextureRect = $BackgroundTexture
@onready var _single_orb: TextureRect = $SingleOrderOrb
@onready var _mixed_group: Control = $MixedOrderGroup
@onready var _mixed_result_orb: TextureRect = $MixedOrderGroup/MixedResultOrb
@onready var _comp_a: TextureRect = $MixedOrderGroup/RecipeRow/CompOrbA
@onready var _comp_b: TextureRect = $MixedOrderGroup/RecipeRow/CompOrbB

var _last_kind: int = -1


func _ready() -> void:
	_sync_shadow_size()
	if not resized.is_connected(_sync_shadow_size):
		resized.connect(_sync_shadow_size)
	if _bg_tex != null and not _bg_tex.resized.is_connected(_sync_shadow_size):
		_bg_tex.resized.connect(_sync_shadow_size)


func _sync_shadow_size() -> void:
	if _bg_tex != null and _bg_tex.material is ShaderMaterial:
		(_bg_tex.material as ShaderMaterial).set_shader_parameter("render_size", _bg_tex.size)


func reset_order() -> void:
	_last_kind = -1


func set_order(liked_kind: int, orb_textures: Dictionary) -> void:
	if liked_kind == _last_kind:
		return
	_last_kind = liked_kind
	if ChemistryRules.is_mixed_kind(liked_kind):
		if _single_orb != null:
			_single_orb.visible = false
		if _mixed_group != null:
			_mixed_group.visible = true
		if _mixed_result_orb != null:
			_mixed_result_orb.texture = orb_textures.get(liked_kind, null) as Texture2D
		var comps: Array[int] = ChemistryRules.get_recipe_components(liked_kind)
		if _comp_a != null:
			_comp_a.texture = orb_textures.get(comps[0], null) as Texture2D
		if _comp_b != null:
			_comp_b.texture = orb_textures.get(comps[1], null) as Texture2D
	else:
		if _single_orb != null:
			_single_orb.visible = true
			_single_orb.texture = orb_textures.get(liked_kind, null) as Texture2D
		if _mixed_group != null:
			_mixed_group.visible = false
