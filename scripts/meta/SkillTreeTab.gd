class_name SkillTreeTab
extends Control
## Pestaña editable del Árbol de Habilidades: ramas visuales, detalle inferior,
## compra de mejoras y banner de tutorial obligatorio.

signal node_purchase_requested(node_id: StringName)
signal back_to_map_requested()

@onready var _tree_canvas: Control = $TreeCanvas
@onready var _tut_banner: PanelContainer = $TutorialBanner
@onready var _tut_title_lbl: Label = $TutorialBanner/Pad/VBox/TitleLabel
@onready var _tut_body_lbl: Label = $TutorialBanner/Pad/VBox/BodyLabel
@onready var _info_title: Label = $BottomDetailCard/Pad/HBox/InfoCol/InfoTitleLabel
@onready var _info_desc: Label = $BottomDetailCard/Pad/HBox/InfoCol/InfoDescLabel
@onready var _info_stats: Label = $BottomDetailCard/Pad/HBox/InfoCol/InfoStatsLabel
@onready var _buy_btn: Button = $BottomDetailCard/Pad/HBox/BuyButton
@onready var _back_btn: Button = $BottomDetailCard/Pad/HBox/BackButton

var _state: Node = null
var _time: float = 0.0
var _tutorial_blocking: bool = false

var selected_node_id: StringName = &"toque_continuo"
var _hovered_node_id: StringName = &""


func _ready() -> void:
	if _tree_canvas != null:
		_tree_canvas.draw.connect(_draw_upgrade_tree)
		_tree_canvas.gui_input.connect(_on_tree_gui_input)
	if _buy_btn != null:
		_buy_btn.pressed.connect(func() -> void: node_purchase_requested.emit(selected_node_id))
	if _back_btn != null:
		_back_btn.pressed.connect(func() -> void: back_to_map_requested.emit())


func configure(state: Node) -> void:
	_state = state


func select_node(node_id: StringName) -> void:
	selected_node_id = node_id
	queue_tree_redraw()


func step_visuals(time_sec: float, is_active: bool) -> void:
	_time = time_sec
	if is_active:
		queue_tree_redraw()


func queue_tree_redraw() -> void:
	if _tree_canvas != null:
		_tree_canvas.queue_redraw()


func is_back_disabled() -> bool:
	return _back_btn == null or _back_btn.disabled


func set_tutorial_warning_text(msg: String) -> void:
	if _info_stats != null:
		_info_stats.text = msg


func refresh_detail_panel(tutorial_blocking: bool) -> void:
	_tutorial_blocking = tutorial_blocking
	if _info_title == null or _state == null:
		return
	var nd: Dictionary = _state.get_node_dict(selected_node_id)
	if nd.is_empty():
		return
	var lvl: int = _state.get_node_level(selected_node_id)
	var max_lvl: int = int(nd["max_level"])
	var cost: int = _state.get_node_cost(selected_node_id)
	var unlocked: bool = _state.is_node_unlocked(selected_node_id)

	_info_title.text = "%s %s  (Nv. %d / %d)" % [String(nd["icon"]), String(nd["name"]), lvl, max_lvl]
	_info_desc.text = String(nd["short_desc"])

	var tut_locked_other: bool = (tutorial_blocking and int(_state.map_tutorial_stage) == 1 and selected_node_id != &"toque_continuo")
	if tut_locked_other:
		_info_stats.text = "✨ Tutorial: ¡Primero compra 👆 Toque Continuo!"
		_buy_btn.text = "TUTORIAL: COMPRA TOQUE CONTINUO"
		_buy_btn.disabled = true
	elif lvl >= max_lvl:
		_info_stats.text = "Estado: ¡MÁXIMO ALCANZADO!"
		_buy_btn.text = "NIVEL MÁXIMO"
		_buy_btn.disabled = true
	elif not unlocked:
		var p_id: StringName = nd.get("parent_id", &"") as StringName
		var p_nd: Dictionary = _state.get_node_dict(p_id)
		var p_name: String = String(p_nd["name"]) if not p_nd.is_empty() else "Anterior"
		_info_stats.text = "Bloqueado — Desbloquea primero: %s" % p_name
		_buy_btn.text = "BLOQUEADO"
		_buy_btn.disabled = true
	else:
		_info_stats.text = "Siguiente nivel cuesta: %d✦ Esencia  (Tienes: %d✦)" % [cost, int(_state.essence_gold)]
		_buy_btn.text = "MEJORAR (%d✦)" % cost
		_buy_btn.disabled = int(_state.essence_gold) < cost

	if _back_btn != null:
		var block_back: bool = (tutorial_blocking and int(_state.get_node_level(&"toque_continuo")) == 0)
		_back_btn.disabled = block_back


