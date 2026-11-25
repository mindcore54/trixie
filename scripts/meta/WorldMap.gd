class_name WorldMap
extends Control
## Coordinador del hub metajuego: barra superior, modales globales y cambio
## entre las sub-escenas editables MapTab, SkillTreeTab y GalleryTab.

enum MapView {
	MAP,
	UPGRADE_TREE,
	GALLERY,
}

const GameStateScript: GDScript = preload("res://scripts/autoloads/GameState.gd")

@onready var _map_tab: MapTab = $MapTab
@onready var _tree_tab: SkillTreeTab = $SkillTreeTab
@onready var _gallery_tab: GalleryTab = $GalleryTab

@onready var _top_essence_lbl: Label = $TopBar/Pad/HBox/EssenceLabel
@onready var _top_progress_lbl: Label = $TopBar/Pad/HBox/ProgressLabel
@onready var _tree_btn: Button = $TopBar/Pad/HBox/TreeButton
@onready var _gallery_btn: Button = $TopBar/Pad/HBox/GalleryButton
@onready var _pause_btn: Button = $TopBar/Pad/HBox/PauseButton
@onready var _tree_badge_panel: PanelContainer = $TreeBadge

@onready var _pause_overlay: ColorRect = $PauseOverlay
@onready var _resume_btn: Button = $PauseOverlay/Center/Panel/Pad/VBox/ResumeButton
@onready var _restart_btn: Button = $PauseOverlay/Center/Panel/Pad/VBox/RestartButton
@onready var _menu_btn: Button = $PauseOverlay/Center/Panel/Pad/VBox/MainMenuButton

@onready var _victory_overlay: ColorRect = $VictoryOverlay
@onready var _victory_continue_btn: Button = $VictoryOverlay/Center/Panel/Pad/VBox/ContinueButton

var _local_state: Node = null
var view_mode: MapView = MapView.MAP
var _time: float = 0.0
var _transitioning: bool = false


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

	# Garantiza Esencia mínima para Toque Continuo en el tutorial obligatorio
	if st.should_run_map_tutorial():
		var hold_cost: int = st.get_node_cost(&"toque_continuo")
		if int(st.essence_gold) < hold_cost:
			st.grant_essence(hold_cost - int(st.essence_gold))
		if int(st.map_tutorial_stage) >= 2:
			st.map_tutorial_stage = 0

	var initial_node: StringName = st.get_recommended_next_map_node_id()
	if initial_node == &"" or not st.is_map_node_unlocked(initial_node):
		initial_node = &"castillo"

	_map_tab.configure(st, _tree_btn)
	_map_tab.select_node(initial_node)
	_tree_tab.configure(st)
	_gallery_tab.configure(st)

	_connect_signals()
	_switch_view(MapView.MAP)

	var fader: Node = _fader()
	if fader != null and bool(fader.call("is_black")):
		fader.call("fade_in", 0.45)


func _connect_signals() -> void:
	_tree_btn.pressed.connect(func() -> void:
		_play_pentatonic(3, -3.0)
		_switch_view(MapView.UPGRADE_TREE)
	)
	_gallery_btn.pressed.connect(func() -> void:
		_play_pentatonic(4, -3.0)
		_switch_view(MapView.GALLERY)
	)
	_pause_btn.pressed.connect(func() -> void: _pause_overlay.visible = true)

	_resume_btn.pressed.connect(func() -> void: _pause_overlay.visible = false)
	_restart_btn.pressed.connect(func() -> void:
		_pause_overlay.visible = false
		_state().reset_run()
		_change_scene("res://scenes/main/Main.tscn", 0.4)
	)
	_menu_btn.pressed.connect(func() -> void:
		_pause_overlay.visible = false
		_change_scene("res://scenes/ui/MainMenu.tscn", 0.4)
	)
	_victory_continue_btn.pressed.connect(func() -> void:
		_victory_overlay.visible = false
		_switch_view(MapView.GALLERY)
	)

	_map_tab.travel_requested.connect(_travel_to_node)
	_map_tab.sfx_requested.connect(_play_pentatonic)

	_tree_tab.node_purchase_requested.connect(_on_tree_node_purchase_requested)
	_tree_tab.back_to_map_requested.connect(_on_back_to_map_pressed)

	_gallery_tab.back_to_map_requested.connect(_on_back_to_map_pressed)
	_gallery_tab.sfx_requested.connect(_play_pentatonic)
	_gallery_tab.essence_changed.connect(_refresh_top_and_tutorials)


