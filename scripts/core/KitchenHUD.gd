class_name KitchenHUD
extends CanvasLayer
## Kitchen HUD & Overlays:
## Top-Left: Clock, Gold, Hearts, XP Bar, Static Witch Portrait/Name (no mid-run switcher)
## Top-Right: Day, Active XP Skills/Familiars, Queue capacity alert
## Bottom-Right: Large 2D Anime Customer Portrait + Chipped Old Parchment Dialogue
## Center Overlays: Diagonal Anime Cut-in, XP Level-Up Draft Modal, Between-Days Witch & Gold Build Screen, End Card

signal force_draft_requested()
signal force_end_day_requested()
signal toggle_fullscreen_requested()
signal upgrade_chosen(upgrade: RogueliteUpgradeData)
signal reroll_requested()
signal build_upgrade_purchased(build_id: StringName)
signal witch_selected_between_days(witch_id: StringName)
signal active_skill_slot_pressed(slot_idx: int)
signal next_day_requested()
signal restart_run_requested()
signal return_to_menu_requested()

var _current_witch: WitchCharacterData
var _current_emotion: EventBus.WitchEmotion = EventBus.WitchEmotion.NORMAL
var _emotion_revert_timer: float = 0.0
var _hearts: int = 3
var _max_hearts: int = 3
var _gold: int = 0
var _combo: int = 0
var _day_num: int = 1
var _time_left: float = 300.0
var _queue_count: int = 0
var _xp_level: int = 1
var _xp_current: int = 0
var _xp_required: int = 80
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
var _xp_bar_fill: ColorRect
var _xp_label: Label
var _witch_name_label: Label
var _combo_label: Label
var _day_label: Label
var _queue_label: Label
var _slots_label: Label
var _relics_label: Label
var _ability_label: Label
var _active_buttons: Array[Button] = []
var _bust_canvas: Control
var _customer_canvas: Control
var _parchment_label: Label
var _customer_name_label: Label
var _trixie_dlg_root: Control
var _trixie_dlg_canvas: Control
var _trixie_dlg_label: Label
var _trixie_dlg_emotion: String = "normal"
var _trixie_dlg_timer: float = 0.0
var _trixie_dlg_time: float = 0.0
var _cutin_panel: Control
var _cutin_title: Label

var _draft_overlay: Control
var _draft_hdr_label: Label
var _draft_slots_label: Label
var _draft_cards_box: HBoxContainer
var _reroll_btn: Button

var _build_screen_overlay: Control
var _build_header_title: Label
var _build_header_stats: Label
var _fullbody_canvas: Control
var _build_witch_name_lbl: Label
var _build_witch_skills_lbl: Label
var _build_witch_buttons_grid: GridContainer
var _build_cards_grid: GridContainer
var _build_xp_summary_lbl: Label
var _next_day_btn: Button
var _selected_build_witch: WitchCharacterData

var _end_overlay: Control
var _end_title: Label
var _end_stats: Label
var _all_witches: Array[WitchCharacterData] = []
var _witch_idx: int = 0


func _ready() -> void:
	_build_ui()
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.xp_changed.connect(_on_xp_changed)
	EventBus.combo_changed.connect(_on_combo_changed)
	EventBus.witch_emotion_changed.connect(_on_witch_emotion_changed)
	EventBus.customer_dialogue_requested.connect(_on_customer_dialogue_requested)
	EventBus.witch_ability_triggered.connect(_on_witch_ability_triggered)


func configure_witches(witches: Array[WitchCharacterData], active_idx: int = 0) -> void:
	_all_witches = witches
	_witch_idx = clampi(active_idx, 0, maxi(0, witches.size() - 1))
	if not _all_witches.is_empty():
		_current_witch = _all_witches[_witch_idx]
		_selected_build_witch = _current_witch
		if _witch_name_label:
			_witch_name_label.text = "Bruja: %s" % _current_witch.display_name
	if _bust_canvas:
		_bust_canvas.queue_redraw()
	if _fullbody_canvas:
		_fullbody_canvas.queue_redraw()


