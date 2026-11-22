class_name MainGame
extends Node2D
## Tactical 2D Alchemy Incremental Prototype (Zero Autoclicker).
## Mechanics:
## - Left-click an orb to extract it; hold & drag across matching colors (plus Stars/Bombs) to chain!
## - Right-click an orb to purge unwanted colors safely without hurting the potion tube or combo.
## - Active Customer sets a live Color Chemistry trio: LIKED (+tube, 2x essence, +Frenzy),
##   NEUTRAL (+small tube, 1x essence), DISLIKED (-18% tube, resets combo).
## - Frenzy transmutes all DISLIKED orbs into LIKED orbs and doubles output for a burst.

enum ViewMode {
	CAULDRON,
	UPGRADE_TREE,
	GALLERY,
}

enum BubbleKind {
	RED,
	BLUE,
	GREEN,
	GOLD,
	BOMB,
}

const VIEWPORT_SIZE: Vector2 = Vector2(1920.0, 1080.0)
const CAULDRON_CENTER: Vector2 = Vector2(880.0, 565.0)
const CAULDRON_RADIUS: float = 335.0
const ORB_RADIUS: float = 34.0
const BASE_ROUND_DURATION: float = 25.0
const CAULDRON_TEX_PATH: String = "res://assets/props/stations/station_cauldron.png"

const TUBE_RECT: Rect2 = Rect2(1312.0, 265.0, 54.0, 445.0)
const AFFINITY_THRESHOLDS: Array[int] = [3, 7, 12]

const CUSTOMER_CHEMISTRY: Dictionary = {
	&"sylvi": {"liked": BubbleKind.RED, "neutral": BubbleKind.GREEN, "disliked": BubbleKind.BLUE},
	&"velvet": {"liked": BubbleKind.BLUE, "neutral": BubbleKind.RED, "disliked": BubbleKind.GREEN},
	&"seraphina": {"liked": BubbleKind.GREEN, "neutral": BubbleKind.BLUE, "disliked": BubbleKind.RED},
	&"mona": {"liked": BubbleKind.BLUE, "neutral": BubbleKind.GREEN, "disliked": BubbleKind.RED},
	&"roxy": {"liked": BubbleKind.RED, "neutral": BubbleKind.BLUE, "disliked": BubbleKind.GREEN},
}

const GALLERY_TITLES: Dictionary = {
	&"trixie": ["Chispas de Apertura", "Sobrecalentamiento Picante", "Maestra del Aquelarre"],
	&"sylvi": ["Brindis del Bosque", "Calor bajo las Hojas", "Fiesta Privada con Trixie"],
	&"velvet": ["Mirada Ejecutiva", "Prueba Directa del Cucharón", "Contrato Carmesí"],
	&"seraphina": ["Inspección de Pureza", "Armadura Entreabierta", "Confesión Secreta de la Orden"],
	&"mona": ["Rivalidad en el Caldero", "Sonrojo Tsundere", "Noche de Alquimia Compartida"],
	&"roxy": ["Aullido de Luna Llena", "Cazadora Cautivada", "Frasco Reservado"],
}

# Catalogs
var witches: Array[WitchCharacterData] = []
var customers_catalog: Array[CustomerArchetypeData] = []
var tree_nodes: Array[Dictionary] = []
var _node_by_id: Dictionary = {}

# Economy & progression
var view_mode: ViewMode = ViewMode.CAULDRON
var essence_gold: int = 0
var total_essence_earned: int = 0
var round_number: int = 1
var round_duration: float = BASE_ROUND_DURATION
var round_time_left: float = BASE_ROUND_DURATION
var round_ending: bool = false
var _round_end_timer: float = 0.0
var _round_essence_gained: int = 0
var orders_completed: int = 0
var victory_achieved: bool = false
var _victory_banner_shown: bool = false

var node_levels: Dictionary = {
	&"root_cauldron": 1,
}

# Derived tactical stats
var spawn_cap: int = 6
var spawn_interval: float = 1.15
var chain_link_range: float = 225.0
var chain_bonus_per_lvl: float = 0.0
var aroma_essence_mult: float = 1.0
var aroma_tube_bonus: float = 0.0
var purge_recycle_lvl: int = 0
var frenzy_gain_mult: float = 1.0
var frenzy_duration_sec: float = 5.0
var chain_spark_jumps: int = 0
var bomb_chance: float = 0.0
var star_chance: float = 0.0
var fam_michi_lvl: int = 0
var fam_imp_lvl: int = 0
var fam_bat_lvl: int = 0
var order_bonus_mult: float = 1.0
var vip_tier: int = 0
var crit_potion_lvl: int = 0

# Live cauldron runtime state
var _time: float = 0.0
var _spawn_accum: float = 0.0
var _michi_timer: float = 1.2
var _imp_timer: float = 1.6
var _bat_timer: float = 1.8
var _combo: int = 0
var _combo_timer: float = 0.0
var _frenzy_charge: float = 0.0
var _frenzy_timer: float = 0.0
var _cauldron_shake: float = 0.0
var _tube_flash_timer: float = 0.0
var _tube_flash_positive: bool = true

var _mouse_pos: Vector2 = CAULDRON_CENTER
var _prev_mouse_pos: Vector2 = CAULDRON_CENTER
var _hovered_orb_idx: int = -1
var _is_dragging: bool = false
var _drag_chain: Array[int] = []
var _drag_base_color: int = -1

var _orbs: Array[Dictionary] = []
var _lightning_arcs: Array[Dictionary] = []
var _shockwaves: Array[Dictionary] = []
var _popups: Array[Dictionary] = []
var _ambient_steam: Array[Dictionary] = []

# Left (Trixie) & Right (Customer) state
var _trixie_emotion: String = "normal"
var _trixie_emotion_timer: float = 0.0
var _trixie_line: String = "Clic o arrastra orbes del color AFÍN. Clic Der purga ❌."

var _active_customer: CustomerArchetypeData
var _potion_tube_pct: float = 0.0
var _customer_order_reward: int = 24
var _customer_line: String = "¡Necesito algo bien fuerte para esta noche!"
var _customer_spicy_mode: bool = false
var _customer_flash_timer: float = 0.0
var _customer_slide_t: float = 1.0

var customer_affinity_pts: Dictionary = {}
var _toast_timer: float = 0.0

# UI nodes
var camera: Camera2D
var _cauldron_tex: Texture2D
var _ui_layer: CanvasLayer

var _top_essence_lbl: Label
var _top_timer_lbl: Label
var _top_round_lbl: Label
var _tab_cauldron_btn: Button
var _tab_tree_btn: Button
var _tab_gallery_btn: Button
var _tree_badge_panel: PanelContainer

var _cauldron_hud_root: Control
var _trixie_speech_lbl: Label
var _frenzy_bar: ProgressBar
var _frenzy_btn: Button
var _cust_name_lbl: Label
var _cust_aff_lbl: Label
var _cust_liked_lbl: Label
var _cust_neutral_lbl: Label
var _cust_disliked_lbl: Label
var _cust_speech_lbl: Label
var _end_round_btn: Button
var _toast_lbl: Label

var _tree_view_root: Control
var _tree_canvas: Control
var _tree_hovered_id: StringName = &""
var _tree_selected_id: StringName = &"aroma_concentrado"
var _tree_info_title: Label
var _tree_info_desc: Label
var _tree_info_stats: Label
var _tree_buy_btn: Button
var _tree_boil_btn: Button

var _gallery_view_root: Control
var _gallery_selected_char_id: StringName = &"sylvi"
var _gallery_char_buttons: Dictionary = {}
var _gallery_portrait_canvas: Control
var _gallery_title_lbl: Label
var _gallery_aff_lbl: Label
var _gallery_lines_lbl: Label
var _gallery_gift_btn: Button
var _gallery_cards_box: HBoxContainer
var _lightbox_overlay: ColorRect
var _lightbox_title_lbl: Label
var _lightbox_scene_idx: int = 0
var _lightbox_canvas: Control
var _lightbox_caption_lbl: Label

var _pause_overlay: ColorRect
var _victory_overlay: ColorRect


func _ready() -> void:
	randomize()
	witches = GameCatalog.get_witches()
	customers_catalog = GameCatalog.get_customers()
	tree_nodes = GameCatalog.get_incremental_nodes()
	for nd: Dictionary in tree_nodes:
		_node_by_id[nd["id"] as StringName] = nd

	for c: CustomerArchetypeData in customers_catalog:
		customer_affinity_pts[c.customer_id] = 0
	customer_affinity_pts[&"trixie"] = 0

	_cauldron_tex = load(CAULDRON_TEX_PATH) as Texture2D

	camera = Camera2D.new()
	camera.position = VIEWPORT_SIZE * 0.5
	add_child(camera)
	var audio: Node = _audio()
	if audio != null:
		audio.call("register_camera", camera)

	for i: int in range(20):
		_ambient_steam.append({
			"x": randf_range(-CAULDRON_RADIUS * 0.8, CAULDRON_RADIUS * 0.8),
			"y": randf_range(-CAULDRON_RADIUS * 0.6, CAULDRON_RADIUS * 0.6),
			"r": randf_range(4.0, 12.0),
			"spd": randf_range(16.0, 34.0),
			"phase": randf_range(0.0, TAU),
		})

	_recalc_stats()
	_build_ui()
	_pick_next_customer(true)
	_start_round(1)

	var fader: Node = _fader()
	if fader != null and bool(fader.call("is_black")):
		fader.call("fade_in", 0.45)

	if OS.get_cmdline_user_args().has("--smoke-test"):
		call_deferred("_run_cmdline_smoke_and_quit")


func _run_cmdline_smoke_and_quit() -> void:
	await get_tree().process_frame
	var res: Dictionary = run_incremental_smoke_step()
	print("INCREMENTAL SMOKE => ", res)
	get_tree().quit(0)


func _process(delta: float) -> void:
	_time += delta
	_prev_mouse_pos = _mouse_pos
	_mouse_pos = get_global_mouse_position()
	_update_popups(delta)

	if _toast_timer > 0.0:
		_toast_timer = maxf(0.0, _toast_timer - delta)
		if _toast_timer <= 0.0 and _toast_lbl != null:
			_toast_lbl.visible = false

	if _trixie_emotion_timer > 0.0:
		_trixie_emotion_timer = maxf(0.0, _trixie_emotion_timer - delta)
		if _trixie_emotion_timer <= 0.0:
			_trixie_emotion = "sonrojada" if _frenzy_timer > 0.0 else ("confiada" if _combo >= 4 else "normal")

	if _customer_flash_timer > 0.0:
		_customer_flash_timer = maxf(0.0, _customer_flash_timer - delta)
	if _tube_flash_timer > 0.0:
		_tube_flash_timer = maxf(0.0, _tube_flash_timer - delta)
	if _customer_slide_t < 1.0:
		_customer_slide_t = minf(1.0, _customer_slide_t + delta * 3.4)

	if view_mode == ViewMode.CAULDRON and not _is_modal_open():
		_process_cauldron_gameplay(delta)
	elif view_mode == ViewMode.UPGRADE_TREE and _tree_canvas != null:
		_tree_canvas.queue_redraw()
	elif view_mode == ViewMode.GALLERY and _gallery_portrait_canvas != null:
		_gallery_portrait_canvas.queue_redraw()
		if _lightbox_overlay != null and _lightbox_overlay.visible and _lightbox_canvas != null:
			_lightbox_canvas.queue_redraw()

	_refresh_hud_labels()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _is_dragging and event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_resolve_drag_chain()


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
				return
			if _is_modal_open():
				return
			if kev.keycode == KEY_1:
				_switch_view(ViewMode.CAULDRON)
				get_viewport().set_input_as_handled()
			elif kev.keycode == KEY_2 or kev.keycode == KEY_TAB:
				_switch_view(ViewMode.UPGRADE_TREE if view_mode != ViewMode.UPGRADE_TREE else ViewMode.CAULDRON)
				get_viewport().set_input_as_handled()
			elif kev.keycode == KEY_3:
				_switch_view(ViewMode.GALLERY)
				get_viewport().set_input_as_handled()
			elif kev.keycode == KEY_SPACE:
				if view_mode == ViewMode.CAULDRON:
					try_activate_frenzy()
				else:
					_start_next_round_from_tree()
				get_viewport().set_input_as_handled()
		return

	if view_mode != ViewMode.CAULDRON or _is_modal_open():
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		var mpos: Vector2 = get_global_mouse_position()
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var hit_idx: int = _find_orb_at(mpos, 10.0)
				if hit_idx != -1 and not round_ending:
					_begin_drag_chain(hit_idx)
					get_viewport().set_input_as_handled()
			else:
				if _is_dragging:
					_resolve_drag_chain()
					get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and not round_ending:
			var r_idx: int = _find_orb_at(mpos, 10.0)
			if r_idx != -1:
				_purge_orb_at(r_idx)
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _is_dragging and not round_ending:
		var mpos: Vector2 = get_global_mouse_position()
		_extend_drag_chain_along_segment(_prev_mouse_pos, mpos)
		_prev_mouse_pos = mpos
		get_viewport().set_input_as_handled()


