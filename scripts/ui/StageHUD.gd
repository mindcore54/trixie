class_name StageHUD
extends CanvasLayer
## Controls all stage HUD elements in Main.tscn (floating top HUD islands,
## fleeting stop intro banner, frenzy dock, customer status, speech bubbles,
## closing parchment overlay, toast banner, and pause menu).

signal pause_requested()
signal frenzy_requested()
signal stop_intro_finished()
signal closing_advance_requested()
signal closing_typewriter_tick()
signal return_to_map_requested()
signal restart_requested()
signal main_menu_requested()

@onready var _top_hud_root: Control = $TopHudRoot
@onready var _essence_plaque_bg: TextureRect = $TopHudRoot/EssenceCounter/PlaqueBg
@onready var _essence_icon: TextureRect = $TopHudRoot/EssenceCounter/Margin/Row/EssenceIcon
@onready var _top_essence_lbl: Label = $TopHudRoot/EssenceCounter/Margin/Row/EssenceLabel
@onready var _wave_dock: WaveProgressDock = $TopHudRoot/WaveProgressDock
@onready var _pause_btn: Button = $TopHudRoot/PauseAnchor/PauseButton

@onready var _stop_intro_banner: Control = $StopIntroBanner
@onready var _stop_intro_backdrop: ColorRect = $StopIntroBanner/DimBackdrop
@onready var _stop_intro_title_box: Control = $StopIntroBanner/TitleContainer
@onready var _stop_intro_lbl: Label = $StopIntroBanner/TitleContainer/TitleShadowGroup/StopTitleLabel

@onready var _cauldron_hud_root: Control = $CauldronHudRoot
@onready var _witch_name_lbl: Label = $CauldronHudRoot/WitchNameShadowGroup/WitchNameLabel
@onready var _frenzy_bar: ProgressBar = $CauldronHudRoot/FrenzyDock/Margin/VBox/FrenzyBar
@onready var _frenzy_btn: Button = $CauldronHudRoot/FrenzyDock/Margin/VBox/FrenzyButton
@onready var customer_hud: CustomerHudPanel = $CauldronHudRoot/CustomerHudPanel
@onready var _toast_lbl: Label = $CauldronHudRoot/ToastLabel

@onready var trixie_bubble: SpeechBubble = $TrixieBubble
@onready var customer_bubble: SpeechBubble = $CustomerBubble

@onready var _closing_overlay: Control = $ClosingOverlay
@onready var closing_dialog_box: DialogBox = $ClosingOverlay/ClosingDialogBox

@onready var _pause_overlay: ColorRect = $PauseOverlay
@onready var _pause_panel: Control = $PauseOverlay/Center/PausePanel
@onready var _pause_scroll_bg: TextureRect = $PauseOverlay/Center/PausePanel/ScrollBg
@onready var _pause_resume_btn: Button = $PauseOverlay/Center/PausePanel/Margin/VBox/ResumeButton
@onready var _pause_map_btn: Button = $PauseOverlay/Center/PausePanel/Margin/VBox/MapButton
@onready var _pause_restart_btn: Button = $PauseOverlay/Center/PausePanel/Margin/VBox/RestartButton
@onready var _pause_menu_btn: Button = $PauseOverlay/Center/PausePanel/Margin/VBox/MenuButton

const PAUSE_BG_ALPHA: float = 0.84

var _toast_timer: float = 0.0
var _stop_intro_tween: Tween = null
var _stop_intro_base_y: float = 455.0
var _pause_open: bool = false
var _pause_open_tween: Tween = null


