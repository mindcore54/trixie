class_name KitchenHUD
extends CanvasLayer
## Implements the exact layout from imagen3.jpeg:
## Top-Left: Stats + Framed Reactive Witch Bust (6 expressions) + Witch switcher
## Top-Right: Day, Active Relics/Familiars, Queue capacity alert
## Bottom-Right: NO Q/W/E buttons — Large 2D Anime Customer Portrait + Chipped Old Parchment Dialogue
## Center Overlays: Diagonal Anime Cut-in, Roguelite Upgrade Draft Modal, Defeat/Victory card

signal witch_switch_requested(witch_id: StringName)
signal force_draft_requested()
signal toggle_fullscreen_requested()
signal upgrade_chosen(upgrade: RogueliteUpgradeData)
signal reroll_requested()
signal restart_run_requested()

var _current_witch: WitchCharacterData
var _current_emotion: EventBus.WitchEmotion = EventBus.WitchEmotion.NORMAL
var _emotion_revert_timer: float = 0.0
var _hearts: int = 3
var _max_hearts: int = 3
var _gold: int = 0
var _combo: int = 0
var _day_num: int = 1
var _time_left: float = 65.0
var _queue_count: int = 0
var _active_customer_id: StringName = &"sylvi"
var _customer_line: String = "¡Necesito algo bien fuerte para esta noche!"
var _customer_spicy: bool = false
var _customer_affinity: int = 0
var _customer_portrait_tex: Texture2D = null
var _cutin_timer: float = 0.0
var _cutin_text: String = ""

var _clock_label: Label
var _gold_label: Label
var _hearts_label: Label
var _combo_label: Label
var _day_label: Label
var _queue_label: Label
var _relics_label: Label
var _ability_label: Label
var _bust_canvas: Control
var _customer_canvas: Control
var _parchment_label: Label
var _customer_name_label: Label
var _cutin_panel: Control
var _cutin_title: Label
var _draft_overlay: Control
var _draft_cards_box: HBoxContainer
var _reroll_btn: Button
var _end_overlay: Control
var _end_title: Label
var _end_stats: Label
var _witch_btn: Button
var _all_witches: Array[WitchCharacterData] = []
var _witch_idx: int = 0


func _ready() -> void:
	_build_ui()
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.combo_changed.connect(_on_combo_changed)
	EventBus.witch_emotion_changed.connect(_on_witch_emotion_changed)
	EventBus.customer_dialogue_requested.connect(_on_customer_dialogue_requested)
	EventBus.witch_ability_triggered.connect(_on_witch_ability_triggered)


func configure_witches(witches: Array[WitchCharacterData], active_idx: int = 0) -> void:
	_all_witches = witches
	_witch_idx = clampi(active_idx, 0, maxi(0, witches.size() - 1))
	if not _all_witches.is_empty():
		_current_witch = _all_witches[_witch_idx]
		if _witch_btn:
			_witch_btn.text = "Bruja: %s ▾" % _current_witch.display_name
	if _bust_canvas:
		_bust_canvas.queue_redraw()


func update_runtime_stats(day_num: int, time_left: float, hearts: int, max_hearts: int, queue_count: int, ability_cd: float, relics_names: PackedStringArray) -> void:
	_day_num = day_num
	_time_left = maxf(0.0, time_left)
	_hearts = hearts
	_max_hearts = max_hearts
	_queue_count = queue_count

	var mins: int = int(_time_left) / 60
	var secs: int = int(_time_left) % 60
	_clock_label.text = "%02d:%02d" % [mins, secs]
	_day_label.text = "DÍA %d/8" % _day_num
	_hearts_label.text = "♥ ".repeat(maxi(0, _hearts)) + "♡ ".repeat(maxi(0, _max_hearts - _hearts))
	_queue_label.text = "FILA: %d/5" % _queue_count
	_queue_label.modulate = Color(1.0, 0.35, 0.35) if _queue_count >= 4 else Color(1.0, 0.96, 0.88)
	_relics_label.text = "Reliquias: " + (", ".join(relics_names) if not relics_names.is_empty() else "Ninguna aún")

	if _current_witch:
		_ability_label.text = "[Clic Der] %s: %s" % [
			_current_witch.active_name,
			"¡LISTA!" if ability_cd <= 0.0 else ("%ds" % ceili(ability_cd * _current_witch.active_cooldown_sec))
		]

	if _emotion_revert_timer <= 0.0:
		var auto_emo: EventBus.WitchEmotion = EventBus.WitchEmotion.NORMAL
		if _hearts <= 1 or _queue_count >= 4:
			auto_emo = EventBus.WitchEmotion.NERVIOSA_SUDANDO
		elif _combo >= 3:
			auto_emo = EventBus.WitchEmotion.CONFIADA
		if _current_emotion != auto_emo:
			_current_emotion = auto_emo
			_bust_canvas.queue_redraw()