func update_runtime_stats(day_num: int, time_left: float, hearts: int, max_hearts: int, queue_count: int, ability_cd: float, relics_names: PackedStringArray, ability_cd_secs: float = -1.0, slot_counts: Vector3i = Vector3i.ZERO, active_slots_info: Array[Dictionary] = [], is_rush_hour: bool = false) -> void:
	_day_num = day_num
	_time_left = maxf(0.0, time_left)
	_hearts = hearts
	_max_hearts = max_hearts
	_queue_count = queue_count

	var mins: int = int(_time_left) / 60
	var secs: int = int(_time_left) % 60
	if _time_left <= 0.0:
		_clock_label.text = "CERRANDO"
		_clock_label.modulate = Color(1.0, 0.72, 0.25)
	else:
		_clock_label.text = "%02d:%02d" % [mins, secs]
		_clock_label.modulate = Color(1.0, 0.36, 0.28) if is_rush_hour else Color(1.0, 0.96, 0.85)
	_day_label.text = "DÍA %d/8" % _day_num
	_hearts_label.text = "♥ ".repeat(maxi(0, _hearts)) + "♡ ".repeat(maxi(0, _max_hearts - _hearts))
	_queue_label.text = "FILA: %d/5" % _queue_count
	_queue_label.modulate = Color(1.0, 0.35, 0.35) if _queue_count >= 4 else Color(1.0, 0.96, 0.88)
	if _slots_label:
		_slots_label.text = "Slots: Familiar %d/1 | Pasivas %d/3 | Activas %d/3" % [slot_counts.x, slot_counts.y, slot_counts.z]
	_relics_label.text = "Habilidades XP: " + (", ".join(relics_names) if not relics_names.is_empty() else "Ninguna aún")

	for i: int in range(_active_buttons.size()):
		var btn: Button = _active_buttons[i]
		if i < active_slots_info.size():
			var info: Dictionary = active_slots_info[i]
			var s_name: String = String(info.get("name", "Activa"))
			var s_lvl: int = int(info.get("level", 1))
			var cd_left: float = float(info.get("cd_left", 0.0))
			if cd_left <= 0.0:
				btn.text = "[%d] %s (Nv.%d)\n¡LISTA!" % [i + 1, s_name, s_lvl]
				btn.disabled = false
				btn.modulate = Color(1.0, 0.94, 0.65)
			else:
				btn.text = "[%d] %s (Nv.%d)\nRecarga: %ds" % [i + 1, s_name, s_lvl, ceili(cd_left)]
				btn.disabled = true
				btn.modulate = Color(0.76, 0.76, 0.86)
		else:
			btn.text = "[%d] Activa Vacía" % [i + 1]
			btn.disabled = true
			btn.modulate = Color(0.55, 0.55, 0.65)

	if _current_witch:
		var secs_left: int = ceili(ability_cd_secs) if ability_cd_secs >= 0.0 else ceili(ability_cd * _current_witch.active_cooldown_sec)
		_ability_label.text = "[Clic Der] %s: %s" % [
			_current_witch.active_name,
			"¡LISTA!" if ability_cd <= 0.0 else ("%ds" % secs_left)
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


func show_draft_modal(options: Array[RogueliteUpgradeData], reroll_cost: int, can_afford_reroll: bool, current_levels: Dictionary = {}, xp_level: int = 1, slot_counts: Vector3i = Vector3i.ZERO) -> void:
	for child: Node in _draft_cards_box.get_children():
		child.queue_free()

	_draft_hdr_label.text = "¡SUBISTE A NIVEL %d! ELIGE O MEJORA UNA HABILIDAD" % xp_level
	if _draft_slots_label:
		_draft_slots_label.text = "Slots actuales: Familiar %d/1  |  Pasivas %d/3  |  Activas %d/3" % [slot_counts.x, slot_counts.y, slot_counts.z]

	for upg: RogueliteUpgradeData in options:
		var cur_lvl: int = int(current_levels.get(upg.upgrade_id, 0))
		var next_lvl: int = cur_lvl + 1

		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(290, 355)
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.11, 0.22, 0.96)
		sb.border_color = _rarity_color(upg.rarity)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(12)
		card.add_theme_stylebox_override("panel", sb)

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_bottom", 16)
		margin.add_child(vbox)
		card.add_child(margin)

		var kind_badge: Label = Label.new()
		match upg.kind:
			RogueliteUpgradeData.UpgradeKind.FAMILIAR_SUMMON:
				kind_badge.text = "[FAMILIAR]"
				kind_badge.modulate = Color(0.95, 0.55, 1.0)
			RogueliteUpgradeData.UpgradeKind.ACTIVE_SKILL:
				kind_badge.text = "[ACTIVA]"
				kind_badge.modulate = Color(1.0, 0.58, 0.35)
			_:
				kind_badge.text = "[PASIVA]"
				kind_badge.modulate = Color(0.42, 0.85, 1.0)
		vbox.add_child(kind_badge)

		var level_badge: Label = Label.new()
		if cur_lvl <= 0:
			level_badge.text = "NUEVA (Nv. 1 / %d)" % upg.max_stacks
			level_badge.modulate = Color(0.45, 1.0, 0.65)
		else:
			level_badge.text = "MEJORAR (Nv. %d ➔ Nv. %d / %d)" % [cur_lvl, next_lvl, upg.max_stacks]
			level_badge.modulate = Color(1.0, 0.86, 0.30)
		vbox.add_child(level_badge)

		var tag_lbl: Label = Label.new()
		tag_lbl.text = " · ".join(upg.synergy_tags)
		tag_lbl.modulate = _rarity_color(upg.rarity)
		vbox.add_child(tag_lbl)

		var title_lbl: Label = Label.new()
		title_lbl.text = upg.display_name
		title_lbl.add_theme_font_size_override("font_size", 21)
		title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(title_lbl)

		var desc_lbl: Label = Label.new()
		desc_lbl.text = upg.description
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(desc_lbl)

		var pick_btn: Button = Button.new()
		pick_btn.text = "ELEGIR (Nv. 1)" if cur_lvl <= 0 else ("MEJORAR A NV. %d" % next_lvl)
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


