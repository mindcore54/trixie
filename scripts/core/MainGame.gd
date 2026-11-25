class_name MainGame
extends Node2D
## Tactical 2D Alchemy Incremental Cauldron Stage (Zero Autoclicker).
## Mechanics:
## - Left-click (tap) on an orb deals hits (3 hits -> 2 -> 1 with upgrades) to crack and break it.
## - Upgrade "Toque Continuo" lets you hold Left-Click steady on a chosen orb to auto-hit rapidly.
## - Drag/Lift an orb cleanly over another compatible orb to combine colors (e.g. Red + Green -> Yellow)
##   or concentrate same-color orbs into x2/x3 orbs! Damage never fires on press so lifting is 100% safe.
## - Right-click (tap or hold) purges unwanted orbs safely without hurting the potion tube or combo.
## - Active Customer sets Color Chemistry (pure or mixed): LIKED (+tube, +essence, +Frenzy),
##   INGREDIENT / NEUTRAL (safe mix fuel / mild progress), DISLIKED (-18% tube, resets combo).
## - Frenzy transmutes all DISLIKED orbs into LIKED orbs (1-hit ready) and doubles output with 1-hit breaks!
## - Completing the stop's customer wave (or running out of time) triggers a short closing dialogue
##   followed by a smooth fade to WorldMap.tscn (where the Skill Tree & Gallery live).

const BubbleKind = ChemistryRules.BubbleKind
const GameStateScript: GDScript = preload("res://scripts/autoloads/GameState.gd")

const VIEWPORT_SIZE: Vector2 = Vector2(1920.0, 1080.0)
const CAULDRON_CENTER: Vector2 = Vector2(880.0, 564.0)
const CAULDRON_ELLIPSE_RX: float = 296.0
const CAULDRON_ELLIPSE_RY: float = 260.0
const CAULDRON_RADIUS: float = 296.0
const CAULDRON_DRAW_SIZE: Vector2 = Vector2(840.0, 804.0)
const CAULDRON_HOLE_OFFSET: Vector2 = Vector2(419.0, 351.0)
const ORB_RADIUS: float = 34.0
const BASE_CUSTOMER_PATIENCE: float = 30.0
const USE_PER_CUSTOMER_PATIENCE: bool = false
const CUSTOMER_IMPATIENT_RATIO: float = 0.30
const CAULDRON_TEX_PATH: String = "res://assets/props/stations/cauldron_main.png"
const ORB_TEX_DIR: String = "res://assets/props/items/orbs/"
const ORB_CANVAS_MULT: float = 1.067
const ORB_BOMB_DRAW_MULT: float = 1.467

const DRAG_LIFT_THRESHOLD: float = 12.0
const HOLD_HIT_START_DELAY: float = 0.16
const RIGHT_PURGE_HOLD_INTERVAL: float = 0.13
const BASE_ORB_HP: int = 3
const AFFINITY_THRESHOLDS: Array[int] = [3, 7, 12]

# Local fallback state when instantiated standalone without autoloads
var _local_state: Node = null

# Catalogs
var witches: Array[WitchCharacterData] = []
var customers_catalog: Array[CustomerArchetypeData] = []
var tree_nodes: Array[Dictionary] = []

# Proxied progression properties (kept for clean access & headless tests)
var essence_gold: int:
	get: return _state().essence_gold
	set(v): _state().essence_gold = v

var total_essence_earned: int:
	get: return _state().total_essence_earned
	set(v): _state().total_essence_earned = v

var orders_completed: int:
	get: return _state().orders_completed
	set(v): _state().orders_completed = v

var node_levels: Dictionary:
	get: return _state().node_levels

var customer_affinity_pts: Dictionary:
	get: return _state().customer_affinity_pts

# Derived tactical stats synced from GameState
var spawn_cap: int = 6
var spawn_interval: float = 1.15
var hold_auto_hit_unlocked: bool = false
var hold_hit_interval: float = 0.36
var click_damage: int = 1
var strength_tube_bonus: float = 0.0
var aroma_essence_mult: float = 1.0
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

# Stop & wave runtime state
var round_number: int = 1
var customer_patience_max: float = BASE_CUSTOMER_PATIENCE
var customer_patience_left: float = BASE_CUSTOMER_PATIENCE
var _customer_impatient_warned: bool = false
var round_ending: bool = false
var _round_end_timer: float = 0.0
var _round_essence_gained: int = 0
var _round_orders_completed: int = 0

var _active_stop: Dictionary = {}
var _wave_customers: Array[StringName] = []
var _wave_index: int = 0
var _wave_served_count: int = 0
var _wave_missed_count: int = 0
var _wave_victory: bool = false
var _stop_essence_mult: float = 1.0
var _stop_affinity_bonus: int = 0
var _stop_spawn_rate_mult: float = 1.0
var _stop_bg_tint: Color = Color(0.08, 0.05, 0.13)
var _fading_out: bool = false

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

var _mouse_pos: Vector2 = CAULDRON_CENTER
var _next_orb_id: int = 1
var _hovered_orb_id: int = -1
var _left_down: bool = false
var _pressed_orb_id: int = -1
var _press_pos: Vector2 = Vector2.ZERO
var _press_elapsed: float = 0.0
var _is_lifting: bool = false
var _lifted_orb_id: int = -1
var _lift_hover_target_id: int = -1
var _hold_hitting: bool = false
var _hold_orb_id: int = -1
var _hold_hit_accum: float = 0.0
var _right_down: bool = false
var _right_purge_accum: float = 0.0

var _orbs: Array[Dictionary] = []
var _lightning_arcs: Array[Dictionary] = []
var _shockwaves: Array[Dictionary] = []
var _popups: Array[Dictionary] = []
var _ambient_steam: Array[Dictionary] = []

# Left (Trixie) & Right (Customer) state
var _trixie_emotion: String = "normal"
var _trixie_emotion_timer: float = 0.0
var _trixie_line: String = "3 clics para romper. Arrastra un orbe sobre otro para mezclar. Clic Der purga ❌."
var _trixie_react_anim: float = 0.0
var _disliked_mistake_streak: int = 0
var _disliked_streak_timer: float = 0.0

var _active_customer: CustomerArchetypeData
var _last_served_customer: CustomerArchetypeData
var _current_order_chemistry: Dictionary = {}
var _last_order_liked_kind: int = -1
var _potion_tube_pct: float = 0.0
var _customer_order_reward: int = 24
var _customer_line: String = "¡Necesito algo bien fuerte para esta noche!"
var _customer_spicy_mode: bool = false
var _customer_flash_timer: float = 0.0
var _customer_slide_t: float = 1.0
var _customer_emotion: String = "normal"
var _customer_emotion_timer: float = 0.0
var _customer_react_anim: float = 0.0

# In-game Cauldron Tutorial & Closing Dialogue state
var _tutorial: TutorialDirector = TutorialDirector.new()

# Closing Dialogue state before smooth fade to WorldMap
var _closing_active: bool = false
var _closing_lines: Array[Dictionary] = []
var _closing_idx: int = -1

# Scene nodes
@onready var camera: Camera2D = $Camera2D
@onready var _bg_sprite: Sprite2D = $StageBackground
@onready var _trixie_stage_slot: TextureRect = $TrixieStageSlot
@onready var _customer_stage_slot: TextureRect = $CustomerStageSlot
@onready var _fire_glow_rect: ColorRect = $CauldronFireGlow
@onready var _cauldron_preview: Sprite2D = $CauldronAnchor/CauldronPreview
@onready var _flask_view: PotionFlaskView = $PotionFlask
@onready var _hud: StageHUD = $UILayer

var _trixie_stage_rect: Rect2 = Rect2(-8.0, 124.0, 520.0, 816.0)
var _customer_stage_rect: Rect2 = Rect2(1404.0, 108.0, 520.0, 822.0)
var _cauldron_tex: Texture2D
var _stop_bg_tex: Texture2D = null
var _bg_shader_mat: ShaderMaterial = null
var _bg_frenzy_mix: float = 0.0
var _fire_shader_mat: ShaderMaterial = null
var _orb_textures: Dictionary = {}
var _crack_textures: Array[Texture2D] = []
var _crack_glow_textures: Array[Texture2D] = []


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
	randomize()
	var st: Node = _state()
	witches = st.get("witches_catalog") as Array[WitchCharacterData]
	customers_catalog = st.get("customers_catalog") as Array[CustomerArchetypeData]
	tree_nodes = st.get("tree_nodes") as Array[Dictionary]

	if _cauldron_preview != null:
		_cauldron_tex = _cauldron_preview.texture
		_cauldron_preview.visible = false
	if _cauldron_tex == null and ResourceLoader.exists(CAULDRON_TEX_PATH):
		_cauldron_tex = load(CAULDRON_TEX_PATH) as Texture2D

	if _trixie_stage_slot != null:
		_trixie_stage_rect = _trixie_stage_slot.get_rect()
		_trixie_stage_slot.visible = false
	if _customer_stage_slot != null:
		_customer_stage_rect = _customer_stage_slot.get_rect()
		_customer_stage_slot.visible = false

	if _bg_sprite != null:
		_bg_sprite.visible = false
		_bg_shader_mat = _bg_sprite.material as ShaderMaterial

	if _fire_glow_rect != null:
		_fire_shader_mat = _fire_glow_rect.material as ShaderMaterial
		if _fire_shader_mat == null:
			_fire_glow_rect.visible = false

	_load_orb_textures()

	var audio: Node = _audio()
	if audio != null and camera != null:
		audio.call("register_camera", camera)

	for _i: int in range(20):
		_ambient_steam.append({
			"x": randf_range(-CAULDRON_ELLIPSE_RX * 0.78, CAULDRON_ELLIPSE_RX * 0.78),
			"y": randf_range(-CAULDRON_ELLIPSE_RY * 0.62, CAULDRON_ELLIPSE_RY * 0.62),
			"r": randf_range(4.0, 12.0),
			"spd": randf_range(16.0, 34.0),
			"phase": randf_range(0.0, TAU),
		})

	_recalc_stats()
	_connect_hud()
	_start_stop()

	var fader: Node = _fader()
	if fader != null and bool(fader.call("is_black")):
		fader.call("fade_in", 0.45)

	if OS.get_cmdline_user_args().has("--smoke-test"):
		call_deferred("_run_cmdline_smoke_and_quit")


func _load_orb_textures() -> void:
	_orb_textures.clear()
	_crack_textures.clear()
	_crack_glow_textures.clear()
	var orb_files: Dictionary = {
		BubbleKind.RED: "orb_red.png",
		BubbleKind.BLUE: "orb_blue.png",
		BubbleKind.GREEN: "orb_green.png",
		BubbleKind.YELLOW: "orb_yellow.png",
		BubbleKind.PURPLE: "orb_purple.png",
		BubbleKind.CYAN: "orb_cyan.png",
		BubbleKind.GOLD: "orb_gold.png",
		BubbleKind.BOMB: "orb_bomb.png",
	}
	for k_var: Variant in orb_files.keys():
		var k: int = int(k_var)
		var p: String = ORB_TEX_DIR + String(orb_files[k])
		if ResourceLoader.exists(p):
			var t: Texture2D = load(p) as Texture2D
			if t != null:
				_orb_textures[k] = t

	for stage_idx: int in [1, 2]:
		var cp: String = "%sorb_crack_%d.png" % [ORB_TEX_DIR, stage_idx]
		var gp: String = "%sorb_crack_%d_glow.png" % [ORB_TEX_DIR, stage_idx]
		if ResourceLoader.exists(cp):
			var ct: Texture2D = load(cp) as Texture2D
			if ct != null:
				_crack_textures.append(ct)
		if ResourceLoader.exists(gp):
			var gt: Texture2D = load(gp) as Texture2D
			if gt != null:
				_crack_glow_textures.append(gt)


func _run_cmdline_smoke_and_quit() -> void:
	await get_tree().process_frame
	var res: Dictionary = run_incremental_smoke_step()
	print("INCREMENTAL SMOKE => ", res)
	get_tree().quit(0)


