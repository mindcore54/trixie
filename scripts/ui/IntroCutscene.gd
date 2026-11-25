class_name IntroCutscene
extends Control
## Visual-novel intro lore cutscene where slightly clumsy Trixie buys her dream potion shop
## from Doña Remedios, using smooth fade-to-black transitions and typewriter dialogue.

const SCRIPT_PATH: String = "res://data/dialogues/intro_cutscene.json"
const CHARS_PER_SEC: float = 52.0
const DIALOG_BG_TEX_PATH: String = "res://assets/ui/hud/dialog_bg.png"
const DIALOG_SHADOW_TEX_PATH: String = "res://assets/ui/hud/dialog_bg_shadow.png"
const INTRO_PARCHMENT_POS: Vector2 = Vector2(267.0, 750.0)
const INTRO_PARCHMENT_SIZE: Vector2 = Vector2(1386.0, 300.0)
const DIALOG_SHADOW_PAD: Vector2 = Vector2(24.0, 24.0)
const DIALOG_SHADOW_OFFSET: Vector2 = Vector2(10.0, 14.0)

var _beats: Array = []
var _idx: int = -1
var _time: float = 0.0
var _bg_mode: String = "exterior"
var _show_trixie: bool = false
var _show_remedios: bool = false
var _trixie_emotion: String = "normal"
var _remedios_emotion: String = "normal"
var _active_speaker: String = ""
var _full_text: String = ""
var _shown_chars: float = 0.0
var _transitioning: bool = false
var _shake_timer: float = 0.0
var _caption_mode: bool = false

var _dialog_bg_tex: Texture2D = null
var _dialog_shadow_tex: Texture2D = null
var _parchment_tween: Tween = null
var _parchment_box: Control
var _speaker_lbl: Label
var _text_lbl: Label
var _continue_lbl: Label
var _caption_lbl: Label
var _skip_btn: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(DIALOG_BG_TEX_PATH):
		_dialog_bg_tex = load(DIALOG_BG_TEX_PATH) as Texture2D
	if ResourceLoader.exists(DIALOG_SHADOW_TEX_PATH):
		_dialog_shadow_tex = load(DIALOG_SHADOW_TEX_PATH) as Texture2D
	_load_beats()
	_build_ui()
	_advance()


func _load_beats() -> void:
	var f: FileAccess = FileAccess.open(SCRIPT_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		_beats = parsed as Array


func _build_ui() -> void:
	# Chipped parchment dialogue panel at bottom
	_parchment_box = Control.new()
	_parchment_box.position = INTRO_PARCHMENT_POS
	_parchment_box.size = INTRO_PARCHMENT_SIZE
	_parchment_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parchment_box.draw.connect(_draw_parchment)
	_parchment_box.visible = false
	add_child(_parchment_box)

	_speaker_lbl = Label.new()
	_speaker_lbl.position = Vector2(78, 38)
	_speaker_lbl.add_theme_font_size_override("font_size", 28)
	_speaker_lbl.add_theme_color_override("font_color", Color(0.56, 0.12, 0.24))
	_parchment_box.add_child(_speaker_lbl)

	_text_lbl = Label.new()
	_text_lbl.position = Vector2(78, 88)
	_text_lbl.size = Vector2(1230, 142)
	_text_lbl.add_theme_font_size_override("font_size", 28)
	_text_lbl.add_theme_color_override("font_color", Color(0.18, 0.10, 0.07))
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_parchment_box.add_child(_text_lbl)

	_continue_lbl = Label.new()
	_continue_lbl.text = "Clic / Espacio para continuar ▾"
	_continue_lbl.position = Vector2(948, 238)
	_continue_lbl.size = Vector2(360, 28)
	_continue_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_lbl.add_theme_font_size_override("font_size", 18)
	_continue_lbl.add_theme_color_override("font_color", Color(0.45, 0.26, 0.16))
	_parchment_box.add_child(_continue_lbl)

	# Fullscreen centered caption label for black-screen narrative beats
	_caption_lbl = Label.new()
	_caption_lbl.set_anchors_preset(Control.PRESET_CENTER)
	_caption_lbl.offset_left = -580
	_caption_lbl.offset_right = 580
	_caption_lbl.offset_top = -120
	_caption_lbl.offset_bottom = 120
	_caption_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption_lbl.add_theme_font_size_override("font_size", 42)
	_caption_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.80))
	_caption_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_lbl.visible = false
	add_child(_caption_lbl)

	# Discreet Skip button
	_skip_btn = Button.new()
	_skip_btn.text = "Saltar ⏭"
	_skip_btn.position = Vector2(1740, 24)
	_skip_btn.custom_minimum_size = Vector2(150, 44)
	_skip_btn.add_theme_font_size_override("font_size", 18)
	_skip_btn.pressed.connect(_finish_cutscene)
	add_child(_skip_btn)


