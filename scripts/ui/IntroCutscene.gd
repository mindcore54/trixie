class_name IntroCutscene
extends Control
## Visual-novel intro lore cutscene where slightly clumsy Trixie buys her dream potion shop
## from Doña Remedios, using smooth fade-to-black transitions and typewriter dialogue.

const SCRIPT_PATH: String = "res://data/dialogues/intro_cutscene.json"
const CHARS_PER_SEC: float = 52.0

@onready var _stage_canvas: Control = $StageCanvas
@onready var _trixie_portrait: TextureRect = $TrixiePortrait
@onready var _dialog_box: DialogBox = $DialogBox
@onready var _caption_lbl: Label = $CaptionLabel
@onready var _skip_btn: Button = $SkipButton

var _beats: Array = []
var _idx: int = -1
var _time: float = 0.0
var _bg_mode: String = "exterior"
var _show_trixie: bool = false
var _show_remedios: bool = false
var _trixie_emotion: String = "normal"
var _loaded_trixie_emotion: String = ""
var _remedios_emotion: String = "normal"
var _active_speaker: String = ""
var _transitioning: bool = false
var _shake_timer: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO
var _caption_mode: bool = false
var _trixie_base_pos: Vector2 = Vector2(240.0, 286.0)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if _trixie_portrait != null:
		_trixie_base_pos = _trixie_portrait.position
		_trixie_portrait.visible = false
	if _stage_canvas != null:
		_stage_canvas.draw.connect(_draw_stage)
	if _caption_lbl != null:
		_caption_lbl.visible = false
	if _skip_btn != null:
		_skip_btn.pressed.connect(_finish_cutscene)
	if _dialog_box != null:
		_dialog_box.set_base_position(_dialog_box.position)
		_dialog_box.chars_per_sec = CHARS_PER_SEC
		_dialog_box.set_body_font_size(28)
		_dialog_box.set_continue_prompt("Clic / Espacio para continuar ▾")
		_dialog_box.hide_box()
		_dialog_box.typewriter_tick.connect(func(_ci: int) -> void:
			AudioJuiceManager.play_pentatonic(3 if _active_speaker == "trixie" else 1, -12.0)
		)
	_load_beats()
	_advance()