func _is_modal_open() -> bool:
	var p_open: bool = _pause_overlay != null and _pause_overlay.visible
	var l_open: bool = _lightbox_overlay != null and _lightbox_overlay.visible
	var v_open: bool = _victory_overlay != null and _victory_overlay.visible
	return p_open or l_open or v_open


# ==============================================================================
# COLOR CHEMISTRY & STATS
# ==============================================================================

func get_customer_chemistry() -> Dictionary:
	if _active_customer != null and CUSTOMER_CHEMISTRY.has(_active_customer.customer_id):
		return CUSTOMER_CHEMISTRY[_active_customer.customer_id] as Dictionary
	return {"liked": BubbleKind.RED, "neutral": BubbleKind.GREEN, "disliked": BubbleKind.BLUE}


func get_orb_relation(kind: int) -> StringName:
	if kind == BubbleKind.GOLD or kind == BubbleKind.BOMB:
		return &"special"
	var chem: Dictionary = get_customer_chemistry()
	if kind == int(chem["liked"]):
		return &"liked"
	if kind == int(chem["disliked"]):
		return &"disliked"
	return &"neutral"


static func get_element_name(kind: int) -> String:
	match kind:
		BubbleKind.RED: return "🔥 Fuego"
		BubbleKind.BLUE: return "🌙 Luna"
		BubbleKind.GREEN: return "🍃 Savia"
		BubbleKind.GOLD: return "⭐ Estrella"
		BubbleKind.BOMB: return "💣 Bomba"
	return "Orbe"


static func get_element_color(kind: int) -> Color:
	match kind:
		BubbleKind.RED: return Color(0.98, 0.28, 0.34)
		BubbleKind.BLUE: return Color(0.24, 0.64, 1.0)
		BubbleKind.GREEN: return Color(0.24, 0.88, 0.46)
		BubbleKind.GOLD: return Color(1.0, 0.86, 0.24)
		BubbleKind.BOMB: return Color(0.78, 0.30, 0.98)
	return Color.WHITE


func get_node_level(node_id: StringName) -> int:
	return int(node_levels.get(node_id, 0))


func get_node_cost(node_id: StringName) -> int:
	if not _node_by_id.has(node_id):
		return 999999
	var nd: Dictionary = _node_by_id[node_id] as Dictionary
	var lvl: int = get_node_level(node_id)
	var base_cost: int = int(nd.get("base_cost", 10))
	var mult: float = float(nd.get("cost_mult", 1.5))
	return int(roundf(float(base_cost) * pow(mult, float(lvl))))


func is_node_unlocked(node_id: StringName) -> bool:
	if not _node_by_id.has(node_id):
		return false
	var nd: Dictionary = _node_by_id[node_id] as Dictionary
	var parent_id: StringName = nd.get("parent_id", &"") as StringName
	if parent_id == &"":
		return true
	return get_node_level(parent_id) > 0


func can_buy_node(node_id: StringName) -> bool:
	if not _node_by_id.has(node_id):
		return false
	var nd: Dictionary = _node_by_id[node_id] as Dictionary
	if get_node_level(node_id) >= int(nd.get("max_level", 1)):
		return false
	if not is_node_unlocked(node_id):
		return false
	return essence_gold >= get_node_cost(node_id)


func count_affordable_nodes() -> int:
	var count: int = 0
	for nd: Dictionary in tree_nodes:
		if can_buy_node(nd["id"] as StringName):
			count += 1
	return count


func buy_incremental_node(node_id: StringName) -> bool:
	if not can_buy_node(node_id):
		return false
	var cost: int = get_node_cost(node_id)
	essence_gold -= cost
	node_levels[node_id] = get_node_level(node_id) + 1
	_emit_gold_changed(essence_gold, -cost)
	_recalc_stats()
	_play_pentatonic(clampi(get_node_level(node_id) + 2, 0, 7), -1.0)

	var nd: Dictionary = _node_by_id[node_id] as Dictionary
	var pos: Vector2 = nd.get("pos", VIEWPORT_SIZE * 0.5) as Vector2
	_spawn_popup(pos + Vector2(0, -36), "¡%s Nv.%d!" % [String(nd["name"]), get_node_level(node_id)], Color(1.0, 0.90, 0.35))

	if node_id == &"elixir_supremo" and not victory_achieved:
		victory_achieved = true
		_add_affinity(&"trixie", 12)
		if not _victory_banner_shown:
			_victory_banner_shown = true
			if _victory_overlay != null:
				_victory_overlay.visible = true

	_refresh_tree_detail_panel()
	if _tree_canvas != null:
		_tree_canvas.queue_redraw()
	return true


func _recalc_stats() -> void:
	var l_aroma: int = get_node_level(&"aroma_concentrado")
	var l_link: int = get_node_level(&"enlace_arcano")
	purge_recycle_lvl = get_node_level(&"espuma_veloz")
	var l_frenzy: int = get_node_level(&"frenesi_escarlata")

	var l_boil: int = get_node_level(&"hervor_creciente")
	var l_spark: int = get_node_level(&"chispa_cadena")
	var l_bomb: int = get_node_level(&"bomba_alquimica")
	var l_star: int = get_node_level(&"orbe_estrella")

	var l_time: int = get_node_level(&"reloj_arena")
	fam_michi_lvl = get_node_level(&"michi_alado")
	fam_imp_lvl = get_node_level(&"diablillo_purgador")
	fam_bat_lvl = get_node_level(&"murcielago_alquimista")

	var l_charm: int = get_node_level(&"encanto_mostrador")
	vip_tier = get_node_level(&"vitrina_picante")
	crit_potion_lvl = get_node_level(&"destilacion_doble")

	aroma_essence_mult = 1.0 + float(l_aroma) * 0.25
	aroma_tube_bonus = float(l_aroma) * 4.0
	chain_link_range = 225.0 + float(l_link) * 45.0
	chain_bonus_per_lvl = float(l_link) * 0.25
	frenzy_gain_mult = 1.0 + float(l_frenzy) * 0.25
	frenzy_duration_sec = 5.0 + float(l_frenzy) * 1.2

	spawn_cap = 6 + l_boil * 2
	spawn_interval = maxf(0.32, 1.15 - float(l_boil) * 0.10)
	chain_spark_jumps = 0 if l_spark <= 0 else (1 + int(floor(float(l_spark) * 0.5)))
	bomb_chance = 0.0 if l_bomb <= 0 else (0.09 + float(l_bomb - 1) * 0.03)
	star_chance = 0.0 if l_star <= 0 else (0.07 + float(l_star - 1) * 0.03)

	round_duration = BASE_ROUND_DURATION + float(l_time) * 4.0
	order_bonus_mult = 1.0 + float(l_charm) * 0.25


# ==============================================================================
# ROUND FLOW, SPAWNER & FAMILIARS
# ==============================================================================

func _start_round(num: int) -> void:
	round_number = num
	round_time_left = round_duration
	round_ending = false
	_round_end_timer = 0.0
	_round_essence_gained = 0
	_combo = 0
	_combo_timer = 0.0
	_frenzy_timer = 0.0
	_spawn_accum = 0.0
	_michi_timer = 1.6
	_imp_timer = 2.0
	_bat_timer = 2.2
	_is_dragging = false
	_drag_chain.clear()
	_drag_base_color = -1

	_orbs.clear()
	_lightning_arcs.clear()
	_shockwaves.clear()

	# Slow, clean initial spawn: start with spawn_cap (6 in Round 1)
	for _i: int in range(spawn_cap):
		_spawn_orb(false)

	_set_trixie_reaction("confiada" if round_number > 1 else "normal", 2.0,
		"¡Ronda %d! Extrae o encadena orbes %s. Purga los ❌ con Clic Der." % [
			round_number, get_element_name(int(get_customer_chemistry()["liked"]))
		])
	_switch_view(ViewMode.CAULDRON)


func _start_next_round_from_tree() -> void:
	_start_round(round_number + 1)


func _finish_round_early() -> void:
	if round_ending:
		return
	round_time_left = 0.0
	_trigger_round_end()


func _trigger_round_end() -> void:
	if round_ending:
		return
	round_ending = true
	_round_end_timer = 0.65
	_is_dragging = false
	_drag_chain.clear()
	_play_pentatonic(6, -2.0)
	_set_trixie_reaction("confiada", 2.0, "¡Fin de hervor! +%d✦ reunida. ¡Mejoremos el caldero!" % _round_essence_gained)


func _process_cauldron_gameplay(delta: float) -> void:
	if _cauldron_shake > 0.0:
		_cauldron_shake = maxf(0.0, _cauldron_shake - delta * 26.0)

	if _combo > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_combo = 0

	if _frenzy_timer > 0.0:
		_frenzy_timer = maxf(0.0, _frenzy_timer - delta)

	for st: Dictionary in _ambient_steam:
		st["y"] = float(st["y"]) - float(st["spd"]) * delta
		if float(st["y"]) < -CAULDRON_RADIUS * 0.72:
			st["y"] = CAULDRON_RADIUS * 0.65
			st["x"] = randf_range(-CAULDRON_RADIUS * 0.75, CAULDRON_RADIUS * 0.75)

	if round_ending:
		_round_end_timer -= delta
		_update_vfx(delta)
		if _round_end_timer <= 0.0:
			_switch_view(ViewMode.UPGRADE_TREE)
		return

	round_time_left = maxf(0.0, round_time_left - delta)
	if round_time_left <= 0.0:
		_trigger_round_end()
		return

	_spawn_accum += delta
	while _spawn_accum >= spawn_interval:
		_spawn_accum -= spawn_interval
		if _orbs.size() < spawn_cap:
			_spawn_orb(false)

	_update_orbs_motion(delta)
	_hovered_orb_idx = _find_orb_at(_mouse_pos, 10.0) if not _is_dragging else -1
	_update_familiars(delta)
	_update_vfx(delta)


func _count_orbs_of_kind(target_kind: int) -> int:
	var c: int = 0
	for o: Dictionary in _orbs:
		if int(o["kind"]) == target_kind:
			c += 1
	return c


func _spawn_orb(avoid_disliked: bool) -> void:
	var chem: Dictionary = get_customer_chemistry()
	var liked_k: int = int(chem["liked"])
	var neutral_k: int = int(chem["neutral"])
	var disliked_k: int = int(chem["disliked"])

	var kind: int = liked_k
	var roll: float = randf()
	if roll < star_chance:
		kind = BubbleKind.GOLD
	elif roll < star_chance + bomb_chance:
		kind = BubbleKind.BOMB
	elif _count_orbs_of_kind(liked_k) < 2:
		kind = liked_k
	else:
		var r_base: float = randf()
		if avoid_disliked:
			kind = liked_k if r_base < 0.62 else neutral_k
		else:
			if r_base < 0.44:
				kind = liked_k
			elif r_base < 0.74:
				kind = neutral_k
			else:
				kind = disliked_k

	# Pick well-spaced position inside cauldron
	var pos: Vector2 = CAULDRON_CENTER
	var max_r: float = CAULDRON_RADIUS - ORB_RADIUS - 22.0
	for _attempt: int in range(12):
		var ang: float = randf_range(0.0, TAU)
		var dist: float = sqrt(randf()) * max_r
		var cand: Vector2 = CAULDRON_CENTER + Vector2(cos(ang), sin(ang)) * dist
		var clear: bool = true
		for o: Dictionary in _orbs:
			if cand.distance_to(o["pos"] as Vector2) < ORB_RADIUS * 2.25:
				clear = false
				break
		pos = cand
		if clear:
			break

	var vel_ang: float = randf_range(0.0, TAU)
	var vel: Vector2 = Vector2(cos(vel_ang), sin(vel_ang)) * randf_range(12.0, 24.0)
	_orbs.append({
		"pos": pos,
		"vel": vel,
		"radius": ORB_RADIUS,
		"kind": kind,
		"scale_pop": 0.25,
		"phase": randf_range(0.0, TAU),
	})