func _process(delta: float) -> void:
	_time += delta
	_refresh_top_and_tutorials()
	_map_tab.step_visuals(delta, _time, view_mode == MapView.MAP)
	_tree_tab.step_visuals(_time, view_mode == MapView.UPGRADE_TREE)
	_gallery_tab.step_visuals(_time, view_mode == MapView.GALLERY)


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
				if _gallery_tab.is_lightbox_open():
					_gallery_tab.close_lightbox()
				elif _victory_overlay.visible:
					_victory_overlay.visible = false
				else:
					_pause_overlay.visible = not _pause_overlay.visible
				get_viewport().set_input_as_handled()


func _is_map_tutorial_blocking() -> bool:
	return _state().should_run_map_tutorial()


func _switch_view(mode: MapView) -> void:
	var st: Node = _state()
	if _is_map_tutorial_blocking():
		if mode == MapView.GALLERY:
			return
		if mode == MapView.MAP and int(st.map_tutorial_stage) == 1 and int(st.get_node_level(&"toque_continuo")) == 0:
			return
		if mode == MapView.UPGRADE_TREE and int(st.map_tutorial_stage) == 0:
			st.map_tutorial_stage = 1
			_tree_tab.select_node(&"toque_continuo")

	view_mode = mode
	_map_tab.visible = (mode == MapView.MAP)
	_tree_tab.visible = (mode == MapView.UPGRADE_TREE)
	_gallery_tab.visible = (mode == MapView.GALLERY)
	if mode != MapView.GALLERY:
		_gallery_tab.close_lightbox()

	var tut_block: bool = _is_map_tutorial_blocking()
	if mode == MapView.MAP:
		_map_tab.refresh_detail_panel(tut_block)
	elif mode == MapView.UPGRADE_TREE:
		_tree_tab.refresh_detail_panel(tut_block)
		_tree_tab.queue_tree_redraw()
	elif mode == MapView.GALLERY:
		_gallery_tab.refresh_gallery()

	_refresh_top_and_tutorials()


func _on_back_to_map_pressed() -> void:
	_play_pentatonic(2, -3.0)
	_switch_view(MapView.MAP)


func _on_tree_node_purchase_requested(node_id: StringName) -> void:
	var st: Node = _state()
	var blocked_other: bool = _is_map_tutorial_blocking() and int(st.map_tutorial_stage) == 1 and node_id != &"toque_continuo"
	if not buy_incremental_node(node_id) and not blocked_other:
		_play_pentatonic(0, -8.0)


func buy_incremental_node(node_id: StringName) -> bool:
	var st: Node = _state()
	if _is_map_tutorial_blocking() and int(st.map_tutorial_stage) == 1 and node_id != &"toque_continuo":
		_play_pentatonic(0, -6.0)
		_tree_tab.set_tutorial_warning_text("✨ Tutorial: ¡Primero mejora 👆 Toque Continuo para desbloquear el resto!")
		return false

	if not st.buy_incremental_node(node_id):
		return false

	_play_pentatonic(clampi(int(st.get_node_level(node_id)) + 2, 0, 7), -1.0)

	if node_id == &"toque_continuo" and not bool(st.map_tutorial_done):
		st.map_tutorial_stage = 2
		st.map_tutorial_done = true
		_play_pentatonic(6, 0.0)

	if node_id == &"elixir_supremo" and not bool(st.victory_banner_shown):
		st.victory_banner_shown = true
		_victory_overlay.visible = true

	_tree_tab.refresh_detail_panel(_is_map_tutorial_blocking())
	_refresh_top_and_tutorials()
	_tree_tab.queue_tree_redraw()
	return true