func _load_beats() -> void:
	var f: FileAccess = FileAccess.open(SCRIPT_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		_beats = parsed as Array


func _process(delta: float) -> void:
	_time += delta
	if _shake_timer > 0.0:
		_shake_timer = maxf(0.0, _shake_timer - delta)
		_shake_offset = Vector2(randf_range(-8.0, 8.0), randf_range(-5.0, 5.0))
	else:
		_shake_offset = Vector2.ZERO

	if _trixie_portrait != null:
		var show_portrait: bool = not _caption_mode and _show_trixie
		_trixie_portrait.visible = show_portrait
		if show_portrait:
			if _trixie_emotion != _loaded_trixie_emotion:
				var tex: Texture2D = CharacterArt.get_trixie_expression(_trixie_emotion, "cutscene")
				if tex != null:
					_trixie_portrait.texture = tex
				_loaded_trixie_emotion = _trixie_emotion
			var t_active: bool = _active_speaker == "trixie"
			var t_dim: float = 1.0 if t_active else 0.58
			var t_y_off: float = 0.0 if t_active else 14.0
			var bob: float = roundf(sin(_time * 2.4) * 2.5)
			_trixie_portrait.modulate = Color(t_dim, t_dim, t_dim, 1.0)
			_trixie_portrait.position = _trixie_base_pos + Vector2(0.0, t_y_off + bob) + _shake_offset

	if _stage_canvas != null:
		_stage_canvas.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_advance_input()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.pressed and not kev.echo:
			if kev.keycode == KEY_SPACE or kev.keycode == KEY_ENTER:
				_handle_advance_input()
			elif kev.keycode == KEY_ESCAPE:
				_finish_cutscene()


func _handle_advance_input() -> void:
	if _transitioning or SceneFader.is_busy():
		return
	if not _caption_mode and _dialog_box != null and _dialog_box.is_typing():
		_dialog_box.complete_typing()
		return
	_advance()


func _advance() -> void:
	_idx += 1
	if _idx >= _beats.size():
		_finish_cutscene()
		return

	var beat: Dictionary = _beats[_idx] as Dictionary
	var action: String = String(beat.get("action", ""))
	if action == "caption":
		_show_caption_beat(String(beat.get("text", "")))
		return
	if action == "bg":
		_change_bg_with_fade(String(beat.get("bg", "interior")))
		return
	if action == "show":
		var who: String = String(beat.get("who", ""))
		if who == "trixie":
			_show_trixie = true
		elif who == "remedios":
			_show_remedios = true
		_advance()
		return
	if action == "hide":
		var who_h: String = String(beat.get("who", ""))
		if who_h == "trixie":
			_show_trixie = false
		elif who_h == "remedios":
			_show_remedios = false
		_advance()
		return

	# Dialogue beat
	var was_hidden: bool = _dialog_box != null and not _dialog_box.visible
	_caption_mode = false
	if _caption_lbl != null:
		_caption_lbl.visible = false
	_active_speaker = String(beat.get("speaker", "trixie"))
	var emo: String = String(beat.get("emotion", "normal"))
	var speaker_name: String = "Trixie"
	var speaker_col: Color = Color(0.68, 0.14, 0.34)
	if _active_speaker == "trixie":
		_trixie_emotion = emo
	else:
		_remedios_emotion = emo
		speaker_name = "Doña Remedios"
		speaker_col = Color(0.32, 0.24, 0.50)

	if _dialog_box != null:
		_dialog_box.show_line(speaker_name, speaker_col, String(beat.get("text", "")), was_hidden)
	if bool(beat.get("shake", false)):
		_shake_timer = 0.35
		AudioJuiceManager.play_pentatonic(0, 0.0)


func _show_caption_beat(txt: String) -> void:
	_transitioning = true
	if _idx > 0:
		await SceneFader.fade_out(0.45)
	_caption_mode = true
	if _dialog_box != null:
		_dialog_box.hide_box()
	if _caption_lbl != null:
		_caption_lbl.text = txt
		_caption_lbl.visible = true
	await SceneFader.fade_in(0.45)
	_transitioning = false


func _change_bg_with_fade(new_bg: String) -> void:
	_transitioning = true
	await SceneFader.fade_out(0.45)
	if _dialog_box != null:
		_dialog_box.hide_box()
	_bg_mode = new_bg
	_caption_mode = false
	if _caption_lbl != null:
		_caption_lbl.visible = false
	if _stage_canvas != null:
		_stage_canvas.queue_redraw()
	await SceneFader.fade_in(0.45)
	_transitioning = false
	_advance()


func _finish_cutscene() -> void:
	if _transitioning or SceneFader.is_busy():
		return
	_transitioning = true
	SceneFader.fade_to_scene("res://scenes/main/Main.tscn", 0.55, 0.55)


func _draw_stage() -> void:
	if _stage_canvas == null:
		return
	_stage_canvas.draw_set_transform(_shake_offset, 0.0, Vector2.ONE)

	if _caption_mode:
		_stage_canvas.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.04, 0.02, 0.06))
		_stage_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	# Illustrated stylized backgrounds
	if _bg_mode == "exterior":
		_stage_canvas.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.14, 0.11, 0.24))
		_stage_canvas.draw_rect(Rect2(0, 0, 1920, 520), Color(0.24, 0.16, 0.32))
		_stage_canvas.draw_circle(Vector2(1580, 180), 68.0, Color(1.0, 0.94, 0.72, 0.85))
		_stage_canvas.draw_rect(Rect2(560, 220, 800, 560), Color(0.32, 0.21, 0.18))
		_stage_canvas.draw_colored_polygon(PackedVector2Array([Vector2(500, 240), Vector2(1420, 240), Vector2(960, 80)]), Color(0.22, 0.12, 0.26))
		_stage_canvas.draw_rect(Rect2(650, 360, 190, 170), Color(1.0, 0.78, 0.36, 0.78))
		_stage_canvas.draw_rect(Rect2(1080, 360, 190, 170), Color(1.0, 0.78, 0.36, 0.78))
		_stage_canvas.draw_rect(Rect2(890, 420, 140, 260), Color(0.44, 0.26, 0.16))
		_stage_canvas.draw_rect(Rect2(780, 260, 360, 62), Color(0.90, 0.80, 0.58))
		_stage_canvas.draw_string(ThemeDB.fallback_font, Vector2(855, 302), "SE VENDE LOCAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.42, 0.14, 0.14))
		_stage_canvas.draw_rect(Rect2(0, 740, 1920, 340), Color(0.24, 0.20, 0.24))
	elif _bg_mode == "interior_morning":
		_stage_canvas.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.30, 0.22, 0.18))
		_stage_canvas.draw_rect(Rect2(0, 0, 1920, 680), Color(0.42, 0.30, 0.22))
		_stage_canvas.draw_colored_polygon(PackedVector2Array([Vector2(760, 0), Vector2(1160, 0), Vector2(1420, 840), Vector2(500, 840)]), Color(1.0, 0.92, 0.65, 0.18))
		_stage_canvas.draw_rect(Rect2(0, 680, 1920, 400), Color(0.46, 0.38, 0.34))
	else:
		_stage_canvas.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.20, 0.14, 0.17))
		_stage_canvas.draw_rect(Rect2(0, 0, 1920, 660), Color(0.28, 0.19, 0.16))
		for sy: int in [220, 360, 500]:
			_stage_canvas.draw_rect(Rect2(340, sy, 1240, 18), Color(0.44, 0.28, 0.18))
			for px: int in range(380, 1520, 110):
				var pcol: Color = Color(0.92, 0.28, 0.38, 0.7) if (px + sy) % 3 == 0 else (Color(0.26, 0.66, 0.98, 0.7) if (px + sy) % 3 == 1 else Color(0.26, 0.86, 0.48, 0.7))
				_stage_canvas.draw_circle(Vector2(px, sy - 16), 14.0, pcol)
		_stage_canvas.draw_rect(Rect2(0, 660, 1920, 420), Color(0.36, 0.30, 0.30))

	# Espacio derecho en blanco hasta rehacer la escena de introducción.

	_stage_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