func show_between_days_screen(
	completed_day: int,
	current_gold: int,
	current_hearts: int,
	max_hearts: int,
	active_witch: WitchCharacterData,
	all_witches: Array[WitchCharacterData],
	unlocked_witch_ids: Array[StringName],
	build_options: Array[Dictionary],
	saved_xp_skills_text: String
) -> void:
	_selected_build_witch = active_witch
	_all_witches = all_witches
	_build_header_title.text = "FIN DEL DÍA %d — PREPARACIÓN Y BUILDS" % completed_day
	_build_header_stats.text = "ORO DISPONIBLE: %dg   |   ♥ %d/%d" % [current_gold, current_hearts, max_hearts]

	if active_witch:
		_build_witch_name_lbl.text = "%s — %s" % [active_witch.display_name, active_witch.archetype_title]
		_build_witch_skills_lbl.text = "Pasiva: %s (%s)\nActiva: %s (%s)" % [
			active_witch.passive_name,
			active_witch.passive_description,
			active_witch.active_name,
			active_witch.active_description,
		]
	_fullbody_canvas.queue_redraw()

	for child: Node in _build_witch_buttons_grid.get_children():
		child.queue_free()

	for w: WitchCharacterData in all_witches:
		var is_unlocked: bool = unlocked_witch_ids.has(w.witch_id)
		var is_active: bool = active_witch != null and w.witch_id == active_witch.witch_id
		var w_btn: Button = Button.new()
		w_btn.custom_minimum_size = Vector2(170, 40)
		if not is_unlocked:
			w_btn.text = "🔒 %s (Historia)" % w.display_name
			w_btn.disabled = true
			w_btn.tooltip_text = "Las demás brujitas llegan según avanza la historia (no se compran con oro)."
		elif is_active:
			w_btn.text = "✓ %s (Activa)" % w.display_name
			w_btn.modulate = Color(1.0, 0.90, 0.45)
			w_btn.pressed.connect(func() -> void: witch_selected_between_days.emit(w.witch_id))
		else:
			w_btn.text = w.display_name
			w_btn.pressed.connect(func() -> void: witch_selected_between_days.emit(w.witch_id))
		_build_witch_buttons_grid.add_child(w_btn)

	for child: Node in _build_cards_grid.get_children():
		child.queue_free()

	for opt: Dictionary in build_options:
		var b_id: StringName = opt.get("id", &"") as StringName
		var title_txt: String = String(opt.get("title", ""))
		var desc_txt: String = String(opt.get("desc", ""))
		var lvl: int = int(opt.get("level", 0))
		var max_lvl: int = int(opt.get("max_level", 1))
		var cost: int = int(opt.get("cost", 50))
		var is_maxed: bool = lvl >= max_lvl

		var b_card: PanelContainer = PanelContainer.new()
		b_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_card.custom_minimum_size = Vector2(360, 128)
		var b_sb: StyleBoxFlat = StyleBoxFlat.new()
		b_sb.bg_color = Color(0.15, 0.11, 0.22, 0.95)
		b_sb.border_color = Color(0.45, 0.92, 0.60) if is_maxed else Color(0.76, 0.56, 0.30)
		b_sb.set_border_width_all(2)
		b_sb.set_corner_radius_all(10)
		b_card.add_theme_stylebox_override("panel", b_sb)

		var b_pad: MarginContainer = MarginContainer.new()
		b_pad.add_theme_constant_override("margin_left", 12)
		b_pad.add_theme_constant_override("margin_right", 12)
		b_pad.add_theme_constant_override("margin_top", 10)
		b_pad.add_theme_constant_override("margin_bottom", 10)
		b_card.add_child(b_pad)

		var b_vbox: VBoxContainer = VBoxContainer.new()
		b_vbox.add_theme_constant_override("separation", 6)
		b_pad.add_child(b_vbox)

		var top_line: HBoxContainer = HBoxContainer.new()
		var b_title: Label = _make_label(title_txt, 19, Color(1.0, 0.94, 0.75))
		b_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b_lvl: Label = _make_label("Nv. %d/%d" % [lvl, max_lvl], 17, Color(0.55, 0.95, 0.72))
		top_line.add_child(b_title)
		top_line.add_child(b_lvl)
		b_vbox.add_child(top_line)

		var b_desc: Label = Label.new()
		b_desc.text = desc_txt
		b_desc.add_theme_font_size_override("font_size", 14)
		b_desc.modulate = Color(0.88, 0.88, 0.95)
		b_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b_vbox.add_child(b_desc)

		var buy_btn: Button = Button.new()
		buy_btn.custom_minimum_size = Vector2(0, 34)
		if is_maxed:
			buy_btn.text = "MÁXIMO"
			buy_btn.disabled = true
		else:
			buy_btn.text = "MEJORAR (%dg)" % cost
			buy_btn.disabled = current_gold < cost
			buy_btn.pressed.connect(func() -> void: build_upgrade_purchased.emit(b_id))
		b_vbox.add_child(buy_btn)

		_build_cards_grid.add_child(b_card)

	_build_xp_summary_lbl.text = saved_xp_skills_text
	_next_day_btn.text = "COMENZAR DÍA %d (05:00) ➔" % (completed_day + 1)
	_build_screen_overlay.visible = true


func is_build_screen_visible() -> bool:
	return _build_screen_overlay != null and _build_screen_overlay.visible


func show_end_screen(victory: bool, reason_text: String, essence_earned: int) -> void:
	_current_emotion = EventBus.WitchEmotion.CONFIADA if victory else EventBus.WitchEmotion.HOLLIN_DERROTA
	_bust_canvas.queue_redraw()
	_end_title.text = "¡TURNO DEL SABBAT SUPERADO!" if victory else "¡CAOS EN LA COCINA! (HOLLÍN)"
	_end_title.modulate = Color(0.45, 1.0, 0.65) if victory else Color(1.0, 0.42, 0.42)
	_end_stats.text = "%s\n\nDía alcanzado: %d | Oro total: %dg | Nivel XP: %d\nEsencias Arcanas ganadas: +%d" % [
		reason_text, _day_num, _gold, _xp_level, essence_earned
	]
	_end_overlay.visible = true


func hide_overlays() -> void:
	_draft_overlay.visible = false
	_build_screen_overlay.visible = false
	_end_overlay.visible = false


func show_trixie_dialogue(line: String, emotion: String = "normal", auto_hide_sec: float = 0.0) -> void:
	if _trixie_dlg_root == null:
		return
	_trixie_dlg_emotion = emotion
	_trixie_dlg_label.text = line
	_trixie_dlg_timer = auto_hide_sec
	_trixie_dlg_root.visible = true
	if _bust_canvas != null:
		_bust_canvas.queue_redraw()


func hide_trixie_dialogue() -> void:
	if _trixie_dlg_root:
		_trixie_dlg_root.visible = false
		_trixie_dlg_timer = 0.0
	if _bust_canvas != null:
		_bust_canvas.queue_redraw()


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
	if _trixie_dlg_root != null and _trixie_dlg_root.visible:
		_trixie_dlg_time += delta
		if _trixie_dlg_timer > 0.0:
			_trixie_dlg_timer -= delta
			if _trixie_dlg_timer <= 0.0:
				_trixie_dlg_root.visible = false
				if _bust_canvas != null:
					_bust_canvas.queue_redraw()


func _on_gold_changed(new_total: int, _delta: int) -> void:
	_gold = new_total
	_gold_label.text = "ORO %d" % _gold


