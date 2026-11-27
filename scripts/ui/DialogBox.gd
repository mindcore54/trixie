@tool
class_name DialogBox
extends Control
## Reusable wide antique parchment dialogue box with shader drop shadow, typewriter reveal,
## pulsing continue prompt, and smooth entrance animation.

signal typewriter_tick(char_index: int)

@export var chars_per_sec: float = 52.0
@export var continue_prompt: String = "Clic / Espacio para continuar ▾"
@export var body_font_size: int = 28
@export var entrance_offset: Vector2 = Vector2(-150.0, 90.0)
@export var entrance_fade_duration: float = 0.55
@export var entrance_slide_duration: float = 0.72

@onready var _bg_rect: TextureRect = $Background
@onready var _speaker_lbl: Label = $TextShadowGroup/SpeakerLabel
@onready var _body_lbl: RichTextLabel = $TextShadowGroup/BodyLabel
@onready var _continue_lbl: Label = $ContinueLabel

var base_position: Vector2 = Vector2.ZERO
var _base_position_set: bool = false
var _full_text: String = ""
var _total_chars: int = 0
var _shown_chars: float = 0.0
var _pulse_time: float = 0.0
var _entrance_tween: Tween = null


func _ready() -> void:
	_sync_shadow_size()
	if not resized.is_connected(_sync_shadow_size):
		resized.connect(_sync_shadow_size)
	if Engine.is_editor_hint():
		return
	if not _base_position_set:
		base_position = position
	if _continue_lbl != null:
		_continue_lbl.text = continue_prompt
	_apply_body_font_size(body_font_size)


func _sync_shadow_size() -> void:
	if _bg_rect != null and _bg_rect.material is ShaderMaterial:
		(_bg_rect.material as ShaderMaterial).set_shader_parameter("render_size", _bg_rect.size)


func _process(delta: float) -> void:
	if visible and not Engine.is_editor_hint():
		step_typewriter(delta)


func set_base_position(pos: Vector2) -> void:
	base_position = pos
	_base_position_set = true
	position = pos


func set_continue_prompt(prompt_text: String) -> void:
	continue_prompt = prompt_text
	if _continue_lbl != null:
		_continue_lbl.text = prompt_text


func set_body_font_size(font_size: int) -> void:
	body_font_size = font_size
	_apply_body_font_size(font_size)


func _apply_body_font_size(font_size: int) -> void:
	if _body_lbl == null:
		return
	_body_lbl.add_theme_font_size_override("normal_font_size", font_size)
	_body_lbl.add_theme_font_size_override("bold_font_size", font_size)
	_body_lbl.add_theme_font_size_override("italics_font_size", font_size)
	_body_lbl.add_theme_font_size_override("bold_italics_font_size", font_size)


static func format_rich_text(raw_text: String) -> String:
	return DialogueBank.format_rich_text(raw_text)


func show_line(speaker_name: String, speaker_color: Color, body_text: String, animate_entrance: bool = false) -> void:
	if _speaker_lbl != null:
		_speaker_lbl.text = speaker_name
		_speaker_lbl.add_theme_color_override("font_color", speaker_color)
	_full_text = format_rich_text(body_text)
	_shown_chars = 0.0
	_pulse_time = 0.0
	if _body_lbl != null:
		_body_lbl.text = _full_text
		_total_chars = _body_lbl.get_parsed_text().length()
		_body_lbl.visible_characters = 0
	else:
		_total_chars = _full_text.length()
	if _continue_lbl != null:
		_continue_lbl.visible = false
	visible = true
	if animate_entrance:
		play_entrance()


func play_entrance() -> void:
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
	position = base_position + entrance_offset
	modulate.a = 0.0
	_entrance_tween = create_tween()
	_entrance_tween.set_parallel(true)
	_entrance_tween.tween_property(self, "modulate:a", 1.0, entrance_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_entrance_tween.tween_property(self, "position", base_position, entrance_slide_duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func hide_box() -> void:
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
	visible = false
	position = base_position
	modulate.a = 1.0


func is_typing() -> bool:
	return _shown_chars < float(_total_chars)


func complete_typing() -> void:
	_shown_chars = float(_total_chars)
	if _body_lbl != null:
		_body_lbl.visible_characters = -1
	if _continue_lbl != null:
		_continue_lbl.visible = true


func step_typewriter(delta: float) -> void:
	_pulse_time += delta
	if _shown_chars < float(_total_chars):
		var prev_i: int = int(_shown_chars)
		_shown_chars = minf(float(_total_chars), _shown_chars + chars_per_sec * delta)
		var cur_i: int = int(_shown_chars)
		if _body_lbl != null:
			_body_lbl.visible_characters = cur_i
		if cur_i > prev_i and cur_i % 4 == 0:
			typewriter_tick.emit(cur_i)
		if _continue_lbl != null:
			_continue_lbl.visible = false
	else:
		if _continue_lbl != null:
			_continue_lbl.visible = true
			_continue_lbl.modulate.a = 0.55 + 0.45 * absf(sin(_pulse_time * 4.0))


func has_textures() -> bool:
	return _bg_rect != null and _bg_rect.texture != null and _bg_rect.material is ShaderMaterial