func _update_orbs_motion(delta: float) -> void:
	var limit: float = CAULDRON_RADIUS - ORB_RADIUS - 14.0
	for i: int in range(_orbs.size()):
		var o: Dictionary = _orbs[i]
		var pos: Vector2 = o["pos"] as Vector2
		var vel: Vector2 = o["vel"] as Vector2
		pos += vel * delta

		var rel: Vector2 = pos - CAULDRON_CENTER
		if rel.length() > limit:
			var n: Vector2 = rel.normalized()
			pos = CAULDRON_CENTER + n * limit
			vel = vel.bounce(n)

		o["pos"] = pos
		o["vel"] = vel
		o["scale_pop"] = lerpf(float(o["scale_pop"]), 1.0, clampf(delta * 10.0, 0.0, 1.0))

	# Soft separation so orbs stay readable and don't stack on top of each other
	for i: int in range(_orbs.size()):
		for j: int in range(i + 1, _orbs.size()):
			var pi: Vector2 = _orbs[i]["pos"] as Vector2
			var pj: Vector2 = _orbs[j]["pos"] as Vector2
			var diff: Vector2 = pj - pi
			var d: float = diff.length()
			var min_d: float = ORB_RADIUS * 2.15
			if d > 0.01 and d < min_d:
				var push: Vector2 = diff.normalized() * (min_d - d) * 0.5 * clampf(delta * 8.0, 0.0, 1.0)
				_orbs[i]["pos"] = pi - push
				_orbs[j]["pos"] = pj + push


func _find_orb_at(pos: Vector2, extra_pad: float = 8.0) -> int:
	for i: int in range(_orbs.size() - 1, -1, -1):
		var opos: Vector2 = _orbs[i]["pos"] as Vector2
		var orad: float = float(_orbs[i]["radius"])
		if pos.distance_to(opos) <= orad + extra_pad:
			return i
	return -1


# ==============================================================================
# TACTICAL DRAG-CHAIN, SINGLE CLICK & RIGHT-CLICK PURGE
# ==============================================================================

func _begin_drag_chain(idx: int) -> void:
	if idx < 0 or idx >= _orbs.size():
		return
	_is_dragging = true
	_drag_chain = [idx]
	var kind: int = int(_orbs[idx]["kind"])
	_drag_base_color = kind if (kind != BubbleKind.GOLD and kind != BubbleKind.BOMB) else -1
	_play_pentatonic(0, -6.0)


func _extend_drag_chain_along_segment(p0: Vector2, p1: Vector2) -> void:
	if not _is_dragging or _drag_chain.is_empty():
		return
	var last_idx: int = _drag_chain[_drag_chain.size() - 1]
	var last_pos: Vector2 = _orbs[last_idx]["pos"] as Vector2

	for i: int in range(_orbs.size()):
		var opos: Vector2 = _orbs[i]["pos"] as Vector2
		var orad: float = float(_orbs[i]["radius"])
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(opos, p0, p1)
		if closest.distance_to(opos) > orad + 10.0:
			continue

		# Backtrack 1 step if hovering back over the penultimate orb
		if _drag_chain.size() >= 2 and i == _drag_chain[_drag_chain.size() - 2]:
			_drag_chain.pop_back()
			_recompute_drag_base_color()
			_play_pentatonic(maxi(0, _drag_chain.size() - 1), -8.0)
			return

		if _drag_chain.has(i):
			continue
		if opos.distance_to(last_pos) > chain_link_range:
			continue
		if _can_link_orb_kind(int(_orbs[i]["kind"])):
			_drag_chain.append(i)
			var k: int = int(_orbs[i]["kind"])
			if _drag_base_color == -1 and k != BubbleKind.GOLD and k != BubbleKind.BOMB:
				_drag_base_color = k
			_play_pentatonic(clampi(_drag_chain.size() - 1, 0, 7), -5.0)
			return


func _recompute_drag_base_color() -> void:
	_drag_base_color = -1
	for idx: int in _drag_chain:
		if idx >= 0 and idx < _orbs.size():
			var k: int = int(_orbs[idx]["kind"])
			if k != BubbleKind.GOLD and k != BubbleKind.BOMB:
				_drag_base_color = k
				return


func _can_link_orb_kind(kind: int) -> bool:
	if kind == BubbleKind.GOLD or kind == BubbleKind.BOMB:
		return true
	if _drag_base_color == -1:
		return true
	return kind == _drag_base_color


func _calc_chain_multiplier(count: int) -> float:
	if count <= 1:
		return 1.0
	var base: float = 2.4
	if count == 3:
		base = 4.2
	elif count == 4:
		base = 6.5
	elif count > 4:
		base = 6.5 + float(count - 4) * 2.5
	return base + float(count - 1) * chain_bonus_per_lvl


func _resolve_drag_chain() -> void:
	_is_dragging = false
	if _drag_chain.is_empty():
		_drag_base_color = -1
		return
	var selected: Array[int] = _drag_chain.duplicate()
	_drag_chain.clear()
	_drag_base_color = -1
	_resolve_orb_indices_as_chain(selected)


func _resolve_orb_indices_as_chain(indices: Array[int]) -> void:
	if indices.is_empty():
		return
	var chain_snaps: Array[Dictionary] = []
	var seen: Dictionary = {}
	for idx: int in indices:
		if idx >= 0 and idx < _orbs.size() and not seen.has(idx):
			seen[idx] = true
			chain_snaps.append(_orbs[idx].duplicate())

	if chain_snaps.is_empty():
		return

	# Remove from _orbs back-to-front cleanly
	var sorted_idxs: Array[int] = []
	for k: Variant in seen.keys():
		sorted_idxs.append(int(k))
	sorted_idxs.sort()
	for r_i: int in range(sorted_idxs.size() - 1, -1, -1):
		_orbs.remove_at(sorted_idxs[r_i])

	var chain_len: int = chain_snaps.size()
	var chain_mult: float = _calc_chain_multiplier(chain_len)
	var frenzy_mult: float = 2.0 if _frenzy_timer > 0.0 else 1.0

	var liked_count: int = 0
	var neutral_count: int = 0
	var disliked_count: int = 0
	var star_count: int = 0
	var bomb_positions: Array[Vector2] = []

	for i: int in range(chain_snaps.size()):
		var snap: Dictionary = chain_snaps[i]
		var pos: Vector2 = snap["pos"] as Vector2
		var kind: int = int(snap["kind"])
		var rel: StringName = get_orb_relation(kind)

		if i > 0:
			_lightning_arcs.append({
				"from": chain_snaps[i - 1]["pos"] as Vector2,
				"to": pos,
				"color": Color(0.45, 0.96, 1.0),
				"life": 0.24,
				"max_life": 0.24,
			})

		_shockwaves.append({
			"pos": pos,
			"radius": 12.0,
			"max_radius": 78.0 if chain_len >= 2 else 58.0,
			"color": get_element_color(kind),
			"life": 0.28,
			"max_life": 0.28,
		})

		if kind == BubbleKind.GOLD:
			star_count += 1
		elif kind == BubbleKind.BOMB:
			bomb_positions.append(pos)
		elif rel == &"liked":
			liked_count += 1
		elif rel == &"neutral":
			neutral_count += 1
		else:
			disliked_count += 1

	var center_pos: Vector2 = chain_snaps[chain_snaps.size() - 1]["pos"] as Vector2

	# 1) Disliked penalty takes effect cleanly if player clicked/linked ❌
	if disliked_count > 0:
		var penalty: float = 18.0 * float(disliked_count)
		_potion_tube_pct = maxf(0.0, _potion_tube_pct - penalty)
		_combo = 0
		_tube_flash_timer = 0.55
		_tube_flash_positive = false
		_cauldron_shake = maxf(_cauldron_shake, 10.0)
		_play_pentatonic(0, 0.0)
		_spawn_popup(center_pos, "¡❌ -%d%% Poción! Combo 0" % int(penalty), Color(1.0, 0.32, 0.34))
		_set_trixie_reaction("nerviosa", 1.8, "¡Cuidado! Ese elemento choca con el pedido.")
		if _active_customer != null and not _active_customer.impatient_lines.is_empty():
			_customer_line = _active_customer.impatient_lines[0]
		return

	# 2) Positive extraction (Liked / Neutral / Star / Bomb)
	var tube_gain: float = 0.0
	var ess_gain: int = 0
	var frenzy_add: float = 0.0

	if liked_count > 0:
		tube_gain += (22.0 + aroma_tube_bonus) * chain_mult * frenzy_mult
		ess_gain += int(roundf(6.0 * chain_mult * aroma_essence_mult * frenzy_mult))
		_combo += liked_count
		_combo_timer = 5.0
		frenzy_add += 16.0 * float(liked_count) * frenzy_gain_mult

	if neutral_count > 0:
		tube_gain += 7.0 * chain_mult * frenzy_mult
		ess_gain += int(roundf(3.0 * chain_mult * frenzy_mult))
		_combo_timer = 5.0
		if chain_len >= 2:
			_combo += 1

	if star_count > 0:
		tube_gain += 16.0 * float(star_count) * frenzy_mult
		ess_gain += int(roundf(15.0 * float(star_count) * chain_mult * aroma_essence_mult * frenzy_mult))
		_combo += star_count
		_combo_timer = 5.0
		frenzy_add += 14.0 * float(star_count) * frenzy_gain_mult

	if chain_len >= 2:
		_play_pentatonic(clampi(chain_len + 1, 0, 7), -1.0)
	else:
		_play_pentatonic(clampi(_combo % 8, 0, 7), -4.0)

	if ess_gain > 0:
		_grant_essence(ess_gain)
	if frenzy_add > 0.0 and _frenzy_timer <= 0.0:
		_frenzy_charge = minf(100.0, _frenzy_charge + frenzy_add)

	if liked_count > 0 or star_count > 0:
		_set_trixie_reaction("confiada", 1.6,
			"¡Cadena x%d perfecta!" % chain_len if chain_len >= 2 else "¡Buen toque! Sigue buscando los afines.")

	# Popup summary
	var pop_txt: String = "+%d%%  +%d✦" % [int(roundf(tube_gain)), ess_gain]
	if chain_len >= 2:
		pop_txt = "¡CADENA x%d! %s" % [chain_len, pop_txt]
	_spawn_popup(center_pos, pop_txt, Color(1.0, 0.90, 0.40) if liked_count > 0 or star_count > 0 else Color(0.84, 0.92, 1.0))

	if tube_gain > 0.0:
		_add_tube_progress(tube_gain)

	# 3) Chain Spark upgrade: zaps extra nearby Liked orbs when chaining 2+
	if chain_spark_jumps > 0 and chain_len >= 2 and liked_count > 0:
		_trigger_chain_spark_zaps(center_pos, chain_spark_jumps)

	# 4) Bomb AoE: extracts nearby Liked/Neutral/Gold while skipping Disliked ❌
	for bpos: Vector2 in bomb_positions:
		_detonate_alchemy_bomb(bpos)