func set_customer_affinity(cust_id: StringName, affinity: int) -> void:
	if _active_customer_id == cust_id:
		_customer_affinity = affinity
		_update_customer_header()


func show_draft_modal(options: Array[RogueliteUpgradeData], reroll_cost: int, can_afford_reroll: bool) -> void:
	for child: Node in _draft_cards_box.get_children():
		child.queue_free()

	for upg: RogueliteUpgradeData in options:
		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(280, 320)
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.11, 0.22, 0.96)
		sb.border_color = _rarity_color(upg.rarity)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(12)
		card.add_theme_stylebox_override("panel", sb)

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_bottom", 16)
		margin.add_child(vbox)
		card.add_child(margin)

		var tag_lbl: Label = Label.new()
		tag_lbl.text = " · ".join(upg.synergy_tags)
		tag_lbl.modulate = _rarity_color(upg.rarity)
		vbox.add_child(tag_lbl)

		var title_lbl: Label = Label.new()
		title_lbl.text = upg.display_name
		title_lbl.add_theme_font_size_override("font_size", 22)
		title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(title_lbl)

		var desc_lbl: Label = Label.new()
		desc_lbl.text = upg.description
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(desc_lbl)

		var pick_btn: Button = Button.new()
		pick_btn.text = "ELEGIR MEJORA"
		pick_btn.custom_minimum_size = Vector2(0, 44)
		pick_btn.pressed.connect(func() -> void:
			_draft_overlay.visible = false
			upgrade_chosen.emit(upg)
		)
		vbox.add_child(pick_btn)
		_draft_cards_box.add_child(card)

	_reroll_btn.text = "Reroll (%dg)" % reroll_cost
	_reroll_btn.disabled = not can_afford_reroll
	_draft_overlay.visible = true


func show_end_screen(victory: bool, reason_text: String, essence_earned: int) -> void:
	_current_emotion = EventBus.WitchEmotion.CONFIADA if victory else EventBus.WitchEmotion.HOLLIN_DERROTA
	_bust_canvas.queue_redraw()
	_end_title.text = "¡TURNO DEL SABBAT SUPERADO!" if victory else "¡CAOS EN LA COCINA! (HOLLÍN)"
	_end_title.modulate = Color(0.45, 1.0, 0.65) if victory else Color(1.0, 0.42, 0.42)
	_end_stats.text = "%s\n\nDía alcanzado: %d | Oro total: %dg\nEsencias Arcanas ganadas: +%d" % [
		reason_text, _day_num, _gold, essence_earned
	]
	_end_overlay.visible = true


func hide_overlays() -> void:
	_draft_overlay.visible = false
	_end_overlay.visible = false


func _process(delta: float) -> void:
	if _emotion_revert_timer > 0.0:
		_emotion_revert_timer -= delta
		if _emotion_revert_timer <= 0.0:
			_current_emotion = EventBus.WitchEmotion.NORMAL
			_bust_canvas.queue_redraw()
	if _cutin_timer > 0.0:
		_cutin_timer -= delta
		if _cutin_timer <= 0.0:
			_cutin_panel.visible = false


func _on_gold_changed(new_total: int, _delta: int) -> void:
	_gold = new_total
	_gold_label.text = "ORO: %d" % _gold


func _on_combo_changed(new_combo: int, mult: float) -> void:
	_combo = new_combo
	if _combo <= 1:
		_combo_label.visible = false
	else:
		_combo_label.visible = true
		_combo_label.text = "¡COMBO x%d! (%.1fx)" % [_combo, mult]


func _on_witch_emotion_changed(emotion: EventBus.WitchEmotion, duration_sec: float) -> void:
	_current_emotion = emotion
	_emotion_revert_timer = duration_sec
	_bust_canvas.queue_redraw()


func _on_customer_dialogue_requested(customer_id: StringName, portrait_texture: Texture2D, line_text: String, is_spicy: bool) -> void:
	_active_customer_id = customer_id
	_customer_portrait_tex = portrait_texture
	_customer_line = line_text
	_customer_spicy = is_spicy
	_parchment_label.text = line_text
	_update_customer_header()
	_customer_canvas.queue_redraw()