func _process(delta: float) -> void:
	_time += delta
	_mouse_pos = get_global_mouse_position()
	_update_popups(delta)
	var target_frenzy: float = 1.0 if _frenzy_timer > 0.0 else 0.0
	_bg_frenzy_mix = lerpf(_bg_frenzy_mix, target_frenzy, clampf(delta * 5.0, 0.0, 1.0))
	if _bg_shader_mat != null:
		_bg_shader_mat.set_shader_parameter("frenzy_amount", _bg_frenzy_mix)
	if _fire_shader_mat != null:
		_fire_shader_mat.set_shader_parameter("frenzy_amount", _bg_frenzy_mix)
	if _flask_view != null:
		_flask_view.step_fluid(delta, _potion_tube_pct, _cauldron_shake)

	if _trixie_react_anim > 0.0:
		_trixie_react_anim = maxf(0.0, _trixie_react_anim - delta * 3.2)

	if _disliked_streak_timer > 0.0:
		_disliked_streak_timer = maxf(0.0, _disliked_streak_timer - delta)
		if _disliked_streak_timer <= 0.0:
			_disliked_mistake_streak = 0

	if _trixie_emotion_timer > 0.0:
		_trixie_emotion_timer = maxf(0.0, _trixie_emotion_timer - delta)
	var patience_low: bool = (not _is_patience_paused_for_tutorial()) and (not round_ending) and (customer_patience_left <= 7.0)
	if _trixie_emotion_timer <= 0.0 and not _closing_active:
		var desired_idle: String = "sonrojada" if _frenzy_timer > 0.0 else ("nerviosa" if patience_low else ("confiada" if _combo >= 4 else "normal"))
		if _trixie_emotion != desired_idle:
			_trixie_emotion = desired_idle
			_trixie_react_anim = 1.0

	if _customer_flash_timer > 0.0:
		_customer_flash_timer = maxf(0.0, _customer_flash_timer - delta)
	if _customer_react_anim > 0.0:
		_customer_react_anim = maxf(0.0, _customer_react_anim - delta * 3.2)
	if _customer_emotion_timer > 0.0:
		_customer_emotion_timer = maxf(0.0, _customer_emotion_timer - delta)
	var cust_ratio: float = customer_patience_left / maxf(1.0, customer_patience_max)
	if _customer_emotion_timer <= 0.0 and not _closing_active:
		var desired_cust: String = "impaciente" if ((not _is_patience_paused_for_tutorial()) and (not round_ending) and cust_ratio <= CUSTOMER_IMPATIENT_RATIO) else ("sonrojada" if (_frenzy_timer > 0.0 or _potion_tube_pct >= 65.0) else "normal")
		if _customer_emotion != desired_cust:
			_customer_emotion = desired_cust
			_customer_react_anim = 1.0
	if _customer_slide_t < 1.0:
		_customer_slide_t = minf(1.0, _customer_slide_t + delta * 3.4)

	if not _closing_active and not _is_modal_open():
		_process_cauldron_gameplay(delta)

	_refresh_hud_labels()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _left_down:
			_on_left_mouse_released(get_global_mouse_position())
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed:
			_right_down = false


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
				if _hud != null and not _fading_out:
					_hud.toggle_pause()
				get_viewport().set_input_as_handled()
				return
			if _closing_active:
				if kev.keycode == KEY_SPACE or kev.keycode == KEY_ENTER:
					_handle_closing_advance_input()
					get_viewport().set_input_as_handled()
				return
			if _is_modal_open():
				return
			if _tutorial.is_waiting_summary_ack() and (kev.keycode == KEY_ENTER or kev.keycode == KEY_KP_ENTER):
				_acknowledge_basic_tutorial_summary()
				get_viewport().set_input_as_handled()
				return
			if kev.keycode == KEY_SPACE:
				try_activate_frenzy()
				get_viewport().set_input_as_handled()
		return

	if _closing_active:
		if event is InputEventMouseButton:
			var mbc: InputEventMouseButton = event as InputEventMouseButton
			if mbc.button_index == MOUSE_BUTTON_LEFT and mbc.pressed:
				_handle_closing_advance_input()
				get_viewport().set_input_as_handled()
		return

	if _is_modal_open() or round_ending:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		var mpos: Vector2 = get_global_mouse_position()
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var hit_id: int = _find_orb_id_at(mpos, 10.0)
			if hit_id != -1:
				_left_down = true
				_pressed_orb_id = hit_id
				_press_pos = mpos
				_press_elapsed = 0.0
				_is_lifting = false
				_lifted_orb_id = -1
				_lift_hover_target_id = -1
				_hold_hitting = false
				_hold_orb_id = -1
				_hold_hit_accum = 0.0
				get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_right_down = true
			_right_purge_accum = 0.0
			var r_id: int = _find_orb_id_at(mpos, 10.0, _lifted_orb_id)
			if r_id != -1:
				_purge_orb_by_id(r_id)
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _left_down:
		var mpos: Vector2 = get_global_mouse_position()
		if _is_lifting:
			var l_idx: int = _find_orb_idx_by_id(_lifted_orb_id)
			if l_idx != -1:
				var clamped_pos: Vector2 = _clamp_to_cauldron_ellipse(mpos, -18.0)
				_orbs[l_idx]["pos"] = clamped_pos
				_orbs[l_idx]["vel"] = Vector2.ZERO
				_lift_hover_target_id = _find_merge_target_id(_lifted_orb_id, clamped_pos)
			else:
				_is_lifting = false
				_lifted_orb_id = -1
				_lift_hover_target_id = -1
			get_viewport().set_input_as_handled()
		elif _hold_hitting:
			if _hold_orb_id != -1:
				var h_idx: int = _find_orb_idx_by_id(_hold_orb_id)
				if h_idx == -1:
					_hold_orb_id = -1
				else:
					var h_pos: Vector2 = _orbs[h_idx]["pos"] as Vector2
					var h_rad: float = float(_orbs[h_idx]["radius"])
					if mpos.distance_to(h_pos) > h_rad + 36.0:
						_hold_orb_id = -1
		elif _pressed_orb_id != -1 and mpos.distance_to(_press_pos) > DRAG_LIFT_THRESHOLD:
			var p_idx: int = _find_orb_idx_by_id(_pressed_orb_id)
			if p_idx != -1 and int(_orbs[p_idx]["kind"]) != BubbleKind.BOMB:
				_is_lifting = true
				_lifted_orb_id = _pressed_orb_id
				var clamped_pos: Vector2 = _clamp_to_cauldron_ellipse(mpos, -18.0)
				_orbs[p_idx]["pos"] = clamped_pos
				_orbs[p_idx]["vel"] = Vector2.ZERO
				_lift_hover_target_id = _find_merge_target_id(_lifted_orb_id, clamped_pos)
				_play_pentatonic(1, -9.0)
				get_viewport().set_input_as_handled()


func _is_modal_open() -> bool:
	return (_hud != null and _hud.is_pause_open()) or _fading_out


func _reset_pointer_state() -> void:
	_left_down = false
	_pressed_orb_id = -1
	_press_elapsed = 0.0
	_is_lifting = false
	_lifted_orb_id = -1
	_lift_hover_target_id = -1
	_hold_hitting = false
	_hold_orb_id = -1
	_hold_hit_accum = 0.0
	_right_down = false
	_right_purge_accum = 0.0


# ==============================================================================
# COLOR CHEMISTRY & STATS
# ==============================================================================

func get_customer_chemistry() -> Dictionary:
	if not _current_order_chemistry.is_empty():
		return _current_order_chemistry
	if _active_customer != null:
		return ChemistryRules.get_default_chemistry_for_customer(_active_customer.customer_id)
	return {"liked": BubbleKind.RED, "neutral": BubbleKind.GREEN, "disliked": BubbleKind.BLUE}


func _roll_order_chemistry_for_customer(cid: StringName, first_order: bool) -> Dictionary:
	var st: Node = _state()
	return ChemistryRules.roll_order_chemistry(
		cid,
		first_order,
		bool(st.call("should_run_cauldron_basics_tutorial")),
		bool(st.call("should_run_mix_tutorial")),
		_last_order_liked_kind
	)


static func is_primary_kind(kind: int) -> bool:
	return ChemistryRules.is_primary_kind(kind)


static func is_mixed_kind(kind: int) -> bool:
	return ChemistryRules.is_mixed_kind(kind)


static func get_recipe_components(kind: int) -> Array[int]:
	return ChemistryRules.get_recipe_components(kind)


static func get_combine_result(a_kind: int, b_kind: int) -> int:
	return ChemistryRules.get_combine_result(a_kind, b_kind)


func get_orb_relation(kind: int) -> StringName:
	return ChemistryRules.get_orb_relation(kind, get_customer_chemistry())


static func get_element_name(kind: int) -> String:
	return ChemistryRules.get_element_name(kind)


static func get_element_glyph(kind: int) -> String:
	return ChemistryRules.get_element_glyph(kind)


static func get_element_color(kind: int) -> Color:
	return ChemistryRules.get_element_color(kind)


func _get_effective_click_damage() -> int:
	return maxi(click_damage, 3) if _frenzy_timer > 0.0 else click_damage


func get_node_level(node_id: StringName) -> int:
	return _state().get_node_level(node_id)


func buy_incremental_node(node_id: StringName) -> bool:
	var ok: bool = _state().buy_incremental_node(node_id)
	if ok:
		_recalc_stats()
	return ok


func _recalc_stats() -> void:
	var st: Node = _state()
	st.recalc_stats()
	hold_auto_hit_unlocked = st.hold_auto_hit_unlocked
	hold_hit_interval = st.hold_hit_interval
	aroma_essence_mult = st.aroma_essence_mult
	click_damage = st.click_damage
	strength_tube_bonus = st.strength_tube_bonus
	purge_recycle_lvl = st.purge_recycle_lvl
	frenzy_gain_mult = st.frenzy_gain_mult
	frenzy_duration_sec = st.frenzy_duration_sec
	spawn_cap = st.spawn_cap
	var base_sp_int: float = st.spawn_interval
	spawn_interval = maxf(0.26, base_sp_int / maxf(0.5, _stop_spawn_rate_mult))
	chain_spark_jumps = st.chain_spark_jumps
	bomb_chance = st.bomb_chance
	star_chance = st.star_chance
	fam_michi_lvl = st.fam_michi_lvl
	fam_imp_lvl = st.fam_imp_lvl
	fam_bat_lvl = st.fam_bat_lvl
	order_bonus_mult = st.order_bonus_mult
	vip_tier = st.vip_tier
	crit_potion_lvl = st.crit_potion_lvl


func _compute_customer_patience(c: CustomerArchetypeData) -> float:
	var base_sec: float = c.base_patience_sec if (USE_PER_CUSTOMER_PATIENCE and c != null) else BASE_CUSTOMER_PATIENCE
	return base_sec + float(get_node_level(&"reloj_arena")) * 4.0


func _is_patience_paused_for_tutorial() -> bool:
	return _tutorial.is_pausing_patience()


# ==============================================================================
# STOP FLOW, TUTORIAL & CLOSING DIALOGUE -> FADE TO WORLD MAP
# ==============================================================================

func _start_stop() -> void:
	var st: Node = _state()
	st.rounds_played += 1
	round_number = st.rounds_played

	_active_stop = st.get_active_map_node()
	_stop_essence_mult = float(_active_stop.get("essence_mult", 1.0))
	_stop_affinity_bonus = int(_active_stop.get("affinity_bonus", 0))
	_stop_spawn_rate_mult = float(_active_stop.get("spawn_rate_mult", 1.0))
	_stop_bg_tint = _active_stop.get("bg_tint", Color(0.08, 0.05, 0.13)) as Color
	_apply_stop_background()
	_recalc_stats()

	round_ending = false
	_round_end_timer = 0.0
	_wave_victory = false
	_closing_active = false
	_fading_out = false
	_round_essence_gained = 0
	_round_orders_completed = 0
	_wave_served_count = 0
	_wave_missed_count = 0
	_disliked_mistake_streak = 0
	_disliked_streak_timer = 0.0
	_combo = 0
	_combo_timer = 0.0
	_frenzy_timer = 0.0
	_spawn_accum = 0.0
	_michi_timer = 1.6
	_imp_timer = 2.0
	_bat_timer = 2.2
	_reset_pointer_state()

	_wave_customers.clear()
	var raw_custs: Array = _active_stop.get("customers", [&"sylvi", &"velvet"]) as Array
	for cv: Variant in raw_custs:
		_wave_customers.append(cv as StringName)
	if _wave_customers.is_empty():
		_wave_customers.append(&"sylvi")
	_wave_index = 0

	_orbs.clear()
	_lightning_arcs.clear()
	_shockwaves.clear()
	_tutorial.reset()
	if _hud != null:
		_hud.set_cauldron_hud_visible(true)
	_hide_trixie_bubble(true)
	_hide_customer_bubble(true)

	_pick_customer_by_id(_wave_customers[0], true)

	var liked_k: int = int(get_customer_chemistry()["liked"])
	if st.should_run_cauldron_basics_tutorial() and not is_mixed_kind(liked_k):
		_tutorial.start_basics()
		_setup_tutorial_initial_orbs()
		_update_tutorial_banner()
		_set_trixie_reaction("confiada", 3.0, "¡Primera clienta! El tiempo está pausado mientras aprendemos lo básico.")
	else:
		if not _tutorial.active:
			_update_tutorial_banner()
		for _i: int in range(spawn_cap):
			_spawn_orb(false)
		if not _tutorial.active:
			var stop_name: String = String(_active_stop.get("name", "Parada"))
			_set_trixie_reaction("confiada", 2.5, "¡Llegamos a %s! Rompe %s (%d golpes) para %s." % [
				stop_name,
				get_element_name(liked_k),
				maxi(1, ceili(float(BASE_ORB_HP) / float(click_damage))),
				_active_customer.display_name if _active_customer != null else "la clienta",
			])

	if _hud != null:
		_hud.set_map_button_disabled(_tutorial.active)