func _ready() -> void:
	if _stop_intro_title_box != null:
		_stop_intro_base_y = _stop_intro_title_box.position.y
	if _stop_intro_banner != null:
		_stop_intro_banner.visible = false
		_stop_intro_banner.modulate = Color(1.0, 1.0, 1.0, 0.0)

	_sync_plaque_shadow()
	if _essence_plaque_bg != null and not _essence_plaque_bg.resized.is_connected(_sync_plaque_shadow):
		_essence_plaque_bg.resized.connect(_sync_plaque_shadow)

	if trixie_bubble != null:
		trixie_bubble.set_base_position(trixie_bubble.position)
		trixie_bubble.hide_bubble(true)

	if customer_bubble != null:
		customer_bubble.set_base_position(customer_bubble.position)
		customer_bubble.hide_bubble(true)

	if closing_dialog_box != null:
		closing_dialog_box.set_base_position(closing_dialog_box.position)
		closing_dialog_box.chars_per_sec = 54.0
		closing_dialog_box.set_body_font_size(26)
		closing_dialog_box.set_continue_prompt("Clic / Espacio para ir al Mapa ▾")
		closing_dialog_box.typewriter_tick.connect(func(_ci: int) -> void: closing_typewriter_tick.emit())

	if _closing_overlay != null:
		_closing_overlay.visible = false
		_closing_overlay.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton:
				var mb: InputEventMouseButton = ev as InputEventMouseButton
				if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
					closing_advance_requested.emit()
		)

	if _pause_overlay != null:
		_pause_open = false
		_pause_overlay.visible = false
		_pause_overlay.color = Color(0.0, 0.0, 0.0, PAUSE_BG_ALPHA)
	if _toast_lbl != null:
		_toast_lbl.visible = false

	if _pause_btn != null:
		_pause_btn.pressed.connect(func() -> void: pause_requested.emit())
	if _frenzy_btn != null:
		_frenzy_btn.pressed.connect(func() -> void: frenzy_requested.emit())
	if _pause_resume_btn != null:
		_pause_resume_btn.pressed.connect(func() -> void: set_pause_visible(false))
	if _pause_map_btn != null:
		_pause_map_btn.pressed.connect(func() -> void: return_to_map_requested.emit())
	if _pause_restart_btn != null:
		_pause_restart_btn.pressed.connect(func() -> void: restart_requested.emit())
	if _pause_menu_btn != null:
		_pause_menu_btn.pressed.connect(func() -> void: main_menu_requested.emit())

	_sync_pause_scroll_shadow()
	if _pause_scroll_bg != null and not _pause_scroll_bg.resized.is_connected(_sync_pause_scroll_shadow):
		_pause_scroll_bg.resized.connect(_sync_pause_scroll_shadow)
	for p_btn: Button in [_pause_resume_btn, _pause_map_btn, _pause_restart_btn, _pause_menu_btn]:
		_wire_scroll_button_hover(p_btn)


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer = maxf(0.0, _toast_timer - delta)
		if _toast_timer <= 0.0 and _toast_lbl != null:
			_toast_lbl.visible = false


func _sync_plaque_shadow() -> void:
	if _essence_plaque_bg != null and _essence_plaque_bg.material is ShaderMaterial:
		(_essence_plaque_bg.material as ShaderMaterial).set_shader_parameter("render_size", _essence_plaque_bg.size)


func _sync_pause_scroll_shadow() -> void:
	if _pause_scroll_bg != null and _pause_scroll_bg.material is ShaderMaterial:
		(_pause_scroll_bg.material as ShaderMaterial).set_shader_parameter("render_size", _pause_scroll_bg.size)
	if _pause_panel != null:
		_pause_panel.pivot_offset = _pause_panel.size * 0.5


func _wire_scroll_button_hover(btn: Button) -> void:
	if btn == null:
		return
	btn.resized.connect(func() -> void:
		btn.pivot_offset = btn.size * 0.5
	)
	btn.pivot_offset = btn.size * 0.5
	btn.mouse_entered.connect(func() -> void:
		if btn.disabled:
			return
		btn.pivot_offset = btn.size * 0.5
		var tw: Tween = create_tween()
		tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func() -> void:
		btn.pivot_offset = btn.size * 0.5
		var tw: Tween = create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)