func _on_xp_changed(level: int, current_xp: int, required_xp: int) -> void:
	_xp_level = level
	_xp_current = current_xp
	_xp_required = maxi(1, required_xp)
	if _xp_bar_fill:
		_xp_bar_fill.anchor_right = clampf(float(_xp_current) / float(_xp_required), 0.0, 1.0)
	if _xp_label:
		_xp_label.text = "NV. %d — XP %d/%d" % [_xp_level, _xp_current, _xp_required]


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
	# Concept-art Top-Left HUD: [Clock] [Gold] [Hearts] in separate cozy wooden boxes -> XP Bar -> Square Portrait + Speech Parchment
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.13, 0.12, 0.92)
	sb.border_color = Color(0.76, 0.56, 0.30)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)

	var top_left: VBoxContainer = VBoxContainer.new()
	top_left.position = Vector2(18, 14)
	top_left.add_theme_constant_override("separation", 8)
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_left)

	# Row 1: Separate boxes for Time, Gold, and Hearts
	var stats_row: HBoxContainer = HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 10)
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_left.add_child(stats_row)

	var clock_box: PanelContainer = _make_hud_pill(sb, 130)
	_clock_label = _make_label("05:00", 24, Color(1.0, 0.96, 0.85))
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_box.get_child(0).add_child(_clock_label)
	stats_row.add_child(clock_box)

	var gold_box: PanelContainer = _make_hud_pill(sb, 138)
	_gold_label = _make_label("ORO 0", 24, Color(1.0, 0.84, 0.28))
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_box.get_child(0).add_child(_gold_label)
	stats_row.add_child(gold_box)

	var hearts_box: PanelContainer = _make_hud_pill(sb, 122)
	_hearts_label = _make_label("♥ ♥ ♥", 24, Color(1.0, 0.32, 0.42))
	_hearts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hearts_box.get_child(0).add_child(_hearts_label)
	stats_row.add_child(hearts_box)

	# Row 2: XP Progress Bar directly below the 3 stat boxes
	var xp_panel: PanelContainer = PanelContainer.new()
	xp_panel.custom_minimum_size = Vector2(410, 26)
	xp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var xp_sb: StyleBoxFlat = StyleBoxFlat.new()
	xp_sb.bg_color = Color(0.11, 0.08, 0.14, 0.92)
	xp_sb.border_color = Color(0.76, 0.56, 0.30)
	xp_sb.set_border_width_all(2)
	xp_sb.set_corner_radius_all(8)
	xp_panel.add_theme_stylebox_override("panel", xp_sb)
	top_left.add_child(xp_panel)

	var xp_wrap: Control = Control.new()
	xp_wrap.custom_minimum_size = Vector2(406, 22)
	xp_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_panel.add_child(xp_wrap)

	_xp_bar_fill = ColorRect.new()
	_xp_bar_fill.color = Color(0.28, 0.72, 0.98, 0.90)
	_xp_bar_fill.anchor_left = 0.0
	_xp_bar_fill.anchor_top = 0.0
	_xp_bar_fill.anchor_bottom = 1.0
	_xp_bar_fill.anchor_right = 0.0
	_xp_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_wrap.add_child(_xp_bar_fill)

	_xp_label = _make_label("NV. 1 — XP 0/80", 14, Color(0.98, 0.98, 1.0))
	_xp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_xp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_wrap.add_child(_xp_label)

	# Row 3: Zoomed Square Portrait on the left + Trixie Speech Parchment emerging to its right
	var bust_row: HBoxContainer = HBoxContainer.new()
	bust_row.add_theme_constant_override("separation", 12)
	bust_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_left.add_child(bust_row)

	var bust_col: VBoxContainer = VBoxContainer.new()
	bust_col.add_theme_constant_override("separation", 6)
	bust_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bust_row.add_child(bust_col)

	_bust_canvas = Control.new()
	_bust_canvas.custom_minimum_size = Vector2(150, 150)
	_bust_canvas.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_bust_canvas.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_bust_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bust_canvas.draw.connect(_draw_witch_bust)
	bust_col.add_child(_bust_canvas)

	_combo_label = _make_label("¡COMBO x2!", 20, Color(1.0, 0.68, 0.22))
	_combo_label.visible = false
	bust_col.add_child(_combo_label)

	# Trixie Dialogue / Tutorial Parchment emerging right next to the top-left portrait
	_trixie_dlg_root = Control.new()
	_trixie_dlg_root.custom_minimum_size = Vector2(465, 146)
	_trixie_dlg_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trixie_dlg_root.visible = false
	bust_row.add_child(_trixie_dlg_root)

	var t_parchment: Control = Control.new()
	t_parchment.position = Vector2(12, 4)
	t_parchment.size = Vector2(452, 138)
	t_parchment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t_parchment.draw.connect(func() -> void: _draw_top_speech_parchment(t_parchment))
	_trixie_dlg_root.add_child(t_parchment)

	var t_name_lbl: Label = _make_label("Trixie", 18, Color(0.68, 0.14, 0.34))
	t_name_lbl.position = Vector2(24, 12)
	t_parchment.add_child(t_name_lbl)

	_trixie_dlg_label = _make_label("", 18, Color(0.18, 0.11, 0.07))
	_trixie_dlg_label.position = Vector2(24, 40)
	_trixie_dlg_label.size = Vector2(404, 86)
	_trixie_dlg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t_parchment.add_child(_trixie_dlg_label)

	# Bottom-Left compact Debug & Menu bar (out of the way of top-left HUD & kitchen)
	var debug_bar: HBoxContainer = HBoxContainer.new()
	debug_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	debug_bar.offset_left = 16
	debug_bar.offset_top = -46
	debug_bar.offset_right = 540
	debug_bar.offset_bottom = -12
	debug_bar.add_theme_constant_override("separation", 8)
	add_child(debug_bar)

	var draft_test_btn: Button = Button.new()
	draft_test_btn.text = "+1 Nivel XP (Test)"
	draft_test_btn.pressed.connect(func() -> void: force_draft_requested.emit())
	debug_bar.add_child(draft_test_btn)

	var end_day_test_btn: Button = Button.new()
	end_day_test_btn.text = "Fin de Día / Builds (Test)"
	end_day_test_btn.pressed.connect(func() -> void: force_end_day_requested.emit())
	debug_bar.add_child(end_day_test_btn)

	var menu_btn: Button = Button.new()
	menu_btn.text = "Menú Principal"
	menu_btn.pressed.connect(func() -> void: return_to_menu_requested.emit())
	debug_bar.add_child(menu_btn)

	# Top-Right Day, Queue Warning & XP Skills
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
	_slots_label = _make_label("Slots: Familiar 0/1 | Pasivas 0/3 | Activas 0/3", 15, Color(1.0, 0.88, 0.55))
	tr_vbox.add_child(_slots_label)
	_relics_label = _make_label("Habilidades XP: Ninguna aún", 15, Color(0.82, 0.85, 0.95))
	_relics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tr_vbox.add_child(_relics_label)

	# Bottom-Center Active Skill Buttons [1][2][3] (centered cleanly between Left & Right dialogue panels)
	var active_bar: HBoxContainer = HBoxContainer.new()
	active_bar.position = Vector2(580, 1002)
	active_bar.size = Vector2(760, 62)
	active_bar.add_theme_constant_override("separation", 14)
	add_child(active_bar)
	_active_buttons.clear()
	for slot_idx: int in range(3):
		var slot_btn: Button = Button.new()
		slot_btn.custom_minimum_size = Vector2(240, 58)
		slot_btn.text = "[%d] Activa Vacía" % (slot_idx + 1)
		slot_btn.disabled = true
		slot_btn.modulate = Color(0.55, 0.55, 0.65)
		slot_btn.pressed.connect(func() -> void: active_skill_slot_pressed.emit(slot_idx))
		active_bar.add_child(slot_btn)
		_active_buttons.append(slot_btn)

	# Bottom-Right: Large Customer Portrait (concept-art scale) + Chipped Old Parchment Dialogue
	var br_root: Control = Control.new()
	br_root.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br_root.offset_left = -530
	br_root.offset_right = -16
	br_root.offset_top = -512
	br_root.offset_bottom = -14
	br_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(br_root)

	_customer_canvas = Control.new()
	_customer_canvas.position = Vector2(88, 0)
	_customer_canvas.size = Vector2(420, 370)
	_customer_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_customer_canvas.draw.connect(_draw_customer_portrait)
	br_root.add_child(_customer_canvas)

	var parchment: Control = Control.new()
	parchment.position = Vector2(0, 354)
	parchment.size = Vector2(510, 142)
	parchment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parchment.draw.connect(func() -> void: _draw_chipped_parchment(parchment))
	br_root.add_child(parchment)

	_customer_name_label = _make_label("Sylvi  ♡♡♡", 19, Color(0.42, 0.14, 0.12))
	_customer_name_label.position = Vector2(24, 14)
	parchment.add_child(_customer_name_label)

	_parchment_label = _make_label(_customer_line, 20, Color(0.18, 0.11, 0.07))
	_parchment_label.position = Vector2(24, 46)
	_parchment_label.size = Vector2(462, 84)
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

	# XP Level-Up Draft Overlay
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

	_draft_hdr_label = _make_label("¡SUBISTE DE NIVEL! ELIGE O MEJORA UNA HABILIDAD", 32, Color(1.0, 0.88, 0.42))
	_draft_hdr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draft_vbox.add_child(_draft_hdr_label)

	_draft_slots_label = _make_label("Slots actuales: Familiar 0/1  |  Pasivas 0/3  |  Activas 0/3", 20, Color(0.75, 0.92, 1.0))
	_draft_slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draft_vbox.add_child(_draft_slots_label)

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

	# Between-Days Witch Selection & Gold Build Screen
	_build_screen_overlay = ColorRect.new()
	_build_screen_overlay.color = Color(0.05, 0.03, 0.09, 0.94)
	_build_screen_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_screen_overlay.visible = false
	add_child(_build_screen_overlay)

	var build_center: CenterContainer = CenterContainer.new()
	build_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_screen_overlay.add_child(build_center)

	var build_frame: PanelContainer = PanelContainer.new()
	build_frame.custom_minimum_size = Vector2(1480, 820)
	var frame_sb: StyleBoxFlat = StyleBoxFlat.new()
	frame_sb.bg_color = Color(0.10, 0.07, 0.15, 0.98)
	frame_sb.border_color = Color(0.82, 0.62, 0.30)
	frame_sb.set_border_width_all(3)
	frame_sb.set_corner_radius_all(14)
	build_frame.add_theme_stylebox_override("panel", frame_sb)
	build_center.add_child(build_frame)

	var frame_pad: MarginContainer = MarginContainer.new()
	frame_pad.add_theme_constant_override("margin_left", 24)
	frame_pad.add_theme_constant_override("margin_right", 24)
	frame_pad.add_theme_constant_override("margin_top", 20)
	frame_pad.add_theme_constant_override("margin_bottom", 20)
	build_frame.add_child(frame_pad)

	var build_root_vbox: VBoxContainer = VBoxContainer.new()
	build_root_vbox.add_theme_constant_override("separation", 16)
	frame_pad.add_child(build_root_vbox)

	var hdr_row: HBoxContainer = HBoxContainer.new()
	_build_header_title = _make_label("FIN DEL DÍA 1 — PREPARACIÓN Y BUILDS", 28, Color(1.0, 0.88, 0.45))
	_build_header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_header_stats = _make_label("ORO DISPONIBLE: 0g   |   ♥ 3/3", 24, Color(1.0, 0.94, 0.82))
	hdr_row.add_child(_build_header_title)
	hdr_row.add_child(_build_header_stats)
	build_root_vbox.add_child(hdr_row)

	var split_row: HBoxContainer = HBoxContainer.new()
	split_row.add_theme_constant_override("separation", 24)
	split_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build_root_vbox.add_child(split_row)

	# Left Panel: Full-Body Witch & Story Roster
	var left_panel: PanelContainer = PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(430, 0)
	var left_sb: StyleBoxFlat = StyleBoxFlat.new()
	left_sb.bg_color = Color(0.14, 0.09, 0.20, 0.95)
	left_sb.border_color = Color(0.62, 0.44, 0.72)
	left_sb.set_border_width_all(2)
	left_sb.set_corner_radius_all(12)
	left_panel.add_theme_stylebox_override("panel", left_sb)
	split_row.add_child(left_panel)

	var left_pad: MarginContainer = MarginContainer.new()
	left_pad.add_theme_constant_override("margin_left", 16)
	left_pad.add_theme_constant_override("margin_right", 16)
	left_pad.add_theme_constant_override("margin_top", 14)
	left_pad.add_theme_constant_override("margin_bottom", 14)
	left_panel.add_child(left_pad)

	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 10)
	left_pad.add_child(left_vbox)

	var left_title: Label = _make_label("BRUJITA DEL TURNO", 20, Color(0.95, 0.80, 1.0))
	left_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(left_title)

	var canvas_center: CenterContainer = CenterContainer.new()
	_fullbody_canvas = Control.new()
	_fullbody_canvas.custom_minimum_size = Vector2(320, 390)
	_fullbody_canvas.draw.connect(_draw_fullbody_witch)
	canvas_center.add_child(_fullbody_canvas)
	left_vbox.add_child(canvas_center)

	_build_witch_name_lbl = _make_label("Trixie — Bruja de Fuego y Caos", 18, Color(1.0, 0.88, 0.45))
	_build_witch_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(_build_witch_name_lbl)

	_build_witch_skills_lbl = Label.new()
	_build_witch_skills_lbl.add_theme_font_size_override("font_size", 13)
	_build_witch_skills_lbl.modulate = Color(0.88, 0.88, 0.96)
	_build_witch_skills_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_vbox.add_child(_build_witch_skills_lbl)

	_build_witch_buttons_grid = GridContainer.new()
	_build_witch_buttons_grid.columns = 2
	_build_witch_buttons_grid.add_theme_constant_override("h_separation", 8)
	_build_witch_buttons_grid.add_theme_constant_override("v_separation", 8)
	left_vbox.add_child(_build_witch_buttons_grid)

	var roster_note: Label = Label.new()
	roster_note.text = "Las demás brujitas llegan según avanza la historia (no se compran con oro)."
	roster_note.add_theme_font_size_override("font_size", 12)
	roster_note.modulate = Color(0.75, 0.72, 0.84)
	roster_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roster_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(roster_note)

	# Right Panel: Gold Build Upgrades + Saved XP Skills + Next Day CTA
	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 12)
	split_row.add_child(right_vbox)

	var right_title: Label = _make_label("MEJORAS DE BUILD (CON ORO)", 22, Color(1.0, 0.84, 0.35))
	right_vbox.add_child(right_title)

	_build_cards_grid = GridContainer.new()
	_build_cards_grid.columns = 2
	_build_cards_grid.add_theme_constant_override("h_separation", 14)
	_build_cards_grid.add_theme_constant_override("v_separation", 12)
	_build_cards_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(_build_cards_grid)

	var xp_sum_panel: PanelContainer = PanelContainer.new()
	var xp_sum_sb: StyleBoxFlat = StyleBoxFlat.new()
	xp_sum_sb.bg_color = Color(0.12, 0.16, 0.24, 0.92)
	xp_sum_sb.border_color = Color(0.42, 0.72, 0.98)
	xp_sum_sb.set_border_width_all(2)
	xp_sum_sb.set_corner_radius_all(8)
	xp_sum_panel.add_theme_stylebox_override("panel", xp_sum_sb)
	right_vbox.add_child(xp_sum_panel)

	var xp_sum_pad: MarginContainer = MarginContainer.new()
	xp_sum_pad.add_theme_constant_override("margin_left", 12)
	xp_sum_pad.add_theme_constant_override("margin_right", 12)
	xp_sum_pad.add_theme_constant_override("margin_top", 8)
	xp_sum_pad.add_theme_constant_override("margin_bottom", 8)
	xp_sum_panel.add_child(xp_sum_pad)

	_build_xp_summary_lbl = Label.new()
	_build_xp_summary_lbl.text = "Habilidades de XP activas (se conservan): Ninguna"
	_build_xp_summary_lbl.add_theme_font_size_override("font_size", 15)
	_build_xp_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	xp_sum_pad.add_child(_build_xp_summary_lbl)

	_next_day_btn = Button.new()
	_next_day_btn.text = "COMENZAR DÍA 2 (05:00) ➔"
	_next_day_btn.custom_minimum_size = Vector2(0, 52)
	_next_day_btn.pressed.connect(func() -> void:
		_build_screen_overlay.visible = false
		next_day_requested.emit()
	)
	right_vbox.add_child(_next_day_btn)

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
	var end_menu_btn: Button = Button.new()
	end_menu_btn.text = "MENÚ PRINCIPAL"
	end_menu_btn.custom_minimum_size = Vector2(260, 48)
	end_menu_btn.pressed.connect(func() -> void:
		_end_overlay.visible = false
		return_to_menu_requested.emit()
	)
	end_box.add_child(_end_title)
	end_box.add_child(_end_stats)
	end_box.add_child(retry_btn)
	end_box.add_child(end_menu_btn)