func _process(delta: float) -> void:
	_time += delta
	if _shake_timer > 0.0:
		_shake_timer = maxf(0.0, _shake_timer - delta)
	if not _caption_mode and _shown_chars < float(_full_text.length()):
		var prev_i: int = int(_shown_chars)
		_shown_chars = minf(float(_full_text.length()), _shown_chars + CHARS_PER_SEC * delta)
		var cur_i: int = int(_shown_chars)
		_text_lbl.visible_characters = cur_i
		if cur_i > prev_i and cur_i % 4 == 0:
			AudioJuiceManager.play_pentatonic(3 if _active_speaker == "trixie" else 1, -12.0)
	_continue_lbl.visible = not _caption_mode and _shown_chars >= float(_full_text.length())
	if _continue_lbl.visible:
		_continue_lbl.modulate.a = 0.55 + 0.45 * absf(sin(_time * 4.0))
	queue_redraw()


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
	if not _caption_mode and _shown_chars < float(_full_text.length()):
		_shown_chars = float(_full_text.length())
		_text_lbl.visible_characters = -1
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
	var was_hidden: bool = not _parchment_box.visible
	_caption_mode = false
	_caption_lbl.visible = false
	_parchment_box.visible = true
	if was_hidden:
		_animate_parchment_in()
	_active_speaker = String(beat.get("speaker", "trixie"))
	var emo: String = String(beat.get("emotion", "normal"))
	if _active_speaker == "trixie":
		_trixie_emotion = emo
		_speaker_lbl.text = "Trixie"
		_speaker_lbl.add_theme_color_override("font_color", Color(0.68, 0.14, 0.34))
	else:
		_remedios_emotion = emo
		_speaker_lbl.text = "Doña Remedios"
		_speaker_lbl.add_theme_color_override("font_color", Color(0.32, 0.24, 0.50))

	_full_text = String(beat.get("text", ""))
	_text_lbl.text = _full_text
	_shown_chars = 0.0
	_text_lbl.visible_characters = 0
	if bool(beat.get("shake", false)):
		_shake_timer = 0.35
		AudioJuiceManager.play_pentatonic(0, 0.0)


func _show_caption_beat(txt: String) -> void:
	_transitioning = true
	if _idx > 0:
		await SceneFader.fade_out(0.45)
	_caption_mode = true
	_parchment_box.visible = false
	_caption_lbl.text = txt
	_caption_lbl.visible = true
	await SceneFader.fade_in(0.45)
	_transitioning = false


func _change_bg_with_fade(new_bg: String) -> void:
	_transitioning = true
	await SceneFader.fade_out(0.45)
	_parchment_box.visible = false
	_bg_mode = new_bg
	_caption_mode = false
	_caption_lbl.visible = false
	queue_redraw()
	await SceneFader.fade_in(0.45)
	_transitioning = false
	_advance()


func _finish_cutscene() -> void:
	if _transitioning or SceneFader.is_busy():
		return
	_transitioning = true
	SceneFader.fade_to_scene("res://scenes/main/Main.tscn", 0.55, 0.55)