func _trigger_chain_spark_zaps(origin: Vector2, jumps: int) -> void:
	var targets: Array[int] = []
	for i: int in range(_orbs.size()):
		if get_orb_relation(int(_orbs[i]["kind"])) == &"liked":
			if (_orbs[i]["pos"] as Vector2).distance_to(origin) <= 270.0:
				targets.append(i)
				if targets.size() >= jumps:
					break
	if targets.is_empty():
		return
	for idx: int in targets:
		_lightning_arcs.append({
			"from": origin,
			"to": _orbs[idx]["pos"] as Vector2,
			"color": Color(0.36, 0.96, 1.0),
			"life": 0.25,
			"max_life": 0.25,
		})
	_resolve_orb_indices_as_chain(targets)


func _detonate_alchemy_bomb(bpos: Vector2) -> void:
	_cauldron_shake = maxf(_cauldron_shake, 11.0)
	_shockwaves.append({
		"pos": bpos,
		"radius": 18.0,
		"max_radius": 175.0,
		"color": Color(0.88, 0.42, 1.0),
		"life": 0.38,
		"max_life": 0.38,
	})
	var hits: Array[int] = []
	for i: int in range(_orbs.size()):
		var o: Dictionary = _orbs[i]
		if (o["pos"] as Vector2).distance_to(bpos) <= 175.0:
			if get_orb_relation(int(o["kind"])) != &"disliked":
				hits.append(i)
	if not hits.is_empty():
		_spawn_popup(bpos + Vector2(0, -28), "¡BOOM ALQUÍMICO!", Color(0.92, 0.56, 1.0))
		_resolve_orb_indices_as_chain(hits)


func _purge_orb_at(idx: int) -> void:
	if idx < 0 or idx >= _orbs.size():
		return
	var o: Dictionary = _orbs[idx]
	var pos: Vector2 = o["pos"] as Vector2
	var rel: StringName = get_orb_relation(int(o["kind"]))
	_orbs.remove_at(idx)

	var a: Node = _audio()
	if a != null:
		a.call("play_stir")
	_shockwaves.append({
		"pos": pos,
		"radius": 10.0,
		"max_radius": 52.0,
		"color": Color(0.75, 0.78, 0.90),
		"life": 0.22,
		"max_life": 0.22,
	})

	if purge_recycle_lvl > 0:
		var rec_ess: int = (6 if rel == &"disliked" else 3) * purge_recycle_lvl
		_grant_essence(rec_ess)
		_spawn_popup(pos, "Purgado +%d✦" % rec_ess, Color(0.72, 0.92, 1.0))
		if _orbs.size() < spawn_cap:
			_spawn_orb(true)
	else:
		_spawn_popup(pos, "Purgado", Color(0.80, 0.84, 0.94))


func try_activate_frenzy() -> bool:
	if _frenzy_charge < 100.0 or _frenzy_timer > 0.0 or round_ending:
		return false
	_frenzy_charge = 0.0
	_frenzy_timer = frenzy_duration_sec
	_cauldron_shake = maxf(_cauldron_shake, 12.0)
	var a: Node = _audio()
	if a != null:
		a.call("trigger_screen_shake", 9.0, 0.25)
	var b: Node = _bus()
	if b != null:
		b.emit_signal("witch_ability_triggered", &"trixie", null)

	# Transmute all DISLIKED orbs in the cauldron into LIKED orbs!
	var liked_k: int = int(get_customer_chemistry()["liked"])
	var transmuted: int = 0
	for o: Dictionary in _orbs:
		if get_orb_relation(int(o["kind"])) == &"disliked":
			o["kind"] = liked_k
			o["scale_pop"] = 0.3
			transmuted += 1
			_shockwaves.append({
				"pos": o["pos"] as Vector2,
				"radius": 10.0,
				"max_radius": 68.0,
				"color": Color(1.0, 0.86, 0.34),
				"life": 0.35,
				"max_life": 0.35,
			})

	_set_trixie_reaction("sonrojada", _frenzy_timer,
		"¡FRENESÍ ESCARLATA! %d orbes negativos transmutados y 2x TODO!" % transmuted)
	_spawn_popup(CAULDRON_CENTER, "¡FRENESÍ ESCARLATA x2!", Color(1.0, 0.42, 0.74))
	return true


func _update_familiars(delta: float) -> void:
	if fam_michi_lvl > 0 and not _orbs.is_empty():
		_michi_timer -= delta
		if _michi_timer <= 0.0:
			_michi_timer = maxf(1.05, 2.5 - float(fam_michi_lvl - 1) * 0.32)
			for i: int in range(_orbs.size()):
				var rel: StringName = get_orb_relation(int(_orbs[i]["kind"]))
				if rel == &"liked" or int(_orbs[i]["kind"]) == BubbleKind.GOLD:
					_lightning_arcs.append({
						"from": _get_michi_pos(),
						"to": _orbs[i]["pos"] as Vector2,
						"color": Color(1.0, 0.72, 0.92),
						"life": 0.20,
						"max_life": 0.20,
					})
					_resolve_orb_indices_as_chain([i])
					break

	if fam_imp_lvl > 0 and not _orbs.is_empty():
		_imp_timer -= delta
		if _imp_timer <= 0.0:
			_imp_timer = maxf(1.2, 2.9 - float(fam_imp_lvl - 1) * 0.35)
			for i: int in range(_orbs.size()):
				if get_orb_relation(int(_orbs[i]["kind"])) == &"disliked":
					_lightning_arcs.append({
						"from": _get_imp_pos(),
						"to": _orbs[i]["pos"] as Vector2,
						"color": Color(1.0, 0.45, 0.28),
						"life": 0.20,
						"max_life": 0.20,
					})
					_purge_orb_at(i)
					break

	if fam_bat_lvl > 0:
		_bat_timer -= delta
		if _bat_timer <= 0.0:
			_bat_timer = maxf(1.0, 2.4 - float(fam_bat_lvl - 1) * 0.30)
			var ess: int = 4 + fam_bat_lvl * 3
			var pct: float = 3.0 + float(fam_bat_lvl) * 1.5
			_grant_essence(ess)
			_add_tube_progress(pct)
			_spawn_popup(_get_bat_pos(), "🦇 +%d%% +%d✦" % [int(pct), ess], Color(0.84, 0.68, 1.0))


func _get_michi_pos() -> Vector2:
	return CAULDRON_CENTER + Vector2(cos(_time * 1.2) * 235.0, sin(_time * 1.2) * 185.0)


func _get_imp_pos() -> Vector2:
	return CAULDRON_CENTER + Vector2(cos(-_time * 1.05 + 2.2) * 245.0, sin(-_time * 1.05 + 2.2) * 195.0)


func _get_bat_pos() -> Vector2:
	return CAULDRON_CENTER + Vector2(cos(_time * 1.5 + 4.1) * 290.0, -255.0 + sin(_time * 3.0) * 18.0)


func _grant_essence(amount: int) -> void:
	essence_gold += amount
	total_essence_earned += amount
	_round_essence_gained += amount
	_emit_gold_changed(essence_gold, amount)


func _add_tube_progress(pct: float) -> void:
	_potion_tube_pct += pct
	_tube_flash_timer = 0.4
	_tube_flash_positive = true
	if _potion_tube_pct >= 100.0:
		_complete_customer_order()


func _update_vfx(delta: float) -> void:
	var l_idx: int = 0
	while l_idx < _lightning_arcs.size():
		_lightning_arcs[l_idx]["life"] = float(_lightning_arcs[l_idx]["life"]) - delta
		if float(_lightning_arcs[l_idx]["life"]) <= 0.0:
			_lightning_arcs.remove_at(l_idx)
			continue
		l_idx += 1

	var s_idx: int = 0
	while s_idx < _shockwaves.size():
		var sw: Dictionary = _shockwaves[s_idx]
		sw["life"] = float(sw["life"]) - delta
		var t: float = 1.0 - clampf(float(sw["life"]) / maxf(0.01, float(sw["max_life"])), 0.0, 1.0)
		sw["radius"] = lerpf(12.0, float(sw["max_radius"]), t)
		if float(sw["life"]) <= 0.0:
			_shockwaves.remove_at(s_idx)
			continue
		s_idx += 1


# ==============================================================================
# CUSTOMERS & SPICY AFFINITY
# ==============================================================================

func get_affinity_points(char_id: StringName) -> int:
	return int(customer_affinity_pts.get(char_id, 0))


func get_affinity_level(char_id: StringName) -> int:
	var pts: int = get_affinity_points(char_id)
	var lvl: int = 0
	for th: int in AFFINITY_THRESHOLDS:
		if pts >= th:
			lvl += 1
	return lvl


func _add_affinity(char_id: StringName, pts: int) -> bool:
	var prev_lvl: int = get_affinity_level(char_id)
	customer_affinity_pts[char_id] = get_affinity_points(char_id) + pts
	return get_affinity_level(char_id) > prev_lvl


func _pick_next_customer(first_order: bool = false) -> void:
	if customers_catalog.is_empty():
		return
	var max_pool: int = mini(customers_catalog.size(), 1 + vip_tier)
	if vip_tier == 0 and orders_completed >= 2:
		max_pool = mini(customers_catalog.size(), 2)
	var pool: Array[CustomerArchetypeData] = []
	for i: int in range(max_pool):
		pool.append(customers_catalog[i])

	var next_c: CustomerArchetypeData = pool[0]
	if pool.size() > 1 and not first_order:
		var cands: Array[CustomerArchetypeData] = []
		for c: CustomerArchetypeData in pool:
			if _active_customer == null or c.customer_id != _active_customer.customer_id:
				cands.append(c)
		if not cands.is_empty():
			next_c = cands[randi() % cands.size()]
	elif not pool.is_empty():
		next_c = pool[0]

	_active_customer = next_c
	_potion_tube_pct = 0.0
	_customer_slide_t = 0.0
	_customer_spicy_mode = false
	_customer_order_reward = int(roundf(float(24 + orders_completed * 14) * next_c.tip_generosity_mult * order_bonus_mult))

	if not next_c.greeting_lines.is_empty():
		_customer_line = next_c.greeting_lines[randi() % next_c.greeting_lines.size()]
	else:
		_customer_line = "¡Prepara mi elixir favorito, brujita!"


func _complete_customer_order() -> void:
	if _active_customer == null:
		return
	var c: CustomerArchetypeData = _active_customer
	var overflow: float = maxf(0.0, _potion_tube_pct - 100.0)
	var crit: bool = crit_potion_lvl > 0 and _combo >= 5
	var bonus_gold: int = _customer_order_reward * (2 if crit else 1) + int(roundf(overflow * 0.4))
	_grant_essence(bonus_gold)
	orders_completed += 1

	var b: Node = _bus()
	if b != null:
		b.emit_signal("customer_served", c.customer_id, bonus_gold, 1.5 if crit else 1.1, 1)

	var aff_gain: int = 1 + (1 if get_node_level(&"encanto_mostrador") >= 3 else 0) + (1 if crit else 0)
	var leveled_up: bool = _add_affinity(c.customer_id, aff_gain)
	var new_aff_lvl: int = get_affinity_level(c.customer_id)
	_customer_spicy_mode = new_aff_lvl >= 1
	_customer_flash_timer = 1.2

	if leveled_up:
		_show_toast("💋 ¡Afinidad Nv.%d con %s! Escena de Galería desbloqueada." % [new_aff_lvl, c.display_name], 4.0)
		_set_trixie_reaction("sonrojada", 2.4, "¡A %s le encantó! Mira cómo se sonroja..." % c.display_name)
	elif crit:
		_show_toast("💎 ¡POCIÓN CRÍTICA! +%d✦  +%d❤ Afinidad" % [bonus_gold, aff_gain], 2.5)

	_spawn_popup(Vector2(1620, 440), "¡ELIXIR LISTO! +%d✦  +%d❤" % [bonus_gold, aff_gain], Color(1.0, 0.78, 0.92))
	_pick_next_customer(false)


func _show_toast(txt: String, duration: float = 3.5) -> void:
	_toast_timer = duration
	if _toast_lbl != null:
		_toast_lbl.text = txt
		_toast_lbl.visible = true


func _set_trixie_reaction(emotion: String, dur: float, line: String) -> void:
	_trixie_emotion = emotion
	_trixie_emotion_timer = dur
	_trixie_line = line


# ==============================================================================
# VIEW SWITCHING & UI BUILD
# ==============================================================================