func _on_witch_ability_triggered(witch_id: StringName, _cutin: Texture2D) -> void:
	_cutin_text = "¡%s: HABILIDAD ACTIVA!" % String(witch_id).to_upper()
	_cutin_title.text = _cutin_text
	_cutin_panel.visible = true
	_cutin_timer = 0.85


func _update_customer_header() -> void:
	var hearts_str: String = "♥".repeat(clampi(_customer_affinity, 0, 3)) + "♡".repeat(maxi(0, 3 - _customer_affinity))
	_customer_name_label.text = "%s  %s" % [String(_active_customer_id).capitalize(), hearts_str]


func _build_ui() -> void:
	# Top-Left Stats + Framed Reactive Bust
	var top_left: VBoxContainer = VBoxContainer.new()
	top_left.position = Vector2(20, 16)
	top_left.add_theme_constant_override("separation", 8)
	add_child(top_left)

	var stats_bar: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.09, 0.16, 0.88)
	sb.border_color = Color(0.76, 0.56, 0.30)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	stats_bar.add_theme_stylebox_override("panel", sb)
	top_left.add_child(stats_bar)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 14)
	pad.add_theme_constant_override("margin_right", 14)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	pad.add_child(hbox)
	stats_bar.add_child(pad)

	_clock_label = _make_label("01:05", 24, Color(1.0, 0.96, 0.85))
	_gold_label = _make_label("ORO: 0", 24, Color(1.0, 0.84, 0.28))
	_hearts_label = _make_label("♥ ♥ ♥", 24, Color(1.0, 0.32, 0.42))
	hbox.add_child(_clock_label)
	hbox.add_child(_gold_label)
	hbox.add_child(_hearts_label)

	var bust_row: HBoxContainer = HBoxContainer.new()
	bust_row.add_theme_constant_override("separation", 12)
	top_left.add_child(bust_row)

	_bust_canvas = Control.new()
	_bust_canvas.custom_minimum_size = Vector2(150, 150)
	_bust_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bust_canvas.draw.connect(_draw_witch_bust)
	bust_row.add_child(_bust_canvas)

	var controls_col: VBoxContainer = VBoxContainer.new()
	controls_col.add_theme_constant_override("separation", 6)
	bust_row.add_child(controls_col)

	_witch_btn = Button.new()
	_witch_btn.text = "Bruja: Trixie ▾"
	_witch_btn.pressed.connect(func() -> void:
		if _all_witches.is_empty():
			return
		_witch_idx = (_witch_idx + 1) % _all_witches.size()
		_current_witch = _all_witches[_witch_idx]
		_witch_btn.text = "Bruja: %s ▾" % _current_witch.display_name
		witch_switch_requested.emit(_current_witch.witch_id)
		_bust_canvas.queue_redraw()
	)
	controls_col.add_child(_witch_btn)

	var draft_test_btn: Button = Button.new()
	draft_test_btn.text = "Abrir Draft Roguelite (Test)"
	draft_test_btn.pressed.connect(func() -> void: force_draft_requested.emit())
	controls_col.add_child(draft_test_btn)

	var fs_btn: Button = Button.new()
	fs_btn.text = "Pantalla Completa (F11)"
	fs_btn.pressed.connect(func() -> void: toggle_fullscreen_requested.emit())
	controls_col.add_child(fs_btn)

	_combo_label = _make_label("¡COMBO x2!", 22, Color(1.0, 0.68, 0.22))
	_combo_label.visible = false
	controls_col.add_child(_combo_label)

	# Top-Right Day, Queue Warning & Relics
	var top_right: VBoxContainer = VBoxContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.offset_left = -450
	top_right.offset_right = -20
	top_right.offset_top = 16
	top_right.add_theme_constant_override("separation", 6)
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_right)

	var tr_panel: PanelContainer = PanelContainer.new()
	tr_panel.add_theme_stylebox_override("panel", sb)
	tr_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_right.add_child(tr_panel)

	var tr_vbox: VBoxContainer = VBoxContainer.new()
	var tr_pad: MarginContainer = MarginContainer.new()
	tr_pad.add_theme_constant_override("margin_left", 14)
	tr_pad.add_theme_constant_override("margin_right", 14)
	tr_pad.add_theme_constant_override("margin_top", 8)
	tr_pad.add_theme_constant_override("margin_bottom", 8)
	tr_pad.add_child(tr_vbox)
	tr_panel.add_child(tr_pad)

	var day_row: HBoxContainer = HBoxContainer.new()
	day_row.add_theme_constant_override("separation", 20)
	_day_label = _make_label("DÍA 1/8", 22, Color(0.98, 0.90, 0.65))
	_queue_label = _make_label("FILA: 0/5", 22, Color(1.0, 0.96, 0.88))
	day_row.add_child(_day_label)
	day_row.add_child(_queue_label)
	tr_vbox.add_child(day_row)

	_ability_label = _make_label("[Clic Der] Fiebre Escarlata: ¡LISTA!", 16, Color(1.0, 0.62, 0.72))
	tr_vbox.add_child(_ability_label)
	_relics_label = _make_label("Reliquias: Ninguna aún", 15, Color(0.82, 0.85, 0.95))
	_relics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tr_vbox.add_child(_relics_label)

	# Bottom-Right: NO Q/W/E buttons — Large Customer Portrait + Chipped Old Parchment Dialogue
	var br_root: Control = Control.new()
	br_root.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br_root.offset_left = -490
	br_root.offset_right = -16
	br_root.offset_top = -380
	br_root.offset_bottom = -14
	br_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(br_root)

	_customer_canvas = Control.new()
	_customer_canvas.position = Vector2(180, 0)
	_customer_canvas.size = Vector2(280, 260)
	_customer_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_customer_canvas.draw.connect(_draw_customer_portrait)
	br_root.add_child(_customer_canvas)

	var parchment: Control = Control.new()
	parchment.position = Vector2(0, 232)
	parchment.size = Vector2(465, 130)
	parchment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parchment.draw.connect(func() -> void: _draw_chipped_parchment(parchment))
	br_root.add_child(parchment)

	_customer_name_label = _make_label("Sylvi  ♡♡♡", 18, Color(0.42, 0.14, 0.12))
	_customer_name_label.position = Vector2(24, 14)
	parchment.add_child(_customer_name_label)

	_parchment_label = _make_label(_customer_line, 19, Color(0.18, 0.11, 0.07))
	_parchment_label.position = Vector2(24, 44)
	_parchment_label.size = Vector2(416, 76)
	_parchment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parchment.add_child(_parchment_label)

	# Cut-In Banner
	_cutin_panel = Control.new()
	_cutin_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cutin_panel.visible = false
	_cutin_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutin_panel.draw.connect(func() -> void:
		_cutin_panel.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.05, 0.02, 0.10, 0.45))
		_cutin_panel.draw_colored_polygon(
			PackedVector2Array([Vector2(0, 380), Vector2(1920, 310), Vector2(1920, 560), Vector2(0, 630)]),
			Color(0.85, 0.16, 0.36, 0.94)
		)
	)
	add_child(_cutin_panel)
	_cutin_title = _make_label("¡HABILIDAD ESPECIAL!", 54, Color(1.0, 0.96, 0.88))
	_cutin_title.set_anchors_preset(Control.PRESET_CENTER)
	_cutin_title.offset_left = -450
	_cutin_title.offset_right = 450
	_cutin_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cutin_panel.add_child(_cutin_title)

	# Draft Overlay
	_draft_overlay = ColorRect.new()
	_draft_overlay.color = Color(0.04, 0.02, 0.08, 0.78)
	_draft_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draft_overlay.visible = false
	add_child(_draft_overlay)

	var draft_center: CenterContainer = CenterContainer.new()
	draft_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draft_overlay.add_child(draft_center)

	var draft_vbox: VBoxContainer = VBoxContainer.new()
	draft_vbox.add_theme_constant_override("separation", 20)
	draft_center.add_child(draft_vbox)

	var draft_hdr: Label = _make_label("¡FIN DEL DÍA! ELIGE 1 MEJORA ROGUELITE", 34, Color(1.0, 0.88, 0.42))
	draft_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draft_vbox.add_child(draft_hdr)

	_draft_cards_box = HBoxContainer.new()
	_draft_cards_box.add_theme_constant_override("separation", 24)
	draft_vbox.add_child(_draft_cards_box)

	var reroll_center: CenterContainer = CenterContainer.new()
	_reroll_btn = Button.new()
	_reroll_btn.text = "Reroll (35g)"
	_reroll_btn.custom_minimum_size = Vector2(220, 44)
	_reroll_btn.pressed.connect(func() -> void: reroll_requested.emit())
	reroll_center.add_child(_reroll_btn)
	draft_vbox.add_child(reroll_center)

	# End / Defeat Overlay
	_end_overlay = ColorRect.new()
	_end_overlay.color = Color(0.05, 0.02, 0.06, 0.88)
	_end_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_overlay.visible = false
	add_child(_end_overlay)

	var end_center: CenterContainer = CenterContainer.new()
	end_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_overlay.add_child(end_center)

	var end_box: VBoxContainer = VBoxContainer.new()
	end_box.add_theme_constant_override("separation", 18)
	end_center.add_child(end_box)

	_end_title = _make_label("FIN DE LA PARTIDA", 42, Color.WHITE)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_stats = _make_label("", 22, Color(0.95, 0.92, 0.90))
	_end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var retry_btn: Button = Button.new()
	retry_btn.text = "REINTENTAR RUN"
	retry_btn.custom_minimum_size = Vector2(260, 54)
	retry_btn.pressed.connect(func() -> void:
		_end_overlay.visible = false
		restart_run_requested.emit()
	)
	end_box.add_child(_end_title)
	end_box.add_child(_end_stats)
	end_box.add_child(retry_btn)


