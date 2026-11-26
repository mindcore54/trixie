class_name StageHUD
extends CanvasLayer
## Controls all stage HUD elements in Main.tscn (top bar, frenzy dock, customer status,
## speech bubbles, closing parchment overlay, toast banner, and pause menu).

signal pause_requested()
signal frenzy_requested()
signal closing_advance_requested()
signal closing_typewriter_tick()
signal return_to_map_requested()
signal restart_requested()
signal main_menu_requested()

@onready var _top_essence_lbl: Label = $TopBar/Margin/HBox/EssenceLabel
@onready var _top_stop_lbl: Label = $TopBar/Margin/HBox/StopLabel
@onready var _top_wave_lbl: Label = $TopBar/Margin/HBox/WaveLabel
@onready var _pause_btn: Button = $TopBar/Margin/HBox/PauseButton

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
@onready var _pause_resume_btn: Button = $PauseOverlay/Center/PausePanel/Margin/VBox/ResumeButton
@onready var _pause_map_btn: Button = $PauseOverlay/Center/PausePanel/Margin/VBox/MapButton
@onready var _pause_restart_btn: Button = $PauseOverlay/Center/PausePanel/Margin/VBox/RestartButton
@onready var _pause_menu_btn: Button = $PauseOverlay/Center/PausePanel/Margin/VBox/MenuButton

var _toast_timer: float = 0.0


func _ready() -> void:
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
		_pause_overlay.visible = false
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


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer = maxf(0.0, _toast_timer - delta)
		if _toast_timer <= 0.0 and _toast_lbl != null:
			_toast_lbl.visible = false


func set_cauldron_hud_visible(show_hud: bool) -> void:
	if _cauldron_hud_root != null:
		_cauldron_hud_root.visible = show_hud


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
	if _pause_overlay != null:
		_pause_overlay.visible = not _pause_overlay.visible


func set_pause_visible(show_pause: bool) -> void:
	if _pause_overlay != null:
		_pause_overlay.visible = show_pause


func is_pause_open() -> bool:
	return _pause_overlay != null and _pause_overlay.visible


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
	stop_icon: String,
	stop_name: String,
	shown_wave: int,
	wave_total: int,
	served_count: int,
	missed_count: int,
	patience_left: float,
	patience_max: float,
	patience_paused: bool,
	impatient_ratio: float,
	frenzy_charge: float,
	frenzy_timer: float,
	customer_title: String,
	affinity_text: String
) -> void:
	if _top_essence_lbl == null:
		return
	_top_essence_lbl.text = "✦ %d" % essence_gold
	_top_stop_lbl.text = "%s %s" % [stop_icon, stop_name]
	_top_wave_lbl.text = "👥 Clienta: %d/%d  (✅%d ❌%d)" % [shown_wave, wave_total, served_count, missed_count]

	if customer_hud != null:
		customer_hud.update_status(
			customer_title,
			affinity_text,
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