func _switch_view(mode: ViewMode) -> void:
	view_mode = mode
	_is_dragging = false
	_drag_chain.clear()
	if _cauldron_hud_root != null:
		_cauldron_hud_root.visible = (mode == ViewMode.CAULDRON)
	if _tree_view_root != null:
		_tree_view_root.visible = (mode == ViewMode.UPGRADE_TREE)
	if _gallery_view_root != null:
		_gallery_view_root.visible = (mode == ViewMode.GALLERY)
	if mode == ViewMode.UPGRADE_TREE:
		_refresh_tree_detail_panel()
		if _tree_canvas != null:
			_tree_canvas.queue_redraw()
	elif mode == ViewMode.GALLERY:
		_refresh_gallery_panel()
	_refresh_hud_labels()


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)

	# Top Bar
	var top_bar: PanelContainer = PanelContainer.new()
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(1920, 76)
	var tb_sb: StyleBoxFlat = StyleBoxFlat.new()
	tb_sb.bg_color = Color(0.08, 0.05, 0.13, 0.95)
	tb_sb.border_color = Color(0.76, 0.58, 0.28)
	tb_sb.border_width_bottom = 3
	top_bar.add_theme_stylebox_override("panel", tb_sb)
	_ui_layer.add_child(top_bar)

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
	_top_essence_lbl.custom_minimum_size = Vector2(260, 0)
	_top_round_lbl = _make_label("Ronda 1  ·  Pedidos: 0", 20, Color(0.92, 0.88, 0.98))
	_top_round_lbl.custom_minimum_size = Vector2(260, 0)
	tb_hbox.add_child(_top_essence_lbl)
	tb_hbox.add_child(_top_round_lbl)

	var sp1: Control = Control.new()
	sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_hbox.add_child(sp1)

	_top_timer_lbl = _make_label("0:25", 28, Color(1.0, 0.94, 0.78))
	_top_timer_lbl.custom_minimum_size = Vector2(130, 0)
	_top_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tb_hbox.add_child(_top_timer_lbl)

	var sp2: Control = Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_hbox.add_child(sp2)

	_tab_cauldron_btn = _make_pill_button("🔥 CALDERO [1]", Color(0.56, 0.16, 0.32), Color(1.0, 0.78, 0.36))
	_tab_cauldron_btn.pressed.connect(func() -> void: _switch_view(ViewMode.CAULDRON))
	_tab_tree_btn = _make_pill_button("🌿 ÁRBOL [TAB]", Color(0.18, 0.28, 0.44), Color(0.45, 0.86, 1.0))
	_tab_tree_btn.pressed.connect(func() -> void: _switch_view(ViewMode.UPGRADE_TREE))
	_tab_gallery_btn = _make_pill_button("💋 GALERÍA [3]", Color(0.36, 0.16, 0.42), Color(1.0, 0.62, 0.84))
	_tab_gallery_btn.pressed.connect(func() -> void: _switch_view(ViewMode.GALLERY))

	tb_hbox.add_child(_tab_cauldron_btn)
	tb_hbox.add_child(_tab_tree_btn)
	tb_hbox.add_child(_tab_gallery_btn)

	_tree_badge_panel = PanelContainer.new()
	_tree_badge_panel.position = Vector2(1656, 4)
	_tree_badge_panel.size = Vector2(28, 28)
	var b_sb: StyleBoxFlat = StyleBoxFlat.new()
	b_sb.bg_color = Color(1.0, 0.84, 0.20)
	b_sb.set_corner_radius_all(14)
	_tree_badge_panel.add_theme_stylebox_override("panel", b_sb)
	var b_lbl: Label = _make_label("!", 18, Color(0.12, 0.04, 0.10))
	b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tree_badge_panel.add_child(b_lbl)
	_tree_badge_panel.visible = false
	_ui_layer.add_child(_tree_badge_panel)

	_build_cauldron_hud()
	_build_upgrade_tree_ui()
	_build_gallery_ui()
	_build_modals()


func _build_cauldron_hud() -> void:
	_cauldron_hud_root = Control.new()
	_cauldron_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cauldron_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_cauldron_hud_root)

	# Left Panel below Trixie's big portrait (FRENZY + Button + Control tip)
	var left_card: PanelContainer = _make_card_panel(Vector2(24, 650), Vector2(402, 404), Color(0.12, 0.07, 0.18, 0.94), Color(0.92, 0.56, 0.40))
	_cauldron_hud_root.add_child(left_card)
	var lv: VBoxContainer = VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	left_card.get_child(0).add_child(lv)

	var f_hdr: Label = _make_label("🔥 FRENESÍ ESCARLATA", 20, Color(1.0, 0.78, 0.36))
	lv.add_child(f_hdr)

	_frenzy_bar = ProgressBar.new()
	_frenzy_bar.custom_minimum_size = Vector2(360, 24)
	_frenzy_bar.max_value = 100.0
	_frenzy_bar.show_percentage = false
	var fbg: StyleBoxFlat = StyleBoxFlat.new()
	fbg.bg_color = Color(0.08, 0.04, 0.12)
	fbg.set_corner_radius_all(8)
	var ffg: StyleBoxFlat = StyleBoxFlat.new()
	ffg.bg_color = Color(1.0, 0.32, 0.44)
	ffg.set_corner_radius_all(8)
	_frenzy_bar.add_theme_stylebox_override("background", fbg)
	_frenzy_bar.add_theme_stylebox_override("fill", ffg)
	lv.add_child(_frenzy_bar)

	_frenzy_btn = _make_pill_button("💥 ACTIVAR FRENESÍ [ESPACIO]", Color(0.68, 0.14, 0.24), Color(1.0, 0.84, 0.38))
	_frenzy_btn.custom_minimum_size = Vector2(360, 56)
	_frenzy_btn.pressed.connect(try_activate_frenzy)
	lv.add_child(_frenzy_btn)

	_trixie_speech_lbl = _make_label(_trixie_line, 17, Color(0.96, 0.92, 0.98))
	_trixie_speech_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trixie_speech_lbl.custom_minimum_size = Vector2(360, 128)
	lv.add_child(_trixie_speech_lbl)

	var ctrl_hint: Label = _make_label("Clic Izq / Arrastrar: Extraer · Clic Der: Purgar ❌", 15, Color(0.74, 0.84, 0.98))
	ctrl_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(ctrl_hint)

	# Right Chemistry Legend + Customer Parchment Box (x=1408..1894)
	var chem_card: PanelContainer = _make_card_panel(Vector2(1408, 568), Vector2(486, 86), Color(0.11, 0.07, 0.17, 0.95), Color(0.76, 0.60, 0.92))
	_cauldron_hud_root.add_child(chem_card)
	var chem_hbox: HBoxContainer = HBoxContainer.new()
	chem_hbox.add_theme_constant_override("separation", 10)
	chem_card.get_child(0).add_child(chem_hbox)

	_cust_liked_lbl = _make_label("✨ AFÍN:\n🔥 Fuego", 16, Color(0.45, 1.0, 0.62))
	_cust_liked_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cust_liked_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cust_neutral_lbl = _make_label("⚪ NEUTRO:\n🍃 Savia", 16, Color(0.88, 0.90, 0.96))
	_cust_neutral_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cust_neutral_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cust_disliked_lbl = _make_label("❌ RESTA:\n🌙 Luna", 16, Color(1.0, 0.42, 0.48))
	_cust_disliked_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cust_disliked_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chem_hbox.add_child(_cust_liked_lbl)
	chem_hbox.add_child(_cust_neutral_lbl)
	chem_hbox.add_child(_cust_disliked_lbl)

	var cust_card: PanelContainer = _make_card_panel(Vector2(1408, 666), Vector2(486, 314), Color(0.90, 0.80, 0.64, 0.96), Color(0.36, 0.22, 0.14))
	_cauldron_hud_root.add_child(cust_card)
	var cv: VBoxContainer = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	cust_card.get_child(0).add_child(cv)

	var chdr: HBoxContainer = HBoxContainer.new()
	_cust_name_lbl = _make_label("Sylvi", 24, Color(0.36, 0.12, 0.22))
	_cust_name_lbl.add_theme_constant_override("outline_size", 0)
	_cust_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cust_aff_lbl = _make_label("❤ Nv.0", 20, Color(0.68, 0.14, 0.36))
	_cust_aff_lbl.add_theme_constant_override("outline_size", 0)
	chdr.add_child(_cust_name_lbl)
	chdr.add_child(_cust_aff_lbl)
	cv.add_child(chdr)

	_cust_speech_lbl = _make_label(_customer_line, 20, Color(0.18, 0.10, 0.08))
	_cust_speech_lbl.add_theme_constant_override("outline_size", 0)
	_cust_speech_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cust_speech_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(_cust_speech_lbl)

	_end_round_btn = _make_pill_button("🌿 TERMINAR HERVOR / IR AL ÁRBOL [TAB]", Color(0.20, 0.30, 0.48), Color(0.55, 0.88, 1.0))
	_end_round_btn.position = Vector2(1408, 994)
	_end_round_btn.size = Vector2(486, 56)
	_end_round_btn.pressed.connect(_finish_round_early)
	_cauldron_hud_root.add_child(_end_round_btn)

	_toast_lbl = _make_label("", 22, Color(1.0, 0.90, 0.42))
	_toast_lbl.position = Vector2(450, 92)
	_toast_lbl.size = Vector2(880, 42)
	_toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_lbl.visible = false
	_cauldron_hud_root.add_child(_toast_lbl)


func _build_upgrade_tree_ui() -> void:
	_tree_view_root = Control.new()
	_tree_view_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tree_view_root.visible = false
	_ui_layer.add_child(_tree_view_root)

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

	_tree_buy_btn = _make_pill_button("COMPRAR MEJORA", Color(0.58, 0.22, 0.40), Color(1.0, 0.84, 0.36))
	_tree_buy_btn.custom_minimum_size = Vector2(290, 92)
	_tree_buy_btn.pressed.connect(func() -> void: buy_incremental_node(_tree_selected_id))
	hbox.add_child(_tree_buy_btn)

	_tree_boil_btn = _make_pill_button("🔥 ¡HERVIR CALDERO!\n[ESPACIO]", Color(0.16, 0.48, 0.26), Color(0.54, 1.0, 0.58))
	_tree_boil_btn.custom_minimum_size = Vector2(310, 92)
	_tree_boil_btn.pressed.connect(_start_next_round_from_tree)
	hbox.add_child(_tree_boil_btn)


func _build_gallery_ui() -> void:
	_gallery_view_root = Control.new()
	_gallery_view_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gallery_view_root.visible = false
	_ui_layer.add_child(_gallery_view_root)

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
		&"mona": "🌙 Mona", &"roxy": "🐺 Roxy", &"trixie": "🔥 Trixie",
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

	var back_btn: Button = _make_pill_button("🔥 VOLVER A HERVIR [ESPACIO]", Color(0.16, 0.48, 0.26), Color(0.54, 1.0, 0.58))
	back_btn.custom_minimum_size = Vector2(0, 66)
	back_btn.pressed.connect(_start_next_round_from_tree)
	rvbox.add_child(back_btn)


