class_name MainMenu
extends Control
## Atmospheric main menu for Trixie with full-screen splash art, sculpted
## transparent logo with pulsing magical halo, Start Game, Options modal, and Quit.

const BG_TEX_PATH: String = "res://assets/ui/menus/trixies_main_bg.jpg"
const LOGO_TEX_PATH: String = "res://assets/ui/menus/trixies_logo.png"
const HALO_SHADER_PATH: String = "res://shaders/logo_magic_halo.gdshader"

const LOGO_POS: Vector2 = Vector2(88.0, 108.0)
const LOGO_SIZE: Vector2 = Vector2(560.0, 350.0)

var _time: float = 0.0
var _bg_tex: Texture2D = null
var _logo_tex: Texture2D = null
var _logo_rect: TextureRect = null
var _sparkles: Array[Dictionary] = []
var _logo_motes: Array[Dictionary] = []
var _options_overlay: ColorRect
var _vol_slider: HSlider
var _vol_val_lbl: Label
var _fs_check: CheckButton
var _tut_check: CheckButton


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--smoke-test"):
		get_tree().call_deferred("change_scene_to_file", "res://scenes/main/Main.tscn")
		return

	set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_tex = load(BG_TEX_PATH) as Texture2D
	_logo_tex = load(LOGO_TEX_PATH) as Texture2D

	for i: int in range(30):
		_sparkles.append({
			"x": randf_range(0.0, 1920.0),
			"y": randf_range(0.0, 1080.0),
			"r": randf_range(1.8, 4.4),
			"spd": randf_range(14.0, 38.0),
			"phase": randf_range(0.0, TAU),
			"col": Color(1.0, 0.85, 0.38) if i % 3 == 0 else (Color(0.36, 0.96, 0.56) if i % 3 == 1 else Color(0.84, 0.52, 1.0)),
		})

	for j: int in range(22):
		_logo_motes.append({
			"angle": float(j) * (TAU / 22.0) + randf_range(-0.15, 0.15),
			"rx": randf_range(235.0, 305.0),
			"ry": randf_range(138.0, 195.0),
			"spd": randf_range(0.18, 0.42) * (1.0 if j % 2 == 0 else -1.0),
			"r": randf_range(2.0, 4.6),
			"phase": randf_range(0.0, TAU),
			"col": Color(1.0, 0.86, 0.40) if j % 2 == 0 else Color(0.86, 0.58, 1.0),
		})

	_build_ui()
	if SceneFader.is_black():
		SceneFader.fade_in(0.5)


func _process(delta: float) -> void:
	_time += delta
	for s: Dictionary in _sparkles:
		s["y"] = float(s["y"]) - float(s["spd"]) * delta
		if float(s["y"]) < -20.0:
			s["y"] = 1100.0
			s["x"] = randf_range(0.0, 1920.0)
	if _logo_rect != null:
		_logo_rect.position.y = LOGO_POS.y + sin(_time * 1.65) * 5.0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.pressed and not kev.echo and kev.keycode == KEY_ESCAPE and _options_overlay.visible:
			_options_overlay.visible = false
			get_viewport().set_input_as_handled()