func _draw_witch_bust() -> void:
	var side: float = minf(_bust_canvas.size.x, _bust_canvas.size.y)
	var rect: Rect2 = Rect2(Vector2.ZERO, Vector2(side, side))
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
	var real_tex: Texture2D = null
	if _current_witch != null:
		if _trixie_dlg_root != null and _trixie_dlg_root.visible:
			match _trixie_dlg_emotion:
				"confiada":
					real_tex = _current_witch.portrait_confiada
				"nerviosa", "nerviosa_sudando":
					real_tex = _current_witch.portrait_nerviosa
				"sonrojada", "sonrojada_picante":
					real_tex = _current_witch.portrait_sonrojada
				"hollin", "hollin_derrota":
					real_tex = _current_witch.portrait_hollin
				"sorprendida":
					real_tex = _current_witch.portrait_sorprendida
				_:
					real_tex = _current_witch.portrait_normal
		else:
			match _current_emotion:
				EventBus.WitchEmotion.CONFIADA, EventBus.WitchEmotion.CUTIN_HABILIDAD:
					real_tex = _current_witch.portrait_confiada
				EventBus.WitchEmotion.NERVIOSA_SUDANDO:
					real_tex = _current_witch.portrait_nerviosa
				EventBus.WitchEmotion.SONROJADA_PICANTE:
					real_tex = _current_witch.portrait_sonrojada
				EventBus.WitchEmotion.HOLLIN_DERROTA:
					real_tex = _current_witch.portrait_hollin
				_:
					real_tex = _current_witch.portrait_normal
		if real_tex == null:
			real_tex = _current_witch.portrait_normal
	if real_tex != null:
		var pad_in: float = 5.0
		var dst: Rect2 = Rect2(pad_in, pad_in, rect.size.x - pad_in * 2.0, rect.size.y - pad_in * 2.0)
		_bust_canvas.draw_texture_rect(real_tex, dst, false)
		_bust_canvas.draw_rect(rect, Color(0.24, 0.14, 0.10), false, 7.0)
		_bust_canvas.draw_rect(rect.grow(-2.0), border_col, false, 3.0)
		return
	_bust_canvas.draw_rect(rect, border_col, false, 5.0)

	var cx: float = 75.0
	_bust_canvas.draw_circle(Vector2(cx, 132), 42.0, Color(0.45, 0.22, 0.62))
	_bust_canvas.draw_circle(Vector2(cx, 118), 22.0, Color(1.0, 0.86, 0.78))
	_bust_canvas.draw_circle(Vector2(cx, 72), 28.0, Color(1.0, 0.87, 0.79))
	_bust_canvas.draw_colored_polygon(PackedVector2Array([Vector2(cx - 38, 52), Vector2(cx + 38, 52), Vector2(cx, 14)]), Color(0.28, 0.14, 0.42))
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