func _setup_tutorial_initial_orbs() -> void:
	_orbs.clear()
	var liked_k: int = int(get_customer_chemistry()["liked"])
	var neutral_k: int = int(get_customer_chemistry()["neutral"])
	var disliked_k: int = int(get_customer_chemistry()["disliked"])
	var positions: Array[Vector2] = [
		CAULDRON_CENTER + Vector2(-125, -45),
		CAULDRON_CENTER + Vector2(125, -45),
		CAULDRON_CENTER + Vector2(-90, 95),
		CAULDRON_CENTER + Vector2(90, 95),
		CAULDRON_CENTER + Vector2(0, -145),
		CAULDRON_CENTER + Vector2(0, 145),
	]
	var kinds: Array[int] = [liked_k, liked_k, neutral_k, neutral_k, disliked_k, neutral_k]
	for i: int in range(mini(spawn_cap, positions.size())):
		_orbs.append(_make_orb_dict(kinds[i], positions[i], 1))


func _ensure_tutorial_orb(target_kind: int) -> void:
	if _count_orbs_of_kind(target_kind) > 0:
		return
	var pos: Vector2 = CAULDRON_CENTER + Vector2(randf_range(-130.0, 130.0), randf_range(-110.0, 110.0))
	_orbs.append(_make_orb_dict(target_kind, pos, 1))


func _ensure_mix_ingredients_for_tutorial(liked_k: int) -> void:
	if not is_mixed_kind(liked_k):
		return
	var comps: Array[int] = get_recipe_components(liked_k)
	if _count_orbs_of_kind(comps[0]) == 0:
		_orbs.append(_make_orb_dict(comps[0], CAULDRON_CENTER + Vector2(-95, 10), 1))
	if _count_orbs_of_kind(comps[1]) == 0:
		_orbs.append(_make_orb_dict(comps[1], CAULDRON_CENTER + Vector2(95, 10), 1))


func _advance_cauldron_tutorial(next_step: TutorialDirector.Step) -> void:
	if not _tutorial.advance_to(next_step):
		return
	_play_pentatonic(4, -2.0)
	if next_step == TutorialDirector.Step.BASIC_PURGE_DISLIKED:
		var disliked_k: int = int(get_customer_chemistry()["disliked"])
		_ensure_tutorial_orb(disliked_k)
	var react: Dictionary = _tutorial.get_step_reaction(next_step)
	if not react.is_empty():
		_set_trixie_reaction(String(react["emotion"]), float(react["dur"]), String(react["line"]))
	_update_tutorial_banner()


func _acknowledge_basic_tutorial_summary() -> void:
	if not _tutorial.acknowledge_basics_summary(_state()):
		return
	_play_pentatonic(6, -1.0)
	_update_tutorial_banner()
	_set_trixie_reaction("confiada", 2.5, "¡Corre la paciencia de Sylvi! Llena su tubo al 100%.")
	if _hud != null:
		_hud.set_map_button_disabled(false)


func _start_mix_tutorial() -> void:
	var liked_k: int = int(get_customer_chemistry()["liked"])
	if not is_mixed_kind(liked_k):
		return
	_tutorial.start_mix()
	_ensure_mix_ingredients_for_tutorial(liked_k)
	_play_pentatonic(5, -2.0)
	_update_tutorial_banner()
	_set_trixie_reaction("sorprendida", 3.2, "¡Pide un color mezclado! Pausé el tiempo para enseñarte a combinarlo.")
	if _hud != null:
		_hud.set_map_button_disabled(true)


func _finish_mix_tutorial() -> void:
	_tutorial.finish_mix(_state())
	_play_pentatonic(6, -1.0)
	_update_tutorial_banner()
	_set_trixie_reaction("confiada", 2.4, "¡Perfecto! Ya dominas las mezclas. ¡A atender antes de que pierda la paciencia!")
	if _hud != null:
		_hud.set_map_button_disabled(false)


func _update_tutorial_banner() -> void:
	if _hud == null:
		return
	if not _tutorial.active or _closing_active or _tutorial.step == TutorialDirector.Step.NONE:
		if _hud.is_trixie_bubble_tutorial():
			_hide_trixie_bubble(false)
		return
	var payload: Dictionary = _tutorial.get_banner_payload(get_customer_chemistry())
	_show_trixie_bubble(String(payload["title"]), String(payload["body"]), -1.0, true, bool(payload["show_ack"]))


func _trigger_stop_end(victory: bool) -> void:
	if round_ending:
		return
	round_ending = true
	_wave_victory = victory
	_round_end_timer = 1.35 if victory else 1.15
	_reset_pointer_state()
	_play_pentatonic(6 if victory else 1, -2.0)
	if _hud != null and _hud.is_trixie_bubble_tutorial():
		_hide_trixie_bubble(false)
	_set_trixie_reaction("confiada" if victory else "hollin", 2.2, "")


func _begin_closing_dialogue(victory: bool) -> void:
	if _closing_active:
		return
	_closing_active = true
	_reset_pointer_state()
	_hide_trixie_bubble(true)
	_hide_customer_bubble(true)
	if _hud != null:
		_hud.set_cauldron_hud_visible(false)

	var raw_lines: Array = []
	if victory:
		raw_lines = _active_stop.get("closing_victory_lines", []) as Array
	else:
		raw_lines = _active_stop.get("closing_timeout_lines", []) as Array

	_closing_lines.clear()
	for lv: Variant in raw_lines:
		if lv is Dictionary:
			var ld: Dictionary = lv as Dictionary
			if String(ld.get("speaker", "trixie")) == "trixie":
				_closing_lines.append(ld.duplicate())
				break

	if _closing_lines.is_empty():
		_closing_lines.append({
			"speaker": "trixie",
			"emotion": "confiada" if victory else "hollin",
			"text": "¡Uf, pude terminar! Ahora a descansar y mejorar el caldero en el Mapa." if victory else "¡Puf...! Toca descansar, mejorar el caldero en el Mapa e intentarlo otra vez.",
		})

	_closing_idx = -1
	if _hud != null:
		_hud.open_closing_overlay()
	_advance_closing_dialogue(true)


func _advance_closing_dialogue(animate_entrance: bool = false) -> void:
	_closing_idx += 1
	if _closing_idx >= _closing_lines.size():
		_finish_stop_and_fade_to_map()
		return

	var line_d: Dictionary = _closing_lines[_closing_idx]
	var spk: String = String(line_d.get("speaker", "trixie"))
	var emo: String = String(line_d.get("emotion", "normal"))
	var body_txt: String = String(line_d.get("text", ""))
	var speaker_name: String = "Trixie"
	var speaker_col: Color = Color(0.68, 0.14, 0.34)

	if spk == "customer":
		speaker_name = _last_served_customer.display_name if _last_served_customer != null else (_active_customer.display_name if _active_customer != null else "Clienta")
		if _last_served_customer != null:
			_active_customer = _last_served_customer
		speaker_col = Color(0.56, 0.12, 0.28)
		_set_customer_reaction(emo, 8.0, "")
	else:
		_set_trixie_reaction(emo, 8.0, "")

	if _hud != null:
		_hud.show_closing_line(speaker_name, speaker_col, body_txt, animate_entrance)


func _handle_closing_advance_input() -> void:
	if not _closing_active or _fading_out:
		return
	if _hud != null and _hud.is_closing_typing():
		_hud.complete_closing_typing()
		return
	_advance_closing_dialogue(false)


func _finish_stop_and_fade_to_map() -> void:
	if _fading_out:
		return
	_fading_out = true

	var st: Node = _state()
	var stop_id: StringName = _active_stop.get("id", &"castillo") as StringName
	if _wave_victory:
		st.mark_map_node_completed(stop_id)
		if stop_id == &"castillo":
			st.cauldron_basics_tutorial_done = true
			st.cauldron_tutorial_done = true
	else:
		st.last_visited_map_node_id = stop_id

	var fader: Node = _fader()
	if fader != null and not bool(fader.call("is_busy")):
		fader.call("fade_to_scene", "res://scenes/meta/WorldMap.tscn", 0.55, 0.55)
	elif get_tree() != null and get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://scenes/meta/WorldMap.tscn")


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
		if float(st["y"]) < -CAULDRON_ELLIPSE_RY * 0.74:
			st["y"] = CAULDRON_ELLIPSE_RY * 0.66
			st["x"] = randf_range(-CAULDRON_ELLIPSE_RX * 0.76, CAULDRON_ELLIPSE_RX * 0.76)

	if round_ending:
		_round_end_timer -= delta
		_update_vfx(delta)
		if _round_end_timer <= 0.0 and not _closing_active:
			_begin_closing_dialogue(_wave_victory)
		return

	# Individual customer patience countdown (100% paused whenever any tutorial is active)
	if not _is_patience_paused_for_tutorial() and _active_customer != null:
		customer_patience_left = maxf(0.0, customer_patience_left - delta)
		var p_ratio: float = customer_patience_left / maxf(1.0, customer_patience_max)
		if p_ratio <= CUSTOMER_IMPATIENT_RATIO and not _customer_impatient_warned:
			_customer_impatient_warned = true
			var imp_line: String = _active_customer.impatient_lines[0] if not _active_customer.impatient_lines.is_empty() else "¡Apúrate, brujita!"
			_set_customer_reaction("impaciente", 3.5, imp_line)
			_set_trixie_reaction("nerviosa", 2.0, "¡%s está perdiendo la paciencia!" % _active_customer.display_name)
		if customer_patience_left <= 0.0:
			_on_customer_patience_expired()
			return

	if _left_down:
		if _is_lifting:
			var l_idx: int = _find_orb_idx_by_id(_lifted_orb_id)
			if l_idx != -1:
				_lift_hover_target_id = _find_merge_target_id(_lifted_orb_id, _orbs[l_idx]["pos"] as Vector2)
			else:
				_is_lifting = false
				_lifted_orb_id = -1
				_lift_hover_target_id = -1
		elif _pressed_orb_id != -1 and not _hold_hitting:
			_press_elapsed += delta
			if hold_auto_hit_unlocked and _press_elapsed >= HOLD_HIT_START_DELAY:
				var p_idx: int = _find_orb_idx_by_id(_pressed_orb_id)
				if p_idx != -1:
					var opos: Vector2 = _orbs[p_idx]["pos"] as Vector2
					var orad: float = float(_orbs[p_idx]["radius"])
					if _mouse_pos.distance_to(opos) <= orad + 28.0:
						_hold_hitting = true
						_hold_orb_id = _pressed_orb_id
						_hold_hit_accum = 0.0
						if _hit_orb_by_id(_hold_orb_id, _get_effective_click_damage(), true):
							_hold_orb_id = -1
		elif _hold_hitting and _hold_orb_id != -1:
			var h_idx: int = _find_orb_idx_by_id(_hold_orb_id)
			if h_idx == -1:
				_hold_orb_id = -1
			else:
				var h_pos: Vector2 = _orbs[h_idx]["pos"] as Vector2
				var h_rad: float = float(_orbs[h_idx]["radius"])
				if _mouse_pos.distance_to(h_pos) > h_rad + 36.0:
					_hold_orb_id = -1
				else:
					_hold_hit_accum += delta
					while _hold_hit_accum >= hold_hit_interval:
						_hold_hit_accum -= hold_hit_interval
						if _hit_orb_by_id(_hold_orb_id, _get_effective_click_damage(), true):
							_hold_orb_id = -1
							break

	if _right_down:
		_right_purge_accum += delta
		while _right_purge_accum >= RIGHT_PURGE_HOLD_INTERVAL:
			_right_purge_accum -= RIGHT_PURGE_HOLD_INTERVAL
			var r_id: int = _find_orb_id_at(_mouse_pos, 10.0, _lifted_orb_id)
			if r_id != -1:
				_purge_orb_by_id(r_id)

	_spawn_accum += delta
	while _spawn_accum >= spawn_interval:
		_spawn_accum -= spawn_interval
		if _orbs.size() < spawn_cap:
			_spawn_orb(false)

	_update_orbs_motion(delta)
	_hovered_orb_id = -1 if _is_lifting else _find_orb_id_at(_mouse_pos, 10.0, _lifted_orb_id)
	_update_familiars(delta)
	_update_vfx(delta)


func _count_orbs_of_kind(target_kind: int) -> int:
	var c: int = 0
	for o: Dictionary in _orbs:
		if int(o["kind"]) == target_kind:
			c += 1
	return c


