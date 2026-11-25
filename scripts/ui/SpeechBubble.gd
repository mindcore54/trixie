@tool
class_name SpeechBubble
extends Control
## Reusable parchment speech bubble prefab with optional right-flipped tail,
## tutorial highlight, and smooth pop-in / fade-out transitions.

const BODY_HEIGHT: float = 180.0
const BODY_WIDTH_FULL: float = 388.0

@export var flip_tail_right: bool = false:
	set(value):
		flip_tail_right = value
		if is_node_ready():
			_apply_flip()

@export var default_title_color: Color = Color(0.68, 0.14, 0.34, 1.0)
@export var tutorial_title_color: Color = Color(0.62, 0.30, 0.04, 1.0)
@export var tutorial_bg_tint: Color = Color(1.0, 0.97, 0.88, 1.0)

@onready var _bg_rect: TextureRect = $Background
@onready var _title_lbl: Label = $TitleLabel
@onready var _body_lbl: Label = $BodyLabel

var base_position: Vector2 = Vector2.ZERO
var _base_position_set: bool = false
var is_showing: bool = false
var is_tutorial_mode: bool = false
var _timer: float = 0.0
var _tween: Tween = null


func _ready() -> void:
	_apply_flip()
	_sync_shadow_size()
	if not resized.is_connected(_sync_shadow_size):
		resized.connect(_sync_shadow_size)
	if Engine.is_editor_hint():
		return
	if not _base_position_set:
		base_position = position


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	tick(delta)


func _apply_flip() -> void:
	if _bg_rect != null:
		_bg_rect.flip_h = flip_tail_right


func _sync_shadow_size() -> void:
	if _bg_rect != null and _bg_rect.material is ShaderMaterial:
		(_bg_rect.material as ShaderMaterial).set_shader_parameter("render_size", _bg_rect.size)


func set_base_position(pos: Vector2) -> void:
	base_position = pos
	_base_position_set = true
	position = pos


func show_message(title: String, body: String, duration: float = 3.2, tutorial_mode: bool = false) -> void:
	if body == "":
		return
	var was_hidden: bool = not is_showing or not visible
	is_tutorial_mode = tutorial_mode
	is_showing = true
	_timer = -1.0 if tutorial_mode else maxf(1.8, duration)
	if _title_lbl != null:
		_title_lbl.text = title
		_title_lbl.add_theme_color_override("font_color", tutorial_title_color if tutorial_mode else default_title_color)
	if _body_lbl != null:
		_body_lbl.text = body
		_body_lbl.size = Vector2(BODY_WIDTH_FULL, 118.0)
	if _bg_rect != null:
		_bg_rect.modulate = tutorial_bg_tint if tutorial_mode else Color.WHITE
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = true
	if was_hidden:
		var slide_x: float = 24.0 if flip_tail_right else -24.0
		position = base_position + Vector2(slide_x, 18.0)
		modulate.a = 0.0
	else:
		position = base_position + Vector2(0.0, 8.0)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", base_position, 0.38).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func hide_bubble(instant: bool = false) -> void:
	is_showing = false
	_timer = 0.0
	is_tutorial_mode = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if instant or not visible:
		visible = false
		modulate.a = 1.0
		position = base_position
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void:
		if is_instance_valid(self) and not is_showing:
			visible = false
	)


func tick(delta: float) -> void:
	if is_showing and not is_tutorial_mode and _timer > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			hide_bubble(false)


func has_textures() -> bool:
	return _bg_rect != null and _bg_rect.texture != null and _bg_rect.material is ShaderMaterial