func _build_modals() -> void:
	_lightbox_overlay = ColorRect.new()
	_lightbox_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lightbox_overlay.color = Color(0.03, 0.02, 0.06, 0.92)
	_lightbox_overlay.visible = false
	_ui_layer.add_child(_lightbox_overlay)

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
	_ui_layer.add_child(_pause_overlay)

	var p_center: CenterContainer = CenterContainer.new()
	p_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(p_center)
	var p_panel: PanelContainer = _make_card_panel(Vector2.ZERO, Vector2(460, 380), Color(0.12, 0.08, 0.19, 0.98), Color(0.88, 0.68, 0.36))
	p_panel.custom_minimum_size = Vector2(460, 380)
	p_center.add_child(p_panel)

	var p_vbox: VBoxContainer = VBoxContainer.new()
	p_vbox.add_theme_constant_override("separation", 18)
	p_panel.get_child(0).add_child(p_vbox)
	var p_hdr: Label = _make_label("PAUSA", 34, Color(1.0, 0.88, 0.44))
	p_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_vbox.add_child(p_hdr)

	var res_btn: Button = _make_pill_button("REANUDAR", Color(0.18, 0.46, 0.28), Color(0.56, 1.0, 0.60))
	res_btn.custom_minimum_size = Vector2(0, 56)
	res_btn.pressed.connect(func() -> void: _pause_overlay.visible = false)
	var rst_btn: Button = _make_pill_button("REINICIAR PROTOTIPO", Color(0.46, 0.24, 0.16), Color(1.0, 0.72, 0.40))
	rst_btn.custom_minimum_size = Vector2(0, 56)
	rst_btn.pressed.connect(func() -> void:
		_pause_overlay.visible = false
		get_tree().reload_current_scene()
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
	_ui_layer.add_child(_victory_overlay)

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
		"¡Has destilado el Elixir Supremo de Trixie!\nLa botica es ahora la más famosa (y picante) del reino.\nPuedes seguir jugando para desbloquear el 100% de la Galería.",
		21, Color(0.96, 0.92, 0.98)
	)
	v_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var v_cont: Button = _make_pill_button("✨ SEGUIR JUGANDO Y VER GALERÍA", Color(0.56, 0.18, 0.38), Color(1.0, 0.84, 0.38))
	v_cont.custom_minimum_size = Vector2(0, 58)
	v_cont.pressed.connect(func() -> void:
		_victory_overlay.visible = false
		_switch_view(ViewMode.GALLERY)
	)
	v_vbox.add_child(v_hdr)
	v_vbox.add_child(v_body)
	v_vbox.add_child(v_cont)


# ==============================================================================
# UPGRADE TREE INTERACTION & DRAWING
# ==============================================================================

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
	for nd: Dictionary in tree_nodes:
		if pos.distance_to(nd["pos"] as Vector2) <= 46.0:
			return nd["id"] as StringName
	return &""


func _refresh_tree_detail_panel() -> void:
	if _tree_info_title == null or not _node_by_id.has(_tree_selected_id):
		return
	var nd: Dictionary = _node_by_id[_tree_selected_id] as Dictionary
	var lvl: int = get_node_level(_tree_selected_id)
	var max_lvl: int = int(nd["max_level"])
	var cost: int = get_node_cost(_tree_selected_id)
	var unlocked: bool = is_node_unlocked(_tree_selected_id)

	_tree_info_title.text = "%s %s  (Nv. %d / %d)" % [String(nd["icon"]), String(nd["name"]), lvl, max_lvl]
	_tree_info_desc.text = String(nd["short_desc"])
	if lvl >= max_lvl:
		_tree_info_stats.text = "Estado: ¡MÁXIMO ALCANZADO!"
		_tree_buy_btn.text = "NIVEL MÁXIMO"
		_tree_buy_btn.disabled = true
	elif not unlocked:
		var p_id: StringName = nd.get("parent_id", &"") as StringName
		var p_name: String = String((_node_by_id[p_id] as Dictionary)["name"]) if _node_by_id.has(p_id) else "Anterior"
		_tree_info_stats.text = "Bloqueado — Desbloquea primero: %s" % p_name
		_tree_buy_btn.text = "BLOQUEADO"
		_tree_buy_btn.disabled = true
	else:
		_tree_info_stats.text = "Siguiente nivel cuesta: %d✦ Esencia  (Tienes: %d✦)" % [cost, essence_gold]
		_tree_buy_btn.text = "MEJORAR (%d✦)" % cost
		_tree_buy_btn.disabled = essence_gold < cost


func _draw_upgrade_tree() -> void:
	if _tree_canvas == null:
		return
	var font: Font = ThemeDB.fallback_font
	for gx: int in range(80, 1920, 120):
		_tree_canvas.draw_line(Vector2(gx, 76), Vector2(gx, 882), Color(1, 1, 1, 0.03), 1.0)
	for gy: int in range(120, 880, 120):
		_tree_canvas.draw_line(Vector2(0, gy), Vector2(1920, gy), Color(1, 1, 1, 0.03), 1.0)

	for nd: Dictionary in tree_nodes:
		var nid: StringName = nd["id"] as StringName
		var p_id: StringName = nd.get("parent_id", &"") as StringName
		if p_id == &"" or not _node_by_id.has(p_id):
			continue
		var p_pos: Vector2 = (_node_by_id[p_id] as Dictionary)["pos"] as Vector2
		var n_pos: Vector2 = nd["pos"] as Vector2
		var col: Color = nd["color"] as Color
		var unlocked: bool = is_node_unlocked(nid)
		var owned: bool = get_node_level(nid) > 0
		var line_col: Color = col if owned else (Color(col.r, col.g, col.b, 0.45) if unlocked else Color(0.28, 0.24, 0.34, 0.45))
		_tree_canvas.draw_line(p_pos, n_pos, line_col, 5.5 if owned else (3.5 if unlocked else 2.0), true)

	for nd: Dictionary in tree_nodes:
		var nid: StringName = nd["id"] as StringName
		var pos: Vector2 = nd["pos"] as Vector2
		var col: Color = nd["color"] as Color
		var lvl: int = get_node_level(nid)
		var max_lvl: int = int(nd["max_level"])
		var unlocked: bool = is_node_unlocked(nid)
		var affordable: bool = can_buy_node(nid)
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
		var sub_txt: String = "MAX" if lvl >= max_lvl else ("%d/%d · %d✦" % [lvl, max_lvl, get_node_cost(nid)] if unlocked else "🔒")
		var sub_col: Color = Color(1.0, 0.88, 0.36) if affordable else (Color(0.55, 0.96, 0.68) if lvl >= max_lvl else Color(0.75, 0.72, 0.84))
		_tree_canvas.draw_string(font, pos + Vector2(-65, 74), sub_txt, HORIZONTAL_ALIGNMENT_CENTER, 130, 13, sub_col)


# ==============================================================================
# GALLERY VIEW
# ==============================================================================

func _refresh_gallery_panel() -> void:
	if _gallery_title_lbl == null:
		return
	for cid: StringName in _gallery_char_buttons.keys():
		(_gallery_char_buttons[cid] as Button).modulate = Color(1.0, 0.92, 0.55) if cid == _gallery_selected_char_id else Color(0.82, 0.78, 0.90)

	var pts: int = get_affinity_points(_gallery_selected_char_id)
	var lvl: int = get_affinity_level(_gallery_selected_char_id)
	var next_req: int = AFFINITY_THRESHOLDS[mini(lvl, AFFINITY_THRESHOLDS.size() - 1)]

	var char_name: String = "Trixie"
	var role_txt: String = "Bruja del Caldero"
	var quotes: PackedStringArray = PackedStringArray([
		"¡El caldero apenas comienza a calentarse!",
		"¡Encadena el color afín y mira cómo llueve el oro!",
	])
	if _gallery_selected_char_id != &"trixie":
		for c: CustomerArchetypeData in customers_catalog:
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
	_gallery_gift_btn.disabled = (essence_gold < gift_cost) or (lvl >= 3)

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
	var lvl: int = get_affinity_level(_gallery_selected_char_id)
	var cost: int = 40 * (lvl + 1)
	if essence_gold < cost or lvl >= 3:
		return
	essence_gold -= cost
	_emit_gold_changed(essence_gold, -cost)
	var leveled: bool = _add_affinity(_gallery_selected_char_id, 2)
	_play_pentatonic(6 if leveled else 4, -1.0)
	_refresh_gallery_panel()


func _open_gallery_lightbox(cid: StringName, scene_idx: int, title_txt: String) -> void:
	_gallery_selected_char_id = cid
	_lightbox_scene_idx = scene_idx
	_lightbox_title_lbl.text = "💋 %s — %s" % [cid.capitalize(), title_txt]
	var captions: Array[String] = [
		"Un momento íntimo junto al mostrador mientras el caldero chisporrotea suavemente.",
		"El aroma dulce del elixir llena la botica y sube el rubor de la noche.",
		"Escena especial de afinidad máxima. ¡Lista para reemplazar con tu ilustración final de Krita!",
	]
	_lightbox_caption_lbl.text = captions[clampi(scene_idx, 0, captions.size() - 1)]
	_lightbox_overlay.visible = true
	_lightbox_canvas.queue_redraw()


# ==============================================================================
# WORLD DRAWING (16:9 MOCKUP LAYOUT, CAULDRON, VERTICAL TUBE, WAIFUS)
# ==============================================================================

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.08, 0.05, 0.13))
	draw_circle(CAULDRON_CENTER, 450.0, Color(0.56, 0.18, 0.42, 0.14) if _frenzy_timer > 0.0 else Color(0.26, 0.14, 0.42, 0.12))

	if view_mode != ViewMode.CAULDRON:
		return

	_draw_trixie_stage_left()
	_draw_customer_stage_right()
	_draw_vertical_potion_tube()

	var shake_v: Vector2 = Vector2(randf_range(-_cauldron_shake, _cauldron_shake), randf_range(-_cauldron_shake, _cauldron_shake)) if _cauldron_shake > 0.2 else Vector2.ZERO
	var c_pos: Vector2 = CAULDRON_CENTER + shake_v

	if _cauldron_tex != null:
		draw_texture_rect(_cauldron_tex, Rect2(c_pos - Vector2(385, 360), Vector2(770, 745)), false, Color(0.75, 0.68, 0.85, 0.30))

	# Outer rim & rotating rune glow
	draw_circle(c_pos, CAULDRON_RADIUS + 20.0, Color(0.16, 0.12, 0.22))
	draw_arc(c_pos, CAULDRON_RADIUS + 20.0, 0.0, TAU, 64, Color(0.88, 0.68, 0.34, 0.88), 6.0)
	draw_arc(c_pos, CAULDRON_RADIUS + 8.0, _time * 0.28, _time * 0.28 + TAU * 0.80, 48,
		Color(1.0, 0.40, 0.72, 0.65) if _frenzy_timer > 0.0 else Color(0.42, 0.84, 1.0, 0.35), 3.0)

	# Potion liquid inside cauldron
	var liq_col: Color = Color(0.24, 0.09, 0.28) if _frenzy_timer > 0.0 else Color(0.11, 0.09, 0.22)
	draw_circle(c_pos, CAULDRON_RADIUS, liq_col)
	draw_circle(c_pos, CAULDRON_RADIUS * 0.76, liq_col.lightened(0.08))

	for st: Dictionary in _ambient_steam:
		var spos: Vector2 = c_pos + Vector2(float(st["x"]), float(st["y"]))
		if spos.distance_to(c_pos) < CAULDRON_RADIUS - 16.0:
			var a: float = 0.08 + 0.08 * sin(_time * 2.0 + float(st["phase"]))
			draw_circle(spos, float(st["r"]), Color(0.72, 0.58, 0.98, a))

	# Draw drag chain preview line underneath orbs
	if _is_dragging and not _drag_chain.is_empty():
		var pts: PackedVector2Array = PackedVector2Array()
		for idx: int in _drag_chain:
			if idx >= 0 and idx < _orbs.size():
				pts.append((_orbs[idx]["pos"] as Vector2) + shake_v)
		pts.append(_mouse_pos)
		if pts.size() >= 2:
			draw_polyline(pts, Color(0.45, 0.96, 1.0, 0.88), 6.5, true)

	# Draw orbs with unmistakable AFÍN / NEUTRO / ❌ RESTA readability
	for i: int in range(_orbs.size()):
		_draw_alchemy_orb(i, _orbs[i], shake_v)

	# Shockwaves & lightning arcs
	for sw: Dictionary in _shockwaves:
		var alpha: float = clampf(float(sw["life"]) / maxf(0.01, float(sw["max_life"])), 0.0, 1.0)
		var scol: Color = sw["color"] as Color
		draw_arc((sw["pos"] as Vector2) + shake_v, float(sw["radius"]), 0.0, TAU, 36, Color(scol.r, scol.g, scol.b, alpha * 0.85), 4.5 * alpha)

	for arc: Dictionary in _lightning_arcs:
		var alpha: float = clampf(float(arc["life"]) / maxf(0.01, float(arc["max_life"])), 0.0, 1.0)
		var acol: Color = arc["color"] as Color
		var p0: Vector2 = (arc["from"] as Vector2) + shake_v
		var p1: Vector2 = (arc["to"] as Vector2) + shake_v
		var mid: Vector2 = (p0 + p1) * 0.5 + Vector2(randf_range(-14, 14), randf_range(-14, 14))
		draw_polyline(PackedVector2Array([p0, mid, p1]), Color(acol.r, acol.g, acol.b, alpha), 3.8)

	# Smart Familiars around the cauldron
	if fam_michi_lvl > 0:
		var mp: Vector2 = _get_michi_pos() + shake_v
		draw_circle(mp, 21.0, Color(1.0, 0.72, 0.92, 0.28))
		draw_circle(mp, 14.0, Color(1.0, 0.86, 0.95))
		draw_colored_polygon(PackedVector2Array([mp + Vector2(-10, -8), mp + Vector2(-14, -20), mp + Vector2(-3, -12)]), Color(0.95, 0.62, 0.85))
		draw_colored_polygon(PackedVector2Array([mp + Vector2(10, -8), mp + Vector2(14, -20), mp + Vector2(3, -12)]), Color(0.95, 0.62, 0.85))
	if fam_imp_lvl > 0:
		var ip: Vector2 = _get_imp_pos() + shake_v
		draw_circle(ip, 21.0, Color(1.0, 0.36, 0.24, 0.30))
		draw_circle(ip, 14.0, Color(0.92, 0.24, 0.36))
		draw_colored_polygon(PackedVector2Array([ip + Vector2(-9, -9), ip + Vector2(-15, -22), ip + Vector2(-2, -12)]), Color(0.28, 0.08, 0.14))
		draw_colored_polygon(PackedVector2Array([ip + Vector2(9, -9), ip + Vector2(15, -22), ip + Vector2(2, -12)]), Color(0.28, 0.08, 0.14))
	if fam_bat_lvl > 0:
		var bp: Vector2 = _get_bat_pos() + shake_v
		draw_circle(bp, 18.0, Color(0.70, 0.50, 1.0, 0.30))
		draw_circle(bp, 12.0, Color(0.42, 0.24, 0.66))

	# COMBO badge above top-right of cauldron (just like the 16:9 mockup!)
	var font: Font = ThemeDB.fallback_font
	if _combo > 0:
		draw_string(font, Vector2(1110, 148), "COMBO", HORIZONTAL_ALIGNMENT_CENTER, 170, 26, Color(1.0, 0.88, 0.36))
		draw_string(font, Vector2(1110, 194), "x%d!" % _combo, HORIZONTAL_ALIGNMENT_CENTER, 170, 44, Color(1.0, 0.56, 0.28))

	if _is_dragging and _drag_chain.size() >= 2:
		var mult_preview: float = _calc_chain_multiplier(_drag_chain.size())
		draw_string(font, _mouse_pos + Vector2(-70, -42), "CADENA x%d (%.1fx)" % [_drag_chain.size(), mult_preview], HORIZONTAL_ALIGNMENT_CENTER, 180, 18, Color(0.45, 0.96, 1.0))

	# Floating popups
	for p: Dictionary in _popups:
		var pos: Vector2 = p["pos"] as Vector2
		var txt: String = p["text"] as String
		var pcol: Color = p["color"] as Color
		var alpha: float = clampf(float(p["life"]), 0.0, 1.0)
		draw_string(font, pos + Vector2(2, 2), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(0.04, 0.02, 0.08, alpha))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(pcol.r, pcol.g, pcol.b, alpha))


