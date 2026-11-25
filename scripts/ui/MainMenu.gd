class_name MainMenu
extends Control
## Atmospheric main menu for Trixie with full-screen splash art, sculpted
## transparent logo with pulsing magical halo, Start Game, Options modal, and Quit.

@onready var _vfx_layer: Control = $VfxLayer
@onready var _logo_rect: TextureRect = $Logo
@onready var _start_btn: Button = $MenuButtons/StartButton
@onready var _options_btn: Button = $MenuButtons/OptionsButton
@onready var _quit_btn: Button = $MenuButtons/QuitButton
@onready var _options_overlay: ColorRect = $OptionsOverlay
@onready var _vol_slider: HSlider = $OptionsOverlay/Center/Panel/Margin/VBox/VolumeRow/VolumeSlider
@onready var _vol_val_lbl: Label = $OptionsOverlay/Center/Panel/Margin/VBox/VolumeRow/VolumeValueLabel
@onready var _fs_check: CheckButton = $OptionsOverlay/Center/Panel/Margin/VBox/FullscreenCheck
@onready var _tut_check: CheckButton = $OptionsOverlay/Center/Panel/Margin/VBox/TutorialCheck
@onready var _close_options_btn: Button = $OptionsOverlay/Center/Panel/Margin/VBox/CloseCenter/CloseButton

var _time: float = 0.0
var _logo_base_pos: Vector2 = Vector2(88.0, 108.0)
var _sparkles: Array[Dictionary] = []
var _logo_motes: Array[Dictionary] = []


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--smoke-test"):
		get_tree().call_deferred("change_scene_to_file", "res://scenes/main/Main.tscn")
		return

	set_anchors_preset(Control.PRESET_FULL_RECT)
	if _logo_rect != null:
		_logo_base_pos = _logo_rect.position

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

	_connect_ui()
	if SceneFader.is_black():
		SceneFader.fade_in(0.5)


func _connect_ui() -> void:
	if _vfx_layer != null:
		_vfx_layer.draw.connect(_draw_vfx)
	if _start_btn != null:
		_start_btn.pressed.connect(_on_start_pressed)
	if _options_btn != null:
		_options_btn.pressed.connect(_on_options_pressed)
	if _quit_btn != null:
		_quit_btn.pressed.connect(_on_quit_pressed)

	if _vol_slider != null:
		_vol_slider.value = GameSettings.master_volume
		_vol_slider.value_changed.connect(_on_volume_changed)
	if _vol_val_lbl != null:
		_vol_val_lbl.text = "%d%%" % int(round(GameSettings.master_volume * 100.0))
	if _fs_check != null:
		_fs_check.button_pressed = GameSettings.fullscreen
		_fs_check.toggled.connect(_on_fullscreen_toggled)
	if _tut_check != null:
		_tut_check.button_pressed = GameSettings.show_tutorial
		_tut_check.toggled.connect(_on_tutorial_toggled)
	if _close_options_btn != null:
		_close_options_btn.pressed.connect(func() -> void:
			AudioJuiceManager.play_pentatonic(2, -3.0)
			if _options_overlay != null:
				_options_overlay.visible = false
		)


func _process(delta: float) -> void:
	_time += delta
	for s: Dictionary in _sparkles:
		s["y"] = float(s["y"]) - float(s["spd"]) * delta
		if float(s["y"]) < -20.0:
			s["y"] = 1100.0
			s["x"] = randf_range(0.0, 1920.0)
	if _logo_rect != null:
		_logo_rect.position.y = _logo_base_pos.y + sin(_time * 1.65) * 5.0
	if _vfx_layer != null:
		_vfx_layer.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.pressed and not kev.echo and kev.keycode == KEY_ESCAPE and _options_overlay != null and _options_overlay.visible:
			_options_overlay.visible = false
			get_viewport().set_input_as_handled()


func _draw_vfx() -> void:
	if _vfx_layer == null:
		return

	# Smooth hardware-interpolated left-edge atmospheric gradient
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
	_vfx_layer.draw_polygon(grad_pts, grad_cols)

	# Pulsing magical halo & arcane ring behind the logo
	var logo_center: Vector2 = _logo_rect.position + _logo_rect.size * 0.5 if _logo_rect != null else Vector2(368.0, 283.0)
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
	_vfx_layer.draw_arc(logo_center, 225.0, _time * 0.22, _time * 0.22 + TAU * 0.72, 48, Color(1.0, 0.85, 0.42, arc_a), 2.0)
	_vfx_layer.draw_arc(logo_center, 196.0, -_time * 0.30, -_time * 0.30 + TAU * 0.65, 44, Color(0.82, 0.48, 1.0, arc_a * 0.85), 1.8)

	# Orbiting magical motes around the logo perimeter
	for m: Dictionary in _logo_motes:
		var ang: float = float(m["angle"]) + _time * float(m["spd"])
		var mx: float = logo_center.x + cos(ang) * float(m["rx"])
		var my: float = logo_center.y + sin(ang) * float(m["ry"])
		var mr: float = float(m["r"])
		var mc: Color = m["col"] as Color
		var ma: float = 0.25 + 0.55 * absf(sin(_time * 2.6 + float(m["phase"])))
		_vfx_layer.draw_circle(Vector2(mx, my), mr * 2.1, Color(mc.r, mc.g, mc.b, ma * 0.24))
		_vfx_layer.draw_circle(Vector2(mx, my), mr, Color(mc.r, mc.g, mc.b, ma))

	# Gentle ambient arcane sparkles rising across the scene
	for s: Dictionary in _sparkles:
		var sx: float = float(s["x"]) + sin(_time * 1.4 + float(s["phase"])) * 12.0
		var sy: float = float(s["y"])
		var r: float = float(s["r"])
		var c: Color = s["col"] as Color
		var a: float = 0.18 + 0.38 * absf(sin(_time * 2.2 + float(s["phase"])))
		_vfx_layer.draw_circle(Vector2(sx, sy), r * 1.9, Color(c.r, c.g, c.b, a * 0.22))
		_vfx_layer.draw_circle(Vector2(sx, sy), r, Color(c.r, c.g, c.b, a))


func _draw_ellipse_filled(center: Vector2, rx: float, ry: float, col: Color, segments: int) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(segments)
	for i: int in range(segments):
		var a: float = float(i) * (TAU / float(segments))
		pts[i] = center + Vector2(cos(a) * rx, sin(a) * ry)
	_vfx_layer.draw_colored_polygon(pts, col)


func _on_start_pressed() -> void:
	if SceneFader.is_busy():
		return
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		gs.call("reset_run")
	AudioJuiceManager.play_pentatonic(5, 0.0)
	SceneFader.fade_to_scene("res://scenes/ui/IntroCutscene.tscn", 0.55, 0.55)


func _on_options_pressed() -> void:
	AudioJuiceManager.play_pentatonic(3, -3.0)
	if _vol_slider != null:
		_vol_slider.value = GameSettings.master_volume
	if _fs_check != null:
		_fs_check.button_pressed = GameSettings.fullscreen
	if _tut_check != null:
		_tut_check.button_pressed = GameSettings.show_tutorial
	if _options_overlay != null:
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
	if _vol_val_lbl != null:
		_vol_val_lbl.text = "%d%%" % int(round(val * 100.0))


func _on_fullscreen_toggled(pressed: bool) -> void:
	GameSettings.fullscreen = pressed
	GameSettings.apply_video()
	GameSettings.save_settings()


func _on_tutorial_toggled(pressed: bool) -> void:
	GameSettings.show_tutorial = pressed
	GameSettings.save_settings()
