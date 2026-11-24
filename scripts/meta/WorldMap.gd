class_name WorldMap
extends Control
## Traveling Witch World Map hub: node selection, Skill Tree, Gallery, and mandatory
## post-Stop-1 Skill Tree tutorial (forcing the Hold-Left-Click upgrade "Toque Continuo").

enum MapView {
	MAP,
	UPGRADE_TREE,
	GALLERY,
}

const VIEWPORT_SIZE: Vector2 = Vector2(1920.0, 1080.0)
const MAP_NODE_RADIUS: float = 48.0

const GALLERY_TITLES: Dictionary = {
	&"trixie": ["Chispas de Apertura", "Sobrecalentamiento Picante", "Maestra del Aquelarre"],
	&"sylvi": ["Brindis del Bosque", "Calor bajo las Hojas", "Fiesta Privada con Trixie"],
	&"velvet": ["Mirada Ejecutiva", "Prueba Directa del Cucharón", "Contrato Carmesí"],
	&"seraphina": ["Inspección de Pureza", "Armadura Entreabierta", "Confesión Secreta de la Orden"],
	&"mona": ["Orgullo Élfico", "Sonrojo Tsundere", "Cita Privada en la Mansión"],
	&"roxy": ["Aullido de Luna Llena", "Cazadora Cautivada", "Frasco Reservado"],
}

const GameStateScript: GDScript = preload("res://scripts/autoloads/GameState.gd")

var _local_state: Node = null
var view_mode: MapView = MapView.MAP
var _time: float = 0.0
var _transitioning: bool = false
var _sparkles: Array[Dictionary] = []

# Map view state
var _selected_node_id: StringName = &"castillo"
var _hovered_node_id: StringName = &""
var _last_clicked_node_id: StringName = &""
var _last_click_time: float = -10.0

# Tree view state
var _tree_hovered_id: StringName = &""
var _tree_selected_id: StringName = &"toque_continuo"

# Gallery view state
var _gallery_selected_char_id: StringName = &"sylvi"
var _gallery_char_buttons: Dictionary = {}
var _lightbox_scene_idx: int = 0

# UI references
var _top_essence_lbl: Label
var _top_progress_lbl: Label
var _tree_btn: Button
var _gallery_btn: Button
var _pause_btn: Button
var _tree_badge_panel: PanelContainer

var _map_view_root: Control
var _map_canvas: Control
var _map_tut_banner: PanelContainer
var _map_tut_title_lbl: Label
var _map_tut_body_lbl: Label
var _node_title_lbl: Label
var _node_meta_lbl: Label
var _node_desc_lbl: Label
var _travel_btn: Button

var _tree_view_root: Control
var _tree_canvas: Control
var _tree_tut_banner: PanelContainer
var _tree_tut_title_lbl: Label
var _tree_tut_body_lbl: Label
var _tree_info_title: Label
var _tree_info_desc: Label
var _tree_info_stats: Label
var _tree_buy_btn: Button
var _tree_back_btn: Button

var _gallery_view_root: Control
var _gallery_portrait_canvas: Control
var _gallery_title_lbl: Label
var _gallery_aff_lbl: Label
var _gallery_lines_lbl: Label
var _gallery_gift_btn: Button
var _gallery_cards_box: HBoxContainer
var _gallery_back_btn: Button

var _lightbox_overlay: ColorRect
var _lightbox_title_lbl: Label
var _lightbox_canvas: Control
var _lightbox_caption_lbl: Label
var _victory_overlay: ColorRect
var _pause_overlay: ColorRect


func _state() -> Node:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		gs.call("ensure_loaded")
		return gs
	if _local_state == null:
		_local_state = GameStateScript.new() as Node
		_local_state.call("ensure_loaded")
	return _local_state


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var st: Node = _state()

	for i: int in range(24):
		_sparkles.append({
			"x": randf_range(0.0, VIEWPORT_SIZE.x),
			"y": randf_range(80.0, VIEWPORT_SIZE.y),
			"r": randf_range(1.5, 3.6),
			"spd": randf_range(10.0, 26.0),
			"phase": randf_range(0.0, TAU),
		})

	# Ensure player always has enough Essence to buy Toque Continuo during the mandatory tutorial (no soft-lock)
	if st.should_run_map_tutorial():
		var hold_cost: int = st.get_node_cost(&"toque_continuo")
		if st.essence_gold < hold_cost:
			st.grant_essence(hold_cost - st.essence_gold)
		if st.map_tutorial_stage >= 2:
			st.map_tutorial_stage = 0

	_selected_node_id = st.get_recommended_next_map_node_id()
	if _selected_node_id == &"" or not st.is_map_node_unlocked(_selected_node_id):
		_selected_node_id = &"castillo"

	_build_ui()
	_switch_view(MapView.MAP)

	var fader: Node = _fader()
	if fader != null and bool(fader.call("is_black")):
		fader.call("fade_in", 0.45)


func _process(delta: float) -> void:
	_time += delta
	for s: Dictionary in _sparkles:
		s["y"] = float(s["y"]) - float(s["spd"]) * delta
		if float(s["y"]) < 76.0:
			s["y"] = VIEWPORT_SIZE.y + 10.0
			s["x"] = randf_range(0.0, VIEWPORT_SIZE.x)

	_refresh_top_and_tutorials()
	if view_mode == MapView.MAP and _map_canvas != null:
		_map_canvas.queue_redraw()
	elif view_mode == MapView.UPGRADE_TREE and _tree_canvas != null:
		_tree_canvas.queue_redraw()
	elif view_mode == MapView.GALLERY and _gallery_portrait_canvas != null:
		_gallery_portrait_canvas.queue_redraw()
		if _lightbox_overlay != null and _lightbox_overlay.visible and _lightbox_canvas != null:
			_lightbox_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.pressed and not kev.echo:
			if kev.keycode == KEY_F11:
				var gs: Node = _settings()
				if gs != null:
					gs.set("fullscreen", not bool(gs.get("fullscreen")))
					gs.call("apply_video")
					gs.call("save_settings")
				get_viewport().set_input_as_handled()
				return
			if kev.keycode == KEY_ESCAPE:
				if _lightbox_overlay != null and _lightbox_overlay.visible:
					_lightbox_overlay.visible = false
				elif _victory_overlay != null and _victory_overlay.visible:
					_victory_overlay.visible = false
				elif _pause_overlay != null:
					_pause_overlay.visible = not _pause_overlay.visible
				get_viewport().set_input_as_handled()


func _is_map_tutorial_blocking() -> bool:
	return _state().should_run_map_tutorial()


func _switch_view(mode: MapView) -> void:
	var st: Node = _state()
	if _is_map_tutorial_blocking():
		if mode == MapView.GALLERY:
			return
		if mode == MapView.MAP and st.map_tutorial_stage == 1 and st.get_node_level(&"toque_continuo") == 0:
			return
		if mode == MapView.UPGRADE_TREE and st.map_tutorial_stage == 0:
			st.map_tutorial_stage = 1
			_tree_selected_id = &"toque_continuo"

	view_mode = mode
	if _map_view_root != null:
		_map_view_root.visible = (mode == MapView.MAP)
	if _tree_view_root != null:
		_tree_view_root.visible = (mode == MapView.UPGRADE_TREE)
	if _gallery_view_root != null:
		_gallery_view_root.visible = (mode == MapView.GALLERY)

	if mode == MapView.MAP:
		_refresh_map_detail_panel()
	elif mode == MapView.UPGRADE_TREE:
		_refresh_tree_detail_panel()
		if _tree_canvas != null:
			_tree_canvas.queue_redraw()
	elif mode == MapView.GALLERY:
		_refresh_gallery_panel()

	_refresh_top_and_tutorials()