func _draw() -> void:
	# Full-screen splash art background
	if _bg_tex != null:
		draw_texture_rect(_bg_tex, Rect2(0.0, 0.0, 1920.0, 1080.0), false)
	else:
		draw_rect(Rect2(0.0, 0.0, 1920.0, 1080.0), Color(0.09, 0.05, 0.14))

	# Smooth hardware-interpolated left-edge atmospheric gradient (no banding or seams)
	var grad_pts: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(760.0, 0.0),
		Vector2(760.0, 1080.0),
		Vector2(0.0, 1080.0),
	])
	var grad_cols: PackedColorArray = PackedColorArray([
		Color(0.04, 0.02, 0.08, 0.30),
		Color(0.04, 0.02, 0.08, 0.0),
		Color(0.04, 0.02, 0.08, 0.0),
		Color(0.04, 0.02, 0.08, 0.30),
	])
	draw_polygon(grad_pts, grad_cols)

	# Pulsing magical halo & arcane ring behind the logo
	var logo_center: Vector2 = LOGO_POS + LOGO_SIZE * 0.5 + Vector2(0.0, sin(_time * 1.65) * 5.0)
	var pulse: float = 0.84 + 0.16 * sin(_time * 2.1)
	for ring: int in range(7):
		var t: float = float(ring) / 6.0
		var rx: float = lerpf(325.0, 140.0, t) * (0.96 + 0.04 * pulse)
		var ry: float = lerpf(205.0, 88.0, t) * (0.96 + 0.04 * pulse)
		var col: Color = Color(0.72, 0.34, 0.98).lerp(Color(1.0, 0.84, 0.38), t)
		col.a = (0.032 + t * 0.038) * pulse
		_draw_ellipse_filled(logo_center, rx, ry, col, 40)

	# Delicate rotating arcane rings behind the wooden sign
	var arc_a: float = 0.16 * pulse
	draw_arc(logo_center, 225.0, _time * 0.22, _time * 0.22 + TAU * 0.72, 48, Color(1.0, 0.85, 0.42, arc_a), 2.0)
	draw_arc(logo_center, 196.0, -_time * 0.30, -_time * 0.30 + TAU * 0.65, 44, Color(0.82, 0.48, 1.0, arc_a * 0.85), 1.8)

	# Orbiting magical motes around the logo perimeter
	for m: Dictionary in _logo_motes:
		var ang: float = float(m["angle"]) + _time * float(m["spd"])
		var mx: float = logo_center.x + cos(ang) * float(m["rx"])
		var my: float = logo_center.y + sin(ang) * float(m["ry"])
		var mr: float = float(m["r"])
		var mc: Color = m["col"] as Color
		var ma: float = 0.25 + 0.55 * absf(sin(_time * 2.6 + float(m["phase"])))
		draw_circle(Vector2(mx, my), mr * 2.1, Color(mc.r, mc.g, mc.b, ma * 0.24))
		draw_circle(Vector2(mx, my), mr, Color(mc.r, mc.g, mc.b, ma))

	# Gentle ambient arcane sparkles rising across the scene
	for s: Dictionary in _sparkles:
		var sx: float = float(s["x"]) + sin(_time * 1.4 + float(s["phase"])) * 12.0
		var sy: float = float(s["y"])
		var r: float = float(s["r"])
		var c: Color = s["col"] as Color
		var a: float = 0.18 + 0.38 * absf(sin(_time * 2.2 + float(s["phase"])))
		draw_circle(Vector2(sx, sy), r * 1.9, Color(c.r, c.g, c.b, a * 0.22))
		draw_circle(Vector2(sx, sy), r, Color(c.r, c.g, c.b, a))


func _draw_ellipse_filled(center: Vector2, rx: float, ry: float, col: Color, segments: int) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(segments)
	for i: int in range(segments):
		var a: float = float(i) * (TAU / float(segments))
		pts[i] = center + Vector2(cos(a) * rx, sin(a) * ry)
	draw_colored_polygon(pts, col)


func _build_ui() -> void:
	# Sculpted 3D transparent logo at native 1:1 size (560x350) with magical halo shader
	_logo_rect = TextureRect.new()
	_logo_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP
	_logo_rect.position = LOGO_POS
	_logo_rect.texture = _logo_tex
	_logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var halo_shader: Shader = load(HALO_SHADER_PATH) as Shader
	if halo_shader != null:
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = halo_shader
		_logo_rect.material = mat
	add_child(_logo_rect)

	# Centered column of Main Menu buttons directly below the logo
	var btn_w: float = 380.0
	var btn_col: VBoxContainer = VBoxContainer.new()
	btn_col.position = Vector2(LOGO_POS.x + (LOGO_SIZE.x - btn_w) * 0.5, LOGO_POS.y + LOGO_SIZE.y + 42.0)
	btn_col.custom_minimum_size = Vector2(btn_w, 260.0)
	btn_col.add_theme_constant_override("separation", 20)
	add_child(btn_col)

	var start_btn: Button = _make_menu_button("INICIAR JUEGO", Color(0.68, 0.16, 0.36, 0.94), Color(1.0, 0.84, 0.38))
	start_btn.pressed.connect(_on_start_pressed)
	btn_col.add_child(start_btn)

	var opt_btn: Button = _make_menu_button("OPCIONES", Color(0.24, 0.14, 0.34, 0.92), Color(0.84, 0.64, 0.36))
	opt_btn.pressed.connect(_on_options_pressed)
	btn_col.add_child(opt_btn)

	var quit_btn: Button = _make_menu_button("SALIR", Color(0.16, 0.10, 0.22, 0.90), Color(0.62, 0.46, 0.58))
	quit_btn.pressed.connect(_on_quit_pressed)
	btn_col.add_child(quit_btn)

	var ver_lbl: Label = _make_label("Godot 4.7 · Prototipo Jugable", 15, Color(0.76, 0.70, 0.84, 0.85))
	ver_lbl.position = Vector2(78, 1028)
	add_child(ver_lbl)

	# Options Modal Overlay
	_options_overlay = ColorRect.new()
	_options_overlay.color = Color(0.03, 0.02, 0.06, 0.82)
	_options_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options_overlay.visible = false
	add_child(_options_overlay)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options_overlay.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 420)
	var psb: StyleBoxFlat = StyleBoxFlat.new()
	psb.bg_color = Color(0.13, 0.09, 0.19, 0.98)
	psb.border_color = Color(0.84, 0.64, 0.32)
	psb.set_border_width_all(3)
	psb.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", psb)
	center.add_child(panel)

	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 32)
	pad.add_theme_constant_override("margin_right", 32)
	pad.add_theme_constant_override("margin_top", 26)
	pad.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(pad)

	var ovbox: VBoxContainer = VBoxContainer.new()
	ovbox.add_theme_constant_override("separation", 20)
	pad.add_child(ovbox)

	var ohdr: Label = _make_label("OPCIONES", 32, Color(1.0, 0.88, 0.45))
	ohdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ovbox.add_child(ohdr)

	var vol_row: HBoxContainer = HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 14)
	var vol_lbl: Label = _make_label("Volumen General:", 20, Color(0.95, 0.92, 0.96))
	_vol_slider = HSlider.new()
	_vol_slider.min_value = 0.0
	_vol_slider.max_value = 1.0
	_vol_slider.step = 0.05
	_vol_slider.value = GameSettings.master_volume
	_vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vol_slider.value_changed.connect(_on_volume_changed)
	_vol_val_lbl = _make_label("%d%%" % int(round(GameSettings.master_volume * 100.0)), 18, Color(1.0, 0.86, 0.42))
	vol_row.add_child(vol_lbl)
	vol_row.add_child(_vol_slider)
	vol_row.add_child(_vol_val_lbl)
	ovbox.add_child(vol_row)

	_fs_check = CheckButton.new()
	_fs_check.text = "  Pantalla Completa (F11)"
	_fs_check.add_theme_font_size_override("font_size", 20)
	_fs_check.button_pressed = GameSettings.fullscreen
	_fs_check.toggled.connect(_on_fullscreen_toggled)
	ovbox.add_child(_fs_check)

	_tut_check = CheckButton.new()
	_tut_check.text = "  Mostrar Tutorial Guiado en Día 1"
	_tut_check.add_theme_font_size_override("font_size", 20)
	_tut_check.button_pressed = GameSettings.show_tutorial
	_tut_check.toggled.connect(_on_tutorial_toggled)
	ovbox.add_child(_tut_check)

	var opt_spacer: Control = Control.new()
	opt_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ovbox.add_child(opt_spacer)

	var close_btn: Button = _make_menu_button("VOLVER", Color(0.32, 0.20, 0.44), Color(0.88, 0.70, 0.36))
	close_btn.custom_minimum_size = Vector2(240, 52)
	close_btn.pressed.connect(func() -> void:
		AudioJuiceManager.play_pentatonic(2, -3.0)
		_options_overlay.visible = false
	)
	var close_center: CenterContainer = CenterContainer.new()
	close_center.add_child(close_btn)
	ovbox.add_child(close_center)