func _travel_to_node(node_id: StringName) -> bool:
	if _transitioning or _is_map_tutorial_blocking():
		return false
	var st: Node = _state()
	if not st.is_map_node_unlocked(node_id):
		return false
	_transitioning = true
	st.active_map_node_id = node_id
	_play_pentatonic(5, 0.0)
	_change_scene("res://scenes/main/Main.tscn", 0.55)
	return true


func _change_scene(scene_path: String, fade_sec: float) -> void:
	var fader: Node = _fader()
	if fader != null and not bool(fader.call("is_busy")):
		fader.call("fade_to_scene", scene_path, fade_sec, fade_sec)
	elif get_tree() != null and get_tree().current_scene == self:
		get_tree().change_scene_to_file(scene_path)


func _refresh_top_and_tutorials() -> void:
	var st: Node = _state()
	if _top_essence_lbl == null:
		return

	_top_essence_lbl.text = "✦ %d" % int(st.essence_gold)
	var lyra_tag: String = "  ·  🌿 Lyra reclutada" if bool(st.recruited_witches.get(&"lyra", false)) else ""
	_top_progress_lbl.text = "🗺 Mapa de Viaje · Paradas: %d / %d%s" % [
		int(st.count_completed_map_nodes()),
		st.map_nodes.size(),
		lyra_tag,
	]

	var tut_block: bool = _is_map_tutorial_blocking()
	_gallery_btn.disabled = tut_block

	var affordable: int = int(st.count_affordable_nodes())
	_tree_badge_panel.visible = (affordable > 0) and (view_mode != MapView.UPGRADE_TREE)
	if _tree_badge_panel.visible:
		_tree_badge_panel.position = _tree_btn.global_position + Vector2(_tree_btn.size.x - 14.0, -4.0)

	_map_tab.refresh_tutorial_banner(view_mode == MapView.MAP, tut_block)
	_tree_tab.refresh_tutorial_banner(view_mode == MapView.UPGRADE_TREE, tut_block)


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


## Verifica tutorial obligatorio post-Parada 1, compra de Toque Continuo, Galería y Parada 2.
func run_worldmap_smoke_step() -> Dictionary:
	var st: Node = _state()
	var travel_blocked_initially: bool = _map_tab.is_travel_disabled() and _gallery_btn.disabled and _map_tab.is_tutorial_banner_visible()
	_switch_view(MapView.UPGRADE_TREE)
	var entered_tree_ok: bool = (view_mode == MapView.UPGRADE_TREE and int(st.map_tutorial_stage) == 1 and _tree_tab.is_back_disabled())
	var other_buy_blocked_ok: bool = not buy_incremental_node(&"hervor_creciente")
	var bought_hold_ok: bool = buy_incremental_node(&"toque_continuo") and bool(st.hold_auto_hit_unlocked) and bool(st.map_tutorial_done)
	var back_unlocked_ok: bool = not _tree_tab.is_back_disabled()

	_switch_view(MapView.GALLERY)
	var gallery_opened_ok: bool = (view_mode == MapView.GALLERY and not _gallery_btn.disabled)

	_switch_view(MapView.MAP)
	_map_tab.select_node(&"pueblo")
	_map_tab.refresh_detail_panel(_is_map_tutorial_blocking())
	var pueblo_travel_ready_ok: bool = (not _map_tab.is_travel_disabled() and bool(st.is_map_node_unlocked(&"pueblo")))

	st.grant_essence(120)
	var bought_strength_ok: bool = buy_incremental_node(&"fuerza_molienda") and int(st.click_damage) == 2
	var bought_boil_ok: bool = buy_incremental_node(&"hervor_creciente") and int(st.spawn_cap) == 8
	var pat_before: float = float(st.customer_patience_sec)
	var bought_patience_ok: bool = buy_incremental_node(&"reloj_arena") and is_equal_approx(float(st.customer_patience_sec), pat_before + 4.0)

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