# ==============================================================================
# UI BUILD
# ==============================================================================

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.04, 0.12, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Top Bar (single canonical location for Skill Tree & Gallery buttons)
	var top_bar: PanelContainer = PanelContainer.new()
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(1920, 76)
	var tb_sb: StyleBoxFlat = StyleBoxFlat.new()
	tb_sb.bg_color = Color(0.08, 0.05, 0.14, 0.96)
	tb_sb.border_color = Color(0.80, 0.62, 0.30)
	tb_sb.border_width_bottom = 3
	top_bar.add_theme_stylebox_override("panel", tb_sb)
	add_child(top_bar)

	var tb_pad: MarginContainer = MarginContainer.new()
	tb_pad.add_theme_constant_override("margin_left", 24)
	tb_pad.add_theme_constant_override("margin_right", 24)
	tb_pad.add_theme_constant_override("margin_top", 10)
	tb_pad.add_theme_constant_override("margin_bottom", 10)
	top_bar.add_child(tb_pad)

	var tb_hbox: HBoxContainer = HBoxContainer.new()
	tb_hbox.add_theme_constant_override("separation", 18)
	tb_pad.add_child(tb_hbox)

	_top_essence_lbl = _make_label("✦ 0", 26, Color(1.0, 0.88, 0.36))
	_top_essence_lbl.custom_minimum_size = Vector2(210, 0)
	_top_progress_lbl = _make_label("🗺 Mapa de Viaje · Paradas: 0 / 6", 20, Color(0.92, 0.88, 0.98))
	_top_progress_lbl.custom_minimum_size = Vector2(520, 0)
	tb_hbox.add_child(_top_essence_lbl)
	tb_hbox.add_child(_top_progress_lbl)

	var sp: Control = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_hbox.add_child(sp)

	_tree_btn = _make_pill_button("🌿 ÁRBOL DE HABILIDADES", Color(0.18, 0.32, 0.50), Color(0.45, 0.88, 1.0))
	_tree_btn.pressed.connect(func() -> void:
		_play_pentatonic(3, -3.0)
		_switch_view(MapView.UPGRADE_TREE)
	)
	_gallery_btn = _make_pill_button("💋 GALERÍA", Color(0.38, 0.16, 0.44), Color(1.0, 0.62, 0.84))
	_gallery_btn.pressed.connect(func() -> void:
		_play_pentatonic(4, -3.0)
		_switch_view(MapView.GALLERY)
	)
	_pause_btn = _make_pill_button("⏸ MENÚ [ESC]", Color(0.24, 0.16, 0.34), Color(0.84, 0.66, 0.38))
	_pause_btn.pressed.connect(func() -> void:
		if _pause_overlay != null:
			_pause_overlay.visible = true
	)
	tb_hbox.add_child(_tree_btn)
	tb_hbox.add_child(_gallery_btn)
	tb_hbox.add_child(_pause_btn)

	_build_map_view_ui()
	_build_upgrade_tree_ui()
	_build_gallery_ui()
	_build_modals()

	# Floating affordable badge on _tree_btn (added last so it renders on top)
	_tree_badge_panel = PanelContainer.new()
	_tree_badge_panel.size = Vector2(28, 28)
	_tree_badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b_sb: StyleBoxFlat = StyleBoxFlat.new()
	b_sb.bg_color = Color(1.0, 0.84, 0.20)
	b_sb.set_corner_radius_all(14)
	_tree_badge_panel.add_theme_stylebox_override("panel", b_sb)
	var b_lbl: Label = _make_label("!", 18, Color(0.12, 0.04, 0.10))
	b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tree_badge_panel.add_child(b_lbl)
	_tree_badge_panel.visible = false
	add_child(_tree_badge_panel)


func _build_map_view_ui() -> void:
	_map_view_root = Control.new()
	_map_view_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_view_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_map_view_root)
	# Keep Top Bar on top of view roots
	move_child(_map_view_root, 1)

	_map_canvas = Control.new()
	_map_canvas.position = Vector2.ZERO
	_map_canvas.size = VIEWPORT_SIZE
	_map_canvas.draw.connect(_draw_world_map)
	_map_canvas.gui_input.connect(_on_map_gui_input)
	_map_view_root.add_child(_map_canvas)

	# Tutorial explanation banner (cleanly at top-center above map nodes)
	_map_tut_banner = _make_card_panel(Vector2(380, 92), Vector2(1060, 118), Color(0.14, 0.08, 0.24, 0.96), Color(1.0, 0.86, 0.34))
	_map_tut_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_tut_banner.visible = false
	_map_view_root.add_child(_map_tut_banner)

	var mt_box: VBoxContainer = VBoxContainer.new()
	mt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mt_box.add_theme_constant_override("separation", 6)
	_map_tut_banner.get_child(0).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_tut_banner.get_child(0).add_child(mt_box)

	_map_tut_title_lbl = _make_label("✨ Trixie · El Mapa y tus Mejoras", 21, Color(1.0, 0.88, 0.38))
	_map_tut_body_lbl = _make_label("", 17, Color(0.98, 0.95, 1.0))
	_map_tut_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mt_box.add_child(_map_tut_title_lbl)
	mt_box.add_child(_map_tut_body_lbl)

	# Bottom Selected Stop Card
	var bottom_bar: PanelContainer = _make_card_panel(Vector2(44, 836), Vector2(1832, 214), Color(0.11, 0.07, 0.19, 0.96), Color(0.84, 0.66, 0.34))
	_map_view_root.add_child(bottom_bar)
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	bottom_bar.get_child(0).add_child(hbox)

	var info_col: VBoxContainer = VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 6)
	hbox.add_child(info_col)

	_node_title_lbl = _make_label("🏰 Afueras del Castillo", 28, Color(1.0, 0.88, 0.42))
	_node_meta_lbl = _make_label("", 18, Color(0.65, 0.92, 1.0))
	_node_desc_lbl = _make_label("", 18, Color(0.95, 0.92, 0.98))
	_node_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_col.add_child(_node_title_lbl)
	info_col.add_child(_node_meta_lbl)
	info_col.add_child(_node_desc_lbl)

	_travel_btn = _make_pill_button("🔥 VIAJAR A ESTA PARADA", Color(0.58, 0.18, 0.36), Color(1.0, 0.84, 0.38))
	_travel_btn.custom_minimum_size = Vector2(360, 108)
	_travel_btn.add_theme_font_size_override("font_size", 22)
	_travel_btn.pressed.connect(_travel_to_selected_node)
	hbox.add_child(_travel_btn)


func _build_upgrade_tree_ui() -> void:
	_tree_view_root = Control.new()
	_tree_view_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tree_view_root.visible = false
	add_child(_tree_view_root)
	move_child(_tree_view_root, 2)

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.04, 0.11, 0.98)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tree_view_root.add_child(bg)

	_tree_canvas = Control.new()
	_tree_canvas.position = Vector2.ZERO
	_tree_canvas.size = VIEWPORT_SIZE
	_tree_canvas.draw.connect(_draw_upgrade_tree)
	_tree_canvas.gui_input.connect(_on_tree_gui_input)
	_tree_view_root.add_child(_tree_canvas)

	var lbl_l: Label = _make_label("✨ RAMA ALQUIMIA Y CADENAS", 18, Color(1.0, 0.46, 0.56))
	lbl_l.position = Vector2(54, 102)
	_tree_view_root.add_child(lbl_l)
	var lbl_n: Label = _make_label("⚡ RAMA CALDERO Y REACCIONES", 18, Color(0.38, 0.92, 1.0))
	lbl_n.position = Vector2(815, 92)
	_tree_view_root.add_child(lbl_n)
	var lbl_r: Label = _make_label("🐱 RAMA FAMILIARES Y TIEMPO", 18, Color(0.82, 0.54, 1.0))
	lbl_r.position = Vector2(1500, 102)
	_tree_view_root.add_child(lbl_r)
	var lbl_s: Label = _make_label("💋 RAMA CLIENTAS Y VICTORIA", 18, Color(1.0, 0.62, 0.84))
	lbl_s.position = Vector2(54, 836)
	_tree_view_root.add_child(lbl_s)

	# Tutorial overlay banner inside the Skill Tree (top-left, clear of nodes)
	_tree_tut_banner = _make_card_panel(Vector2(54, 146), Vector2(530, 148), Color(0.16, 0.08, 0.26, 0.96), Color(1.0, 0.86, 0.34))
	_tree_tut_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tree_tut_banner.visible = false
	_tree_view_root.add_child(_tree_tut_banner)

	var ttv: VBoxContainer = VBoxContainer.new()
	ttv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ttv.add_theme_constant_override("separation", 6)
	_tree_tut_banner.get_child(0).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tree_tut_banner.get_child(0).add_child(ttv)

	_tree_tut_title_lbl = _make_label("👆 ¡Sube Toque Continuo!", 20, Color(1.0, 0.88, 0.38))
	_tree_tut_body_lbl = _make_label("", 16, Color(0.98, 0.95, 1.0))
	_tree_tut_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ttv.add_child(_tree_tut_title_lbl)
	ttv.add_child(_tree_tut_body_lbl)

	var bottom_bar: PanelContainer = _make_card_panel(Vector2(40, 882), Vector2(1840, 174), Color(0.11, 0.07, 0.18, 0.98), Color(0.82, 0.64, 0.32))
	_tree_view_root.add_child(bottom_bar)
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	bottom_bar.get_child(0).add_child(hbox)

	var info_col: VBoxContainer = VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 6)
	hbox.add_child(info_col)

	_tree_info_title = _make_label("Selecciona un nodo del árbol", 26, Color(1.0, 0.88, 0.42))
	_tree_info_desc = _make_label("", 20, Color(0.95, 0.92, 0.98))
	_tree_info_stats = _make_label("", 18, Color(0.68, 0.88, 1.0))
	info_col.add_child(_tree_info_title)
	info_col.add_child(_tree_info_desc)
	info_col.add_child(_tree_info_stats)

	_tree_buy_btn = _make_pill_button("MEJORAR", Color(0.58, 0.22, 0.40), Color(1.0, 0.84, 0.36))
	_tree_buy_btn.custom_minimum_size = Vector2(290, 92)
	_tree_buy_btn.pressed.connect(func() -> void: buy_incremental_node(_tree_selected_id))
	hbox.add_child(_tree_buy_btn)

	_tree_back_btn = _make_pill_button("🗺 VOLVER AL MAPA", Color(0.18, 0.34, 0.50), Color(0.54, 0.88, 1.0))
	_tree_back_btn.custom_minimum_size = Vector2(300, 92)
	_tree_back_btn.pressed.connect(func() -> void:
		_play_pentatonic(2, -3.0)
		_switch_view(MapView.MAP)
	)
	hbox.add_child(_tree_back_btn)