func _draw_witch_bust() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, _bust_canvas.size)
	var bg_col: Color = Color(0.24, 0.16, 0.30)
	var border_col: Color = Color(0.76, 0.56, 0.30)
	if _current_emotion == EventBus.WitchEmotion.NERVIOSA_SUDANDO:
		bg_col = Color(0.38, 0.22, 0.18)
		border_col = Color(1.0, 0.55, 0.25)
	elif _current_emotion == EventBus.WitchEmotion.HOLLIN_DERROTA:
		bg_col = Color(0.18, 0.15, 0.17)
		border_col = Color(0.95, 0.25, 0.28)
	elif _current_emotion == EventBus.WitchEmotion.CONFIADA:
		bg_col = Color(0.26, 0.20, 0.38)
		border_col = Color(1.0, 0.85, 0.32)

	_bust_canvas.draw_rect(rect, bg_col)
	_bust_canvas.draw_rect(rect, border_col, false, 5.0)

	# Stylized placeholder bust showing live expression (replaced automatically if Texture2D is assigned)
	var cx: float = 75.0
	_bust_canvas.draw_circle(Vector2(cx, 132), 42.0, Color(0.45, 0.22, 0.62))
	_bust_canvas.draw_circle(Vector2(cx, 118), 22.0, Color(1.0, 0.86, 0.78))
	_bust_canvas.draw_circle(Vector2(cx, 72), 28.0, Color(1.0, 0.87, 0.79))
	_bust_canvas.draw_colored_polygon(PackedVector2Array([Vector2(cx - 38, 52), Vector2(cx + 38, 52), Vector2(cx, 14)]), Color(0.28, 0.14, 0.42))
	# Eyes / Blush / Soot based on emotion
	_bust_canvas.draw_circle(Vector2(cx - 10, 72), 3.5, Color(0.1, 0.08, 0.14))
	_bust_canvas.draw_circle(Vector2(cx + 10, 72), 3.5, Color(0.1, 0.08, 0.14))
	if _current_emotion == EventBus.WitchEmotion.NERVIOSA_SUDANDO:
		_bust_canvas.draw_circle(Vector2(cx + 22, 58), 4.0, Color(0.45, 0.85, 1.0))
		_bust_canvas.draw_line(Vector2(cx - 8, 86), Vector2(cx + 8, 84), Color(0.4, 0.15, 0.15), 2.5)
	elif _current_emotion == EventBus.WitchEmotion.HOLLIN_DERROTA:
		_bust_canvas.draw_circle(Vector2(cx - 12, 80), 8.0, Color(0.12, 0.10, 0.12, 0.65))
		_bust_canvas.draw_circle(Vector2(cx + 10, 124), 10.0, Color(0.12, 0.10, 0.12, 0.65))
	else:
		_bust_canvas.draw_arc(Vector2(cx, 78), 7.0, 0.2, PI - 0.2, 8, Color(0.55, 0.15, 0.22), 2.5)

	var emo_name: String = EventBus.WitchEmotion.keys()[int(_current_emotion)]
	_bust_canvas.draw_string(ThemeDB.fallback_font, Vector2(8, 142), emo_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.85))