func _draw_alchemy_orb(idx: int, o: Dictionary, shake_v: Vector2) -> void:
	var pos: Vector2 = (o["pos"] as Vector2) + shake_v
	var r: float = float(o["radius"]) * float(o["scale_pop"])
	var kind: int = int(o["kind"])
	var rel: StringName = get_orb_relation(kind)
	var col: Color = get_element_color(kind)
	var in_chain: bool = _drag_chain.has(idx)
	var hovered: bool = (idx == _hovered_orb_idx)

	# Relation outer ring: LIKED gets bright golden halo; DISLIKED gets dark warning ring
	if rel == &"liked":
		var p: float = 0.65 + 0.35 * sin(_time * 4.5 + float(o["phase"]))
		draw_circle(pos, r + 9.0, Color(1.0, 0.88, 0.34, 0.22 * p))
		draw_arc(pos, r + 5.0, 0.0, TAU, 28, Color(1.0, 0.90, 0.38, 0.88), 2.8)
	elif rel == &"disliked":
		draw_arc(pos, r + 4.0, 0.0, TAU, 28, Color(0.14, 0.04, 0.08, 0.92), 4.0)

	if in_chain or hovered:
		draw_arc(pos, r + 9.0, 0.0, TAU, 28, Color(0.45, 0.96, 1.0) if in_chain else Color.WHITE, 3.5)

	draw_circle(pos, r, col.darkened(0.22) if rel == &"disliked" else col)
	draw_arc(pos, r, 0.0, TAU, 28, col.lightened(0.45), 2.5)
	draw_circle(pos + Vector2(-r * 0.32, -r * 0.32), r * 0.26, Color(1, 1, 1, 0.58))

	# Crisp symbol in center so colorblind or fast-glancing players read elements & ❌ at 1 glance
	var font: Font = ThemeDB.fallback_font
	var glyph: String = "🔥" if kind == BubbleKind.RED else ("🌙" if kind == BubbleKind.BLUE else ("🍃" if kind == BubbleKind.GREEN else ("⭐" if kind == BubbleKind.GOLD else "💣")))
	draw_string(font, pos + Vector2(-14, 9), glyph, HORIZONTAL_ALIGNMENT_CENTER, 28, 22, Color.WHITE)

	if rel == &"disliked":
		draw_circle(pos + Vector2(r * 0.62, -r * 0.62), 11.0, Color(0.86, 0.14, 0.20))
		draw_string(font, pos + Vector2(r * 0.62 - 6, -r * 0.62 + 5), "✕", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _draw_vertical_potion_tube() -> void:
	var r: Rect2 = TUBE_RECT
	var liked_col: Color = get_element_color(int(get_customer_chemistry()["liked"]))
	var pct: float = clampf(_potion_tube_pct / 100.0, 0.0, 1.0)

	# Glass tube body
	draw_rect(r, Color(0.08, 0.06, 0.14, 0.90))
	if pct > 0.0:
		var fill_h: float = r.size.y * pct
		var fill_rect: Rect2 = Rect2(r.position.x + 5, r.position.y + r.size.y - fill_h, r.size.x - 10, fill_h)
		var fill_col: Color = liked_col.lightened(0.18) if (_tube_flash_timer > 0.0 and _tube_flash_positive) else (Color(1.0, 0.24, 0.28) if (_tube_flash_timer > 0.0 and not _tube_flash_positive) else liked_col)
		draw_rect(fill_rect, fill_col)
		# Meniscus glow
		draw_rect(Rect2(fill_rect.position.x, fill_rect.position.y, fill_rect.size.x, 6.0), Color(1, 1, 1, 0.65))

	# Tick marks & glass rim
	for mark: float in [0.25, 0.50, 0.75]:
		var my: float = r.position.y + r.size.y * (1.0 - mark)
		draw_line(Vector2(r.position.x + 4, my), Vector2(r.position.x + 20, my), Color(1, 1, 1, 0.45), 2.0)

	draw_rect(r, Color(0.78, 0.84, 0.96, 0.85), false, 3.5)
	# Cork stopper at top
	draw_rect(Rect2(r.position.x + 8, r.position.y - 16, r.size.x - 16, 16), Color(0.68, 0.46, 0.26))
	# Percentage badge below tube
	draw_string(ThemeDB.fallback_font, Vector2(r.position.x - 12, r.position.y + r.size.y + 34), "%d%%" % int(roundf(_potion_tube_pct)), HORIZONTAL_ALIGNMENT_CENTER, 78, 24, Color(1.0, 0.94, 0.78))


func _draw_trixie_stage_left() -> void:
	var frame: Rect2 = Rect2(24, 96, 402, 540)
	draw_rect(frame, Color(0.14, 0.08, 0.22, 0.88))
	draw_rect(frame, Color(0.92, 0.56, 0.40, 0.78), false, 3.0)
	draw_circle(Vector2(225, 430), 165.0, Color(0.84, 0.28, 0.48, 0.18 if _frenzy_timer <= 0.0 else 0.36))
	CharacterArt.draw_trixie_bust(self, Rect2(32, 108, 386, 520), _trixie_emotion, _time, 1.0, "cutscene")


func _draw_customer_stage_right() -> void:
	var slide_off: float = (1.0 - _customer_slide_t) * 140.0
	var frame: Rect2 = Rect2(1408 + slide_off, 96, 486, 460)
	var border_col: Color = Color(1.0, 0.45, 0.78) if _customer_flash_timer > 0.0 else Color(0.84, 0.62, 0.92, 0.78)
	draw_rect(frame, Color(0.13, 0.08, 0.21, 0.88))
	draw_rect(frame, border_col, false, 3.5)
	if _active_customer != null:
		_draw_expressive_waifu_bust(self, frame.grow(-8), _active_customer.customer_id, _customer_spicy_mode or _customer_flash_timer > 0.0, _time)


func _draw_gallery_portrait() -> void:
	if _gallery_portrait_canvas == null:
		return
	var r: Rect2 = Rect2(Vector2.ZERO, _gallery_portrait_canvas.size)
	_gallery_portrait_canvas.draw_rect(r, Color(0.14, 0.09, 0.22))
	_gallery_portrait_canvas.draw_rect(r, Color(0.94, 0.64, 0.82, 0.6), false, 2.0)
	if _gallery_selected_char_id == &"trixie":
		CharacterArt.draw_trixie_full(_gallery_portrait_canvas, Vector2(r.size.x * 0.5, r.size.y - 22.0), 1.02, "sonrojada", _time, 1.0)
	else:
		_draw_expressive_waifu_bust(_gallery_portrait_canvas, r.grow(-12), _gallery_selected_char_id, get_affinity_level(_gallery_selected_char_id) >= 2, _time)


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
	else:
		_draw_expressive_waifu_bust(ci, r.grow(-10), cid, scene_idx >= 1, _time)


func _draw_lightbox_scene() -> void:
	if _lightbox_canvas == null:
		return
	var r: Rect2 = Rect2(Vector2.ZERO, _lightbox_canvas.size)
	_lightbox_canvas.draw_rect(r, Color(0.14, 0.07, 0.20))
	_lightbox_canvas.draw_circle(r.size * 0.5, 250.0, Color(1.0, 0.42, 0.74, 0.20))
	if _gallery_selected_char_id == &"trixie":
		CharacterArt.draw_trixie_bust(_lightbox_canvas, Rect2(r.size.x * 0.5 - 295.0, r.size.y - 520.0, 590.0, 510.0), "sonrojada" if _lightbox_scene_idx == 2 else ("confiada" if _lightbox_scene_idx == 1 else "normal"), _time, 1.0, "cutscene")
	else:
		_draw_expressive_waifu_bust(_lightbox_canvas, Rect2(r.size.x * 0.5 - 240.0, 20.0, 480.0, r.size.y - 30.0), _gallery_selected_char_id, _lightbox_scene_idx >= 1, _time)


func _draw_expressive_waifu_bust(ci: CanvasItem, rect: Rect2, cid: StringName, spicy: bool, t: float) -> void:
	var s: float = minf(rect.size.x / 360.0, rect.size.y / 440.0)
	var center: Vector2 = rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.56 + sin(t * 2.1) * 3.0)
	var skin: Color = Color(1.0, 0.87, 0.79)
	var outline: Color = Color(0.09, 0.05, 0.14)
	var hair_col: Color = Color(0.72, 0.42, 0.26)
	var outfit_col: Color = Color(0.28, 0.62, 0.42)
	var eye_col: Color = Color(0.24, 0.68, 0.42)
	match cid:
		&"velvet":
			hair_col = Color(0.56, 0.12, 0.28); outfit_col = Color(0.22, 0.08, 0.20); eye_col = Color(0.95, 0.28, 0.54)
		&"seraphina":
			hair_col = Color(0.96, 0.84, 0.48); outfit_col = Color(0.84, 0.86, 0.94); eye_col = Color(0.26, 0.62, 0.96)
		&"mona":
			hair_col = Color(0.22, 0.20, 0.44); outfit_col = Color(0.32, 0.20, 0.52); eye_col = Color(0.74, 0.36, 0.98)
		&"roxy":
			hair_col = Color(0.52, 0.34, 0.24); outfit_col = Color(0.62, 0.24, 0.22); eye_col = Color(0.96, 0.68, 0.20)

	ci.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-88, -110) * s, center + Vector2(88, -110) * s,
		center + Vector2(115, 110) * s, center + Vector2(-115, 110) * s,
	]), hair_col.darkened(0.15))
	ci.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-112, 165) * s, center + Vector2(112, 165) * s,
		center + Vector2(78, 32) * s, center + Vector2(-78, 32) * s,
	]), outfit_col)
	ci.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-38, 32) * s, center + Vector2(38, 32) * s, center + Vector2(0, 86) * s,
	]), skin)
	ci.draw_rect(Rect2(center + Vector2(-14, -14) * s, Vector2(28, 48) * s), skin)
	ci.draw_circle(center + Vector2(0, -68) * s, 68.0 * s, skin)
	ci.draw_circle(center + Vector2(0, -68) * s, 68.0 * s, outline, false, 3.5 * s)

	match cid:
		&"sylvi":
			ci.draw_arc(center + Vector2(-56, -112) * s, 28.0 * s, 0.2, PI * 1.3, 14, Color(0.72, 0.52, 0.34), 10.0 * s)
			ci.draw_arc(center + Vector2(56, -112) * s, 28.0 * s, -PI * 0.3, PI * 0.8, 14, Color(0.72, 0.52, 0.34), 10.0 * s)
		&"velvet":
			ci.draw_colored_polygon(PackedVector2Array([center + Vector2(-34, -124) * s, center + Vector2(-68, -182) * s, center + Vector2(-12, -130) * s]), Color(0.18, 0.06, 0.14))
			ci.draw_colored_polygon(PackedVector2Array([center + Vector2(34, -124) * s, center + Vector2(68, -182) * s, center + Vector2(12, -130) * s]), Color(0.18, 0.06, 0.14))
		&"seraphina":
			ci.draw_arc(center + Vector2(0, -158) * s, 44.0 * s, 0.0, TAU, 24, Color(1.0, 0.88, 0.32), 6.0 * s)
		&"mona":
			ci.draw_colored_polygon(PackedVector2Array([center + Vector2(-84, -114) * s, center + Vector2(84, -114) * s, center + Vector2(0, -206) * s]), Color(0.18, 0.16, 0.36))
		&"roxy":
			ci.draw_colored_polygon(PackedVector2Array([center + Vector2(-52, -114) * s, center + Vector2(-74, -178) * s, center + Vector2(-18, -128) * s]), hair_col)
			ci.draw_colored_polygon(PackedVector2Array([center + Vector2(52, -114) * s, center + Vector2(74, -178) * s, center + Vector2(18, -128) * s]), hair_col)

	ci.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-66, -114) * s, center + Vector2(66, -114) * s,
		center + Vector2(52, -82) * s, center + Vector2(14, -96) * s,
		center + Vector2(0, -78) * s, center + Vector2(-14, -96) * s, center + Vector2(-52, -82) * s,
	]), hair_col)

	for ex: float in [-24.0, 24.0]:
		var ep: Vector2 = center + Vector2(ex, -68) * s
		ci.draw_circle(ep, 11.0 * s, Color.WHITE)
		ci.draw_circle(ep, 8.0 * s, eye_col)
		ci.draw_circle(ep, 4.0 * s, outline)
		ci.draw_circle(ep + Vector2(-3.0, -3.0) * s, 2.8 * s, Color.WHITE)

	var blush_a: float = 0.72 if spicy else 0.34
	ci.draw_circle(center + Vector2(-34, -46) * s, 14.0 * s, Color(1.0, 0.38, 0.54, blush_a))
	ci.draw_circle(center + Vector2(34, -46) * s, 14.0 * s, Color(1.0, 0.38, 0.54, blush_a))
	ci.draw_arc(center + Vector2(0, -40) * s, 12.0 * s, 0.15, PI - 0.15, 10, Color(0.66, 0.16, 0.24), 3.0 * s)
	if spicy:
		var heart_y: float = -126.0 * s - absf(sin(t * 4.0)) * 10.0 * s
		ci.draw_string(ThemeDB.fallback_font, center + Vector2(56 * s, heart_y), "♥", HORIZONTAL_ALIGNMENT_LEFT, -1, int(26.0 * s), Color(1.0, 0.42, 0.70))