func _on_start_pressed() -> void:
	if SceneFader.is_busy():
		return
	AudioJuiceManager.play_pentatonic(5, 0.0)
	SceneFader.fade_to_scene("res://scenes/ui/IntroCutscene.tscn", 0.55, 0.55)


func _on_options_pressed() -> void:
	AudioJuiceManager.play_pentatonic(3, -3.0)
	_vol_slider.value = GameSettings.master_volume
	_fs_check.button_pressed = GameSettings.fullscreen
	_tut_check.button_pressed = GameSettings.show_tutorial
	_options_overlay.visible = true


func _on_quit_pressed() -> void:
	if SceneFader.is_busy():
		return
	AudioJuiceManager.play_pentatonic(0, -2.0)
	await SceneFader.fade_out(0.4)
	get_tree().quit()


func _on_volume_changed(val: float) -> void:
	GameSettings.master_volume = val
	GameSettings.apply_audio()
	GameSettings.save_settings()
	_vol_val_lbl.text = "%d%%" % int(round(val * 100.0))


func _on_fullscreen_toggled(pressed: bool) -> void:
	GameSettings.fullscreen = pressed
	GameSettings.apply_video()
	GameSettings.save_settings()


func _on_tutorial_toggled(pressed: bool) -> void:
	GameSettings.show_tutorial = pressed
	GameSettings.save_settings()


static func _make_label(txt: String, fsize: int, col: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.09))
	lbl.add_theme_constant_override("outline_size", 4)
	return lbl


static func _make_menu_button(txt: String, bg: Color, border: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(380, 64)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.90))
	var normal_sb: StyleBoxFlat = StyleBoxFlat.new()
	normal_sb.bg_color = bg
	normal_sb.border_color = border
	normal_sb.set_border_width_all(3)
	normal_sb.set_corner_radius_all(14)
	normal_sb.shadow_color = Color(0.02, 0.01, 0.05, 0.55)
	normal_sb.shadow_size = 8
	normal_sb.shadow_offset = Vector2(0, 4)
	var hover_sb: StyleBoxFlat = normal_sb.duplicate() as StyleBoxFlat
	hover_sb.bg_color = bg.lightened(0.16)
	hover_sb.border_color = border.lightened(0.22)
	hover_sb.shadow_color = Color(1.0, 0.82, 0.36, 0.32)
	hover_sb.shadow_size = 12
	var pressed_sb: StyleBoxFlat = normal_sb.duplicate() as StyleBoxFlat
	pressed_sb.bg_color = bg.darkened(0.15)
	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	return btn