func _build_gallery_ui() -> void:
	_gallery_view_root = Control.new()
	_gallery_view_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gallery_view_root.visible = false
	add_child(_gallery_view_root)
	move_child(_gallery_view_root, 3)

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.07, 0.04, 0.12, 0.98)
	_gallery_view_root.add_child(bg)

	var selector_row: HBoxContainer = HBoxContainer.new()
	selector_row.position = Vector2(56, 98)
	selector_row.size = Vector2(1808, 56)
	selector_row.add_theme_constant_override("separation", 14)
	_gallery_view_root.add_child(selector_row)

	var roster_ids: Array[StringName] = [&"sylvi", &"velvet", &"seraphina", &"mona", &"roxy", &"trixie"]
	var roster_labels: Dictionary = {
		&"sylvi": "🌿 Sylvi", &"velvet": "🦇 Velvet", &"seraphina": "🛡 Seraphina",
		&"mona": "✨ Mona", &"roxy": "🐺 Roxy", &"trixie": "🔥 Trixie",
	}
	for cid: StringName in roster_ids:
		var btn: Button = _make_pill_button(String(roster_labels[cid]), Color(0.22, 0.14, 0.32), Color(0.92, 0.62, 0.82))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func() -> void:
			_gallery_selected_char_id = cid
			_refresh_gallery_panel()
		)
		selector_row.add_child(btn)
		_gallery_char_buttons[cid] = btn

	var left_card: PanelContainer = _make_card_panel(Vector2(56, 174), Vector2(580, 860), Color(0.12, 0.07, 0.18, 0.96), Color(0.96, 0.62, 0.84))
	_gallery_view_root.add_child(left_card)
	var lvbox: VBoxContainer = VBoxContainer.new()
	lvbox.add_theme_constant_override("separation", 12)
	left_card.get_child(0).add_child(lvbox)

	_gallery_portrait_canvas = Control.new()
	_gallery_portrait_canvas.custom_minimum_size = Vector2(520, 440)
	_gallery_portrait_canvas.draw.connect(_draw_gallery_portrait)
	lvbox.add_child(_gallery_portrait_canvas)

	_gallery_title_lbl = _make_label("Sylvi", 28, Color(1.0, 0.88, 0.44))
	_gallery_aff_lbl = _make_label("❤ Afinidad Nv.0 (0/3)", 20, Color(1.0, 0.56, 0.82))
	_gallery_lines_lbl = _make_label("", 18, Color(0.94, 0.90, 0.96))
	_gallery_lines_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gallery_lines_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lvbox.add_child(_gallery_title_lbl)
	lvbox.add_child(_gallery_aff_lbl)
	lvbox.add_child(_gallery_lines_lbl)

	_gallery_gift_btn = _make_pill_button("🎁 REGALAR ELIXIR (40✦ -> +2❤)", Color(0.54, 0.16, 0.36), Color(1.0, 0.82, 0.42))
	_gallery_gift_btn.custom_minimum_size = Vector2(0, 56)
	_gallery_gift_btn.pressed.connect(_on_gallery_gift_pressed)
	lvbox.add_child(_gallery_gift_btn)

	var right_card: PanelContainer = _make_card_panel(Vector2(660, 174), Vector2(1204, 860), Color(0.11, 0.07, 0.17, 0.96), Color(0.84, 0.66, 0.36))
	_gallery_view_root.add_child(right_card)
	var rvbox: VBoxContainer = VBoxContainer.new()
	rvbox.add_theme_constant_override("separation", 20)
	right_card.get_child(0).add_child(rvbox)

	rvbox.add_child(_make_label("GALERÍA DE ILUSTRACIONES Y ESCENAS PICANTES", 28, Color(1.0, 0.88, 0.44)))

	_gallery_cards_box = HBoxContainer.new()
	_gallery_cards_box.add_theme_constant_override("separation", 24)
	_gallery_cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rvbox.add_child(_gallery_cards_box)

	_gallery_back_btn = _make_pill_button("🗺 VOLVER AL MAPA", Color(0.18, 0.34, 0.50), Color(0.54, 0.88, 1.0))
	_gallery_back_btn.custom_minimum_size = Vector2(0, 66)
	_gallery_back_btn.pressed.connect(func() -> void:
		_play_pentatonic(2, -3.0)
		_switch_view(MapView.MAP)
	)
	rvbox.add_child(_gallery_back_btn)