func _draw_customer_portrait() -> void:
	if _customer_portrait_tex != null:
		_customer_canvas.draw_texture_rect(_customer_portrait_tex, Rect2(Vector2.ZERO, _customer_canvas.size), false)
		return
	var cx: float = 140.0
	var col: Color = CustomerEntity._character_color(_active_customer_id)
	# Bust & outfit placeholder with Helltaker-style bold outline
	_customer_canvas.draw_colored_polygon(
		PackedVector2Array([Vector2(cx - 72, 250), Vector2(cx + 72, 250), Vector2(cx + 46, 150), Vector2(cx - 46, 150)]),
		col
	)
	_customer_canvas.draw_circle(Vector2(cx, 158), 34.0, Color(1.0, 0.86, 0.78))
	# Head + character flair
	_customer_canvas.draw_circle(Vector2(cx, 96), 44.0, Color(1.0, 0.87, 0.79))
	_customer_canvas.draw_circle(Vector2(cx, 96), 44.0, Color(0.10, 0.07, 0.13), false, 3.5)
	if _active_customer_id == &"sylvi":
		_customer_canvas.draw_arc(Vector2(cx - 38, 68), 22.0, 0.3, PI * 1.35, 14, Color(0.75, 0.56, 0.40), 9.0)
		_customer_canvas.draw_arc(Vector2(cx + 38, 68), 22.0, -PI * 0.35, PI * 0.7, 14, Color(0.75, 0.56, 0.40), 9.0)
	elif _active_customer_id == &"velvet":
		_customer_canvas.draw_colored_polygon(PackedVector2Array([Vector2(cx - 20, 56), Vector2(cx - 40, 22), Vector2(cx - 6, 54)]), Color(0.20, 0.08, 0.15))
		_customer_canvas.draw_colored_polygon(PackedVector2Array([Vector2(cx + 20, 56), Vector2(cx + 40, 22), Vector2(cx + 6, 54)]), Color(0.20, 0.08, 0.15))
	# Eyes + Spicy blush
	_customer_canvas.draw_circle(Vector2(cx - 15, 92), 4.5, Color(0.12, 0.08, 0.15))
	_customer_canvas.draw_circle(Vector2(cx + 15, 92), 4.5, Color(0.12, 0.08, 0.15))
	if _customer_spicy:
		_customer_canvas.draw_circle(Vector2(cx - 22, 105), 11.0, Color(1.0, 0.42, 0.54, 0.65))
		_customer_canvas.draw_circle(Vector2(cx + 22, 105), 11.0, Color(1.0, 0.42, 0.54, 0.65))
	_customer_canvas.draw_arc(Vector2(cx, 108), 10.0, 0.1, PI - 0.1, 10, Color(0.72, 0.20, 0.28), 3.0)