func _make_orb_dict(kind: int, pos: Vector2, tier: int = 1) -> Dictionary:
	var oid: int = _next_orb_id
	_next_orb_id += 1
	var clamped_tier: int = clampi(tier, 1, 3)
	var max_hp: int = 1 if kind == BubbleKind.BOMB else (2 if kind == BubbleKind.GOLD else (BASE_ORB_HP + (clamped_tier - 1)))
	var rad: float = ORB_RADIUS + (5.0 if is_mixed_kind(kind) else 0.0) + float(clamped_tier - 1) * 6.0
	var vel_ang: float = randf_range(0.0, TAU)
	var vel: Vector2 = Vector2(cos(vel_ang), sin(vel_ang)) * randf_range(12.0, 24.0)
	return {
		"id": oid,
		"pos": pos,
		"vel": vel,
		"radius": rad,
		"kind": kind,
		"tier": clamped_tier,
		"hp": max_hp,
		"max_hp": max_hp,
		"scale_pop": 0.25,
		"hit_flash": 0.0,
		"hit_wobble": 0.0,
		"phase": randf_range(0.0, TAU),
		"crack_rot": randf_range(-0.38, 0.38),
	}


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
	elif is_mixed_kind(liked_k):
		var comps: Array[int] = get_recipe_components(liked_k)
		var c0: int = comps[0]
		var c1: int = comps[1]
		var have_mixed: int = _count_orbs_of_kind(liked_k)
		var have_c0: int = _count_orbs_of_kind(c0)
		var have_c1: int = _count_orbs_of_kind(c1)
		if have_mixed == 0 and have_c0 < 2:
			kind = c0
		elif have_mixed == 0 and have_c1 < 2:
			kind = c1
		else:
			var r_mix: float = randf()
			if avoid_disliked:
				kind = c0 if r_mix < 0.50 else c1
			else:
				if r_mix < 0.40:
					kind = c0
				elif r_mix < 0.80:
					kind = c1
				else:
					kind = disliked_k
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

	var pos: Vector2 = CAULDRON_CENTER
	var max_rx: float = maxf(24.0, CAULDRON_ELLIPSE_RX - ORB_RADIUS - 22.0)
	var max_ry: float = maxf(24.0, CAULDRON_ELLIPSE_RY - ORB_RADIUS - 22.0)
	for _attempt: int in range(12):
		var ang: float = randf_range(0.0, TAU)
		var dist: float = sqrt(randf())
		var cand: Vector2 = CAULDRON_CENTER + Vector2(cos(ang) * max_rx, sin(ang) * max_ry) * dist
		var clear: bool = true
		for o: Dictionary in _orbs:
			if cand.distance_to(o["pos"] as Vector2) < ORB_RADIUS * 2.25:
				clear = false
				break
		pos = cand
		if clear:
			break

	_orbs.append(_make_orb_dict(kind, pos, 1))


func _update_orbs_motion(delta: float) -> void:
	for i: int in range(_orbs.size()):
		var o: Dictionary = _orbs[i]
		o["scale_pop"] = lerpf(float(o["scale_pop"]), 1.0, clampf(delta * 10.0, 0.0, 1.0))
		o["hit_flash"] = maxf(0.0, float(o["hit_flash"]) - delta * 6.5)
		o["hit_wobble"] = maxf(0.0, float(o["hit_wobble"]) - delta * 7.5)
		if int(o["id"]) == _lifted_orb_id:
			continue

		var rad: float = float(o["radius"])
		var lim_x: float = maxf(20.0, CAULDRON_ELLIPSE_RX - rad - 12.0)
		var lim_y: float = maxf(20.0, CAULDRON_ELLIPSE_RY - rad - 12.0)
		var pos: Vector2 = o["pos"] as Vector2
		var vel: Vector2 = o["vel"] as Vector2
		pos += vel * delta

		var rel: Vector2 = pos - CAULDRON_CENTER
		var norm_r2: float = (rel.x * rel.x) / (lim_x * lim_x) + (rel.y * rel.y) / (lim_y * lim_y)
		if norm_r2 > 1.0:
			var scale_back: float = 1.0 / sqrt(norm_r2)
			rel *= scale_back
			pos = CAULDRON_CENTER + rel
			var n: Vector2 = Vector2(rel.x / (lim_x * lim_x), rel.y / (lim_y * lim_y)).normalized()
			vel = vel.bounce(n)

		o["pos"] = pos
		o["vel"] = vel

	for i: int in range(_orbs.size()):
		if int(_orbs[i]["id"]) == _lifted_orb_id:
			continue
		for j: int in range(i + 1, _orbs.size()):
			if int(_orbs[j]["id"]) == _lifted_orb_id:
				continue
			var pi: Vector2 = _orbs[i]["pos"] as Vector2
			var pj: Vector2 = _orbs[j]["pos"] as Vector2
			var diff: Vector2 = pj - pi
			var d: float = diff.length()
			var min_d: float = (float(_orbs[i]["radius"]) + float(_orbs[j]["radius"])) * 1.08
			if d > 0.01 and d < min_d:
				var push: Vector2 = diff.normalized() * (min_d - d) * 0.5 * clampf(delta * 8.0, 0.0, 1.0)
				_orbs[i]["pos"] = pi - push
				_orbs[j]["pos"] = pj + push


func _find_orb_idx_by_id(oid: int) -> int:
	if oid == -1:
		return -1
	for i: int in range(_orbs.size()):
		if int(_orbs[i]["id"]) == oid:
			return i
	return -1


func _find_orb_id_at(pos: Vector2, extra_pad: float = 8.0, exclude_id: int = -1) -> int:
	for i: int in range(_orbs.size() - 1, -1, -1):
		var oid: int = int(_orbs[i]["id"])
		if oid == exclude_id:
			continue
		var opos: Vector2 = _orbs[i]["pos"] as Vector2
		var orad: float = float(_orbs[i]["radius"])
		if pos.distance_to(opos) <= orad + extra_pad:
			return oid
	return -1


func _can_combine_orbs(a: Dictionary, b: Dictionary) -> bool:
	var ak: int = int(a["kind"])
	var bk: int = int(b["kind"])
	if get_combine_result(ak, bk) == -1:
		return false
	if ak == bk and ak != BubbleKind.GOLD:
		return maxi(int(a["tier"]), int(b["tier"])) < 3
	if ak == BubbleKind.GOLD and bk != BubbleKind.GOLD:
		return int(b["tier"]) < 3 or int(b["hp"]) > 1
	if bk == BubbleKind.GOLD and ak != BubbleKind.GOLD:
		return int(a["tier"]) < 3 or int(a["hp"]) > 1
	return true


func _find_merge_target_id(lifted_id: int, pos: Vector2) -> int:
	var l_idx: int = _find_orb_idx_by_id(lifted_id)
	if l_idx == -1:
		return -1
	var lifted: Dictionary = _orbs[l_idx]
	var lifted_r: float = float(lifted["radius"])
	var best_id: int = -1
	var best_dist: float = 999999.0
	for o: Dictionary in _orbs:
		var oid: int = int(o["id"])
		if oid == lifted_id:
			continue
		if not _can_combine_orbs(lifted, o):
			continue
		var opos: Vector2 = o["pos"] as Vector2
		var orad: float = float(o["radius"])
		var d: float = pos.distance_to(opos)
		if d <= orad + lifted_r * 0.78 and d < best_dist:
			best_dist = d
			best_id = oid
	return best_id


# ==============================================================================
# LIFT-AND-DROP COLOR COMBINING, MULTI-CLICK BREAKING & RIGHT-CLICK PURGE
# ==============================================================================

func _on_left_mouse_released(mpos: Vector2) -> void:
	if _is_lifting and _lifted_orb_id != -1 and not round_ending and not _closing_active:
		var l_idx: int = _find_orb_idx_by_id(_lifted_orb_id)
		if l_idx != -1:
			var drop_pos: Vector2 = _orbs[l_idx]["pos"] as Vector2
			var target_id: int = _find_merge_target_id(_lifted_orb_id, drop_pos)
			if target_id != -1:
				_combine_orbs_by_id(_lifted_orb_id, target_id)
			else:
				var r: float = float(_orbs[l_idx]["radius"])
				_orbs[l_idx]["pos"] = _clamp_to_cauldron_ellipse(drop_pos, r + 12.0)
				var ang: float = randf_range(0.0, TAU)
				_orbs[l_idx]["vel"] = Vector2(cos(ang), sin(ang)) * randf_range(12.0, 22.0)
				_orbs[l_idx]["scale_pop"] = 0.88
	elif not _hold_hitting and _pressed_orb_id != -1 and not round_ending and not _closing_active:
		var p_idx: int = _find_orb_idx_by_id(_pressed_orb_id)
		if p_idx != -1:
			var opos: Vector2 = _orbs[p_idx]["pos"] as Vector2
			var orad: float = float(_orbs[p_idx]["radius"])
			if mpos.distance_to(opos) <= orad + 28.0:
				_hit_orb_by_id(_pressed_orb_id, _get_effective_click_damage(), true)

	_left_down = false
	_pressed_orb_id = -1
	_press_elapsed = 0.0
	_is_lifting = false
	_lifted_orb_id = -1
	_lift_hover_target_id = -1
	_hold_hitting = false
	_hold_orb_id = -1
	_hold_hit_accum = 0.0


func _combine_orbs_by_id(src_id: int, dst_id: int) -> bool:
	if src_id == dst_id:
		return false
	var s_idx: int = _find_orb_idx_by_id(src_id)
	var d_idx: int = _find_orb_idx_by_id(dst_id)
	if s_idx == -1 or d_idx == -1:
		return false
	var src: Dictionary = _orbs[s_idx]
	var dst: Dictionary = _orbs[d_idx]
	if not _can_combine_orbs(src, dst):
		return false

	var sk: int = int(src["kind"])
	var dk: int = int(dst["kind"])
	var stier: int = int(src["tier"])
	var dtier: int = int(dst["tier"])
	var dpos: Vector2 = dst["pos"] as Vector2
	var res_kind: int = get_combine_result(sk, dk)
	if res_kind == -1:
		return false

	var is_star_boost: bool = (sk == BubbleKind.GOLD or dk == BubbleKind.GOLD) and not (sk == BubbleKind.GOLD and dk == BubbleKind.GOLD)
	var is_same_merge: bool = (sk == dk)
	var new_tier: int = 1
	if is_star_boost:
		var base_tier: int = dtier if sk == BubbleKind.GOLD else stier
		new_tier = mini(3, base_tier + 1)
	elif is_same_merge:
		new_tier = mini(3, maxi(stier, dtier) + 1)
	else:
		new_tier = mini(3, maxi(stier, dtier))

	var new_hp: int = 1 if is_star_boost else (2 if res_kind == BubbleKind.GOLD else (BASE_ORB_HP + (new_tier - 1)))
	var new_rad: float = ORB_RADIUS + (5.0 if is_mixed_kind(res_kind) else 0.0) + float(new_tier - 1) * 6.0

	dst["kind"] = res_kind
	dst["tier"] = new_tier
	dst["max_hp"] = new_hp
	dst["hp"] = new_hp
	dst["radius"] = new_rad
	dst["scale_pop"] = 1.38
	dst["hit_flash"] = 0.85
	dst["hit_wobble"] = 0.0

	dst["pos"] = _clamp_to_cauldron_ellipse(dpos, new_rad + 12.0)

	_orbs.remove_at(s_idx)
	var final_pos: Vector2 = dst["pos"] as Vector2

	_lightning_arcs.append({
		"from": src["pos"] as Vector2,
		"to": final_pos,
		"color": Color(1.0, 0.88, 0.38),
		"life": 0.24,
		"max_life": 0.24,
	})
	_shockwaves.append({
		"pos": final_pos,
		"radius": 14.0,
		"max_radius": 92.0,
		"color": get_element_color(res_kind),
		"life": 0.30,
		"max_life": 0.30,
	})
	_play_pentatonic(mini(7, 2 + new_tier), -1.0)
	if _combo > 0:
		_combo_timer = 5.0

	var liked_k: int = int(get_customer_chemistry()["liked"])
	if is_star_boost:
		var star_ess: int = int(roundf(10.0 * aroma_essence_mult * _stop_essence_mult))
		_grant_essence(star_ess)
		_spawn_popup(final_pos + Vector2(0, -18), "⭐ ¡POTENCIADO x%d! +%d✦" % [new_tier, star_ess], Color(1.0, 0.90, 0.32))
		_set_trixie_reaction("sorprendida", 1.7, "¡Estrella fusionada! ¡Ese orbe brilla x%d!" % new_tier)
	elif is_same_merge:
		_spawn_popup(final_pos + Vector2(0, -18), "%s ¡CONCENTRADO x%d!" % [get_element_name(res_kind), new_tier], get_element_color(res_kind).lightened(0.35))
		if new_tier >= 3:
			_set_trixie_reaction("sorprendida", 1.8, "¡Concentrado x3! ¡Ese orbe va a reventar el tubo!")
		elif res_kind == liked_k:
			_set_trixie_reaction("confiada", 1.5, "¡Orbe concentrado x%d! ¡Rómpelo a golpes!" % new_tier)
	else:
		_spawn_popup(final_pos + Vector2(0, -18), "✨ %s!" % get_element_name(res_kind), get_element_color(res_kind).lightened(0.35))
		if res_kind == liked_k:
			_set_trixie_reaction("confiada", 1.7, "¡Mezcla perfecta! ¡Ahora rómpela a golpes!")

	if _tutorial.active and _tutorial.step == TutorialDirector.Step.MIX_DRAG_COMBINE and res_kind == liked_k:
		_advance_cauldron_tutorial(TutorialDirector.Step.MIX_BREAK_RESULT)
	return true