func _build_modals() -> void:
	_lightbox_overlay = ColorRect.new()
	_lightbox_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lightbox_overlay.color = Color(0.03, 0.02, 0.06, 0.92)
	_lightbox_overlay.visible = false
	add_child(_lightbox_overlay)

	var lb_center: CenterContainer = CenterContainer.new()
	lb_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lightbox_overlay.add_child(lb_center)
	var lb_panel: PanelContainer = _make_card_panel(Vector2.ZERO, Vector2(1140, 840), Color(0.12, 0.07, 0.18, 0.98), Color(1.0, 0.82, 0.40))
	lb_panel.custom_minimum_size = Vector2(1140, 840)
	lb_center.add_child(lb_panel)

	var lb_vbox: VBoxContainer = VBoxContainer.new()
	lb_vbox.add_theme_constant_override("separation", 14)
	lb_panel.get_child(0).add_child(lb_vbox)

	_lightbox_title_lbl = _make_label("", 28, Color(1.0, 0.88, 0.44))
	_lightbox_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb_vbox.add_child(_lightbox_title_lbl)

	_lightbox_canvas = Control.new()
	_lightbox_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lightbox_canvas.draw.connect(_draw_lightbox_scene)
	lb_vbox.add_child(_lightbox_canvas)

	_lightbox_caption_lbl = _make_label("", 20, Color(0.96, 0.88, 0.94))
	_lightbox_caption_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lightbox_caption_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb_vbox.add_child(_lightbox_caption_lbl)

	var lb_close: Button = _make_pill_button("CERRAR VISOR [ESC]", Color(0.46, 0.18, 0.30), Color(1.0, 0.72, 0.42))
	lb_close.custom_minimum_size = Vector2(260, 50)
	lb_close.pressed.connect(func() -> void: _lightbox_overlay.visible = false)
	var cc: CenterContainer = CenterContainer.new()
	cc.add_child(lb_close)
	lb_vbox.add_child(cc)

	_pause_overlay = ColorRect.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.color = Color(0.04, 0.02, 0.08, 0.84)
	_pause_overlay.visible = false
	add_child(_pause_overlay)

	var p_center: CenterContainer = CenterContainer.new()
	p_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(p_center)
	var p_panel: PanelContainer = _make_card_panel(Vector2.ZERO, Vector2(460, 340), Color(0.12, 0.08, 0.19, 0.98), Color(0.88, 0.68, 0.36))
	p_panel.custom_minimum_size = Vector2(460, 340)
	p_center.add_child(p_panel)

	var p_vbox: VBoxContainer = VBoxContainer.new()
	p_vbox.add_theme_constant_override("separation", 18)
	p_panel.get_child(0).add_child(p_vbox)
	var p_hdr: Label = _make_label("MENÚ", 34, Color(1.0, 0.88, 0.44))
	p_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_vbox.add_child(p_hdr)

	var res_btn: Button = _make_pill_button("REANUDAR", Color(0.18, 0.46, 0.28), Color(0.56, 1.0, 0.60))
	res_btn.custom_minimum_size = Vector2(0, 56)
	res_btn.pressed.connect(func() -> void: _pause_overlay.visible = false)
	var rst_btn: Button = _make_pill_button("REINICIAR PARTIDA", Color(0.46, 0.24, 0.16), Color(1.0, 0.72, 0.40))
	rst_btn.custom_minimum_size = Vector2(0, 56)
	rst_btn.pressed.connect(func() -> void:
		_pause_overlay.visible = false
		_state().reset_run()
		var fader: Node = _fader()
		if fader != null:
			fader.call("fade_to_scene", "res://scenes/main/Main.tscn", 0.4, 0.4)
		else:
			get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
	)
	var menu_btn: Button = _make_pill_button("MENÚ PRINCIPAL", Color(0.28, 0.16, 0.38), Color(0.88, 0.66, 0.98))
	menu_btn.custom_minimum_size = Vector2(0, 56)
	menu_btn.pressed.connect(func() -> void:
		_pause_overlay.visible = false
		var fader: Node = _fader()
		if fader != null:
			fader.call("fade_to_scene", "res://scenes/ui/MainMenu.tscn", 0.4, 0.4)
		else:
			get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	)
	p_vbox.add_child(res_btn)
	p_vbox.add_child(rst_btn)
	p_vbox.add_child(menu_btn)

	_victory_overlay = ColorRect.new()
	_victory_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_victory_overlay.color = Color(0.05, 0.02, 0.08, 0.88)
	_victory_overlay.visible = false
	add_child(_victory_overlay)

	var v_center: CenterContainer = CenterContainer.new()
	v_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_victory_overlay.add_child(v_center)
	var v_panel: PanelContainer = _make_card_panel(Vector2.ZERO, Vector2(680, 440), Color(0.15, 0.08, 0.20, 0.98), Color(1.0, 0.88, 0.36))
	v_panel.custom_minimum_size = Vector2(680, 440)
	v_center.add_child(v_panel)

	var v_vbox: VBoxContainer = VBoxContainer.new()
	v_vbox.add_theme_constant_override("separation", 18)
	v_panel.get_child(0).add_child(v_vbox)
	var v_hdr: Label = _make_label("🏆 ¡BOTICA CONSAGRADA! 🏆", 36, Color(1.0, 0.90, 0.38))
	v_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var v_body: Label = _make_label(
		"¡Has destilado el Elixir Supremo de Trixie!\nLa botica ambulante es ahora leyenda en todo el reino.\nPuedes seguir viajando y desbloquear el 100% de la Galería.",
		21, Color(0.96, 0.92, 0.98)
	)
	v_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var v_cont: Button = _make_pill_button("✨ SEGUIR Y VER GALERÍA", Color(0.56, 0.18, 0.38), Color(1.0, 0.84, 0.38))
	v_cont.custom_minimum_size = Vector2(0, 58)
	v_cont.pressed.connect(func() -> void:
		_victory_overlay.visible = false
		_switch_view(MapView.GALLERY)
	)
	v_vbox.add_child(v_hdr)
	v_vbox.add_child(v_body)
	v_vbox.add_child(v_cont)


# ==============================================================================
# MAP INTERACTION, SELECTION & TRAVEL
# ==============================================================================

func _on_map_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var hit: StringName = _hit_test_map_node(mm.position)
		if hit != _hovered_node_id:
			_hovered_node_id = hit
			_map_canvas.queue_redraw()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var hit: StringName = _hit_test_map_node(mb.position)
			if hit != &"":
				_selected_node_id = hit
				_refresh_map_detail_panel()
				_play_pentatonic(3 if _state().is_map_node_unlocked(hit) else 0, -5.0)
				if not _is_map_tutorial_blocking() and _state().is_map_node_unlocked(hit):
					if hit == _last_clicked_node_id and (_time - _last_click_time) <= 0.42:
						_travel_to_selected_node()
						return
					_last_clicked_node_id = hit
					_last_click_time = _time
				_map_canvas.queue_redraw()


func _hit_test_map_node(pos: Vector2) -> StringName:
	for mn: Dictionary in _state().map_nodes:
		if pos.distance_to(mn["pos"] as Vector2) <= MAP_NODE_RADIUS + 14.0:
			return mn["id"] as StringName
	return &""


func _refresh_map_detail_panel() -> void:
	if _node_title_lbl == null:
		return
	var st: Node = _state()
	var mn: Dictionary = st.get_map_node(_selected_node_id)
	if mn.is_empty():
		return

	var unlocked: bool = st.is_map_node_unlocked(_selected_node_id)
	var completed: bool = st.is_map_node_completed(_selected_node_id)
	var status_txt: String = "✅ Completada" if completed else ("✨ Disponible" if unlocked else "🔒 Bloqueada")

	var cust_names: Array[String] = []
	for cv: Variant in (mn.get("customers", []) as Array):
		var cname: String = String(cv).capitalize()
		cust_names.append(cname)

	_node_title_lbl.text = "%s %s — %s" % [String(mn["icon"]), String(mn["name"]), String(mn["subtitle"])]
	_node_meta_lbl.text = "%s  ·  %s  ·  Clientas: %s  ·  Esencia x%.2f" % [
		status_txt,
		String(mn.get("route_tag", "")),
		", ".join(cust_names),
		float(mn.get("essence_mult", 1.0)),
	]
	_node_desc_lbl.text = String(mn.get("description", ""))

	if _is_map_tutorial_blocking():
		_travel_btn.disabled = true
		_travel_btn.text = "🌿 PRIMERO ENTRA AL ÁRBOL ☝"
	elif not unlocked:
		_travel_btn.disabled = true
		_travel_btn.text = "🔒 PARADA BLOQUEADA"
	else:
		_travel_btn.disabled = false
		_travel_btn.text = "🔥 REJUGAR PARADA" if completed else "🔥 VIAJAR A ESTA PARADA"


func _travel_to_selected_node() -> bool:
	if _transitioning or _is_map_tutorial_blocking():
		return false
	var st: Node = _state()
	if not st.is_map_node_unlocked(_selected_node_id):
		return false
	_transitioning = true
	st.active_map_node_id = _selected_node_id
	_play_pentatonic(5, 0.0)
	var fader: Node = _fader()
	if fader != null and not bool(fader.call("is_busy")):
		fader.call("fade_to_scene", "res://scenes/main/Main.tscn", 0.55, 0.55)
	elif get_tree() != null and get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
	return true