func _draw_fullbody_witch() -> void:
	var w: float = _fullbody_canvas.size.x
	var h: float = _fullbody_canvas.size.y
	var cx: float = w * 0.5
	var outline: Color = Color(0.08, 0.05, 0.12)

	# Arcane pedestal glow
	_fullbody_canvas.draw_rect(Rect2(0, 0, w, h), Color(0.11, 0.07, 0.17, 0.75))
	_fullbody_canvas.draw_rect(Rect2(0, 0, w, h), Color(0.42, 0.28, 0.55, 0.6), false, 2.0)
	_fullbody_canvas.draw_circle(Vector2(cx, h - 38.0), 86.0, Color(0.75, 0.25, 0.45, 0.22))
	_fullbody_canvas.draw_arc(Vector2(cx, h - 38.0), 80.0, 0.0, TAU, 36, Color(1.0, 0.82, 0.35, 0.45), 2.0)

	if _selected_build_witch != null and _selected_build_witch.fullbody_illustration != null:
		var fb_tex: Texture2D = _selected_build_witch.fullbody_illustration
		var tw: float = float(fb_tex.get_width())
		var th: float = float(fb_tex.get_height())
		var sc: float = minf(1.0, minf((w - 20.0) / maxf(1.0, tw), (h - 24.0) / maxf(1.0, th)))
		var dw: float = roundf(tw * sc)
		var dh: float = roundf(th * sc)
		var dst: Rect2 = Rect2(roundf((w - dw) * 0.5), roundf(h - 14.0 - dh), dw, dh)
		_fullbody_canvas.draw_texture_rect(fb_tex, dst, false)
		return

	var dress_col: Color = Color(0.66, 0.18, 0.38)
	var hair_col: Color = Color(0.24, 0.13, 0.18)
	var skin_col: Color = Color(1.0, 0.87, 0.79)
	if _selected_build_witch != null:
		match _selected_build_witch.witch_id:
			&"lyra":
				dress_col = Color(0.22, 0.62, 0.36)
				hair_col = Color(0.92, 0.68, 0.34)
			&"nyxara":
				dress_col = Color(0.20, 0.30, 0.58)
				hair_col = Color(0.84, 0.84, 0.94)
			&"morrigan":
				dress_col = Color(0.70, 0.14, 0.26)
				hair_col = Color(0.12, 0.10, 0.16)

	# Flowing hair behind shoulders
	_fullbody_canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 46, 108), Vector2(cx + 46, 108), Vector2(cx + 58, 224), Vector2(cx - 58, 224)
	]), hair_col)

	# Legs & thigh-high stockings
	_fullbody_canvas.draw_rect(Rect2(cx - 26, 260, 18, 52), skin_col)
	_fullbody_canvas.draw_rect(Rect2(cx + 8, 260, 18, 52), skin_col)
	_fullbody_canvas.draw_rect(Rect2(cx - 26, 286, 18, 50), Color(0.16, 0.11, 0.20))
	_fullbody_canvas.draw_rect(Rect2(cx + 8, 286, 18, 50), Color(0.16, 0.11, 0.20))

	# Arcane heeled boots
	var left_boot: PackedVector2Array = PackedVector2Array([
		Vector2(cx - 28, 326), Vector2(cx - 6, 326), Vector2(cx - 4, 362), Vector2(cx - 34, 362)
	])
	var right_boot: PackedVector2Array = PackedVector2Array([
		Vector2(cx + 6, 326), Vector2(cx + 28, 326), Vector2(cx + 34, 362), Vector2(cx + 4, 362)
	])
	_fullbody_canvas.draw_colored_polygon(left_boot, Color(0.24, 0.12, 0.30))
	_fullbody_canvas.draw_polyline(left_boot + PackedVector2Array([left_boot[0]]), outline, 2.5)
	_fullbody_canvas.draw_colored_polygon(right_boot, Color(0.24, 0.12, 0.30))
	_fullbody_canvas.draw_polyline(right_boot + PackedVector2Array([right_boot[0]]), outline, 2.5)

	# Flared witch skirt + curvy corset bodice
	var skirt: PackedVector2Array = PackedVector2Array([
		Vector2(cx - 26, 200), Vector2(cx + 26, 200), Vector2(cx + 62, 272), Vector2(cx - 62, 272)
	])
	_fullbody_canvas.draw_colored_polygon(skirt, dress_col)
	_fullbody_canvas.draw_polyline(skirt + PackedVector2Array([skirt[0]]), outline, 3.0)

	var bodice: PackedVector2Array = PackedVector2Array([
		Vector2(cx - 26, 144), Vector2(cx + 26, 144), Vector2(cx + 18, 202), Vector2(cx - 18, 202)
	])
	_fullbody_canvas.draw_colored_polygon(bodice, dress_col.darkened(0.15))
	_fullbody_canvas.draw_polyline(bodice + PackedVector2Array([bodice[0]]), outline, 2.8)
	_fullbody_canvas.draw_line(Vector2(cx - 18, 200), Vector2(cx + 18, 200), Color(1.0, 0.82, 0.32), 4.0)

	# Arms & floating fire spark
	_fullbody_canvas.draw_line(Vector2(cx - 24, 152), Vector2(cx - 56, 200), skin_col, 10.0)
	_fullbody_canvas.draw_line(Vector2(cx + 24, 152), Vector2(cx + 64, 174), skin_col, 10.0)
	_fullbody_canvas.draw_circle(Vector2(cx + 76, 154), 16.0, Color(1.0, 0.45, 0.25, 0.45))
	_fullbody_canvas.draw_circle(Vector2(cx + 76, 154), 9.0, Color(1.0, 0.85, 0.35))

	# Neck, head, expressive anime face
	_fullbody_canvas.draw_rect(Rect2(cx - 7, 130, 14, 18), skin_col)
	_fullbody_canvas.draw_circle(Vector2(cx, 104), 34.0, skin_col)
	_fullbody_canvas.draw_circle(Vector2(cx, 104), 34.0, outline, false, 3.0)
	_fullbody_canvas.draw_circle(Vector2(cx - 12, 102), 4.2, outline)
	_fullbody_canvas.draw_circle(Vector2(cx + 12, 102), 4.2, outline)
	_fullbody_canvas.draw_circle(Vector2(cx - 18, 112), 6.5, Color(1.0, 0.48, 0.56, 0.55))
	_fullbody_canvas.draw_circle(Vector2(cx + 18, 112), 6.5, Color(1.0, 0.48, 0.56, 0.55))
	_fullbody_canvas.draw_arc(Vector2(cx, 114), 8.0, 0.15, PI - 0.15, 10, Color(0.62, 0.16, 0.24), 2.5)

	# Pointed witch hat
	var brim: PackedVector2Array = PackedVector2Array([
		Vector2(cx - 58, 82), Vector2(cx + 58, 82), Vector2(cx, 66)
	])
	var cone: PackedVector2Array = PackedVector2Array([
		Vector2(cx - 30, 76), Vector2(cx + 30, 76), Vector2(cx - 10, 16)
	])
	_fullbody_canvas.draw_colored_polygon(brim, dress_col.darkened(0.32))
	_fullbody_canvas.draw_polyline(brim + PackedVector2Array([brim[0]]), outline, 2.8)
	_fullbody_canvas.draw_colored_polygon(cone, dress_col.darkened(0.28))
	_fullbody_canvas.draw_polyline(cone + PackedVector2Array([cone[0]]), outline, 2.8)
	_fullbody_canvas.draw_line(Vector2(cx - 28, 74), Vector2(cx + 28, 74), Color(1.0, 0.80, 0.30), 5.0)


