class_name CustomerStageSlot
extends CharacterStageSlot
## Customer stage slot (right side) with independent slide-in entrance and reaction animations.

@export var slide_in_distance: float = 140.0


func update_customer(customer_id: StringName, emotion: String, t: float, react_progress: float, slide_t: float, dim: float = 1.0) -> void:
	_extra_offset = Vector2((1.0 - slide_t) * slide_in_distance, 0.0)
	var tex: Texture2D = CharacterArt.get_customer_halfbody(customer_id, emotion)
	apply_texture(tex)
	if tex == null:
		return
	var p: float = clampf(react_progress, 0.0, 1.0)
	var pop: float = sin(p * PI)
	var off_x: float = 0.0
	var off_y: float = -pop * 6.0
	var sx: float = 1.0
	var sy: float = 1.0
	var bob: float = roundf(sin(t * 1.8) * 3.0)
	match emotion:
		"sonrojada", "sonrojada_picante":
			off_x = sin(t * 2.0) * 3.0
			off_y = -pop * 8.0
			sx = 1.0 + pop * 0.025
			sy = 1.0 + pop * 0.025
			bob = roundf(sin(t * 1.9) * 3.0)
		"impaciente", "molesta":
			off_x = sin(t * 36.0) * 5.0 * p
			off_y = -pop * 9.0
			sx = 1.0 - pop * 0.02
			sy = 1.0 + pop * 0.03
			bob = roundf(sin(t * 2.4) * 2.0)
	apply_motion(off_x, off_y, sx, sy, bob, dim)


func clear_customer() -> void:
	if sprite_rect != null:
		sprite_rect.visible = false
