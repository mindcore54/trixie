class_name MapTab
extends Control
## Pestaña editable del Mapa de Viaje: lienzo cartográfico, selección de paradas,
## tarjeta inferior de detalle y banner contextual de tutorial.

signal travel_requested(node_id: StringName)
signal sfx_requested(step_index: int, vol_db: float)

const VIEWPORT_SIZE: Vector2 = Vector2(1920.0, 1080.0)
const MAP_NODE_RADIUS: float = 48.0

@onready var _map_canvas: Control = $MapCanvas
@onready var _tut_banner: PanelContainer = $TutorialBanner
@onready var _tut_title_lbl: Label = $TutorialBanner/Pad/VBox/TitleLabel
@onready var _tut_body_lbl: Label = $TutorialBanner/Pad/VBox/BodyLabel
@onready var _node_title_lbl: Label = $BottomStopCard/Pad/HBox/InfoCol/NodeTitleLabel
@onready var _node_meta_lbl: Label = $BottomStopCard/Pad/HBox/InfoCol/NodeMetaLabel
@onready var _node_desc_lbl: Label = $BottomStopCard/Pad/HBox/InfoCol/NodeDescLabel
@onready var _travel_btn: Button = $BottomStopCard/Pad/HBox/TravelButton

var _state: Node = null
var _tree_btn_ref: Control = null
var _time: float = 0.0
var _sparkles: Array[Dictionary] = []
var _tutorial_blocking: bool = false

var selected_node_id: StringName = &"castillo"
var _hovered_node_id: StringName = &""
var _last_clicked_node_id: StringName = &""
var _last_click_time: float = -10.0


func _ready() -> void:
	for i: int in range(24):
		_sparkles.append({
			"x": randf_range(0.0, VIEWPORT_SIZE.x),
			"y": randf_range(80.0, VIEWPORT_SIZE.y),
			"r": randf_range(1.5, 3.6),
			"spd": randf_range(10.0, 26.0),
			"phase": randf_range(0.0, TAU),
		})
	if _map_canvas != null:
		_map_canvas.draw.connect(_draw_world_map)
		_map_canvas.gui_input.connect(_on_map_gui_input)
	if _travel_btn != null:
		_travel_btn.pressed.connect(func() -> void: travel_requested.emit(selected_node_id))


func configure(state: Node, tree_btn_ref: Control) -> void:
	_state = state
	_tree_btn_ref = tree_btn_ref


func select_node(node_id: StringName) -> void:
	selected_node_id = node_id
	if _map_canvas != null:
		_map_canvas.queue_redraw()


func step_visuals(delta: float, time_sec: float, is_active: bool) -> void:
	_time = time_sec
	for s: Dictionary in _sparkles:
		s["y"] = float(s["y"]) - float(s["spd"]) * delta
		if float(s["y"]) < 76.0:
			s["y"] = VIEWPORT_SIZE.y + 10.0
			s["x"] = randf_range(0.0, VIEWPORT_SIZE.x)
	if is_active and _map_canvas != null:
		_map_canvas.queue_redraw()


func is_travel_disabled() -> bool:
	return _travel_btn == null or _travel_btn.disabled


func is_tutorial_banner_visible() -> bool:
	return _tut_banner != null and _tut_banner.visible