func _draw_customer_portrait() -> void:
	if _customer_portrait_tex != null:
		_customer_canvas.draw_texture_rect(_customer_portrait_tex, Rect2(Vector2.ZERO, _customer_canvas.size), false)
		return
	var cx: float = 140.0
	var col: Color = CustomerEntity._character_color(_active_customer_id)
	_customer_canvas.draw_colored_polygon(
		PackedVector2Array([Vector2(cx - 72, 250), Vector2(cx + 72, 250), Vector2(cx + 46, 150), Vector2(cx - 46, 150)]),
		col
	)
	_customer_canvas.draw_circle(Vector2(cx, 158), 34.0, Color(1.0, 0.86, 0.78))
	_customer_canvas.draw_circle(Vector2(cx, 96), 44.0, Color(1.0, 0.87, 0.79))
	_customer_canvas.draw_circle(Vector2(cx, 96), 44.0, Color(0.10, 0.07, 0.13), false, 3.5)
	if _active_customer_id == &"sylvi":
		_customer_canvas.draw_arc(Vector2(cx - 38, 68), 22.0, 0.3, PI * 1.35, 14, Color(0.75, 0.56, 0.40), 9.0)
		_customer_canvas.draw_arc(Vector2(cx + 38, 68), 22.0, -PI * 0.35, PI * 0.7, 14, Color(0.75, 0.56, 0.40), 9.0)
	elif _active_customer_id == &"velvet":
		_customer_canvas.draw_colored_polygon(PackedVector2Array([Vector2(cx - 20, 56), Vector2(cx - 40, 22), Vector2(cx - 6, 54)]), Color(0.20, 0.08, 0.15))
		_customer_canvas.draw_colored_polygon(PackedVector2Array([Vector2(cx + 20, 56), Vector2(cx + 40, 22), Vector2(cx + 6, 54)]), Color(0.20, 0.08, 0.15))
	_customer_canvas.draw_circle(Vector2(cx - 15, 92), 4.5, Color(0.12, 0.08, 0.15))
	_customer_canvas.draw_circle(Vector2(cx + 15, 92), 4.5, Color(0.12, 0.08, 0.15))
	if _customer_spicy:
		_customer_canvas.draw_circle(Vector2(cx - 22, 105), 11.0, Color(1.0, 0.42, 0.54, 0.65))
		_customer_canvas.draw_circle(Vector2(cx + 22, 105), 11.0, Color(1.0, 0.42, 0.54, 0.65))
	_customer_canvas.draw_arc(Vector2(cx, 108), 10.0, 0.1, PI - 0.1, 10, Color(0.72, 0.20, 0.28), 3.0)


static func _make_hud_pill(style: StyleBoxFlat, min_w: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_w, 46)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style)
	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_bottom", 6)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pad)
	return panel


func _draw_top_speech_parchment(ctrl: Control) -> void:
	_draw_chipped_parchment(ctrl)
	# Small parchment pointer pointing left toward Trixie's square HUD portrait
	var tail: PackedVector2Array = PackedVector2Array([
		Vector2(6.0, 38.0),
		Vector2(-12.0, 50.0),
		Vector2(6.0, 62.0),
	])
	ctrl.draw_colored_polygon(tail, Color(0.93, 0.85, 0.69, 0.96))
	ctrl.draw_polyline(PackedVector2Array([Vector2(6.0, 38.0), Vector2(-12.0, 50.0), Vector2(6.0, 62.0)]), Color(0.32, 0.18, 0.10), 3.0)


func _draw_chipped_parchment(ctrl: Control) -> void:
	var w: float = ctrl.size.x
	var h: float = ctrl.size.y
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