# ==============================================================================
# HUD REFRESH & HELPERS
# ==============================================================================

func _refresh_hud_labels() -> void:
	if _top_essence_lbl == null:
		return
	_top_essence_lbl.text = "✦ %d" % essence_gold
	_top_round_lbl.text = "Ronda %d  ·  Pedidos: %d" % [round_number, orders_completed]
	var secs_int: int = ceili(round_time_left)
	_top_timer_lbl.text = "0:%02d" % secs_int
	_top_timer_lbl.modulate = Color(1.0, 0.42, 0.42) if secs_int <= 5 else Color(1.0, 0.94, 0.78)

	var affordable: int = count_affordable_nodes()
	if _tree_badge_panel != null:
		_tree_badge_panel.visible = affordable > 0
		if _tab_tree_btn != null and _tree_badge_panel.visible:
			_tree_badge_panel.position = _tab_tree_btn.global_position + Vector2(_tab_tree_btn.size.x - 16.0, -4.0)

	if _trixie_speech_lbl != null:
		_trixie_speech_lbl.text = _trixie_line
	if _frenzy_bar != null:
		_frenzy_bar.value = 100.0 if _frenzy_timer > 0.0 else _frenzy_charge
	if _frenzy_btn != null:
		if _frenzy_timer > 0.0:
			_frenzy_btn.text = "🔥 ¡FRENESÍ x2 ACTIVO! (%.1fs)" % _frenzy_timer
			_frenzy_btn.disabled = true
		elif _frenzy_charge >= 100.0:
			_frenzy_btn.text = "💥 ¡ACTIVAR FRENESÍ x2! [ESPACIO]"
			_frenzy_btn.disabled = false
		else:
			_frenzy_btn.text = "FRENESÍ (%d%%)" % int(_frenzy_charge)
			_frenzy_btn.disabled = true

	if _active_customer != null and _cust_name_lbl != null:
		var cid: StringName = _active_customer.customer_id
		var chem: Dictionary = get_customer_chemistry()
		_cust_name_lbl.text = "%s (%s)" % [_active_customer.display_name, _active_customer.species_archetype]
		_cust_aff_lbl.text = "❤ Nv.%d · +%d✦" % [get_affinity_level(cid), _customer_order_reward]
		_cust_liked_lbl.text = "✨ AFÍN (+22%)\n" + get_element_name(int(chem["liked"]))
		_cust_neutral_lbl.text = "⚪ NEUTRO (+7%)\n" + get_element_name(int(chem["neutral"]))
		_cust_disliked_lbl.text = "❌ RESTA (-18%)\n" + get_element_name(int(chem["disliked"]))
		_cust_speech_lbl.text = _customer_line


func _spawn_popup(world_pos: Vector2, txt: String, col: Color) -> void:
	_popups.append({"pos": world_pos, "text": txt, "color": col, "life": 0.95})


func _update_popups(delta: float) -> void:
	var idx: int = 0
	while idx < _popups.size():
		_popups[idx]["life"] = float(_popups[idx]["life"]) - delta
		_popups[idx]["pos"] = (_popups[idx]["pos"] as Vector2) + Vector2(0, -34.0 * delta)
		if float(_popups[idx]["life"]) <= 0.0:
			_popups.remove_at(idx)
			continue
		idx += 1


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


# ==============================================================================
# AUTOLOAD SAFE HELPERS & SMOKE TEST API
# ==============================================================================

func _bus() -> Node:
	return get_node_or_null("/root/EventBus")


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


func _emit_gold_changed(new_total: int, delta_val: int) -> void:
	var b: Node = _bus()
	if b != null:
		b.emit_signal("gold_changed", new_total, delta_val)


## Exercises zero-autoclicker tactical chemistry, purge, chains, Frenzy, and tree buys.
func run_incremental_smoke_step() -> Dictionary:
	var initial_cap_ok: bool = (spawn_cap == 6 and _orbs.size() == 6)

	# 1) Verify mouse movement alone causes zero passive extraction
	var tube_before: float = _potion_tube_pct
	var ess_before: int = essence_gold
	_process_cauldron_gameplay(0.1)
	var no_autoclicker_ok: bool = (_potion_tube_pct == tube_before and essence_gold == ess_before)

	# 2) Ensure deterministic orbs for Liked, Disliked, and Chain tests
	var chem: Dictionary = get_customer_chemistry()
	var liked_k: int = int(chem["liked"])
	var disliked_k: int = int(chem["disliked"])

	_orbs.clear()
	_orbs.append({"pos": CAULDRON_CENTER, "vel": Vector2.ZERO, "radius": ORB_RADIUS, "kind": liked_k, "scale_pop": 1.0, "phase": 0.0})
	_orbs.append({"pos": CAULDRON_CENTER + Vector2(90, 0), "vel": Vector2.ZERO, "radius": ORB_RADIUS, "kind": disliked_k, "scale_pop": 1.0, "phase": 0.0})
	_orbs.append({"pos": CAULDRON_CENTER + Vector2(0, 90), "vel": Vector2.ZERO, "radius": ORB_RADIUS, "kind": disliked_k, "scale_pop": 1.0, "phase": 0.0})

	# Extract single Liked orb -> raises tube & combo
	_resolve_orb_indices_as_chain([0])
	var liked_raised_tube: bool = _potion_tube_pct > 15.0 and _combo == 1

	# Purge one Disliked orb with Right-click helper -> preserves combo
	_purge_orb_at(1)
	var purge_kept_combo: bool = (_combo == 1 and _potion_tube_pct > 15.0)

	# Extract remaining Disliked orb -> lowers tube & resets combo to 0
	var tube_pre_bad: float = _potion_tube_pct
	_resolve_orb_indices_as_chain([0])
	var disliked_lowered_tube: bool = _potion_tube_pct < tube_pre_bad
	var disliked_reset_combo: bool = (_combo == 0)

	# 3) Chain 2+ Liked orbs to complete customer order & charge Frenzy
	_orbs.clear()
	for idx_l: int in range(6):
		_orbs.append({"pos": CAULDRON_CENTER + Vector2(float(idx_l) * 50.0 - 125.0, 0.0), "vel": Vector2.ZERO, "radius": ORB_RADIUS, "kind": liked_k, "scale_pop": 1.0, "phase": 0.0})
	_resolve_orb_indices_as_chain([0, 1, 2, 3])
	_resolve_orb_indices_as_chain([0, 1])

	# Trigger Frenzy when full (or top up if needed)
	if _frenzy_charge < 100.0:
		_frenzy_charge = 100.0
	var frenzy_triggered: bool = try_activate_frenzy()

	# 4) Buy upgrades in the tree
	var bought_aroma: bool = buy_incremental_node(&"aroma_concentrado")
	var bought_boil: bool = buy_incremental_node(&"hervor_creciente")

	return {
		"initial_cap_ok": initial_cap_ok,
		"no_autoclicker_ok": no_autoclicker_ok,
		"liked_raised_tube": liked_raised_tube,
		"purge_kept_combo": purge_kept_combo,
		"disliked_lowered_tube": disliked_lowered_tube,
		"disliked_reset_combo": disliked_reset_combo,
		"orders_completed": orders_completed,
		"frenzy_triggered": frenzy_triggered,
		"bought_aroma": bought_aroma,
		"bought_boil": bought_boil,
		"nodes_count": tree_nodes.size(),
	}