func refresh_detail_panel(tutorial_blocking: bool) -> void:
	_tutorial_blocking = tutorial_blocking
	if _node_title_lbl == null or _state == null:
		return
	var mn: Dictionary = _state.get_map_node(selected_node_id)
	if mn.is_empty():
		return

	var unlocked: bool = _state.is_map_node_unlocked(selected_node_id)
	var completed: bool = _state.is_map_node_completed(selected_node_id)
	var status_txt: String = "✅ Completada" if completed else ("✨ Disponible" if unlocked else "🔒 Bloqueada")

	var cust_names: Array[String] = []
	for cv: Variant in (mn.get("customers", []) as Array):
		cust_names.append(String(cv).capitalize())

	_node_title_lbl.text = "%s %s — %s" % [String(mn["icon"]), String(mn["name"]), String(mn["subtitle"])]
	_node_meta_lbl.text = "%s  ·  %s  ·  Clientas: %s  ·  Esencia x%.2f" % [
		status_txt,
		String(mn.get("route_tag", "")),
		", ".join(cust_names),
		float(mn.get("essence_mult", 1.0)),
	]
	_node_desc_lbl.text = String(mn.get("description", ""))

	if tutorial_blocking:
		_travel_btn.disabled = true
		_travel_btn.text = "🌿 PRIMERO ENTRA AL ÁRBOL ☝"
	elif not unlocked:
		_travel_btn.disabled = true
		_travel_btn.text = "🔒 PARADA BLOQUEADA"
	else:
		_travel_btn.disabled = false
		_travel_btn.text = "🔥 REJUGAR PARADA" if completed else "🔥 VIAJAR A ESTA PARADA"


func refresh_tutorial_banner(is_map_view: bool, tutorial_blocking: bool) -> void:
	_tutorial_blocking = tutorial_blocking
	if _tut_banner == null or _state == null:
		return
	if is_map_view and tutorial_blocking:
		_tut_banner.visible = true
		_tut_title_lbl.text = DialogueBank.strip_tags(DialogueBank.get_trixie_tutorial("map_intro_title"))
		_tut_body_lbl.text = DialogueBank.strip_tags(DialogueBank.get_trixie_tutorial("map_intro_body"))
	elif is_map_view and bool(_state.map_tutorial_done) and int(_state.count_completed_map_nodes()) <= 1 and not bool(_state.is_map_node_completed(&"pueblo")):
		_tut_banner.visible = true
		_tut_title_lbl.text = DialogueBank.strip_tags(DialogueBank.get_trixie_tutorial("map_stop2_title"))
		_tut_body_lbl.text = DialogueBank.strip_tags(DialogueBank.get_trixie_tutorial("map_stop2_body"))
	else:
		_tut_banner.visible = false


func _on_map_gui_input(event: InputEvent) -> void:
	if _state == null:
		return
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
				selected_node_id = hit
				refresh_detail_panel(_tutorial_blocking)
				sfx_requested.emit(3 if _state.is_map_node_unlocked(hit) else 0, -5.0)
				if not _tutorial_blocking and _state.is_map_node_unlocked(hit):
					if hit == _last_clicked_node_id and (_time - _last_click_time) <= 0.42:
						travel_requested.emit(selected_node_id)
						return
					_last_clicked_node_id = hit
					_last_click_time = _time
				_map_canvas.queue_redraw()


func _hit_test_map_node(pos: Vector2) -> StringName:
	for mn: Dictionary in _state.map_nodes:
		if pos.distance_to(mn["pos"] as Vector2) <= MAP_NODE_RADIUS + 14.0:
			return mn["id"] as StringName
	return &""


