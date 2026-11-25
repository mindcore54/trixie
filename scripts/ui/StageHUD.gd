class_name StageHUD
extends CanvasLayer
## Controls all stage HUD elements in Main.tscn (top bar, frenzy dock, customer status,
## speech bubbles, closing parchment overlay, toast banner, and pause menu).

signal pause_requested()
signal frenzy_requested()
signal tutorial_ack_pressed()
signal closing_advance_requested()
signal closing_typewriter_tick()
signal return_to_map_requested()
signal restart_requested()
signal main_menu_requested()

@onready var _top_essence_lbl: Label = $TopBar/Margin/HBox/EssenceLabel
@onready var _top_stop_lbl: Label = $TopBar/Margin/HBox/StopLabel
@onready var _top_wave_lbl: Label = $TopBar/Margin/HBox/WaveLabel
@onready var _top_timer_lbl: Label = $TopBar/Margin/HBox/TimerLabel
@onready var _pause_btn: Button = $TopBar/Margin/HBox/PauseButton

@onready var _cauldron_hud_root: Control = $CauldronHudRoot
@onready var _frenzy_bar: ProgressBar = $CauldronHudRoot/FrenzyDock/Margin/VBox/FrenzyBar
@onready var _frenzy_btn: Button = $CauldronHudRoot/FrenzyDock/Margin/VBox/FrenzyButton
@onready var _cust_name_lbl: Label = $CauldronHudRoot/CustomerHeaderCard/Margin/HBox/CustomerNameLabel
@onready var _cust_aff_lbl: Label = $CauldronHudRoot/CustomerHeaderCard/Margin/HBox/CustomerAffinityLabel
@onready var _cust_patience_lbl: Label = $CauldronHudRoot/PatienceCard/Margin/HBox/PatienceLabel
@onready var _cust_patience_bar: ProgressBar = $CauldronHudRoot/PatienceCard/Margin/HBox/PatienceBar
@onready var chem_visual_canvas: Control = $CauldronHudRoot/ChemistryCard/Margin/ChemVisualCanvas
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

var _cust_patience_fill: StyleBoxFlat = null
var _toast_timer: float = 0.0


func _ready() -> void:
	if _cust_patience_bar != null:
		var fill_sb: StyleBox = _cust_patience_bar.get_theme_stylebox("fill")
		if fill_sb is StyleBoxFlat:
			_cust_patience_fill = fill_sb.duplicate() as StyleBoxFlat
			_cust_patience_bar.add_theme_stylebox_override("fill", _cust_patience_fill)

	if trixie_bubble != null:
		trixie_bubble.set_base_position(trixie_bubble.position)
		trixie_bubble.hide_bubble(true)
		trixie_bubble.ack_pressed.connect(func() -> void: tutorial_ack_pressed.emit())

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


func show_trixie_bubble(title: String, text: String, duration: float, is_tutorial: bool = false, show_ack: bool = false) -> void:
	if trixie_bubble != null:
		trixie_bubble.show_message(title, text, duration, is_tutorial, show_ack)


func hide_trixie_bubble(instant: bool = false) -> void:
	if trixie_bubble != null:
		trixie_bubble.hide_bubble(instant)


func is_trixie_bubble_tutorial() -> bool:
	return trixie_bubble != null and trixie_bubble.is_tutorial_mode


func show_customer_bubble(speaker_name: String, text: String, duration: float = 3.2) -> void:
	if customer_bubble != null:
		customer_bubble.show_message(speaker_name, text, duration, false, false)


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

	var p_ratio: float = clampf(patience_left / maxf(1.0, patience_max), 0.0, 1.0)
	if patience_paused:
		_top_timer_lbl.text = "⏸ Tutorial"
		_top_timer_lbl.modulate = Color(1.0, 0.88, 0.42)
	else:
		var secs_int: int = ceili(patience_left)
		_top_timer_lbl.text = "⏳ Paciencia: %ds" % secs_int
		_top_timer_lbl.modulate = Color(1.0, 0.38, 0.42) if p_ratio <= impatient_ratio else Color(1.0, 0.94, 0.78)

	if _cust_patience_bar != null:
		_cust_patience_bar.value = p_ratio * 100.0
	if _cust_patience_fill != null:
		if patience_paused:
			_cust_patience_fill.bg_color = Color(0.45, 0.82, 1.0)
		elif p_ratio > 0.55:
			_cust_patience_fill.bg_color = Color(0.32, 0.88, 0.56)
		elif p_ratio > impatient_ratio:
			_cust_patience_fill.bg_color = Color(0.98, 0.74, 0.24)
		else:
			_cust_patience_fill.bg_color = Color(1.0, 0.30, 0.38)
	if _cust_patience_lbl != null:
		if patience_paused:
			_cust_patience_lbl.text = "⏸ Pausado"
			_cust_patience_lbl.modulate = Color(0.65, 0.92, 1.0)
		else:
			var p_secs: int = ceili(patience_left)
			_cust_patience_lbl.text = "⏳ Paciencia: %ds" % p_secs
			_cust_patience_lbl.modulate = Color(1.0, 0.42, 0.46) if p_ratio <= impatient_ratio else Color(1.0, 0.92, 0.65)

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

	if customer_title != "" and _cust_name_lbl != null:
		_cust_name_lbl.text = customer_title
	if affinity_text != "" and _cust_aff_lbl != null:
		_cust_aff_lbl.text = affinity_text
	if chem_visual_canvas != null:
		chem_visual_canvas.queue_redraw()
