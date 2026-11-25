class_name CharacterStageSlot
extends Control
## Base stage slot that renders a real TextureRect sprite (no preview ghosts)
## and animates squash/stretch, breathing bob, and optional slide offsets.

@onready var sprite_rect: TextureRect = $SpriteRect

var _extra_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_update_pivot()
	if not resized.is_connected(_update_pivot):
		resized.connect(_update_pivot)


func _update_pivot() -> void:
	if sprite_rect != null:
		sprite_rect.pivot_offset = Vector2(size.x * 0.5, size.y)


func apply_texture(tex: Texture2D) -> void:
	if sprite_rect == null:
		return
	if sprite_rect.texture != tex:
		sprite_rect.texture = tex
	sprite_rect.visible = (tex != null)


func apply_motion(off_x: float, off_y: float, sx: float, sy: float, bob: float, dim: float = 1.0) -> void:
	if sprite_rect == null:
		return
	sprite_rect.position = Vector2(roundf(off_x + _extra_offset.x), roundf(bob + off_y + _extra_offset.y))
	sprite_rect.scale = Vector2(sx, sy)
	sprite_rect.self_modulate = Color(dim, dim, dim, 1.0)