func show_stop_intro(stop_name: String, hold_sec: float = 2.6) -> void:
	if _stop_intro_banner == null:
		stop_intro_finished.emit()
		return
	if _stop_intro_tween != null and is_instance_valid(_stop_intro_tween):
		_stop_intro_tween.kill()
	if _stop_intro_lbl != null:
		_stop_intro_lbl.text = stop_name
	if _stop_intro_title_box != null:
		_stop_intro_title_box.position.y = _stop_intro_base_y - 16.0
	_stop_intro_banner.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_stop_intro_banner.visible = true

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_stop_intro_banner, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _stop_intro_title_box != null:
		tw.tween_property(_stop_intro_title_box, "position:y", _stop_intro_base_y, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(hold_sec)
	tw.chain().set_parallel(true)
	tw.tween_property(_stop_intro_banner, "modulate:a", 0.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if _stop_intro_title_box != null:
		tw.tween_property(_stop_intro_title_box, "position:y", _stop_intro_base_y - 10.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		if _stop_intro_banner != null:
			_stop_intro_banner.visible = false
		if _stop_intro_title_box != null:
			_stop_intro_title_box.position.y = _stop_intro_base_y
		_stop_intro_tween = null
		stop_intro_finished.emit()
	)
	_stop_intro_tween = tw


func finish_stop_intro_now() -> void:
	if _stop_intro_tween != null and is_instance_valid(_stop_intro_tween):
		_stop_intro_tween.kill()
		_stop_intro_tween = null
	var was_active: bool = is_stop_intro_visible()
	if _stop_intro_banner != null:
		_stop_intro_banner.visible = false
		_stop_intro_banner.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if _stop_intro_title_box != null:
		_stop_intro_title_box.position.y = _stop_intro_base_y
	if was_active:
		stop_intro_finished.emit()


func hide_stop_intro(instant: bool = true) -> void:
	if _stop_intro_banner == null:
		return
	if _stop_intro_tween != null and is_instance_valid(_stop_intro_tween):
		_stop_intro_tween.kill()
		_stop_intro_tween = null
	if instant:
		_stop_intro_banner.visible = false
		_stop_intro_banner.modulate = Color(1.0, 1.0, 1.0, 0.0)
		if _stop_intro_title_box != null:
			_stop_intro_title_box.position.y = _stop_intro_base_y
	else:
		var tw: Tween = create_tween()
		tw.tween_property(_stop_intro_banner, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func() -> void:
			if _stop_intro_banner != null:
				_stop_intro_banner.visible = false
			if _stop_intro_title_box != null:
				_stop_intro_title_box.position.y = _stop_intro_base_y
		)
		_stop_intro_tween = tw


func has_stop_intro_backdrop() -> bool:
	return _stop_intro_backdrop != null and _stop_intro_backdrop.color.a > 0.35


func is_stop_intro_visible() -> bool:
	return _stop_intro_banner != null and _stop_intro_banner.visible


func get_stop_intro_text() -> String:
	return _stop_intro_lbl.text if _stop_intro_lbl != null else ""


func has_floating_top_hud() -> bool:
	return (
		get_node_or_null("TopBar") == null
		and _top_hud_root != null
		and get_node_or_null("TopHudRoot/EssenceCounter") != null
		and _wave_dock != null
		and _pause_btn != null
	)


func has_top_hud_textures() -> bool:
	return (
		_essence_plaque_bg != null and _essence_plaque_bg.texture != null
		and _essence_icon != null and _essence_icon.texture != null
		and _wave_dock != null and _wave_dock.has_textures()
		and _pause_btn != null and (_pause_btn.get_theme_stylebox("normal") is StyleBoxTexture)
	)


func get_wave_dock() -> WaveProgressDock:
	return _wave_dock


func set_cauldron_hud_visible(show_hud: bool) -> void:
	if _cauldron_hud_root != null:
		_cauldron_hud_root.visible = show_hud
	if _wave_dock != null:
		_wave_dock.visible = show_hud


func show_toast(txt: String, duration: float = 3.5) -> void:
	_toast_timer = duration
	if _toast_lbl != null:
		_toast_lbl.text = txt
		_toast_lbl.visible = true


func show_trixie_bubble(title: String, text: String, duration: float, is_tutorial: bool = false) -> void:
	if trixie_bubble != null:
		trixie_bubble.show_message(title, text, duration, is_tutorial)


func hide_trixie_bubble(instant: bool = false) -> void:
	if trixie_bubble != null:
		trixie_bubble.hide_bubble(instant)


func is_trixie_bubble_tutorial() -> bool:
	return trixie_bubble != null and trixie_bubble.is_tutorial_mode


func show_customer_bubble(speaker_name: String, text: String, duration: float = 3.2) -> void:
	if customer_bubble != null:
		customer_bubble.show_message(speaker_name, text, duration, false)


func hide_customer_bubble(instant: bool = false) -> void:
	if customer_bubble != null:
		customer_bubble.hide_bubble(instant)


func open_closing_overlay() -> void:
	if _closing_overlay != null:
		_closing_overlay.visible = true


func hide_closing_overlay() -> void:
	if _closing_overlay != null:
		_closing_overlay.visible = false


func is_closing_visible() -> bool:
	return _closing_overlay != null and _closing_overlay.visible


func show_closing_line(speaker_name: String, speaker_color: Color, body_text: String, animate_entrance: bool) -> void:
	if closing_dialog_box != null:
		closing_dialog_box.show_line(speaker_name, speaker_color, body_text, animate_entrance)


func is_closing_typing() -> bool:
	return closing_dialog_box != null and closing_dialog_box.is_typing()


func complete_closing_typing() -> void:
	if closing_dialog_box != null:
		closing_dialog_box.complete_typing()


func toggle_pause() -> void:
	set_pause_visible(not is_pause_open())


func set_pause_visible(show_pause: bool, instant: bool = false) -> void:
	if _pause_overlay == null:
		return
	if _pause_open_tween != null and is_instance_valid(_pause_open_tween):
		_pause_open_tween.kill()
		_pause_open_tween = null
	_pause_open = show_pause

	if instant:
		_pause_overlay.visible = show_pause
		_pause_overlay.color = Color(0.0, 0.0, 0.0, PAUSE_BG_ALPHA)
		_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		if _pause_panel != null:
			_pause_panel.scale = Vector2.ONE
			_pause_panel.modulate = Color.WHITE
		return

	if show_pause:
		var was_visible: bool = _pause_overlay.visible
		_pause_overlay.visible = true
		_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		if not was_visible:
			_pause_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
			if _pause_panel != null:
				_pause_panel.pivot_offset = _pause_panel.size * 0.5
				_pause_panel.scale = Vector2(0.94, 0.94)
				_pause_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(_pause_overlay, "color:a", PAUSE_BG_ALPHA, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if _pause_panel != null:
			_pause_panel.pivot_offset = _pause_panel.size * 0.5
			tw.tween_property(_pause_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(_pause_panel, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(func() -> void:
			_pause_open_tween = null
		)
		_pause_open_tween = tw
	else:
		if not _pause_overlay.visible:
			return
		_pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw_out: Tween = create_tween()
		tw_out.set_parallel(true)
		tw_out.tween_property(_pause_overlay, "color:a", 0.0, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		if _pause_panel != null:
			_pause_panel.pivot_offset = _pause_panel.size * 0.5
			tw_out.tween_property(_pause_panel, "scale", Vector2(0.95, 0.95), 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw_out.tween_property(_pause_panel, "modulate:a", 0.0, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw_out.chain().tween_callback(func() -> void:
			if _pause_overlay != null:
				_pause_overlay.visible = false
				_pause_overlay.color = Color(0.0, 0.0, 0.0, PAUSE_BG_ALPHA)
				_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
			if _pause_panel != null:
				_pause_panel.scale = Vector2.ONE
				_pause_panel.modulate = Color.WHITE
			_pause_open_tween = null
		)
		_pause_open_tween = tw_out


func is_pause_open() -> bool:
	return _pause_open


func set_map_button_disabled(is_disabled: bool) -> void:
	if _pause_map_btn != null:
		_pause_map_btn.disabled = is_disabled


func has_dialog_and_bubble_textures() -> bool:
	return (
		closing_dialog_box != null and closing_dialog_box.has_textures()
		and trixie_bubble != null and trixie_bubble.has_textures()
		and customer_bubble != null and customer_bubble.has_textures()
	)


func has_customer_hud_textures() -> bool:
	return customer_hud != null and customer_hud.has_textures()


func set_witch_name(witch_name: String) -> void:
	if _witch_name_lbl != null and witch_name != "" and _witch_name_lbl.text != witch_name:
		_witch_name_lbl.text = witch_name


func get_witch_name_text() -> String:
	return _witch_name_lbl.text if _witch_name_lbl != null else ""


func has_styled_witch_name() -> bool:
	return (
		_witch_name_lbl != null
		and _witch_name_lbl.has_theme_font_override("font")
		and _witch_name_lbl.get_theme_font("font") != null
		and _witch_name_lbl.material is ShaderMaterial
	)


func refresh_status(
	essence_gold: int,
	wave_slot_states: Array[int],
	patience_left: float,
	patience_max: float,
	patience_paused: bool,
	impatient_ratio: float,
	frenzy_charge: float,
	frenzy_timer: float,
	customer_title: String,
	affinity_level: int,
	reward_gold: int
) -> void:
	if _top_essence_lbl == null:
		return
	_top_essence_lbl.text = "%d" % essence_gold

	if _wave_dock != null:
		_wave_dock.update_slots(wave_slot_states)

	if customer_hud != null:
		customer_hud.update_status_data(
			customer_title,
			affinity_level,
			reward_gold,
			patience_left,
			patience_max,
			patience_paused,
			impatient_ratio
		)

	if _frenzy_bar != null:
		_frenzy_bar.value = 100.0 if frenzy_timer > 0.0 else frenzy_charge
	if _frenzy_btn != null:
		if frenzy_timer > 0.0:
			_frenzy_btn.text = "🔥 ¡FRENESÍ x2 ACTIVO! (%.1fs)" % frenzy_timer
			_frenzy_btn.disabled = true
		elif frenzy_charge >= 100.0:
			_frenzy_btn.text = "💥 ¡ACTIVAR FRENESÍ x2! [ESPACIO]"
			_frenzy_btn.disabled = false
		else:
			_frenzy_btn.text = "FRENESÍ (%d%%)" % int(frenzy_charge)
			_frenzy_btn.disabled = true