func _hit_orb_by_id(orb_id: int, dmg: int, by_player: bool = true) -> bool:
	var idx: int = _find_orb_idx_by_id(orb_id)
	if idx == -1:
		return false
	var o: Dictionary = _orbs[idx]
	var new_hp: int = maxi(0, int(o["hp"]) - maxi(1, dmg))
	o["hp"] = new_hp
	o["hit_flash"] = 1.0
	o["hit_wobble"] = 1.0
	o["scale_pop"] = 0.80

	if new_hp > 0:
		var pos: Vector2 = o["pos"] as Vector2
		var kind: int = int(o["kind"])
		var max_hp: int = int(o["max_hp"])
		var dmg_step: int = clampi(max_hp - new_hp, 0, 7)
		_play_pentatonic(dmg_step, -5.0)
		_cauldron_shake = maxf(_cauldron_shake, 2.5)
		_shockwaves.append({
			"pos": pos,
			"radius": 8.0,
			"max_radius": 44.0,
			"color": get_element_color(kind).lightened(0.25),
			"life": 0.16,
			"max_life": 0.16,
		})
		if by_player:
			var hits_left: int = ceili(float(new_hp) / float(maxi(1, _get_effective_click_damage())))
			_spawn_popup(pos + Vector2(0, -24), "💥 (%d)" % hits_left, Color(1.0, 0.96, 0.82))
		return false

	_shatter_orb_at_idx(idx, by_player)
	return true


func _shatter_orb_at_idx(idx: int, _by_player: bool = true) -> void:
	if idx < 0 or idx >= _orbs.size():
		return
	var snap: Dictionary = _orbs[idx].duplicate()
	var oid: int = int(snap["id"])
	if _hold_orb_id == oid:
		_hold_orb_id = -1
	if _pressed_orb_id == oid:
		_pressed_orb_id = -1
	if _lifted_orb_id == oid:
		_lifted_orb_id = -1
		_is_lifting = false
	_orbs.remove_at(idx)

	var pos: Vector2 = snap["pos"] as Vector2
	var kind: int = int(snap["kind"])
	var tier: int = int(snap["tier"])
	var rel: StringName = get_orb_relation(kind)
	if _flask_view != null:
		_flask_view.inject_mix_pigment(kind, tier)
	var frenzy_mult: float = 2.0 if _frenzy_timer > 0.0 else 1.0
	var tier_mult: float = 1.0 if tier <= 1 else (2.3 if tier == 2 else 4.2)

	_shockwaves.append({
		"pos": pos,
		"radius": 14.0,
		"max_radius": 88.0 if tier >= 2 or is_mixed_kind(kind) else 66.0,
		"color": get_element_color(kind),
		"life": 0.30,
		"max_life": 0.30,
	})

	if rel == &"disliked":
		var prev_combo: int = _combo
		var penalty: float = 18.0
		_potion_tube_pct = maxf(0.0, _potion_tube_pct - penalty)
		if _flask_view != null:
			_flask_view.excite(-penalty)
			_flask_view.trigger_flash(0.55, false)
		_combo = 0
		_disliked_mistake_streak += 1
		_disliked_streak_timer = 7.0
		_play_pentatonic(0, 0.0)
		_spawn_popup(pos, "¡❌ -%d%% Poción! Combo 0" % int(penalty), Color(1.0, 0.32, 0.34))
		var severe_backfire: bool = prev_combo >= 2 or _disliked_mistake_streak >= 2 or _potion_tube_pct <= 0.0
		if severe_backfire:
			_cauldron_shake = maxf(_cauldron_shake, 14.0)
			_shockwaves.append({
				"pos": pos,
				"radius": 16.0,
				"max_radius": 115.0,
				"color": Color(0.24, 0.20, 0.28),
				"life": 0.42,
				"max_life": 0.42,
			})
			_set_trixie_reaction("hollin", 2.4, "¡Puf...! ¡Me explotó en la cara! Purga los ❌ con Clic Der.")
		else:
			_cauldron_shake = maxf(_cauldron_shake, 10.0)
			_set_trixie_reaction("nerviosa", 1.8, "¡Cuidado! Ese elemento choca con el pedido.")
		var imp_line: String = _active_customer.impatient_lines[0] if (_active_customer != null and not _active_customer.impatient_lines.is_empty()) else ""
		_set_customer_reaction("impaciente", 2.2, imp_line)
		return

	var tube_gain: float = 0.0
	var ess_gain: int = 0
	var frenzy_add: float = 0.0

	if kind == BubbleKind.GOLD:
		tube_gain = 22.0 * tier_mult * frenzy_mult
		ess_gain = int(roundf(15.0 * 5.0 * tier_mult * aroma_essence_mult * _stop_essence_mult * frenzy_mult))
		_combo += 1
		_combo_timer = 5.0
		frenzy_add = 22.0 * frenzy_gain_mult
	elif kind == BubbleKind.BOMB:
		ess_gain = int(roundf(8.0 * aroma_essence_mult * _stop_essence_mult * frenzy_mult))
		frenzy_add = 12.0 * frenzy_gain_mult
	elif rel == &"liked":
		var base_tube: float = 42.0 if is_mixed_kind(kind) else 24.0
		var base_ess: float = 14.0 if is_mixed_kind(kind) else 7.0
		tube_gain = base_tube * (1.0 + strength_tube_bonus) * tier_mult * frenzy_mult
		ess_gain = int(roundf(base_ess * tier_mult * aroma_essence_mult * _stop_essence_mult * frenzy_mult))
		_combo += tier
		_combo_timer = 5.0
		frenzy_add = (24.0 if is_mixed_kind(kind) else 18.0) * tier_mult * frenzy_gain_mult
	else:
		tube_gain = 8.0 * tier_mult * (1.0 + strength_tube_bonus * 0.5) * frenzy_mult
		ess_gain = int(roundf(3.0 * tier_mult * aroma_essence_mult * _stop_essence_mult * frenzy_mult))
		_combo_timer = 5.0
		if tier >= 2:
			_combo += 1

	_play_pentatonic(clampi(_combo % 8 + (1 if tier >= 2 else 0), 0, 7), -1.0 if rel == &"liked" or kind == BubbleKind.GOLD else -4.0)

	if ess_gain > 0:
		_grant_essence(ess_gain)
	var prev_frenzy: float = _frenzy_charge
	if frenzy_add > 0.0 and _frenzy_timer <= 0.0:
		_frenzy_charge = minf(100.0, _frenzy_charge + frenzy_add)
	var frenzy_just_ready: bool = prev_frenzy < 100.0 and _frenzy_charge >= 100.0 and _frenzy_timer <= 0.0

	if rel == &"liked" or kind == BubbleKind.GOLD:
		_disliked_mistake_streak = 0
		_disliked_streak_timer = 0.0

	if frenzy_just_ready:
		_set_trixie_reaction("sorprendida", 2.0, "¡Caldero al 100%! ¡Pulsa [ESPACIO] para el Frenesí!")
	elif kind == BubbleKind.GOLD:
		_set_trixie_reaction("sorprendida", 1.8, "¡Un Orbe Estrella! ¡Brilla muchísimo!")
	elif rel == &"liked" and (tier >= 2 or is_mixed_kind(kind)):
		_set_trixie_reaction("confiada", 1.7, "¡%s pulverizado! ¡Cómo sube el elixir!" % get_element_name(kind))
	elif rel == &"liked":
		_set_trixie_reaction("confiada", 1.5, "¡Bien triturado! Sigue buscando los afines.")
	elif rel == &"ingredient":
		_set_trixie_reaction("normal", 1.5, "Tip: ¡arrastra %s sobre el otro color para mezclar!" % get_element_name(kind))

	if (rel == &"liked" and (tier >= 2 or is_mixed_kind(kind) or _combo >= 2)) or kind == BubbleKind.GOLD:
		var sat_line: String = ""
		if (tier >= 2 or is_mixed_kind(kind) or kind == BubbleKind.GOLD) and _active_customer != null and not _active_customer.satisfied_lines.is_empty():
			sat_line = _active_customer.satisfied_lines[randi() % _active_customer.satisfied_lines.size()]
		_set_customer_reaction("sonrojada", 1.8, sat_line)

	var pop_txt: String = "+%d%%  +%d✦" % [int(roundf(tube_gain)), ess_gain]
	if tier >= 2:
		pop_txt = "¡x%d! %s" % [tier, pop_txt]
	if kind != BubbleKind.BOMB:
		_spawn_popup(pos, pop_txt, Color(1.0, 0.90, 0.40) if (rel == &"liked" or kind == BubbleKind.GOLD) else Color(0.84, 0.92, 1.0))

	if _tutorial.active and _tutorial.step == TutorialDirector.Step.BASIC_BREAK_LIKED and rel == &"liked":
		_advance_cauldron_tutorial(TutorialDirector.Step.BASIC_PURGE_DISLIKED)
	elif _tutorial.active and _tutorial.step == TutorialDirector.Step.MIX_BREAK_RESULT and rel == &"liked":
		_finish_mix_tutorial()

	if tube_gain > 0.0:
		_add_tube_progress(tube_gain)

	if chain_spark_jumps > 0 and (rel == &"liked" or tier >= 2):
		_trigger_chain_spark_zaps(pos, chain_spark_jumps)

	if kind == BubbleKind.BOMB:
		_detonate_alchemy_bomb(pos)


func _trigger_chain_spark_zaps(origin: Vector2, jumps: int) -> void:
	var target_ids: Array[int] = []
	for o: Dictionary in _orbs:
		var oid: int = int(o["id"])
		if oid == _lifted_orb_id:
			continue
		var rel: StringName = get_orb_relation(int(o["kind"]))
		if rel == &"liked" or rel == &"ingredient" or int(o["kind"]) == BubbleKind.GOLD:
			if (o["pos"] as Vector2).distance_to(origin) <= 270.0:
				target_ids.append(oid)
				if target_ids.size() >= jumps:
					break
	for tid: int in target_ids:
		var tidx: int = _find_orb_idx_by_id(tid)
		if tidx != -1:
			_lightning_arcs.append({
				"from": origin,
				"to": _orbs[tidx]["pos"] as Vector2,
				"color": Color(0.36, 0.96, 1.0),
				"life": 0.25,
				"max_life": 0.25,
			})
			_hit_orb_by_id(tid, maxi(_get_effective_click_damage(), 2), false)


func _detonate_alchemy_bomb(bpos: Vector2) -> void:
	_cauldron_shake = maxf(_cauldron_shake, 11.0)
	_shockwaves.append({
		"pos": bpos,
		"radius": 18.0,
		"max_radius": 185.0,
		"color": Color(0.88, 0.42, 1.0),
		"life": 0.38,
		"max_life": 0.38,
	})
	var target_ids: Array[int] = []
	for o: Dictionary in _orbs:
		var oid: int = int(o["id"])
		if oid == _lifted_orb_id:
			continue
		if (o["pos"] as Vector2).distance_to(bpos) <= 185.0:
			if get_orb_relation(int(o["kind"])) != &"disliked":
				target_ids.append(oid)
	if not target_ids.is_empty():
		_spawn_popup(bpos + Vector2(0, -28), "¡BOOM ALQUÍMICO!", Color(0.92, 0.56, 1.0))
		for tid: int in target_ids:
			_hit_orb_by_id(tid, 3, false)
		if _trixie_emotion != "sonrojada":
			_set_trixie_reaction("sorprendida", 1.9, "¡WHOA! ¡Bomba alquímica en reacción en cadena!")


func _purge_orb_by_id(orb_id: int) -> void:
	var idx: int = _find_orb_idx_by_id(orb_id)
	if idx == -1:
		return
	var o: Dictionary = _orbs[idx]
	var pos: Vector2 = o["pos"] as Vector2
	var rel: StringName = get_orb_relation(int(o["kind"]))
	if _hold_orb_id == orb_id:
		_hold_orb_id = -1
	if _pressed_orb_id == orb_id:
		_pressed_orb_id = -1
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

	if _tutorial.active and _tutorial.step == TutorialDirector.Step.BASIC_PURGE_DISLIKED and rel == &"disliked":
		_advance_cauldron_tutorial(TutorialDirector.Step.BASIC_READY_SUMMARY)