func _draw_chipped_parchment(ctrl: Control) -> void:
	var w: float = ctrl.size.x
	var h: float = ctrl.size.y
	# Chipped weathered edges polygon
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(8, 4), Vector2(120, 2), Vector2(130, 10), Vector2(142, 2),
		Vector2(w - 18, 5), Vector2(w - 6, 18), Vector2(w - 10, 55), Vector2(w - 2, 70),
		Vector2(w - 8, h - 10), Vector2(w - 40, h - 4), Vector2(w - 52, h - 13), Vector2(w - 66, h - 4),
		Vector2(80, h - 5), Vector2(68, h - 12), Vector2(56, h - 4), Vector2(10, h - 8),
		Vector2(2, 65), Vector2(12, 52), Vector2(4, 22)
	])
	ctrl.draw_colored_polygon(pts, Color(0.91, 0.81, 0.63, 0.96))
	ctrl.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.32, 0.20, 0.11), 3.5)


static func _make_label(txt: String, fsize: int, col: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.10))
	lbl.add_theme_constant_override("outline_size", 3)
	return lbl


static func _rarity_color(rarity: RogueliteUpgradeData.Rarity) -> Color:
	match rarity:
		RogueliteUpgradeData.Rarity.COMMON: return Color(0.72, 0.80, 0.92)
		RogueliteUpgradeData.Rarity.RARE: return Color(0.36, 0.78, 1.0)
		RogueliteUpgradeData.Rarity.EPIC: return Color(0.84, 0.42, 1.0)
		RogueliteUpgradeData.Rarity.BROKEN_SYNERGY: return Color(1.0, 0.76, 0.22)
	return Color.WHITE