func _draw_world_map() -> void:
	if _map_canvas == null:
		return
	var st: Node = _state()
	var font: Font = ThemeDB.fallback_font

	# Illustrated atmospheric parchment-night backdrop for the Kingdom Map
	_map_canvas.draw_rect(Rect2(0, 76, 1920, 760), Color(0.08, 0.05, 0.14))
	_map_canvas.draw_circle(Vector2(260, 480), 280.0, Color(0.24, 0.14, 0.36, 0.24))
	_map_canvas.draw_circle(Vector2(920, 500), 310.0, Color(0.14, 0.10, 0.26, 0.30))
	_map_canvas.draw_circle(Vector2(1500, 490), 300.0, Color(0.10, 0.22, 0.28, 0.24))

	# Subtle cartographic grid lines & compass rose
	for gx: int in range(120, 1920, 180):
		_map_canvas.draw_line(Vector2(gx, 76), Vector2(gx, 836), Color(1, 1, 1, 0.03), 1.0)
	for gy: int in range(160, 820, 160):
		_map_canvas.draw_line(Vector2(0, gy), Vector2(1920, gy), Color(1, 1, 1, 0.03), 1.0)
	_map_canvas.draw_arc(Vector2(1740, 220), 64.0, 0.0, TAU, 36, Color(0.86, 0.72, 0.38, 0.16), 2.0)
	_map_canvas.draw_string(font, Vector2(1726, 178), "N", HORIZONTAL_ALIGNMENT_CENTER, 28, 18, Color(0.92, 0.80, 0.44, 0.35))

	for s: Dictionary in _sparkles:
		var a: float = 0.14 + 0.24 * absf(sin(_time * 2.0 + float(s["phase"])))
		_map_canvas.draw_circle(Vector2(float(s["x"]), float(s["y"])), float(s["r"]), Color(1.0, 0.88, 0.48, a))

	# Curved/straight route edges between map stops
	for mn: Dictionary in st.map_nodes:
		var p0: Vector2 = mn["pos"] as Vector2
		var from_id: StringName = mn["id"] as StringName
		var from_done: bool = st.is_map_node_completed(from_id)
		var nexts: Array = mn.get("next_ids", []) as Array
		for nv: Variant in nexts:
			var nid: StringName = nv as StringName
			var target: Dictionary = st.get_map_node(nid)
			if target.is_empty():
				continue
			var p1: Vector2 = target["pos"] as Vector2
			var to_unl: bool = st.is_map_node_unlocked(nid)
			var edge_col: Color = Color(1.0, 0.84, 0.38, 0.75) if (from_done and to_unl) else Color(0.35, 0.30, 0.46, 0.45)
			var mid: Vector2 = (p0 + p1) * 0.5 + Vector2(0.0, -26.0 if p1.y < p0.y else (26.0 if p1.y > p0.y else -16.0))
			_map_canvas.draw_polyline(PackedVector2Array([p0, mid, p1]), edge_col, 5.0 if from_done else 3.0, true)

	# Draw stops
	for mn: Dictionary in st.map_nodes:
		var mid: StringName = mn["id"] as StringName
		var pos: Vector2 = mn["pos"] as Vector2
		var col: Color = mn["color"] as Color
		var unlocked: bool = st.is_map_node_unlocked(mid)
		var completed: bool = st.is_map_node_completed(mid)
		var selected: bool = (mid == _selected_node_id)
		var hovered: bool = (mid == _hovered_node_id)
		var pulse: float = 0.5 + 0.5 * sin(_time * 4.5)

		if selected:
			_map_canvas.draw_circle(pos, MAP_NODE_RADIUS + 16.0 + pulse * 4.0, Color(1.0, 0.86, 0.34, 0.20))
			_map_canvas.draw_arc(pos, MAP_NODE_RADIUS + 11.0, 0.0, TAU, 36, Color(1.0, 0.92, 0.46), 4.0)
		elif hovered and unlocked:
			_map_canvas.draw_arc(pos, MAP_NODE_RADIUS + 8.0, 0.0, TAU, 36, Color(1, 1, 1, 0.75), 2.5)

		var fill_col: Color = col.darkened(0.42) if completed else (col.darkened(0.58) if unlocked else Color(0.12, 0.10, 0.17))
		var border_col: Color = Color(0.55, 0.98, 0.68) if completed else (col if unlocked else Color(0.32, 0.28, 0.42))
		_map_canvas.draw_circle(pos, MAP_NODE_RADIUS, fill_col)
		_map_canvas.draw_arc(pos, MAP_NODE_RADIUS, 0.0, TAU, 36, border_col, 4.5 if unlocked else 2.5)

		_map_canvas.draw_string(font, pos + Vector2(-18, 12), String(mn["icon"]), HORIZONTAL_ALIGNMENT_CENTER, 36, 32, Color.WHITE if unlocked else Color(0.5, 0.5, 0.58))

		if completed:
			_map_canvas.draw_circle(pos + Vector2(36, -34), 14.0, Color(0.18, 0.68, 0.36))
			_map_canvas.draw_string(font, pos + Vector2(28, -28), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		elif not unlocked:
			_map_canvas.draw_circle(pos + Vector2(36, -34), 14.0, Color(0.20, 0.16, 0.28))
			_map_canvas.draw_string(font, pos + Vector2(27, -28), "🔒", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.72, 0.84))

		_map_canvas.draw_string(font, pos + Vector2(-120, MAP_NODE_RADIUS + 26), String(mn["name"]), HORIZONTAL_ALIGNMENT_CENTER, 240, 17, Color(1.0, 0.96, 0.88) if unlocked else Color(0.55, 0.52, 0.64))
		_map_canvas.draw_string(font, pos + Vector2(-120, MAP_NODE_RADIUS + 46), String(mn.get("route_tag", "")), HORIZONTAL_ALIGNMENT_CENTER, 240, 13, col.lightened(0.25) if unlocked else Color(0.45, 0.42, 0.52))

	# Draw Trixie's small portrait marker above her last visited stop
	var last_nd: Dictionary = st.get_map_node(st.last_visited_map_node_id)
	if not last_nd.is_empty():
		var tp: Vector2 = (last_nd["pos"] as Vector2) + Vector2(0.0, -MAP_NODE_RADIUS - 34.0 + sin(_time * 3.0) * 4.0)
		var portrait_tex: Texture2D = CharacterArt.get_trixie_expression("confiada", "hud")
		if portrait_tex != null:
			_map_canvas.draw_circle(tp, 28.0, Color(0.16, 0.08, 0.22))
			_map_canvas.draw_texture_rect(portrait_tex, Rect2(tp - Vector2(24, 24), Vector2(48, 48)), false)
			_map_canvas.draw_arc(tp, 28.0, 0.0, TAU, 24, Color(1.0, 0.86, 0.36), 3.0)

	# Mandatory Tutorial Pointer Arrow aimed directly at the Skill Tree button in Top Bar
	if _is_map_tutorial_blocking() and st.map_tutorial_stage == 0 and _tree_btn != null:
		var btn_center: Vector2 = _tree_btn.global_position + Vector2(_tree_btn.size.x * 0.5, _tree_btn.size.y)
		var bounce: float = absf(sin(_time * 5.0)) * 12.0
		var arrow_tip: Vector2 = btn_center + Vector2(0.0, 14.0 + bounce)
		_map_canvas.draw_colored_polygon(PackedVector2Array([
			arrow_tip,
			arrow_tip + Vector2(-16, 24),
			arrow_tip + Vector2(16, 24),
		]), Color(1.0, 0.88, 0.32))
		_map_canvas.draw_string(font, arrow_tip + Vector2(-140, 52), "☝ ¡ENTRA AQUÍ!", HORIZONTAL_ALIGNMENT_CENTER, 280, 20, Color(1.0, 0.90, 0.36))


# ==============================================================================
# UPGRADE TREE INTERACTION & DRAWING (SHARED VIA GameState)
# ==============================================================================

func buy_incremental_node(node_id: StringName) -> bool:
	var st: Node = _state()
	if _is_map_tutorial_blocking() and st.map_tutorial_stage == 1 and node_id != &"toque_continuo":
		_play_pentatonic(0, -6.0)
		if _tree_info_stats != null:
			_tree_info_stats.text = "✨ Tutorial: ¡Primero mejora 👆 Toque Continuo para desbloquear el resto!"
		return false

	if not st.buy_incremental_node(node_id):
		return false

	_play_pentatonic(clampi(st.get_node_level(node_id) + 2, 0, 7), -1.0)

	if node_id == &"toque_continuo" and not st.map_tutorial_done:
		st.map_tutorial_stage = 2
		st.map_tutorial_done = true
		_play_pentatonic(6, 0.0)

	if node_id == &"elixir_supremo" and not st.victory_banner_shown:
		st.victory_banner_shown = true
		if _victory_overlay != null:
			_victory_overlay.visible = true

	_refresh_tree_detail_panel()
	_refresh_top_and_tutorials()
	if _tree_canvas != null:
		_tree_canvas.queue_redraw()
	return true