func try_activate_frenzy() -> bool:
	if _frenzy_charge < 100.0 or _frenzy_timer > 0.0 or round_ending or _closing_active:
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

	var liked_k: int = int(get_customer_chemistry()["liked"])
	var transmuted: int = 0
	for o: Dictionary in _orbs:
		if get_orb_relation(int(o["kind"])) == &"disliked":
			o["kind"] = liked_k
			o["hp"] = 1
			o["radius"] = ORB_RADIUS + (5.0 if is_mixed_kind(liked_k) else 0.0) + float(int(o["tier"]) - 1) * 6.0
			o["scale_pop"] = 1.32
			o["hit_flash"] = 0.75
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
		"¡FRENESÍ ESCARLATA! %d ❌ transmutados, 1 golpe y 2x TODO!" % transmuted)
	_set_customer_reaction("sonrojada", _frenzy_timer)
	_spawn_popup(CAULDRON_CENTER, "¡FRENESÍ ESCARLATA x2!", Color(1.0, 0.42, 0.74))
	return true


func _update_familiars(delta: float) -> void:
	if fam_michi_lvl > 0 and not _orbs.is_empty():
		_michi_timer -= delta
		if _michi_timer <= 0.0:
			_michi_timer = maxf(1.05, 2.5 - float(fam_michi_lvl - 1) * 0.32)
			var struck: bool = false
			for o: Dictionary in _orbs:
				var oid: int = int(o["id"])
				if oid == _lifted_orb_id:
					continue
				var rel: StringName = get_orb_relation(int(o["kind"]))
				if rel == &"liked" or int(o["kind"]) == BubbleKind.GOLD:
					_lightning_arcs.append({
						"from": _get_michi_pos(),
						"to": o["pos"] as Vector2,
						"color": Color(1.0, 0.72, 0.92),
						"life": 0.20,
						"max_life": 0.20,
					})
					_hit_orb_by_id(oid, maxi(click_damage, 2), false)
					struck = true
					break
			if not struck:
				var liked_k: int = int(get_customer_chemistry()["liked"])
				if is_mixed_kind(liked_k):
					var comps: Array[int] = get_recipe_components(liked_k)
					var id_a: int = -1
					var id_b: int = -1
					for o: Dictionary in _orbs:
						var oid: int = int(o["id"])
						if oid == _lifted_orb_id:
							continue
						if id_a == -1 and int(o["kind"]) == comps[0]:
							id_a = oid
						elif id_b == -1 and int(o["kind"]) == comps[1]:
							id_b = oid
					if id_a != -1 and id_b != -1:
						_combine_orbs_by_id(id_a, id_b)

	if fam_imp_lvl > 0 and not _orbs.is_empty():
		_imp_timer -= delta
		if _imp_timer <= 0.0:
			_imp_timer = maxf(1.2, 2.9 - float(fam_imp_lvl - 1) * 0.35)
			for o: Dictionary in _orbs:
				var oid: int = int(o["id"])
				if oid == _lifted_orb_id:
					continue
				if get_orb_relation(int(o["kind"])) == &"disliked":
					_lightning_arcs.append({
						"from": _get_imp_pos(),
						"to": o["pos"] as Vector2,
						"color": Color(1.0, 0.45, 0.28),
						"life": 0.20,
						"max_life": 0.20,
					})
					_purge_orb_by_id(oid)
					break

	if fam_bat_lvl > 0:
		_bat_timer -= delta
		if _bat_timer <= 0.0:
			_bat_timer = maxf(1.0, 2.4 - float(fam_bat_lvl - 1) * 0.30)
			var ess: int = int(roundf(float(4 + fam_bat_lvl * 3) * _stop_essence_mult))
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
	_state().grant_essence(amount)
	_round_essence_gained += amount


func _add_tube_progress(pct: float) -> void:
	_potion_tube_pct += pct
	if _flask_view != null:
		_flask_view.trigger_flash(0.45, true)
		_flask_view.excite(pct)
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
# CUSTOMERS WAVE & SPICY AFFINITY
# ==============================================================================

func get_affinity_points(char_id: StringName) -> int:
	return _state().get_affinity_points(char_id)


func get_affinity_level(char_id: StringName) -> int:
	return _state().get_affinity_level(char_id)


func _add_affinity(char_id: StringName, pts: int) -> bool:
	return _state().add_affinity(char_id, pts)


func _find_customer_by_id(cid: StringName) -> CustomerArchetypeData:
	for c: CustomerArchetypeData in customers_catalog:
		if c.customer_id == cid:
			return c
	return customers_catalog[0] if not customers_catalog.is_empty() else null


func _pick_customer_by_id(cid: StringName, first_order: bool = false) -> void:
	var next_c: CustomerArchetypeData = _find_customer_by_id(cid)
	if next_c == null:
		return

	_active_customer = next_c
	_current_order_chemistry = _roll_order_chemistry_for_customer(next_c.customer_id, first_order)
	_last_order_liked_kind = int(_current_order_chemistry["liked"])
	_potion_tube_pct = 0.0
	if _flask_view != null:
		_flask_view.reset_for_new_customer(first_order)
	customer_patience_max = _compute_customer_patience(next_c)
	customer_patience_left = customer_patience_max
	_customer_impatient_warned = false
	_customer_slide_t = 0.0
	_customer_spicy_mode = false
	_customer_emotion = "normal"
	_customer_emotion_timer = 0.0
	_customer_react_anim = 1.0
	_customer_order_reward = int(roundf(float(24 + orders_completed * 12) * next_c.tip_generosity_mult * order_bonus_mult * _stop_essence_mult))

	if not next_c.greeting_lines.is_empty():
		_customer_line = next_c.greeting_lines[randi() % next_c.greeting_lines.size()]
	else:
		_customer_line = "¡Prepara mi elixir favorito, brujita!"
	_show_customer_bubble(next_c.display_name, _customer_line, 3.2)

	var liked_k: int = int(get_customer_chemistry()["liked"])
	if is_mixed_kind(liked_k) and _state().should_run_mix_tutorial():
		_start_mix_tutorial()
	elif _tutorial.active:
		_update_tutorial_banner()


func _on_customer_patience_expired() -> void:
	if _active_customer == null or round_ending:
		return
	var c: CustomerArchetypeData = _active_customer
	_last_served_customer = c
	_wave_missed_count += 1
	_combo = 0
	_combo_timer = 0.0
	_potion_tube_pct = 0.0
	if _flask_view != null:
		_flask_view.trigger_flash(0.55, false)
	_cauldron_shake = maxf(_cauldron_shake, 10.0)
	_play_pentatonic(0, 0.0)
	_reset_pointer_state()

	var b: Node = _bus()
	if b != null:
		b.emit_signal("customer_patience_expired", c.customer_id, 0)

	var leave_line: String = c.impatient_lines[0] if not c.impatient_lines.is_empty() else "¡Me cansé de esperar, brujita!"
	_show_customer_bubble(c.display_name, leave_line, 2.5)
	_spawn_popup(Vector2(1620, 440), "💢 ¡%s se fue!" % c.display_name, Color(1.0, 0.32, 0.36))
	_show_toast("💢 ¡%s perdió la paciencia y se marchó!" % c.display_name, 3.0)
	_set_trixie_reaction("nerviosa", 2.2, "¡Ay, %s se cansó de esperar!" % c.display_name)

	_wave_index += 1
	_advance_wave_or_finish()


func _advance_wave_or_finish() -> void:
	if _wave_index < _wave_customers.size():
		_pick_customer_by_id(_wave_customers[_wave_index], false)
	else:
		var min_needed: int = ceili(float(_wave_customers.size()) * 0.5)
		var victory: bool = _wave_served_count >= min_needed
		if victory:
			_potion_tube_pct = 100.0
		_trigger_stop_end(victory)


func _complete_customer_order() -> void:
	if _active_customer == null or round_ending:
		return
	var c: CustomerArchetypeData = _active_customer
	_last_served_customer = c
	var overflow: float = maxf(0.0, _potion_tube_pct - 100.0)
	var crit: bool = crit_potion_lvl > 0 and _combo >= 5
	var bonus_gold: int = _customer_order_reward * (2 if crit else 1) + int(roundf(overflow * 0.4))
	_grant_essence(bonus_gold)
	_state().orders_completed += 1
	_round_orders_completed += 1
	_wave_served_count += 1

	var b: Node = _bus()
	if b != null:
		b.emit_signal("customer_served", c.customer_id, bonus_gold, 1.5 if crit else 1.1, 1)

	var aff_gain: int = 1 + (1 if get_node_level(&"encanto_mostrador") >= 3 else 0) + (1 if crit else 0) + _stop_affinity_bonus
	var leveled_up: bool = _add_affinity(c.customer_id, aff_gain)
	var new_aff_lvl: int = get_affinity_level(c.customer_id)
	_customer_spicy_mode = new_aff_lvl >= 1
	_customer_flash_timer = 1.2

	var done_line: String = ""
	if _customer_spicy_mode and not c.spicy_affinity_lines.is_empty():
		done_line = c.spicy_affinity_lines[randi() % c.spicy_affinity_lines.size()]
	elif not c.satisfied_lines.is_empty():
		done_line = c.satisfied_lines[randi() % c.satisfied_lines.size()]
	else:
		done_line = "¡Mmm, qué elixir tan delicioso, brujita!"

	if leveled_up:
		_show_toast("💋 ¡Afinidad Nv.%d con %s! Escena desbloqueada en Galería." % [new_aff_lvl, c.display_name], 4.0)
		_set_trixie_reaction("sonrojada", 2.6, "¡A %s le encantó! Mira cómo se sonroja..." % c.display_name)
	elif crit:
		_show_toast("💎 ¡POCIÓN CRÍTICA! +%d✦  +%d❤ Afinidad" % [bonus_gold, aff_gain], 2.5)
		_set_trixie_reaction("sorprendida", 2.2, "¡¿POCIÓN CRÍTICA?! ¡Hasta brilló el frasco entero!")
	elif _trixie_emotion != "sorprendida":
		if _frenzy_timer > 0.0 or new_aff_lvl >= 2:
			_set_trixie_reaction("sonrojada", 1.8, "¡Mmm, %s quedó fascinada con ese elixir!" % c.display_name)
		else:
			_set_trixie_reaction("confiada", 1.6, "¡Elixir listo para %s! +%d✦" % [c.display_name, bonus_gold])

	_spawn_popup(Vector2(1620, 440), "¡ELIXIR LISTO! +%d✦  +%d❤" % [bonus_gold, aff_gain], Color(1.0, 0.78, 0.92))
	_set_customer_reaction("sonrojada", 3.0, done_line)

	_wave_index += 1
	_advance_wave_or_finish()


func _show_toast(txt: String, duration: float = 3.5) -> void:
	if _hud != null:
		_hud.show_toast(txt, duration)


func _set_trixie_reaction(emotion: String, dur: float, line: String) -> void:
	if emotion != _trixie_emotion or emotion in ["hollin", "sorprendida", "sonrojada"]:
		_trixie_react_anim = 1.0
	_trixie_emotion = emotion
	_trixie_emotion_timer = dur
	if line != "":
		_trixie_line = line
		if not _tutorial.active and not _closing_active:
			_show_trixie_bubble("Trixie", line, clampf(dur, 2.4, 3.6), false, false)


func _set_customer_reaction(emotion: String, dur: float, line: String = "") -> void:
	if emotion != _customer_emotion or emotion in ["sonrojada", "impaciente"]:
		_customer_react_anim = 1.0
	_customer_emotion = emotion
	_customer_emotion_timer = dur
	if line != "":
		_customer_line = line
		if not _closing_active:
			var cname: String = _active_customer.display_name if _active_customer != null else "Clienta"
			_show_customer_bubble(cname, line, clampf(dur, 2.4, 3.6))


# ==============================================================================
# HUD CONNECTION & BUBBLE/PAUSE DELEGATES
# ==============================================================================

func _connect_hud() -> void:
	if _hud == null:
		return
	_hud.pause_requested.connect(func() -> void:
		if not _fading_out:
			_hud.set_pause_visible(true)
	)
	_hud.frenzy_requested.connect(try_activate_frenzy)
	_hud.tutorial_ack_pressed.connect(_acknowledge_basic_tutorial_summary)
	_hud.closing_advance_requested.connect(_handle_closing_advance_input)
	_hud.closing_typewriter_tick.connect(func() -> void:
		_play_pentatonic(3, -12.0)
	)
	_hud.return_to_map_requested.connect(_on_pause_return_to_map)
	_hud.restart_requested.connect(_on_pause_restart)
	_hud.main_menu_requested.connect(_on_pause_main_menu)
	if _hud.chem_visual_canvas != null:
		_hud.chem_visual_canvas.draw.connect(_draw_chem_visual_strip)


