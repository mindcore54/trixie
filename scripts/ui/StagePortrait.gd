class_name StagePortrait
extends TextureRect
## Un retrato de medio cuerpo dentro de un diálogo con varios interlocutores.
## Cuando habla se muestra grande y brillante; cuando calla se achica y se oscurece.
## El movimiento (entrada, foco, rebote, sacudida) se hace por código sobre el sprite real.

const BASE_SCALE: float = 1.0
const INACTIVE_SCALE: float = 0.8
const INACTIVE_DIM: float = 0.42
const SLIDE_DISTANCE: float = 110.0

var member_id: StringName = &""
var kind: String = "witch"
var side: String = "left"
var feet_x: float = 0.0
var feet_y: float = 1080.0
var focus: float = 0.0
var appear: float = 0.0
var pop: float = 0.0

var _emotion: String = ""
var _slide_dir: float = -1.0
var _time: float = 0.0
var _shake_left: float = 0.0
var _focus_tween: Tween = null
var _move_tween: Tween = null


func setup(id: StringName, art_kind: String, lane: String) -> void:
	member_id = id
	kind = art_kind
	side = lane
	_slide_dir = -1.0 if lane == "left" else 1.0
	modulate.a = 0.0


func set_emotion(emotion: String) -> void:
	if emotion == _emotion:
		return
	var first_time: bool = _emotion == ""
	_emotion = emotion
	var tex: Texture2D = _texture_for(emotion)
	if tex != null:
		texture = tex
		size = tex.get_size() * BASE_SCALE
		pivot_offset = Vector2(size.x * 0.5, size.y)
	if not first_time:
		pulse()


func set_focused(on: bool, seconds: float) -> void:
	z_index = 2 if on else 1
	if _focus_tween != null:
		_focus_tween.kill()
	_focus_tween = create_tween()
	_focus_tween.tween_property(self, "focus", 1.0 if on else 0.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func move_to(x: float, seconds: float) -> void:
	if _move_tween != null:
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(self, "feet_x", x, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func appear_in(seconds: float) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "appear", 1.0, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func disappear(seconds: float) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "appear", 0.0, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func pulse() -> void:
	pop = 1.0
	var tw: Tween = create_tween()
	tw.tween_property(self, "pop", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func shake(seconds: float) -> void:
	_shake_left = seconds


func _texture_for(emotion: String) -> Texture2D:
	if kind == "customer":
		return CharacterArt.get_customer_halfbody(member_id, emotion)
	if member_id == &"trixie":
		return CharacterArt.get_trixie_halfbody(emotion)
	return null


func _process(delta: float) -> void:
	_time += delta
	var shake_x: float = 0.0
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		shake_x = sin(_time * 70.0) * 9.0
	var s: float = lerpf(INACTIVE_SCALE, 1.0, focus)
	scale = Vector2(s * (1.0 - pop * 0.03), s * (1.0 + pop * 0.05))
	var dim: float = lerpf(INACTIVE_DIM, 1.0, focus)
	modulate = Color(dim, dim, dim, appear)
	var bob: float = sin(_time * 2.4) * 3.0 * focus
	var slide: float = (1.0 - appear) * _slide_dir * SLIDE_DISTANCE
	position = Vector2(feet_x - size.x * 0.5 + slide + shake_x, feet_y - size.y + bob)