func _on_tree_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var hit: StringName = _hit_test_tree_node(mm.position)
		if hit != _tree_hovered_id:
			_tree_hovered_id = hit
			if hit != &"":
				_tree_selected_id = hit
				_refresh_tree_detail_panel()
			_tree_canvas.queue_redraw()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var hit: StringName = _hit_test_tree_node(mb.position)
			if hit != &"":
				_tree_selected_id = hit
				if not buy_incremental_node(hit):
					_play_pentatonic(0, -8.0)
				_refresh_tree_detail_panel()
				_tree_canvas.queue_redraw()


func _hit_test_tree_node(pos: Vector2) -> StringName:
	for nd: Dictionary in _state().tree_nodes:
		if pos.distance_to(nd["pos"] as Vector2) <= 46.0:
			return nd["id"] as StringName
	return &""


func _refresh_tree_detail_panel() -> void:
	if _tree_info_title == null:
		return
	var st: Node = _state()
	var nd: Dictionary = st.get_node_dict(_tree_selected_id)
	if nd.is_empty():
		return
	var lvl: int = st.get_node_level(_tree_selected_id)
	var max_lvl: int = int(nd["max_level"])
	var cost: int = st.get_node_cost(_tree_selected_id)
	var unlocked: bool = st.is_node_unlocked(_tree_selected_id)

	_tree_info_title.text = "%s %s  (Nv. %d / %d)" % [String(nd["icon"]), String(nd["name"]), lvl, max_lvl]
	_tree_info_desc.text = String(nd["short_desc"])

	var tut_locked_other: bool = (_is_map_tutorial_blocking() and st.map_tutorial_stage == 1 and _tree_selected_id != &"toque_continuo")
	if tut_locked_other:
		_tree_info_stats.text = "✨ Tutorial: ¡Primero compra 👆 Toque Continuo!"
		_tree_buy_btn.text = "TUTORIAL: COMPRA TOQUE CONTINUO"
		_tree_buy_btn.disabled = true
	elif lvl >= max_lvl:
		_tree_info_stats.text = "Estado: ¡MÁXIMO ALCANZADO!"
		_tree_buy_btn.text = "NIVEL MÁXIMO"
		_tree_buy_btn.disabled = true
	elif not unlocked:
		var p_id: StringName = nd.get("parent_id", &"") as StringName
		var p_nd: Dictionary = st.get_node_dict(p_id)
		var p_name: String = String(p_nd["name"]) if not p_nd.is_empty() else "Anterior"
		_tree_info_stats.text = "Bloqueado — Desbloquea primero: %s" % p_name
		_tree_buy_btn.text = "BLOQUEADO"
		_tree_buy_btn.disabled = true
	else:
		_tree_info_stats.text = "Siguiente nivel cuesta: %d✦ Esencia  (Tienes: %d✦)" % [cost, st.essence_gold]
		_tree_buy_btn.text = "MEJORAR (%d✦)" % cost
		_tree_buy_btn.disabled = st.essence_gold < cost

	if _tree_back_btn != null:
		var block_back: bool = (_is_map_tutorial_blocking() and st.get_node_level(&"toque_continuo") == 0)
		_tree_back_btn.disabled = block_back


func _draw_upgrade_tree() -> void:
	if _tree_canvas == null:
		return
	var st: Node = _state()
	var font: Font = ThemeDB.fallback_font
	for gx: int in range(80, 1920, 120):
		_tree_canvas.draw_line(Vector2(gx, 76), Vector2(gx, 882), Color(1, 1, 1, 0.03), 1.0)
	for gy: int in range(120, 880, 120):
		_tree_canvas.draw_line(Vector2(0, gy), Vector2(1920, gy), Color(1, 1, 1, 0.03), 1.0)

	for nd: Dictionary in st.tree_nodes:
		var nid: StringName = nd["id"] as StringName
		var p_id: StringName = nd.get("parent_id", &"") as StringName
		if p_id == &"":
			continue
		var p_nd: Dictionary = st.get_node_dict(p_id)
		if p_nd.is_empty():
			continue
		var p_pos: Vector2 = p_nd["pos"] as Vector2
		var n_pos: Vector2 = nd["pos"] as Vector2
		var col: Color = nd["color"] as Color
		var unlocked: bool = st.is_node_unlocked(nid)
		var owned: bool = st.get_node_level(nid) > 0
		var line_col: Color = col if owned else (Color(col.r, col.g, col.b, 0.45) if unlocked else Color(0.28, 0.24, 0.34, 0.45))
		_tree_canvas.draw_line(p_pos, n_pos, line_col, 5.5 if owned else (3.5 if unlocked else 2.0), true)

	for nd: Dictionary in st.tree_nodes:
		var nid: StringName = nd["id"] as StringName
		var pos: Vector2 = nd["pos"] as Vector2
		var col: Color = nd["color"] as Color
		var lvl: int = st.get_node_level(nid)
		var max_lvl: int = int(nd["max_level"])
		var unlocked: bool = st.is_node_unlocked(nid)
		var affordable: bool = st.can_buy_node(nid)
		var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)

		if affordable:
			_tree_canvas.draw_circle(pos, 47.0 + pulse * 5.0, Color(1.0, 0.88, 0.36, 0.22 + pulse * 0.16))
		if nid == _tree_selected_id or nid == _tree_hovered_id:
			_tree_canvas.draw_arc(pos, 48.0, 0.0, TAU, 32, Color(1.0, 0.94, 0.55), 3.5)

		var fill_col: Color = Color(0.18, 0.12, 0.26)
		if lvl >= max_lvl:
			fill_col = col.darkened(0.32)
		elif lvl > 0:
			fill_col = col.darkened(0.55)
		elif not unlocked:
			fill_col = Color(0.10, 0.08, 0.14)

		var border_col: Color = Color(1.0, 0.90, 0.36) if affordable else (col if unlocked else Color(0.30, 0.26, 0.38))
		_tree_canvas.draw_circle(pos, 38.0, fill_col)
		_tree_canvas.draw_arc(pos, 38.0, 0.0, TAU, 32, border_col, 4.0 if affordable or lvl > 0 else 2.5)
		_tree_canvas.draw_string(font, pos + Vector2(-14, 10), String(nd["icon"]), HORIZONTAL_ALIGNMENT_CENTER, 28, 26, Color.WHITE if unlocked else Color(0.5, 0.5, 0.55))

		var name_col: Color = Color(1.0, 0.96, 0.88) if unlocked else Color(0.56, 0.52, 0.64)
		_tree_canvas.draw_string(font, pos + Vector2(-95, 56), String(nd["name"]), HORIZONTAL_ALIGNMENT_CENTER, 190, 15, name_col)
		var sub_txt: String = "MAX" if lvl >= max_lvl else ("%d/%d · %d✦" % [lvl, max_lvl, st.get_node_cost(nid)] if unlocked else "🔒")
		var sub_col: Color = Color(1.0, 0.88, 0.36) if affordable else (Color(0.55, 0.96, 0.68) if lvl >= max_lvl else Color(0.75, 0.72, 0.84))
		_tree_canvas.draw_string(font, pos + Vector2(-65, 74), sub_txt, HORIZONTAL_ALIGNMENT_CENTER, 130, 13, sub_col)

		# Mandatory tutorial ring & floating label on Toque Continuo
		if _is_map_tutorial_blocking() and nid == &"toque_continuo" and lvl == 0:
			var tpulse: float = 0.5 + 0.5 * sin(_time * 8.0)
			_tree_canvas.draw_arc(pos, 58.0 + tpulse * 7.0, 0.0, TAU, 36, Color(1.0, 0.88, 0.32), 4.5)
			_tree_canvas.draw_string(font, pos + Vector2(-115, -64), "👇 ¡SUBE ESTA HABILIDAD!", HORIZONTAL_ALIGNMENT_CENTER, 230, 17, Color(1.0, 0.90, 0.36))


# ==============================================================================
# GALLERY VIEW (MIGRATED FROM MAINGAME)
# ==============================================================================