func _on_pause_return_to_map() -> void:
	if _fading_out or _tutorial.active:
		return
	if _hud != null:
		_hud.set_pause_visible(false)
	_fading_out = true
	var fader: Node = _fader()
	if fader != null:
		fader.call("fade_to_scene", "res://scenes/meta/WorldMap.tscn", 0.45, 0.45)
	else:
		get_tree().change_scene_to_file("res://scenes/meta/WorldMap.tscn")


func _on_pause_restart() -> void:
	if _hud != null:
		_hud.set_pause_visible(false)
	_state().reset_run()
	get_tree().reload_current_scene()


func _on_pause_main_menu() -> void:
	if _hud != null:
		_hud.set_pause_visible(false)
	var fader: Node = _fader()
	if fader != null:
		fader.call("fade_to_scene", "res://scenes/ui/MainMenu.tscn", 0.4, 0.4)
	else:
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _show_trixie_bubble(title: String, text: String, duration: float, is_tutorial: bool = false, show_ack: bool = false) -> void:
	if _hud == null or _closing_active or text == "":
		return
	if _tutorial.active and not is_tutorial:
		return
	_hud.show_trixie_bubble(title, text, duration, is_tutorial, show_ack)


func _hide_trixie_bubble(instant: bool = false) -> void:
	if _hud != null:
		_hud.hide_trixie_bubble(instant)


func _show_customer_bubble(speaker_name: String, text: String, duration: float = 3.2) -> void:
	if _hud == null or _closing_active or text == "":
		return
	_hud.show_customer_bubble(speaker_name, text, duration)


func _hide_customer_bubble(instant: bool = false) -> void:
	if _hud != null:
		_hud.hide_customer_bubble(instant)


# ==============================================================================
# WORLD DRAWING (CAULDRON, VERTICAL TUBE, WAIFUS, TUTORIAL HIGHLIGHTS)
# ==============================================================================

func _clamp_to_cauldron_ellipse(pos: Vector2, inset: float) -> Vector2:
	var rx: float = maxf(20.0, CAULDRON_ELLIPSE_RX - inset)
	var ry: float = maxf(20.0, CAULDRON_ELLIPSE_RY - inset)
	var rel: Vector2 = pos - CAULDRON_CENTER
	var norm_r2: float = (rel.x * rel.x) / (rx * rx) + (rel.y * rel.y) / (ry * ry)
	if norm_r2 <= 1.0:
		return pos
	return CAULDRON_CENTER + rel / sqrt(norm_r2)


func _is_inside_cauldron_ellipse(pos: Vector2, inset: float) -> bool:
	var rx: float = maxf(20.0, CAULDRON_ELLIPSE_RX - inset)
	var ry: float = maxf(20.0, CAULDRON_ELLIPSE_RY - inset)
	var rel: Vector2 = pos - CAULDRON_CENTER
	return (rel.x * rel.x) / (rx * rx) + (rel.y * rel.y) / (ry * ry) <= 1.0


func _get_orb_depth_scale(pos: Vector2) -> float:
	var ny: float = clampf((pos.y - CAULDRON_CENTER.y) / CAULDRON_ELLIPSE_RY, -1.0, 1.0)
	return lerpf(0.93, 1.06, (ny + 1.0) * 0.5)


func _draw_filled_ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, ry / maxf(1.0, rx)))
	draw_circle(Vector2.ZERO, rx, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_ellipse_arc(center: Vector2, rx: float, ry: float, start_a: float, end_a: float, col: Color, width: float) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, ry / maxf(1.0, rx)))
	draw_arc(Vector2.ZERO, rx, start_a, end_a, 48, col, width)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _apply_stop_background() -> void:
	_stop_bg_tex = null
	if _bg_sprite == null:
		return
	var bg_path: String = String(_active_stop.get("bg_path", ""))
	if bg_path != "" and ResourceLoader.exists(bg_path):
		var tex: Texture2D = load(bg_path) as Texture2D
		if tex != null:
			_stop_bg_tex = tex
			var tex_sz: Vector2 = tex.get_size()
			var overscan: Vector2 = Vector2(24.0, 24.0)
			_bg_sprite.texture = tex
			_bg_sprite.position = -overscan
			if tex_sz.x > 0.0 and tex_sz.y > 0.0:
				_bg_sprite.scale = (VIEWPORT_SIZE + overscan * 2.0) / tex_sz
			_bg_sprite.visible = true
			return
	_bg_sprite.texture = null
	_bg_sprite.visible = false


func _draw() -> void:
	if _stop_bg_tex == null:
		draw_rect(Rect2(0, 0, 1920, 1080), _stop_bg_tint)

	_draw_trixie_stage_left()
	_draw_customer_stage_right()
	_draw_vertical_potion_tube()
	_draw_visual_order_bubble()

	var shake_v: Vector2 = Vector2(randf_range(-_cauldron_shake, _cauldron_shake), randf_range(-_cauldron_shake, _cauldron_shake)) if _cauldron_shake > 0.2 else Vector2.ZERO
	var c_pos: Vector2 = CAULDRON_CENTER + shake_v

	# Layer 1: Broth liquid tucked slightly wider than inner opening so foreground rim overlaps cleanly
	var broth_base: Color = _flask_view.broth_current_color if _flask_view != null else PotionFlaskView.BROTH_NEUTRAL_COLOR
	var liq_col: Color = broth_base.lightened(0.08 + 0.04 * sin(_time * 8.0)) if _frenzy_timer > 0.0 else broth_base
	_draw_filled_ellipse(c_pos, CAULDRON_ELLIPSE_RX * 1.035, CAULDRON_ELLIPSE_RY * 1.035, liq_col)
	_draw_filled_ellipse(c_pos + Vector2(0.0, 16.0), CAULDRON_ELLIPSE_RX * 0.93, CAULDRON_ELLIPSE_RY * 0.89, liq_col.lightened(0.10))
	var ripple_base: Color = liq_col.lightened(0.48)
	var ripple_col: Color = Color(1.0, 0.45, 0.78, 0.52) if _frenzy_timer > 0.0 else Color(ripple_base.r, ripple_base.g, ripple_base.b, 0.30)
	_draw_ellipse_arc(c_pos + Vector2(0.0, 10.0), CAULDRON_ELLIPSE_RX * 0.84, CAULDRON_ELLIPSE_RY * 0.80, _time * 0.32, _time * 0.32 + TAU * 0.55, ripple_col, 2.5)
	_draw_ellipse_arc(c_pos + Vector2(0.0, 10.0), CAULDRON_ELLIPSE_RX * 0.62, CAULDRON_ELLIPSE_RY * 0.58, -_time * 0.24, -_time * 0.24 + TAU * 0.45, Color(ripple_col.r, ripple_col.g, ripple_col.b, ripple_col.a * 0.75), 2.0)

	var steam_base: Color = liq_col.lightened(0.56)
	for st: Dictionary in _ambient_steam:
		var spos: Vector2 = c_pos + Vector2(float(st["x"]), float(st["y"]))
		if _is_inside_cauldron_ellipse(spos, 18.0):
			var a: float = 0.10 + 0.08 * sin(_time * 2.0 + float(st["phase"]))
			draw_circle(spos, float(st["r"]), Color(steam_base.r, steam_base.g, steam_base.b, a))

	# Layer 3: Foreground cauldron rim & handles drawn over the broth
	if _cauldron_tex != null:
		draw_texture_rect(_cauldron_tex, Rect2(c_pos - CAULDRON_HOLE_OFFSET, CAULDRON_DRAW_SIZE), false)

	var font: Font = ThemeDB.fallback_font

	# Layer 4: Orbs Y-sorted with subtle depth scale
	var sorted_orbs: Array[Dictionary] = []
	for o: Dictionary in _orbs:
		if int(o["id"]) == _lifted_orb_id:
			continue
		sorted_orbs.append(o)
	sorted_orbs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float((a["pos"] as Vector2).y) < float((b["pos"] as Vector2).y)
	)
	for o: Dictionary in sorted_orbs:
		_draw_alchemy_orb(o, shake_v, false)

	if _is_lifting and _lifted_orb_id != -1:
		var l_idx: int = _find_orb_idx_by_id(_lifted_orb_id)
		if l_idx != -1:
			var l_orb: Dictionary = _orbs[l_idx]
			var l_pos: Vector2 = (l_orb["pos"] as Vector2) + shake_v
			var l_rad: float = float(l_orb["radius"]) * float(l_orb["scale_pop"]) * 1.16
			if _lift_hover_target_id != -1:
				var t_idx: int = _find_orb_idx_by_id(_lift_hover_target_id)
				if t_idx != -1:
					var t_orb: Dictionary = _orbs[t_idx]
					var t_pos: Vector2 = (t_orb["pos"] as Vector2) + shake_v
					var t_rad: float = float(t_orb["radius"])
					var pulse: float = 0.5 + 0.5 * sin(_time * 9.0)
					draw_arc(t_pos, t_rad + 12.0 + pulse * 4.0, 0.0, TAU, 32, Color(0.45, 0.96, 1.0, 0.95), 4.0)
					var sk: int = int(l_orb["kind"])
					var dk: int = int(t_orb["kind"])
					var res_k: int = get_combine_result(sk, dk)
					var preview_txt: String = ""
					if sk == BubbleKind.GOLD or dk == BubbleKind.GOLD:
						var nt: int = mini(3, (int(t_orb["tier"]) if sk == BubbleKind.GOLD else int(l_orb["tier"])) + 1)
						preview_txt = "⭐ + %s -> x%d!" % [get_element_glyph(res_k), nt]
					elif sk == dk:
						var nt: int = mini(3, maxi(int(l_orb["tier"]), int(t_orb["tier"])) + 1)
						preview_txt = "%s + %s -> x%d!" % [get_element_glyph(sk), get_element_glyph(dk), nt]
					else:
						preview_txt = "%s + %s -> %s" % [get_element_glyph(sk), get_element_glyph(dk), get_element_name(res_k)]
					draw_string(font, t_pos + Vector2(-115, -t_rad - 20.0), preview_txt, HORIZONTAL_ALIGNMENT_CENTER, 230, 17, Color(1.0, 0.95, 0.58))
			draw_circle(l_pos + Vector2(6.0, 16.0), l_rad * 0.92, Color(0.0, 0.0, 0.0, 0.42))
			_draw_alchemy_orb(l_orb, shake_v, true)

	_draw_tutorial_orb_guide(shake_v, font)

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

	# COMBO badge positioned at right shoulder of cauldron so top tutorial banner stays 100% clear
	if _combo > 0:
		draw_string(font, Vector2(1175, 224), "COMBO", HORIZONTAL_ALIGNMENT_CENTER, 170, 24, Color(1.0, 0.88, 0.36))
		draw_string(font, Vector2(1175, 268), "x%d!" % _combo, HORIZONTAL_ALIGNMENT_CENTER, 170, 42, Color(1.0, 0.56, 0.28))

	for p: Dictionary in _popups:
		var pos: Vector2 = p["pos"] as Vector2
		var txt: String = p["text"] as String
		var pcol: Color = p["color"] as Color
		var alpha: float = clampf(float(p["life"]), 0.0, 1.0)
		draw_string(font, pos + Vector2(2, 2), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(0.04, 0.02, 0.08, alpha))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(pcol.r, pcol.g, pcol.b, alpha))


func _draw_tutorial_orb_guide(shake_v: Vector2, font: Font) -> void:
	_tutorial.draw_orb_guide(
		self,
		_orbs,
		_lifted_orb_id,
		get_customer_chemistry(),
		get_orb_relation,
		ORB_RADIUS,
		shake_v,
		_time,
		font,
		round_ending,
		_closing_active
	)


