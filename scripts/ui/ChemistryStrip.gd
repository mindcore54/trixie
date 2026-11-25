class_name ChemistryStrip
extends HBoxContainer
## Standalone HUD strip displaying the active customer's liked, neutral/recipe, and disliked orbs.

@onready var _liked_orb: TextureRect = $LikedOrb
@onready var _single_group: Control = $SingleGroup
@onready var _neutral_orb: TextureRect = $SingleGroup/NeutralOrb
@onready var _mixed_group: Control = $MixedGroup
@onready var _comp_a: TextureRect = $MixedGroup/CompOrbA
@onready var _comp_b: TextureRect = $MixedGroup/CompOrbB
@onready var _disliked_orb: TextureRect = $DislikedSlot/DislikedOrb

var _last_key: String = ""


func reset_cache() -> void:
	_last_key = ""


func set_chemistry(chem: Dictionary, orb_textures: Dictionary) -> void:
	var liked_k: int = int(chem["liked"])
	var neutral_k: int = int(chem["neutral"])
	var disliked_k: int = int(chem["disliked"])
	var key: String = "%d:%d:%d" % [liked_k, neutral_k, disliked_k]
	if key == _last_key:
		return
	_last_key = key

	if _liked_orb != null:
		_liked_orb.texture = orb_textures.get(liked_k, null) as Texture2D
	if _disliked_orb != null:
		_disliked_orb.texture = orb_textures.get(disliked_k, null) as Texture2D

	if ChemistryRules.is_mixed_kind(liked_k):
		if _single_group != null:
			_single_group.visible = false
		if _mixed_group != null:
			_mixed_group.visible = true
		var comps: Array[int] = ChemistryRules.get_recipe_components(liked_k)
		if _comp_a != null:
			_comp_a.texture = orb_textures.get(comps[0], null) as Texture2D
		if _comp_b != null:
			_comp_b.texture = orb_textures.get(comps[1], null) as Texture2D
	else:
		if _single_group != null:
			_single_group.visible = true
		if _mixed_group != null:
			_mixed_group.visible = false
		if _neutral_orb != null:
			_neutral_orb.texture = orb_textures.get(neutral_k, null) as Texture2D