func _refresh_gallery_panel() -> void:
	if _gallery_title_lbl == null:
		return
	var st: Node = _state()
	for cid: StringName in _gallery_char_buttons.keys():
		(_gallery_char_buttons[cid] as Button).modulate = Color(1.0, 0.92, 0.55) if cid == _gallery_selected_char_id else Color(0.82, 0.78, 0.90)

	var pts: int = st.get_affinity_points(_gallery_selected_char_id)
	var lvl: int = st.get_affinity_level(_gallery_selected_char_id)
	var next_req: int = GameStateScript.AFFINITY_THRESHOLDS[mini(lvl, GameStateScript.AFFINITY_THRESHOLDS.size() - 1)]

	var char_name: String = "Trixie"
	var role_txt: String = "Bruja del Caldero"
	var quotes: PackedStringArray = PackedStringArray([
		"¡El caldero apenas comienza a calentarse!",
		"¡Mantén presionado el clic o mezcla colores y mira cómo llueve la Esencia!",
	])
	if _gallery_selected_char_id != &"trixie":
		for c: CustomerArchetypeData in st.customers_catalog:
			if c.customer_id == _gallery_selected_char_id:
				char_name = c.display_name
				role_txt = c.species_archetype
				var all_q: Array[String] = []
				for s: String in c.greeting_lines:
					all_q.append("• " + s)
				if lvl >= 1:
					for s: String in c.satisfied_lines:
						all_q.append("★ " + s)
				if lvl >= 2:
					for s: String in c.spicy_affinity_lines:
						all_q.append("💋 " + s)
				else:
					all_q.append("🔒 Frases picantes bloqueadas (Requiere Afinidad Nv.2)")
				quotes = PackedStringArray(all_q)
				break

	_gallery_title_lbl.text = "%s — %s" % [char_name, role_txt]
	_gallery_aff_lbl.text = "❤ Afinidad Nv.%d / 3  (%d / %d pts)" % [lvl, pts, next_req]
	_gallery_lines_lbl.text = "\n".join(quotes)

	var gift_cost: int = 40 * (lvl + 1)
	_gallery_gift_btn.text = "🎁 REGALAR ELIXIR (%d✦ -> +2❤)" % gift_cost
	_gallery_gift_btn.disabled = (st.essence_gold < gift_cost) or (lvl >= 3)

	for child: Node in _gallery_cards_box.get_children():
		child.queue_free()

	var titles: Array = GALLERY_TITLES.get(_gallery_selected_char_id, ["Escena I", "Escena II", "Escena III"]) as Array
	for idx: int in range(3):
		var req_lvl: int = idx + 1
		var unlocked: bool = lvl >= req_lvl
		var card_panel: PanelContainer = _make_card_panel(Vector2.ZERO, Vector2(360, 560),
			Color(0.18, 0.10, 0.24) if unlocked else Color(0.09, 0.07, 0.13),
			Color(1.0, 0.80, 0.42) if unlocked else Color(0.32, 0.28, 0.42)
		)
		card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_gallery_cards_box.add_child(card_panel)

		var cv: VBoxContainer = VBoxContainer.new()
		cv.add_theme_constant_override("separation", 12)
		card_panel.get_child(0).add_child(cv)
		var c_hdr: Label = _make_label("Escena %d · Nv.%d" % [req_lvl, req_lvl], 20, Color(1.0, 0.68, 0.86) if unlocked else Color(0.55, 0.52, 0.65))
		c_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(c_hdr)

		var preview: Control = Control.new()
		preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var cap_cid: StringName = _gallery_selected_char_id
		var cap_idx: int = idx
		var cap_unl: bool = unlocked
		preview.draw.connect(func() -> void: _draw_gallery_card_preview(preview, cap_cid, cap_idx, cap_unl))
		cv.add_child(preview)

		var c_title: Label = _make_label(String(titles[idx]) if unlocked else "🔒 Afinidad Nv.%d" % req_lvl, 19, Color(1.0, 0.90, 0.48) if unlocked else Color(0.60, 0.56, 0.70))
		c_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(c_title)

		var open_btn: Button = _make_pill_button("🔍 VER ESCENA" if unlocked else "BLOQUEADA",
			Color(0.58, 0.18, 0.38) if unlocked else Color(0.20, 0.18, 0.25),
			Color(1.0, 0.84, 0.38) if unlocked else Color(0.40, 0.36, 0.48)
		)
		open_btn.custom_minimum_size = Vector2(0, 48)
		open_btn.disabled = not unlocked
		open_btn.pressed.connect(func() -> void: _open_gallery_lightbox(cap_cid, cap_idx, String(titles[cap_idx])))
		cv.add_child(open_btn)

	_gallery_portrait_canvas.queue_redraw()


func _on_gallery_gift_pressed() -> void:
	var st: Node = _state()
	var lvl: int = st.get_affinity_level(_gallery_selected_char_id)
	var cost: int = 40 * (lvl + 1)
	if lvl >= 3 or not st.spend_essence(cost):
		return
	var leveled: bool = st.add_affinity(_gallery_selected_char_id, 2)
	_play_pentatonic(6 if leveled else 4, -1.0)
	_refresh_gallery_panel()


func _open_gallery_lightbox(cid: StringName, scene_idx: int, title_txt: String) -> void:
	_gallery_selected_char_id = cid
	_lightbox_scene_idx = scene_idx
	_lightbox_title_lbl.text = "💋 %s — %s" % [String(cid).capitalize(), title_txt]
	var captions: Array[String] = [
		"Un momento íntimo junto al caldero ambulante tras cerrar la jornada.",
		"El aroma dulce del elixir llena la posada y sube el rubor de la noche.",
		"Escena especial de afinidad máxima. ¡Lista para reemplazar con tu ilustración final de Krita!",
	]
	_lightbox_caption_lbl.text = captions[clampi(scene_idx, 0, captions.size() - 1)]
	_lightbox_overlay.visible = true
	_lightbox_canvas.queue_redraw()


func _draw_gallery_portrait() -> void:
	if _gallery_portrait_canvas == null:
		return
	var st: Node = _state()
	var r: Rect2 = Rect2(Vector2.ZERO, _gallery_portrait_canvas.size)
	_gallery_portrait_canvas.draw_rect(r, Color(0.14, 0.09, 0.22))
	_gallery_portrait_canvas.draw_rect(r, Color(0.94, 0.64, 0.82, 0.6), false, 2.0)
	if _gallery_selected_char_id == &"trixie":
		CharacterArt.draw_trixie_full(_gallery_portrait_canvas, Vector2(r.size.x * 0.5, r.size.y - 22.0), 1.02, "sonrojada", _time, 1.0)
	elif CharacterArt.has_customer_halfbody(_gallery_selected_char_id):
		CharacterArt.draw_customer_halfbody(_gallery_portrait_canvas, r.grow(-8), _gallery_selected_char_id, "sonrojada" if st.get_affinity_level(_gallery_selected_char_id) >= 1 else "normal", _time, 1.0)
	else:
		MainGame.draw_expressive_waifu_bust(_gallery_portrait_canvas, r.grow(-12), _gallery_selected_char_id, st.get_affinity_level(_gallery_selected_char_id) >= 2, _time)


func _draw_gallery_card_preview(ci: CanvasItem, cid: StringName, scene_idx: int, unlocked: bool) -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, ci.size)
	ci.draw_rect(r, Color(0.18, 0.10, 0.24) if unlocked else Color(0.08, 0.06, 0.12))
	if not unlocked:
		ci.draw_circle(r.size * 0.5, 42.0, Color(0.22, 0.16, 0.30))
		ci.draw_string(ThemeDB.fallback_font, r.size * 0.5 + Vector2(-14, 10), "🔒", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.75, 0.70, 0.85))
		return
	var glow_col: Color = Color(1.0, 0.48, 0.72, 0.24) if scene_idx == 2 else (Color(0.98, 0.72, 0.36, 0.20) if scene_idx == 1 else Color(0.45, 0.80, 1.0, 0.16))
	ci.draw_circle(r.size * 0.5, minf(r.size.x, r.size.y) * 0.42, glow_col)
	if cid == &"trixie":
		CharacterArt.draw_trixie_bust(ci, r.grow(-8), "sonrojada" if scene_idx == 2 else ("confiada" if scene_idx == 1 else "normal"), _time, 1.0, "dialogue")
	elif CharacterArt.has_customer_halfbody(cid):
		CharacterArt.draw_customer_halfbody(ci, r.grow(-6), cid, "sonrojada" if scene_idx == 2 else ("impaciente" if scene_idx == 1 else "normal"), _time, 1.0)
	else:
		MainGame.draw_expressive_waifu_bust(ci, r.grow(-10), cid, scene_idx >= 1, _time)