func _draw_alchemy_orb(o: Dictionary, shake_v: Vector2, is_lifted: bool) -> void:
	var oid: int = int(o["id"])
	var hit_wobble: float = float(o["hit_wobble"])
	var hit_flash: float = float(o["hit_flash"])
	var wobble_off: Vector2 = Vector2(sin(_time * 75.0) * 5.0 * hit_wobble, 0.0) if hit_wobble > 0.01 else Vector2.ZERO
	var pos: Vector2 = (o["pos"] as Vector2) + shake_v + wobble_off
	var depth_scale: float = 1.0 if is_lifted else _get_orb_depth_scale(o["pos"] as Vector2)
	var hovered: bool = (oid == _hovered_orb_id)
	var hover_scale: float = 1.06 if (hovered and not is_lifted) else 1.0
	var scale_mult: float = float(o["scale_pop"]) * depth_scale * hover_scale * (1.16 if is_lifted else 1.0)
	var r: float = float(o["radius"]) * scale_mult
	var kind: int = int(o["kind"])
	var tier: int = int(o["tier"])
	var hp: int = int(o["hp"])
	var max_hp: int = int(o["max_hp"])
	var rel: StringName = get_orb_relation(kind)
	var col: Color = get_element_color(kind)

	if not is_lifted:
		_draw_filled_ellipse(pos + Vector2(0.0, r * 0.72), r * 0.76, r * 0.30, Color(0.02, 0.01, 0.06, 0.36))

	var orb_tex: Texture2D = _orb_textures.get(kind, null) as Texture2D
	if orb_tex != null:
		var draw_r: float = r * (ORB_BOMB_DRAW_MULT if kind == BubbleKind.BOMB else ORB_CANVAS_MULT)
		var mod_col: Color = Color(0.50, 0.44, 0.56, 0.92) if rel == &"disliked" else Color.WHITE
		draw_texture_rect(orb_tex, Rect2(pos - Vector2(draw_r, draw_r), Vector2(draw_r * 2.0, draw_r * 2.0)), false, mod_col)
		if hit_flash > 0.02:
			draw_circle(pos, r, Color(1.0, 1.0, 1.0, clampf(hit_flash * 0.56, 0.0, 0.60)))
		if hp < max_hp and _crack_textures.size() >= 2:
			var dmg_ratio: float = clampf(float(max_hp - hp) / float(maxi(1, max_hp)), 0.0, 1.0)
			var stage_idx: int = 1 if (dmg_ratio >= 0.55 or (max_hp >= 3 and hp <= 1)) else 0
			var crack_r: float = r * ORB_CANVAS_MULT
			var crack_rect: Rect2 = Rect2(-Vector2(crack_r, crack_r), Vector2(crack_r * 2.0, crack_r * 2.0))
			draw_set_transform(pos, float(o.get("crack_rot", 0.0)), Vector2.ONE)
			if _crack_glow_textures.size() > stage_idx:
				var glow_base: Color = col.lightened(0.60)
				var glow_a: float = clampf((0.62 if stage_idx == 0 else (0.74 + 0.22 * sin(_time * 12.0))) + hit_flash * 0.30, 0.0, 1.0)
				draw_texture_rect(_crack_glow_textures[stage_idx], crack_rect, false, Color(glow_base.r, glow_base.g, glow_base.b, glow_a))
			draw_texture_rect(_crack_textures[stage_idx], crack_rect, false, Color.WHITE)
			if hit_flash > 0.12:
				draw_texture_rect(_crack_textures[stage_idx], crack_rect, false, Color(1.0, 1.0, 1.0, clampf(hit_flash * 0.35, 0.0, 0.40)))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(pos, r, col.darkened(0.22) if rel == &"disliked" else col)
		if hit_flash > 0.02:
			draw_circle(pos, r, Color(1.0, 1.0, 1.0, clampf(hit_flash * 0.62, 0.0, 0.65)))
		draw_arc(pos, r, 0.0, TAU, 28, col.lightened(0.45), 2.5)
		draw_circle(pos + Vector2(-r * 0.32, -r * 0.32), r * 0.26, Color(1, 1, 1, 0.58))

		if hp < max_hp:
			var dmg_ratio: float = clampf(float(max_hp - hp) / float(maxi(1, max_hp)), 0.0, 1.0)
			var crack_col: Color = Color(0.12, 0.06, 0.18, 0.85)
			draw_polyline(PackedVector2Array([
				pos + Vector2(-r * 0.65, -r * 0.18),
				pos + Vector2(-r * 0.18, -r * 0.05),
				pos + Vector2(-r * 0.04, r * 0.38),
			]), crack_col, 2.6)
			if dmg_ratio >= 0.5 or (max_hp >= 3 and hp <= 1):
				draw_polyline(PackedVector2Array([
					pos + Vector2(r * 0.55, -r * 0.35),
					pos + Vector2(r * 0.12, 0.02 * r),
					pos + Vector2(r * 0.34, r * 0.45),
				]), crack_col, 2.6)

		var glyph: String = get_element_glyph(kind)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-14, 9), glyph, HORIZONTAL_ALIGNMENT_CENTER, 28, 22 if tier == 1 else 25, Color.WHITE)

	var font: Font = ThemeDB.fallback_font

	if tier >= 2:
		draw_circle(pos + Vector2(-r * 0.60, -r * 0.60), 12.0, Color(0.16, 0.08, 0.26, 0.94))
		draw_arc(pos + Vector2(-r * 0.60, -r * 0.60), 12.0, 0.0, TAU, 16, Color(1.0, 0.86, 0.34), 2.0)
		draw_string(font, pos + Vector2(-r * 0.60 - 11, -r * 0.60 + 5), "x%d" % tier, HORIZONTAL_ALIGNMENT_CENTER, 22, 12, Color(1.0, 0.92, 0.52))


func _draw_vertical_potion_tube() -> void:
	if _flask_view != null:
		var liked_col: Color = get_element_color(int(get_customer_chemistry()["liked"]))
		_flask_view.draw_potion_tube(self, _potion_tube_pct, liked_col)


func _draw_mini_orb_badge(ci: CanvasItem, center: Vector2, rad: float, kind: int, is_forbidden: bool = false) -> void:
	var col: Color = get_element_color(kind)
	var orb_tex: Texture2D = _orb_textures.get(kind, null) as Texture2D
	if orb_tex != null:
		if is_forbidden:
			ci.draw_circle(center, rad + 3.0, Color(0.22, 0.04, 0.08, 0.92))
		var draw_r: float = rad * (ORB_BOMB_DRAW_MULT if kind == BubbleKind.BOMB else ORB_CANVAS_MULT)
		var mod_c: Color = Color(0.76, 0.70, 0.82, 1.0) if is_forbidden else Color.WHITE
		ci.draw_texture_rect(orb_tex, Rect2(center - Vector2(draw_r, draw_r), Vector2(draw_r * 2.0, draw_r * 2.0)), false, mod_c)
		if is_forbidden:
			ci.draw_arc(center, rad, 0.0, TAU, 24, Color(1.0, 0.30, 0.36), 2.5)
	else:
		if is_forbidden:
			ci.draw_circle(center, rad + 3.0, Color(0.22, 0.04, 0.08, 0.92))
			ci.draw_circle(center, rad, col.darkened(0.25))
			ci.draw_arc(center, rad, 0.0, TAU, 24, Color(1.0, 0.30, 0.36), 2.5)
		else:
			ci.draw_circle(center, rad, col)
			ci.draw_arc(center, rad, 0.0, TAU, 24, col.lightened(0.45), 2.2)
			ci.draw_circle(center + Vector2(-rad * 0.32, -rad * 0.32), rad * 0.25, Color(1, 1, 1, 0.58))
		var glyph: String = get_element_glyph(kind)
		var fsize: int = maxi(12, int(roundf(rad * 0.85)))
		ci.draw_string(ThemeDB.fallback_font, center + Vector2(-rad * 0.75, float(fsize) * 0.38), glyph, HORIZONTAL_ALIGNMENT_CENTER, int(rad * 1.5), fsize, Color.WHITE)
	if is_forbidden:
		ci.draw_circle(center + Vector2(rad * 0.68, -rad * 0.68), 8.5, Color(0.88, 0.12, 0.20))
		ci.draw_string(ThemeDB.fallback_font, center + Vector2(rad * 0.68 - 5.0, -rad * 0.68 + 4.0), "✕", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


func _draw_visual_order_bubble() -> void:
	if _active_customer == null or _flask_view == null:
		return
	_flask_view.draw_order_bubble(self, get_customer_chemistry(), _time, _draw_mini_orb_badge)


func _draw_chem_visual_strip() -> void:
	if _hud == null or _hud.chem_visual_canvas == null:
		return
	var canvas: Control = _hud.chem_visual_canvas
	var chem: Dictionary = get_customer_chemistry()
	var liked_k: int = int(chem["liked"])
	var disliked_k: int = int(chem["disliked"])
	var font: Font = ThemeDB.fallback_font
	var cy: float = canvas.size.y * 0.5

	canvas.draw_string(font, Vector2(4.0, cy + 5.0), "PIDE:", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.55, 1.0, 0.68))
	_draw_mini_orb_badge(canvas, Vector2(72.0, cy), 17.0, liked_k, false)

	if is_mixed_kind(liked_k):
		var comps: Array[int] = get_recipe_components(liked_k)
		canvas.draw_string(font, Vector2(96.0, cy + 6.0), "=", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.92, 0.65))
		_draw_mini_orb_badge(canvas, Vector2(130.0, cy), 14.0, comps[0], false)
		canvas.draw_string(font, Vector2(150.0, cy + 6.0), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.92, 0.65))
		_draw_mini_orb_badge(canvas, Vector2(182.0, cy), 14.0, comps[1], false)
	else:
		var neutral_k: int = int(chem["neutral"])
		canvas.draw_string(font, Vector2(106.0, cy + 5.0), "OK:", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.84, 0.88, 0.96))
		_draw_mini_orb_badge(canvas, Vector2(152.0, cy), 14.0, neutral_k, false)

	canvas.draw_line(Vector2(276.0, 6.0), Vector2(276.0, canvas.size.y - 6.0), Color(1, 1, 1, 0.16), 2.0)
	canvas.draw_string(font, Vector2(294.0, cy + 5.0), "EVITA:", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.45, 0.50))
	_draw_mini_orb_badge(canvas, Vector2(374.0, cy), 17.0, disliked_k, true)


func _draw_trixie_stage_left() -> void:
	CharacterArt.draw_trixie_halfbody(self, _trixie_stage_rect, _trixie_emotion, _time, 1.0, _trixie_react_anim)


func _draw_customer_stage_right() -> void:
	var slide_off: float = (1.0 - _customer_slide_t) * 140.0
	if _active_customer != null:
		if CharacterArt.has_customer_halfbody(_active_customer.customer_id):
			var stage: Rect2 = Rect2(_customer_stage_rect.position + Vector2(slide_off, 0.0), _customer_stage_rect.size)
			CharacterArt.draw_customer_halfbody(self, stage, _active_customer.customer_id, _customer_emotion, _time, 1.0, _customer_react_anim)
		else:
			var stage: Rect2 = Rect2(1408 + slide_off, 150, 486, 580)
			draw_expressive_waifu_bust(self, stage, _active_customer.customer_id, _customer_spicy_mode or _customer_emotion == "sonrojada" or _customer_flash_timer > 0.0, _time)


static func draw_expressive_waifu_bust(ci: CanvasItem, rect: Rect2, cid: StringName, spicy: bool, t: float) -> void:
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
			# Noble High-Elf pointed ears + golden lunar tiara (no witch hat)
			ci.draw_colored_polygon(PackedVector2Array([center + Vector2(-64, -76) * s, center + Vector2(-118, -94) * s, center + Vector2(-64, -54) * s]), skin)
			ci.draw_colored_polygon(PackedVector2Array([center + Vector2(64, -76) * s, center + Vector2(118, -94) * s, center + Vector2(64, -54) * s]), skin)
			ci.draw_arc(center + Vector2(0, -114) * s, 32.0 * s, PI + 0.25, TAU - 0.25, 16, Color(1.0, 0.86, 0.36), 4.0 * s)
			ci.draw_circle(center + Vector2(0, -142) * s, 6.0 * s, Color(0.45, 0.92, 1.0))
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
	if _hud == null:
		return
	var stop_icon: String = String(_active_stop.get("icon", "📍"))
	var stop_name: String = String(_active_stop.get("name", "Parada"))
	var shown_wave: int = mini(_wave_index + 1, _wave_customers.size())
	var cust_title: String = ""
	var aff_txt: String = ""
	if _active_customer != null:
		var cid: StringName = _active_customer.customer_id
		cust_title = "%s (%s)" % [_active_customer.display_name, _active_customer.species_archetype]
		aff_txt = "❤ Nv.%d · +%d✦" % [get_affinity_level(cid), _customer_order_reward]
	_hud.refresh_status(
		essence_gold,
		stop_icon,
		stop_name,
		shown_wave,
		_wave_customers.size(),
		_wave_served_count,
		_wave_missed_count,
		customer_patience_left,
		customer_patience_max,
		_is_patience_paused_for_tutorial(),
		CUSTOMER_IMPATIENT_RATIO,
		_frenzy_charge,
		_frenzy_timer,
		cust_title,
		aff_txt
	)


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


# ==============================================================================
# AUTOLOAD SAFE HELPERS & SMOKE TEST API
# ==============================================================================

func _audio() -> Node:
	return get_node_or_null("/root/AudioJuiceManager")


func _bus() -> Node:
	return get_node_or_null("/root/EventBus")


func _settings() -> Node:
	return get_node_or_null("/root/GameSettings")


func _fader() -> Node:
	return get_node_or_null("/root/SceneFader")


func _play_pentatonic(step_index: int, vol_db: float = 0.0) -> void:
	var a: Node = _audio()
	if a != null:
		a.call("play_pentatonic", step_index, vol_db)


## Exercises cauldron mechanics, paused just-in-time tutorials, per-customer patience timeout, wave closing dialogue, and clean HUD.
func run_incremental_smoke_step() -> Dictionary:
	return MainGameSmokeRunner.run(self)