func _draw_world_map() -> void:
	if _map_canvas == null or _state == null:
		return
	var font: Font = ThemeDB.fallback_font

	# Fondo cartográfico nocturno del mapa
	_map_canvas.draw_rect(Rect2(0, 76, 1920, 760), Color(0.08, 0.05, 0.14))
	_map_canvas.draw_circle(Vector2(520, 480), 280.0, Color(0.24, 0.14, 0.36, 0.24))
	_map_canvas.draw_circle(Vector2(920, 500), 310.0, Color(0.14, 0.10, 0.26, 0.30))
	_map_canvas.draw_circle(Vector2(1500, 490), 300.0, Color(0.10, 0.22, 0.28, 0.24))

	# Cuadrícula y rosa de los vientos
	for gx: int in range(120, 1920, 180):
		_map_canvas.draw_line(Vector2(gx, 76), Vector2(gx, 836), Color(1, 1, 1, 0.03), 1.0)
	for gy: int in range(160, 820, 160):
		_map_canvas.draw_line(Vector2(0, gy), Vector2(1920, gy), Color(1, 1, 1, 0.03), 1.0)
	_map_canvas.draw_arc(Vector2(1740, 220), 64.0, 0.0, TAU, 36, Color(0.86, 0.72, 0.38, 0.16), 2.0)
	_map_canvas.draw_string(font, Vector2(1726, 178), "N", HORIZONTAL_ALIGNMENT_CENTER, 28, 18, Color(0.92, 0.80, 0.44, 0.35))

	for s: Dictionary in _sparkles:
		var a: float = 0.14 + 0.24 * absf(sin(_time * 2.0 + float(s["phase"])))
		_map_canvas.draw_circle(Vector2(float(s["x"]), float(s["y"])), float(s["r"]), Color(1.0, 0.88, 0.48, a))

	# Rutas entre paradas
	for mn: Dictionary in _state.map_nodes:
		var p0: Vector2 = mn["pos"] as Vector2
		var from_id: StringName = mn["id"] as StringName
		var from_done: bool = _state.is_map_node_completed(from_id)
		var nexts: Array = mn.get("next_ids", []) as Array
		for nv: Variant in nexts:
			var nid: StringName = nv as StringName
			var target: Dictionary = _state.get_map_node(nid)
			if target.is_empty():
				continue
			var p1: Vector2 = target["pos"] as Vector2
			var to_unl: bool = _state.is_map_node_unlocked(nid)
			var edge_col: Color = Color(1.0, 0.84, 0.38, 0.75) if (from_done and to_unl) else Color(0.35, 0.30, 0.46, 0.45)
			var mid: Vector2 = (p0 + p1) * 0.5 + Vector2(0.0, -26.0 if p1.y < p0.y else (26.0 if p1.y > p0.y else -16.0))
			_map_canvas.draw_polyline(PackedVector2Array([p0, mid, p1]), edge_col, 5.0 if from_done else 3.0, true)

	# Nodos del mapa
	for mn: Dictionary in _state.map_nodes:
		var mid: StringName = mn["id"] as StringName
		var pos: Vector2 = mn["pos"] as Vector2
		var col: Color = mn["color"] as Color
		var unlocked: bool = _state.is_map_node_unlocked(mid)
		var completed: bool = _state.is_map_node_completed(mid)
		var selected: bool = (mid == selected_node_id)
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

	# Marcador de Trixie sobre su última parada visitada
	var last_nd: Dictionary = _state.get_map_node(_state.last_visited_map_node_id)
	if not last_nd.is_empty():
		var tp: Vector2 = (last_nd["pos"] as Vector2) + Vector2(0.0, -MAP_NODE_RADIUS - 34.0 + sin(_time * 3.0) * 4.0)
		var portrait_tex: Texture2D = CharacterArt.get_trixie_expression("confiada", "hud")
		if portrait_tex != null:
			_map_canvas.draw_circle(tp, 28.0, Color(0.16, 0.08, 0.22))
			_map_canvas.draw_texture_rect(portrait_tex, Rect2(tp - Vector2(24, 24), Vector2(48, 48)), false)
			_map_canvas.draw_arc(tp, 28.0, 0.0, TAU, 24, Color(1.0, 0.86, 0.36), 3.0)

	# Flecha del tutorial señalando al botón Árbol de Habilidades en TopBar
	if _tutorial_blocking and int(_state.map_tutorial_stage) == 0 and _tree_btn_ref != null:
		var btn_center: Vector2 = _tree_btn_ref.global_position + Vector2(_tree_btn_ref.size.x * 0.5, _tree_btn_ref.size.y)
		var bounce: float = absf(sin(_time * 5.0)) * 12.0
		var arrow_tip: Vector2 = btn_center + Vector2(0.0, 14.0 + bounce)
		_map_canvas.draw_colored_polygon(PackedVector2Array([
			arrow_tip,
			arrow_tip + Vector2(-16, 24),
			arrow_tip + Vector2(16, 24),
		]), Color(1.0, 0.88, 0.32))
		_map_canvas.draw_string(font, arrow_tip + Vector2(-140, 52), "☝ ¡ENTRA AQUÍ!", HORIZONTAL_ALIGNMENT_CENTER, 280, 20, Color(1.0, 0.90, 0.36))