func _draw_lightbox_scene() -> void:
	if _lightbox_canvas == null:
		return
	var r: Rect2 = Rect2(Vector2.ZERO, _lightbox_canvas.size)
	_lightbox_canvas.draw_rect(r, Color(0.14, 0.07, 0.20))
	_lightbox_canvas.draw_circle(r.size * 0.5, 250.0, Color(1.0, 0.42, 0.74, 0.20))
	if _gallery_selected_char_id == &"trixie":
		CharacterArt.draw_trixie_bust(_lightbox_canvas, Rect2(r.size.x * 0.5 - 295.0, r.size.y - 520.0, 590.0, 510.0), "sonrojada" if _lightbox_scene_idx == 2 else ("confiada" if _lightbox_scene_idx == 1 else "normal"), _time, 1.0, "cutscene")
	elif CharacterArt.has_customer_halfbody(_gallery_selected_char_id):
		CharacterArt.draw_customer_halfbody(_lightbox_canvas, Rect2(r.size.x * 0.5 - 260.0, 12.0, 520.0, r.size.y - 20.0), _gallery_selected_char_id, "sonrojada" if _lightbox_scene_idx == 2 else ("impaciente" if _lightbox_scene_idx == 1 else "normal"), _time, 1.0)
	else:
		MainGame.draw_expressive_waifu_bust(_lightbox_canvas, Rect2(r.size.x * 0.5 - 240.0, 20.0, 480.0, r.size.y - 30.0), _gallery_selected_char_id, _lightbox_scene_idx >= 1, _time)


# ==============================================================================
# HUD & TUTORIAL REFRESH
# ==============================================================================

func _refresh_top_and_tutorials() -> void:
	var st: Node = _state()
	if _top_essence_lbl == null:
		return

	_top_essence_lbl.text = "✦ %d" % st.essence_gold
	var lyra_tag: String = "  ·  🌿 Lyra reclutada" if bool(st.recruited_witches.get(&"lyra", false)) else ""
	_top_progress_lbl.text = "🗺 Mapa de Viaje · Paradas: %d / %d%s" % [
		st.count_completed_map_nodes(),
		st.map_nodes.size(),
		lyra_tag,
	]

	var tut_block: bool = _is_map_tutorial_blocking()
	if _gallery_btn != null:
		_gallery_btn.disabled = tut_block

	var affordable: int = st.count_affordable_nodes()
	if _tree_badge_panel != null:
		_tree_badge_panel.visible = (affordable > 0) and (view_mode != MapView.UPGRADE_TREE)
		if _tree_btn != null and _tree_badge_panel.visible:
			_tree_badge_panel.position = _tree_btn.global_position + Vector2(_tree_btn.size.x - 14.0, -4.0)

	if _map_tut_banner != null:
		if view_mode == MapView.MAP and tut_block:
			_map_tut_banner.visible = true
			_map_tut_title_lbl.text = "✨ Trixie · ¡Tu Mapa de Gira y Árbol de Habilidades!"
			_map_tut_body_lbl.text = "Aquí eliges tu próxima parada y ves la 💋 Galería. Pero antes de seguir: pulsa 🌿 ÁRBOL DE HABILIDADES (arriba a la derecha) para mejorar tu magia."
		elif view_mode == MapView.MAP and st.map_tutorial_done and st.count_completed_map_nodes() <= 1 and not st.is_map_node_completed(&"pueblo"):
			_map_tut_banner.visible = true
			_map_tut_title_lbl.text = "✨ ¡Lista para la Parada 2!"
			_map_tut_body_lbl.text = "Ya puedes mantener presionado Clic Izquierdo en el caldero. Selecciona 🏘 El Pueblo y pulsa 🔥 VIAJAR A ESTA PARADA."
		else:
			_map_tut_banner.visible = false

	if _tree_tut_banner != null:
		if view_mode == MapView.UPGRADE_TREE and tut_block:
			_tree_tut_banner.visible = true
			_tree_tut_title_lbl.text = "👆 Tutorial Obligatorio: Toque Continuo"
			_tree_tut_body_lbl.text = "Haz clic en el nodo rojo 👆 Toque Continuo (a la derecha) o pulsa MEJORAR abajo. Así podrás MANTENER PRESIONADO Clic Izquierdo sobre un orbe sin cansarte."
		else:
			_tree_tut_banner.visible = false


# ==============================================================================
# HELPERS & SMOKE TEST API
# ==============================================================================

static func _make_label(txt: String, fsize: int, col: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.09))
	lbl.add_theme_constant_override("outline_size", 3)
	return lbl


static func _make_pill_button(txt: String, bg: Color, border: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = txt
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.92))
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.16)
	hover.border_color = border.lightened(0.20)
	var disabled: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.16, 0.14, 0.22)
	disabled.border_color = Color(0.35, 0.32, 0.45)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	return btn


static func _make_card_panel(pos: Vector2, sz: Vector2, bg: Color, border: Color) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = pos
	panel.size = sz
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(pad)
	return panel


func _audio() -> Node:
	return get_node_or_null("/root/AudioJuiceManager")


func _settings() -> Node:
	return get_node_or_null("/root/GameSettings")


func _fader() -> Node:
	return get_node_or_null("/root/SceneFader")


func _play_pentatonic(step_index: int, vol_db: float = 0.0) -> void:
	var a: Node = _audio()
	if a != null:
		a.call("play_pentatonic", step_index, vol_db)


## Exercises mandatory post-Stop-1 WorldMap tutorial, forced Toque Continuo buy, Gallery, and Stop 2 selection.
func run_worldmap_smoke_step() -> Dictionary:
	var st: Node = _state()
	var travel_blocked_initially: bool = _travel_btn.disabled and _gallery_btn.disabled and _map_tut_banner.visible
	_switch_view(MapView.UPGRADE_TREE)
	var entered_tree_ok: bool = (view_mode == MapView.UPGRADE_TREE and st.map_tutorial_stage == 1 and _tree_back_btn.disabled)
	var other_buy_blocked_ok: bool = not buy_incremental_node(&"hervor_creciente")
	var bought_hold_ok: bool = buy_incremental_node(&"toque_continuo") and st.hold_auto_hit_unlocked and st.map_tutorial_done
	var back_unlocked_ok: bool = not _tree_back_btn.disabled

	_switch_view(MapView.GALLERY)
	var gallery_opened_ok: bool = (view_mode == MapView.GALLERY and not _gallery_btn.disabled)

	_switch_view(MapView.MAP)
	_selected_node_id = &"pueblo"
	_refresh_map_detail_panel()
	var pueblo_travel_ready_ok: bool = (not _travel_btn.disabled and st.is_map_node_unlocked(&"pueblo"))

	# Also test buying additional upgrades through the WorldMap Skill Tree
	st.grant_essence(120)
	var bought_strength_ok: bool = buy_incremental_node(&"fuerza_molienda") and st.click_damage == 2
	var bought_boil_ok: bool = buy_incremental_node(&"hervor_creciente") and st.spawn_cap == 8
	var pat_before: float = st.customer_patience_sec
	var bought_patience_ok: bool = buy_incremental_node(&"reloj_arena") and is_equal_approx(st.customer_patience_sec, pat_before + 4.0)

	return {
		"travel_blocked_initially": travel_blocked_initially,
		"entered_tree_ok": entered_tree_ok,
		"other_buy_blocked_ok": other_buy_blocked_ok,
		"bought_hold_ok": bought_hold_ok,
		"back_unlocked_ok": back_unlocked_ok,
		"gallery_opened_ok": gallery_opened_ok,
		"pueblo_travel_ready_ok": pueblo_travel_ready_ok,
		"bought_strength_ok": bought_strength_ok,
		"bought_boil_ok": bought_boil_ok,
		"reloj_arena_patience_ok": bought_patience_ok,
	}