func refresh_tutorial_banner(is_tree_view: bool, tutorial_blocking: bool) -> void:
	_tutorial_blocking = tutorial_blocking
	if _tut_banner == null:
		return
	if is_tree_view and tutorial_blocking:
		_tut_banner.visible = true
		_tut_title_lbl.text = DialogueBank.strip_tags(DialogueBank.get_trixie_tutorial("tree_mandatory_title"))
		_tut_body_lbl.text = DialogueBank.strip_tags(DialogueBank.get_trixie_tutorial("tree_mandatory_body"))
	else:
		_tut_banner.visible = false


func _on_tree_gui_input(event: InputEvent) -> void:
	if _state == null:
		return
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var hit: StringName = _hit_test_tree_node(mm.position)
		if hit != _hovered_node_id:
			_hovered_node_id = hit
			if hit != &"":
				selected_node_id = hit
				refresh_detail_panel(_tutorial_blocking)
			queue_tree_redraw()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var hit: StringName = _hit_test_tree_node(mb.position)
			if hit != &"":
				selected_node_id = hit
				node_purchase_requested.emit(hit)
				refresh_detail_panel(_tutorial_blocking)
				queue_tree_redraw()


func _hit_test_tree_node(pos: Vector2) -> StringName:
	for nd: Dictionary in _state.tree_nodes:
		if pos.distance_to(nd["pos"] as Vector2) <= 46.0:
			return nd["id"] as StringName
	return &""


func _draw_upgrade_tree() -> void:
	if _tree_canvas == null or _state == null:
		return
	var font: Font = ThemeDB.fallback_font
	for gx: int in range(80, 1920, 120):
		_tree_canvas.draw_line(Vector2(gx, 76), Vector2(gx, 882), Color(1, 1, 1, 0.03), 1.0)
	for gy: int in range(120, 880, 120):
		_tree_canvas.draw_line(Vector2(0, gy), Vector2(1920, gy), Color(1, 1, 1, 0.03), 1.0)

	for nd: Dictionary in _state.tree_nodes:
		var nid: StringName = nd["id"] as StringName
		var p_id: StringName = nd.get("parent_id", &"") as StringName
		if p_id == &"":
			continue
		var p_nd: Dictionary = _state.get_node_dict(p_id)
		if p_nd.is_empty():
			continue
		var p_pos: Vector2 = p_nd["pos"] as Vector2
		var n_pos: Vector2 = nd["pos"] as Vector2
		var col: Color = nd["color"] as Color
		var unlocked: bool = _state.is_node_unlocked(nid)
		var owned: bool = _state.get_node_level(nid) > 0
		var line_col: Color = col if owned else (Color(col.r, col.g, col.b, 0.45) if unlocked else Color(0.28, 0.24, 0.34, 0.45))
		_tree_canvas.draw_line(p_pos, n_pos, line_col, 5.5 if owned else (3.5 if unlocked else 2.0), true)

	for nd: Dictionary in _state.tree_nodes:
		var nid: StringName = nd["id"] as StringName
		var pos: Vector2 = nd["pos"] as Vector2
		var col: Color = nd["color"] as Color
		var lvl: int = _state.get_node_level(nid)
		var max_lvl: int = int(nd["max_level"])
		var unlocked: bool = _state.is_node_unlocked(nid)
		var affordable: bool = _state.can_buy_node(nid)
		var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)

		if affordable:
			_tree_canvas.draw_circle(pos, 47.0 + pulse * 5.0, Color(1.0, 0.88, 0.36, 0.22 + pulse * 0.16))
		if nid == selected_node_id or nid == _hovered_node_id:
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
		var sub_txt: String = "MAX" if lvl >= max_lvl else ("%d/%d · %d✦" % [lvl, max_lvl, int(_state.get_node_cost(nid))] if unlocked else "🔒")
		var sub_col: Color = Color(1.0, 0.88, 0.36) if affordable else (Color(0.55, 0.96, 0.68) if lvl >= max_lvl else Color(0.75, 0.72, 0.84))
		_tree_canvas.draw_string(font, pos + Vector2(-65, 74), sub_txt, HORIZONTAL_ALIGNMENT_CENTER, 130, 13, sub_col)

		if _tutorial_blocking and nid == &"toque_continuo" and lvl == 0:
			var tpulse: float = 0.5 + 0.5 * sin(_time * 8.0)
			_tree_canvas.draw_arc(pos, 58.0 + tpulse * 7.0, 0.0, TAU, 36, Color(1.0, 0.88, 0.32), 4.5)
			_tree_canvas.draw_string(font, pos + Vector2(-115, -64), "👇 ¡SUBE ESTA HABILIDAD!", HORIZONTAL_ALIGNMENT_CENTER, 230, 17, Color(1.0, 0.90, 0.36))