func _draw() -> void:
	var shake_off: Vector2 = Vector2(randf_range(-8, 8), randf_range(-5, 5)) if _shake_timer > 0.0 else Vector2.ZERO
	draw_set_transform(shake_off, 0.0, Vector2.ONE)

	if _caption_mode:
		draw_rect(Rect2(0, 0, 1920, 1080), Color(0.04, 0.02, 0.06))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	# Illustrated stylized backgrounds
	if _bg_mode == "exterior":
		draw_rect(Rect2(0, 0, 1920, 1080), Color(0.14, 0.11, 0.24))
		draw_rect(Rect2(0, 0, 1920, 520), Color(0.24, 0.16, 0.32))
		# Moon & cozy shop facade
		draw_circle(Vector2(1580, 180), 68.0, Color(1.0, 0.94, 0.72, 0.85))
		draw_rect(Rect2(560, 220, 800, 560), Color(0.32, 0.21, 0.18))
		draw_colored_polygon(PackedVector2Array([Vector2(500, 240), Vector2(1420, 240), Vector2(960, 80)]), Color(0.22, 0.12, 0.26))
		# Warm glowing shop windows & "SE VENDE" sign
		draw_rect(Rect2(650, 360, 190, 170), Color(1.0, 0.78, 0.36, 0.78))
		draw_rect(Rect2(1080, 360, 190, 170), Color(1.0, 0.78, 0.36, 0.78))
		draw_rect(Rect2(890, 420, 140, 260), Color(0.44, 0.26, 0.16))
		draw_rect(Rect2(780, 260, 360, 62), Color(0.90, 0.80, 0.58))
		draw_string(ThemeDB.fallback_font, Vector2(855, 302), "SE VENDE LOCAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.42, 0.14, 0.14))
		draw_rect(Rect2(0, 740, 1920, 340), Color(0.24, 0.20, 0.24))
	elif _bg_mode == "interior_morning":
		draw_rect(Rect2(0, 0, 1920, 1080), Color(0.30, 0.22, 0.18))
		draw_rect(Rect2(0, 0, 1920, 680), Color(0.42, 0.30, 0.22))
		# Morning sunbeams from window
		draw_colored_polygon(PackedVector2Array([Vector2(760, 0), Vector2(1160, 0), Vector2(1420, 840), Vector2(500, 840)]), Color(1.0, 0.92, 0.65, 0.18))
		draw_rect(Rect2(0, 680, 1920, 400), Color(0.46, 0.38, 0.34))
	else:
		# Cozy dusk potion shop interior
		draw_rect(Rect2(0, 0, 1920, 1080), Color(0.20, 0.14, 0.17))
		draw_rect(Rect2(0, 0, 1920, 660), Color(0.28, 0.19, 0.16))
		# Potion shelves in background
		for sy: int in [220, 360, 500]:
			draw_rect(Rect2(340, sy, 1240, 18), Color(0.44, 0.28, 0.18))
			for px: int in range(380, 1520, 110):
				var pcol: Color = Color(0.92, 0.28, 0.38, 0.7) if (px + sy) % 3 == 0 else (Color(0.26, 0.66, 0.98, 0.7) if (px + sy) % 3 == 1 else Color(0.26, 0.86, 0.48, 0.7))
				draw_circle(Vector2(px, sy - 16), 14.0, pcol)
		draw_rect(Rect2(0, 660, 1920, 420), Color(0.36, 0.30, 0.30))

	# Draw characters: Trixie expressive bust on the LEFT (1:1 cutscene size, rising cleanly behind parchment), Doña Remedios on the RIGHT
	if _show_trixie:
		var t_active: bool = _active_speaker == "trixie"
		var t_dim: float = 1.0 if t_active else 0.58
		var t_y_off: float = 0.0 if t_active else 14.0
		CharacterArt.draw_trixie_bust(self, Rect2(240.0, 788.0 - 510.0 + t_y_off, 590.0, 510.0), _trixie_emotion, _time, t_dim, "cutscene")
	if _show_remedios:
		var r_dim: float = 1.0 if _active_speaker == "remedios" else 0.58
		var r_scale: float = 1.85 if _active_speaker == "remedios" else 1.72
		CharacterArt.draw_granny_full(self, Vector2(1400, 835), r_scale, _remedios_emotion, _time, r_dim)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _animate_parchment_in() -> void:
	if _parchment_box == null:
		return
	if _parchment_tween != null and _parchment_tween.is_valid():
		_parchment_tween.kill()
	_parchment_box.position = INTRO_PARCHMENT_POS + Vector2(-150.0, 90.0)
	_parchment_box.modulate.a = 0.0
	_parchment_tween = create_tween()
	_parchment_tween.set_parallel(true)
	_parchment_tween.tween_property(_parchment_box, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_parchment_tween.tween_property(_parchment_box, "position", INTRO_PARCHMENT_POS, 0.72).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _draw_parchment() -> void:
	if _dialog_bg_tex != null:
		if _dialog_shadow_tex != null:
			_parchment_box.draw_texture_rect(
				_dialog_shadow_tex,
				Rect2(-DIALOG_SHADOW_PAD + DIALOG_SHADOW_OFFSET, _parchment_box.size + DIALOG_SHADOW_PAD * 2.0),
				false,
				Color(1.0, 1.0, 1.0, 0.56)
			)
		_parchment_box.draw_texture_rect(_dialog_bg_tex, Rect2(Vector2.ZERO, _parchment_box.size), false)
		return

	var w: float = _parchment_box.size.x
	var h: float = _parchment_box.size.y
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(14, 6), Vector2(340, 4), Vector2(360, 14), Vector2(380, 4),
		Vector2(w - 28, 8), Vector2(w - 8, 28), Vector2(w - 14, 110), Vector2(w - 4, 130),
		Vector2(w - 12, h - 14), Vector2(w - 120, h - 6), Vector2(w - 140, h - 18), Vector2(w - 162, h - 6),
		Vector2(210, h - 8), Vector2(188, h - 16), Vector2(168, h - 6), Vector2(14, h - 10),
		Vector2(4, 140), Vector2(16, 120), Vector2(6, 36)
	])
	_parchment_box.draw_colored_polygon(pts, Color(0.93, 0.84, 0.68, 0.97))
	_parchment_box.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.32, 0.18, 0.11), 4.0)
