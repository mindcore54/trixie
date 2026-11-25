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

enum BubbleKind {
	RED,
	BLUE,
	GREEN,
	YELLOW,
	PURPLE,
	CYAN,
	GOLD,
	BOMB,
}

enum CauldronTutStep {
	NONE = 0,
	BASIC_BREAK_LIKED = 1,
	BASIC_PURGE_DISLIKED = 2,
	BASIC_READY_SUMMARY = 3,
	MIX_DRAG_COMBINE = 4,
	MIX_BREAK_RESULT = 5,
}

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
const STAGE_BG_SHADER_PATH: String = "res://shaders/stage_bg_depth.gdshader"
const CAULDRON_FIRE_SHADER_PATH: String = "res://shaders/cauldron_fire_glow.gdshader"
const FLASK_GLASS_TEX_PATH: String = "res://assets/props/items/flask_empty.png"
const FLASK_MASK_TEX_PATH: String = "res://assets/props/items/flask_liquid_mask.png"
const FLASK_LIQUID_SHADER_PATH: String = "res://shaders/flask_liquid.gdshader"
const ORB_TEX_DIR: String = "res://assets/props/items/orbs/"
const ORB_CANVAS_MULT: float = 1.067
const ORB_BOMB_DRAW_MULT: float = 1.467
const DIALOG_BG_TEX_PATH: String = "res://assets/ui/hud/dialog_bg.png"
const DIALOG_SHADOW_TEX_PATH: String = "res://assets/ui/hud/dialog_bg_shadow.png"
const CLOSING_PARCHMENT_POS: Vector2 = Vector2(267.0, 750.0)
const CLOSING_PARCHMENT_SIZE: Vector2 = Vector2(1386.0, 300.0)
const DIALOG_SHADOW_PAD: Vector2 = Vector2(24.0, 24.0)
const DIALOG_SHADOW_OFFSET: Vector2 = Vector2(10.0, 14.0)
const SPEECH_BUBBLE_TEX_PATH: String = "res://assets/ui/hud/speech_bubble.png"
const SPEECH_BUBBLE_SHADOW_TEX_PATH: String = "res://assets/ui/hud/speech_bubble_shadow.png"
const SPEECH_BUBBLE_SIZE: Vector2 = Vector2(460.0, 223.0)
const SPEECH_BUBBLE_BODY_H: float = 180.0
const SPEECH_BUBBLE_SHADOW_PAD: Vector2 = Vector2(18.0, 18.0)
const SPEECH_BUBBLE_SHADOW_OFFSET: Vector2 = Vector2(6.0, 9.0)
const TRIXIE_BUBBLE_POS: Vector2 = Vector2(356.0, 78.0)
const CUSTOMER_BUBBLE_POS: Vector2 = Vector2(1418.0, 638.0)

const DRAG_LIFT_THRESHOLD: float = 12.0
const HOLD_HIT_START_DELAY: float = 0.16
const RIGHT_PURGE_HOLD_INTERVAL: float = 0.13
const BASE_ORB_HP: int = 3
const CLOSING_CHARS_PER_SEC: float = 54.0

const TUBE_RECT: Rect2 = Rect2(1312.0, 265.0, 54.0, 445.0)
const FLASK_RECT: Rect2 = Rect2(1304.0, 238.0, 88.0, 501.0)
const BROTH_NEUTRAL_COLOR: Color = Color(0.11, 0.09, 0.22)
const FLASK_NEUTRAL_COLOR: Color = Color(0.42, 0.36, 0.58)
const AFFINITY_THRESHOLDS: Array[int] = [3, 7, 12]

const CUSTOMER_CHEMISTRY: Dictionary = {
	&"sylvi": {"liked": BubbleKind.RED, "neutral": BubbleKind.GREEN, "disliked": BubbleKind.BLUE},
	&"velvet": {"liked": BubbleKind.PURPLE, "neutral": BubbleKind.RED, "disliked": BubbleKind.GREEN},
	&"seraphina": {"liked": BubbleKind.YELLOW, "neutral": BubbleKind.GREEN, "disliked": BubbleKind.BLUE},
	&"mona": {"liked": BubbleKind.CYAN, "neutral": BubbleKind.BLUE, "disliked": BubbleKind.RED},
	&"roxy": {"liked": BubbleKind.YELLOW, "neutral": BubbleKind.RED, "disliked": BubbleKind.BLUE},
}

const GameStateScript: GDScript = preload("res://scripts/autoloads/GameState.gd")

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
var _tube_flash_timer: float = 0.0
var _tube_flash_positive: bool = true

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
var _toast_timer: float = 0.0

# In-game Cauldron Tutorial & Ephemeral Speech Bubbles
var _tut_active: bool = false
var _tut_step: CauldronTutStep = CauldronTutStep.NONE
var _trixie_bubble: Control
var _trixie_bubble_title: Label
var _trixie_bubble_body: Label
var _trixie_bubble_ack_btn: Button
var _trixie_bubble_tween: Tween = null
var _trixie_bubble_timer: float = 0.0
var _trixie_bubble_is_tutorial: bool = false
var _trixie_bubble_showing: bool = false

var _cust_bubble: Control
var _cust_bubble_name: Label
var _cust_bubble_body: Label
var _cust_bubble_tween: Tween = null
var _cust_bubble_timer: float = 0.0
var _cust_bubble_showing: bool = false

# Closing Dialogue Overlay before smooth fade to WorldMap
var _closing_active: bool = false
var _closing_lines: Array[Dictionary] = []
var _closing_idx: int = -1
var _closing_full_text: String = ""
var _closing_shown_chars: float = 0.0
var _closing_overlay: Control
var _closing_parchment: Control
var _closing_speaker_lbl: Label
var _closing_text_lbl: Label
var _closing_continue_lbl: Label

# UI nodes
var camera: Camera2D
var _cauldron_tex: Texture2D
var _stop_bg_tex: Texture2D = null
var _bg_sprite: Sprite2D = null
var _bg_shader_mat: ShaderMaterial = null
var _bg_frenzy_mix: float = 0.0
var _fire_glow_rect: ColorRect = null
var _fire_shader_mat: ShaderMaterial = null
var _flask_glass_tex: Texture2D = null
var _flask_mask_tex: Texture2D = null
var _flask_liquid_sprite: Sprite2D = null
var _flask_glass_sprite: Sprite2D = null
var _flask_liquid_mat: ShaderMaterial = null
var _tube_display_pct: float = 0.0
var _tube_fill_vel: float = 0.0
var _tube_slosh_amp: float = 0.0
var _tube_slosh_tilt: float = 0.0
var _tube_slosh_vel: float = 0.0
var _tube_pour_glow: float = 0.0
var _tube_color_current: Color = FLASK_NEUTRAL_COLOR
var _mix_hue_vec: Vector2 = Vector2.ZERO
var _mix_weight: float = 0.0
var _broth_target_color: Color = BROTH_NEUTRAL_COLOR
var _broth_current_color: Color = BROTH_NEUTRAL_COLOR
var _flask_target_color: Color = FLASK_NEUTRAL_COLOR
var _orb_textures: Dictionary = {}
var _crack_textures: Array[Texture2D] = []
var _crack_glow_textures: Array[Texture2D] = []
var _dialog_bg_tex: Texture2D = null
var _dialog_shadow_tex: Texture2D = null
var _speech_bubble_tex: Texture2D = null
var _speech_bubble_shadow_tex: Texture2D = null
var _closing_tween: Tween = null
var _ui_layer: CanvasLayer

var _top_essence_lbl: Label
var _top_stop_lbl: Label
var _top_wave_lbl: Label
var _top_timer_lbl: Label
var _pause_btn: Button

var _cauldron_hud_root: Control
var _frenzy_bar: ProgressBar
var _frenzy_btn: Button
var _cust_patience_bar: ProgressBar
var _cust_patience_fill: StyleBoxFlat
var _cust_patience_lbl: Label
var _cust_name_lbl: Label
var _cust_aff_lbl: Label
var _chem_visual_canvas: Control
var _toast_lbl: Label

var _pause_overlay: ColorRect
var _pause_map_btn: Button


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

	_cauldron_tex = load(CAULDRON_TEX_PATH) as Texture2D

	_bg_sprite = Sprite2D.new()
	_bg_sprite.centered = false
	_bg_sprite.z_index = -10
	_bg_sprite.visible = false
	if ResourceLoader.exists(STAGE_BG_SHADER_PATH):
		var bg_shader: Shader = load(STAGE_BG_SHADER_PATH) as Shader
		if bg_shader != null:
			_bg_shader_mat = ShaderMaterial.new()
			_bg_shader_mat.shader = bg_shader
			_bg_sprite.material = _bg_shader_mat
	add_child(_bg_sprite)

	_fire_glow_rect = ColorRect.new()
	_fire_glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fire_glow_rect.z_index = -1
	_fire_glow_rect.color = Color.WHITE
	_fire_glow_rect.position = Vector2(CAULDRON_CENTER.x - 320.0, CAULDRON_CENTER.y + 305.0)
	_fire_glow_rect.size = Vector2(640.0, 210.0)
	if ResourceLoader.exists(CAULDRON_FIRE_SHADER_PATH):
		var fire_shader: Shader = load(CAULDRON_FIRE_SHADER_PATH) as Shader
		if fire_shader != null:
			_fire_shader_mat = ShaderMaterial.new()
			_fire_shader_mat.shader = fire_shader
			_fire_glow_rect.material = _fire_shader_mat
		else:
			_fire_glow_rect.visible = false
	else:
		_fire_glow_rect.visible = false
	add_child(_fire_glow_rect)

	if ResourceLoader.exists(FLASK_GLASS_TEX_PATH):
		_flask_glass_tex = load(FLASK_GLASS_TEX_PATH) as Texture2D
	if ResourceLoader.exists(FLASK_MASK_TEX_PATH):
		_flask_mask_tex = load(FLASK_MASK_TEX_PATH) as Texture2D
	if _flask_glass_tex != null and _flask_mask_tex != null:
		_flask_liquid_sprite = Sprite2D.new()
		_flask_liquid_sprite.centered = false
		_flask_liquid_sprite.z_index = 1
		_flask_liquid_sprite.texture = _flask_mask_tex
		_flask_liquid_sprite.position = FLASK_RECT.position
		var mask_sz: Vector2 = _flask_mask_tex.get_size()
		if mask_sz.x > 0.0 and mask_sz.y > 0.0:
			_flask_liquid_sprite.scale = FLASK_RECT.size / mask_sz
		if ResourceLoader.exists(FLASK_LIQUID_SHADER_PATH):
			var liq_shader: Shader = load(FLASK_LIQUID_SHADER_PATH) as Shader
			if liq_shader != null:
				_flask_liquid_mat = ShaderMaterial.new()
				_flask_liquid_mat.shader = liq_shader
				_flask_liquid_sprite.material = _flask_liquid_mat
		add_child(_flask_liquid_sprite)

		_flask_glass_sprite = Sprite2D.new()
		_flask_glass_sprite.centered = false
		_flask_glass_sprite.z_index = 2
		_flask_glass_sprite.texture = _flask_glass_tex
		_flask_glass_sprite.position = FLASK_RECT.position
		var glass_sz: Vector2 = _flask_glass_tex.get_size()
		if glass_sz.x > 0.0 and glass_sz.y > 0.0:
			_flask_glass_sprite.scale = FLASK_RECT.size / glass_sz
		add_child(_flask_glass_sprite)

	_load_orb_textures()
	if ResourceLoader.exists(DIALOG_BG_TEX_PATH):
		_dialog_bg_tex = load(DIALOG_BG_TEX_PATH) as Texture2D
	if ResourceLoader.exists(DIALOG_SHADOW_TEX_PATH):
		_dialog_shadow_tex = load(DIALOG_SHADOW_TEX_PATH) as Texture2D
	if ResourceLoader.exists(SPEECH_BUBBLE_TEX_PATH):
		_speech_bubble_tex = load(SPEECH_BUBBLE_TEX_PATH) as Texture2D
	if ResourceLoader.exists(SPEECH_BUBBLE_SHADOW_TEX_PATH):
		_speech_bubble_shadow_tex = load(SPEECH_BUBBLE_SHADOW_TEX_PATH) as Texture2D

	camera = Camera2D.new()
	camera.position = VIEWPORT_SIZE * 0.5
	add_child(camera)
	var audio: Node = _audio()
	if audio != null:
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
	_build_ui()
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
	_update_flask_fluid(delta)

	if _toast_timer > 0.0:
		_toast_timer = maxf(0.0, _toast_timer - delta)
		if _toast_timer <= 0.0 and _toast_lbl != null:
			_toast_lbl.visible = false
	_update_speech_bubbles(delta)

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
	if _tube_flash_timer > 0.0:
		_tube_flash_timer = maxf(0.0, _tube_flash_timer - delta)
	if _customer_slide_t < 1.0:
		_customer_slide_t = minf(1.0, _customer_slide_t + delta * 3.4)

	if _closing_active:
		_process_closing_dialogue(delta)
	elif not _is_modal_open():
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
				if _pause_overlay != null and not _fading_out:
					_pause_overlay.visible = not _pause_overlay.visible
				get_viewport().set_input_as_handled()
				return
			if _closing_active:
				if kev.keycode == KEY_SPACE or kev.keycode == KEY_ENTER:
					_handle_closing_advance_input()
					get_viewport().set_input_as_handled()
				return
			if _is_modal_open():
				return
			if _tut_active and _tut_step == CauldronTutStep.BASIC_READY_SUMMARY and (kev.keycode == KEY_ENTER or kev.keycode == KEY_KP_ENTER):
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
	return (_pause_overlay != null and _pause_overlay.visible) or _fading_out


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
	if _active_customer != null and CUSTOMER_CHEMISTRY.has(_active_customer.customer_id):
		return CUSTOMER_CHEMISTRY[_active_customer.customer_id] as Dictionary
	return {"liked": BubbleKind.RED, "neutral": BubbleKind.GREEN, "disliked": BubbleKind.BLUE}


func _build_chemistry_for_liked(liked_k: int, deterministic_neutral: int = -1) -> Dictionary:
	var primaries: Array[int] = [BubbleKind.RED, BubbleKind.BLUE, BubbleKind.GREEN]
	if is_mixed_kind(liked_k):
		var comps: Array[int] = get_recipe_components(liked_k)
		var disliked_k: int = BubbleKind.BLUE
		for p: int in primaries:
			if not comps.has(p):
				disliked_k = p
				break
		return {
			"liked": liked_k,
			"neutral": comps[0],
			"disliked": disliked_k,
		}
	var others: Array[int] = []
	for p: int in primaries:
		if p != liked_k:
			others.append(p)
	var neutral_k: int = deterministic_neutral if (deterministic_neutral != -1 and others.has(deterministic_neutral)) else others[randi() % others.size()]
	var disliked_p: int = others[1] if neutral_k == others[0] else others[0]
	return {
		"liked": liked_k,
		"neutral": neutral_k,
		"disliked": disliked_p,
	}


func _roll_order_chemistry_for_customer(cid: StringName, first_order: bool) -> Dictionary:
	var st: Node = _state()
	if first_order and bool(st.call("should_run_cauldron_basics_tutorial")):
		return _build_chemistry_for_liked(BubbleKind.RED, BubbleKind.GREEN)
	if not first_order and bool(st.call("should_run_mix_tutorial")) and cid == &"velvet":
		return _build_chemistry_for_liked(BubbleKind.PURPLE)

	var pool: Array[int] = [
		BubbleKind.RED, BubbleKind.BLUE, BubbleKind.GREEN,
		BubbleKind.PURPLE, BubbleKind.YELLOW, BubbleKind.CYAN,
	]
	var candidates: Array[int] = []
	for k: int in pool:
		if k != _last_order_liked_kind:
			candidates.append(k)
	if candidates.is_empty():
		candidates = pool
	var chosen: int = candidates[randi() % candidates.size()]
	return _build_chemistry_for_liked(chosen)


static func is_primary_kind(kind: int) -> bool:
	return kind == BubbleKind.RED or kind == BubbleKind.BLUE or kind == BubbleKind.GREEN


static func is_mixed_kind(kind: int) -> bool:
	return kind == BubbleKind.YELLOW or kind == BubbleKind.PURPLE or kind == BubbleKind.CYAN


static func get_recipe_components(kind: int) -> Array[int]:
	match kind:
		BubbleKind.YELLOW:
			return [BubbleKind.RED, BubbleKind.GREEN]
		BubbleKind.PURPLE:
			return [BubbleKind.RED, BubbleKind.BLUE]
		BubbleKind.CYAN:
			return [BubbleKind.BLUE, BubbleKind.GREEN]
	return []


static func get_combine_result(a_kind: int, b_kind: int) -> int:
	if a_kind == BubbleKind.BOMB or b_kind == BubbleKind.BOMB:
		return -1
	if a_kind == BubbleKind.GOLD and b_kind == BubbleKind.GOLD:
		return BubbleKind.GOLD
	if a_kind == BubbleKind.GOLD:
		return b_kind
	if b_kind == BubbleKind.GOLD:
		return a_kind
	if a_kind == b_kind:
		return a_kind
	if is_primary_kind(a_kind) and is_primary_kind(b_kind):
		var lo: int = mini(a_kind, b_kind)
		var hi: int = maxi(a_kind, b_kind)
		if lo == BubbleKind.RED and hi == BubbleKind.BLUE:
			return BubbleKind.PURPLE
		if lo == BubbleKind.RED and hi == BubbleKind.GREEN:
			return BubbleKind.YELLOW
		if lo == BubbleKind.BLUE and hi == BubbleKind.GREEN:
			return BubbleKind.CYAN
	return -1


func get_orb_relation(kind: int) -> StringName:
	if kind == BubbleKind.GOLD or kind == BubbleKind.BOMB:
		return &"special"
	var chem: Dictionary = get_customer_chemistry()
	var liked_k: int = int(chem["liked"])
	if kind == liked_k:
		return &"liked"
	if kind == int(chem["disliked"]):
		return &"disliked"
	if is_mixed_kind(liked_k) and get_recipe_components(liked_k).has(kind):
		return &"ingredient"
	return &"neutral"


static func get_element_name(kind: int) -> String:
	match kind:
		BubbleKind.RED: return "🔥 Fuego"
		BubbleKind.BLUE: return "🌙 Luna"
		BubbleKind.GREEN: return "🍃 Savia"
		BubbleKind.YELLOW: return "☀️ Solar"
		BubbleKind.PURPLE: return "🔮 Estelar"
		BubbleKind.CYAN: return "💧 Bruma"
		BubbleKind.GOLD: return "⭐ Estrella"
		BubbleKind.BOMB: return "💣 Bomba"
	return "Orbe"


static func get_element_glyph(kind: int) -> String:
	match kind:
		BubbleKind.RED: return "🔥"
		BubbleKind.BLUE: return "🌙"
		BubbleKind.GREEN: return "🍃"
		BubbleKind.YELLOW: return "☀️"
		BubbleKind.PURPLE: return "🔮"
		BubbleKind.CYAN: return "💧"
		BubbleKind.GOLD: return "⭐"
		BubbleKind.BOMB: return "💣"
	return "●"


static func get_element_color(kind: int) -> Color:
	match kind:
		BubbleKind.RED: return Color(0.98, 0.28, 0.34)
		BubbleKind.BLUE: return Color(0.24, 0.64, 1.0)
		BubbleKind.GREEN: return Color(0.24, 0.88, 0.46)
		BubbleKind.YELLOW: return Color(1.0, 0.80, 0.22)
		BubbleKind.PURPLE: return Color(0.74, 0.34, 1.0)
		BubbleKind.CYAN: return Color(0.18, 0.88, 0.90)
		BubbleKind.GOLD: return Color(1.0, 0.88, 0.28)
		BubbleKind.BOMB: return Color(0.56, 0.22, 0.72)
	return Color.WHITE


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
	return _tut_active and _tut_step != CauldronTutStep.NONE


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
	_tut_active = false
	_tut_step = CauldronTutStep.NONE
	if _cauldron_hud_root != null:
		_cauldron_hud_root.visible = true
	_hide_trixie_bubble(true)
	_hide_customer_bubble(true)

	_pick_customer_by_id(_wave_customers[0], true)

	var liked_k: int = int(get_customer_chemistry()["liked"])
	if st.should_run_cauldron_basics_tutorial() and not is_mixed_kind(liked_k):
		_tut_active = true
		_tut_step = CauldronTutStep.BASIC_BREAK_LIKED
		_setup_tutorial_initial_orbs()
		_update_tutorial_banner()
		_set_trixie_reaction("confiada", 3.0, "¡Primera clienta! El tiempo está pausado mientras aprendemos lo básico.")
	else:
		if not _tut_active:
			_update_tutorial_banner()
		for _i: int in range(spawn_cap):
			_spawn_orb(false)
		if not _tut_active:
			var stop_name: String = String(_active_stop.get("name", "Parada"))
			_set_trixie_reaction("confiada", 2.5, "¡Llegamos a %s! Rompe %s (%d golpes) para %s." % [
				stop_name,
				get_element_name(liked_k),
				maxi(1, ceili(float(BASE_ORB_HP) / float(click_damage))),
				_active_customer.display_name if _active_customer != null else "la clienta",
			])

	if _pause_map_btn != null:
		_pause_map_btn.disabled = _tut_active


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


func _advance_cauldron_tutorial(next_step: CauldronTutStep) -> void:
	if not _tut_active or int(next_step) <= int(_tut_step):
		return
	_tut_step = next_step
	_play_pentatonic(4, -2.0)
	match _tut_step:
		CauldronTutStep.BASIC_PURGE_DISLIKED:
			var disliked_k: int = int(get_customer_chemistry()["disliked"])
			_ensure_tutorial_orb(disliked_k)
			_set_trixie_reaction("nerviosa", 3.0, "¡Bien! Ahora purga el orbe con ❌ usando Clic Derecho sin romper el combo.")
		CauldronTutStep.BASIC_READY_SUMMARY:
			_set_trixie_reaction("confiada", 3.2, "¡Eso es todo lo básico! Revisa el resumen arriba y pulsa ¡ENTENDIDO! para iniciar.")
		CauldronTutStep.MIX_BREAK_RESULT:
			_set_trixie_reaction("confiada", 2.8, "¡Mezcla lograda! Ahora rompe ese orbe combinado para llenar el tubo mucho más rápido.")
	_update_tutorial_banner()


func _acknowledge_basic_tutorial_summary() -> void:
	if not _tut_active or _tut_step != CauldronTutStep.BASIC_READY_SUMMARY:
		return
	var st: Node = _state()
	st.cauldron_basics_tutorial_done = true
	st.cauldron_tutorial_done = true
	_tut_active = false
	_tut_step = CauldronTutStep.NONE
	_play_pentatonic(6, -1.0)
	_update_tutorial_banner()
	_set_trixie_reaction("confiada", 2.5, "¡Corre la paciencia de Sylvi! Llena su tubo al 100%.")
	if _pause_map_btn != null:
		_pause_map_btn.disabled = false


func _start_mix_tutorial() -> void:
	var liked_k: int = int(get_customer_chemistry()["liked"])
	if not is_mixed_kind(liked_k):
		return
	_tut_active = true
	_tut_step = CauldronTutStep.MIX_DRAG_COMBINE
	_ensure_mix_ingredients_for_tutorial(liked_k)
	_play_pentatonic(5, -2.0)
	_update_tutorial_banner()
	_set_trixie_reaction("sorprendida", 3.2, "¡Pide un color mezclado! Pausé el tiempo para enseñarte a combinarlo.")
	if _pause_map_btn != null:
		_pause_map_btn.disabled = true


func _finish_mix_tutorial() -> void:
	var st: Node = _state()
	st.mix_tutorial_done = true
	_tut_active = false
	_tut_step = CauldronTutStep.NONE
	_play_pentatonic(6, -1.0)
	_update_tutorial_banner()
	_set_trixie_reaction("confiada", 2.4, "¡Perfecto! Ya dominas las mezclas. ¡A atender antes de que pierda la paciencia!")
	if _pause_map_btn != null:
		_pause_map_btn.disabled = false


func _update_tutorial_banner() -> void:
	if _trixie_bubble == null:
		return
	if not _tut_active or _closing_active or _tut_step == CauldronTutStep.NONE:
		if _trixie_bubble_is_tutorial:
			_hide_trixie_bubble(false)
		return

	var tut_title: String = "✨ Tutorial · Pausado"
	var tut_body: String = ""
	var show_ack: bool = (_tut_step == CauldronTutStep.BASIC_READY_SUMMARY)
	match _tut_step:
		CauldronTutStep.BASIC_BREAK_LIKED:
			var liked_k: int = int(get_customer_chemistry()["liked"])
			tut_title = "✨ Tutorial 1/3 · Pausado"
			tut_body = "Haz 3 CLICS IZQ en un orbe %s para llenar el matraz." % get_element_name(liked_k)
		CauldronTutStep.BASIC_PURGE_DISLIKED:
			var disliked_k: int = int(get_customer_chemistry()["disliked"])
			tut_title = "✨ Tutorial 2/3 · Pausado"
			tut_body = "Haz CLIC DER en el orbe %s ❌ para purgarlo sin perder combo." % get_element_name(disliked_k)
		CauldronTutStep.BASIC_READY_SUMMARY:
			tut_title = "✨ ¡Lista! (3/3)"
			tut_body = "Cuida la Paciencia y usa [ESPACIO] al cargar Frenesí."
		CauldronTutStep.MIX_DRAG_COMBINE:
			var liked_m: int = int(get_customer_chemistry()["liked"])
			var comps: Array[int] = get_recipe_components(liked_m)
			tut_title = "✨ Mezcla · Pausado"
			tut_body = "ARRASTRA %s sobre %s para crear %s." % [
				get_element_name(comps[0]),
				get_element_name(comps[1]),
				get_element_name(liked_m),
			]
		CauldronTutStep.MIX_BREAK_RESULT:
			var liked_m2: int = int(get_customer_chemistry()["liked"])
			tut_title = "✨ ¡Mezcla lista!"
			tut_body = "¡Genial! Ahora rompe ese orbe %s a clics." % get_element_name(liked_m2)

	_show_trixie_bubble(tut_title, tut_body, -1.0, true, show_ack)


func _trigger_stop_end(victory: bool) -> void:
	if round_ending:
		return
	round_ending = true
	_wave_victory = victory
	_round_end_timer = 1.35 if victory else 1.15
	_reset_pointer_state()
	_play_pentatonic(6 if victory else 1, -2.0)
	if _trixie_bubble_is_tutorial:
		_hide_trixie_bubble(false)
	_set_trixie_reaction("confiada" if victory else "hollin", 2.2, "")


func _begin_closing_dialogue(victory: bool) -> void:
	if _closing_active:
		return
	_closing_active = true
	_reset_pointer_state()
	_hide_trixie_bubble(true)
	_hide_customer_bubble(true)
	if _cauldron_hud_root != null:
		_cauldron_hud_root.visible = false

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
	if _closing_overlay != null:
		_closing_overlay.visible = true
	_animate_closing_parchment_in()
	_advance_closing_dialogue()


func _animate_closing_parchment_in() -> void:
	if _closing_parchment == null:
		return
	if _closing_tween != null and _closing_tween.is_valid():
		_closing_tween.kill()
	_closing_parchment.position = CLOSING_PARCHMENT_POS + Vector2(-150.0, 90.0)
	_closing_parchment.modulate.a = 0.0
	_closing_tween = create_tween()
	_closing_tween.set_parallel(true)
	_closing_tween.tween_property(_closing_parchment, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_closing_tween.tween_property(_closing_parchment, "position", CLOSING_PARCHMENT_POS, 0.72).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _advance_closing_dialogue() -> void:
	_closing_idx += 1
	if _closing_idx >= _closing_lines.size():
		_finish_stop_and_fade_to_map()
		return

	var line_d: Dictionary = _closing_lines[_closing_idx]
	var spk: String = String(line_d.get("speaker", "trixie"))
	var emo: String = String(line_d.get("emotion", "normal"))
	_closing_full_text = String(line_d.get("text", ""))
	_closing_shown_chars = 0.0

	if spk == "customer":
		var cname: String = _last_served_customer.display_name if _last_served_customer != null else (_active_customer.display_name if _active_customer != null else "Clienta")
		if _last_served_customer != null:
			_active_customer = _last_served_customer
		_closing_speaker_lbl.text = cname
		_closing_speaker_lbl.add_theme_color_override("font_color", Color(0.56, 0.12, 0.28))
		_set_customer_reaction(emo, 8.0, "")
	else:
		_closing_speaker_lbl.text = "Trixie"
		_closing_speaker_lbl.add_theme_color_override("font_color", Color(0.68, 0.14, 0.34))
		_set_trixie_reaction(emo, 8.0, "")

	_closing_text_lbl.text = _closing_full_text
	_closing_text_lbl.visible_characters = 0
	_closing_continue_lbl.visible = false


func _process_closing_dialogue(delta: float) -> void:
	if _closing_shown_chars < float(_closing_full_text.length()):
		var prev_i: int = int(_closing_shown_chars)
		_closing_shown_chars = minf(float(_closing_full_text.length()), _closing_shown_chars + CLOSING_CHARS_PER_SEC * delta)
		var cur_i: int = int(_closing_shown_chars)
		_closing_text_lbl.visible_characters = cur_i
		if cur_i > prev_i and cur_i % 4 == 0:
			_play_pentatonic(3, -12.0)
	else:
		_closing_continue_lbl.visible = true
		_closing_continue_lbl.modulate.a = 0.55 + 0.45 * absf(sin(_time * 4.0))


func _handle_closing_advance_input() -> void:
	if not _closing_active or _fading_out:
		return
	if _closing_shown_chars < float(_closing_full_text.length()):
		_closing_shown_chars = float(_closing_full_text.length())
		_closing_text_lbl.visible_characters = -1
		return
	_advance_closing_dialogue()


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

	if _tut_active and _tut_step == CauldronTutStep.MIX_DRAG_COMBINE and res_kind == liked_k:
		_advance_cauldron_tutorial(CauldronTutStep.MIX_BREAK_RESULT)
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
	_inject_mix_pigment(kind, tier)
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
		_excite_flask_fluid(-penalty)
		_combo = 0
		_disliked_mistake_streak += 1
		_disliked_streak_timer = 7.0
		_tube_flash_timer = 0.55
		_tube_flash_positive = false
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

	if _tut_active and _tut_step == CauldronTutStep.BASIC_BREAK_LIKED and rel == &"liked":
		_advance_cauldron_tutorial(CauldronTutStep.BASIC_PURGE_DISLIKED)
	elif _tut_active and _tut_step == CauldronTutStep.MIX_BREAK_RESULT and rel == &"liked":
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

	if _tut_active and _tut_step == CauldronTutStep.BASIC_PURGE_DISLIKED and rel == &"disliked":
		_advance_cauldron_tutorial(CauldronTutStep.BASIC_READY_SUMMARY)


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


func _reset_mix_pigment(instant: bool = false) -> void:
	_mix_hue_vec = Vector2.ZERO
	_mix_weight = 0.0
	_broth_target_color = BROTH_NEUTRAL_COLOR
	_flask_target_color = FLASK_NEUTRAL_COLOR
	if instant:
		_broth_current_color = BROTH_NEUTRAL_COLOR
		_tube_color_current = FLASK_NEUTRAL_COLOR


func _inject_mix_pigment(kind: int, tier: int = 1) -> void:
	var c: Color = get_element_color(kind)
	var ang: float = c.h * TAU
	var w: float = (0.7 if kind == BubbleKind.GOLD else (0.45 if kind == BubbleKind.BOMB else 1.0)) * (1.0 + float(maxi(0, tier - 1)) * 0.35)
	_mix_hue_vec = _mix_hue_vec * 0.85 + Vector2(cos(ang), sin(ang)) * w
	_mix_weight = minf(12.0, _mix_weight * 0.85 + w)
	var res_h: float = c.h
	if _mix_hue_vec.length() >= 0.14:
		res_h = fposmod(atan2(_mix_hue_vec.y, _mix_hue_vec.x) / TAU, 1.0)
	_broth_target_color = Color.from_hsv(res_h, 0.72, 0.34)
	_flask_target_color = Color.from_hsv(res_h, 0.82, 0.96)


func _excite_flask_fluid(delta_pct: float) -> void:
	_tube_fill_vel += delta_pct * 3.8
	_tube_slosh_amp = minf(1.25, _tube_slosh_amp + clampf(absf(delta_pct) / 28.0, 0.25, 0.95))
	var impulse_dir: float = 1.0 if delta_pct >= 0.0 else -1.0
	_tube_slosh_vel += impulse_dir * randf_range(3.2, 5.2)
	if delta_pct > 0.0:
		_tube_pour_glow = minf(1.2, _tube_pour_glow + 0.85)


func _update_flask_fluid(delta: float) -> void:
	var target_pct: float = clampf(_potion_tube_pct, 0.0, 100.0)
	var fill_force: float = (target_pct - _tube_display_pct) * 78.0 - _tube_fill_vel * 11.5
	_tube_fill_vel += fill_force * delta
	_tube_display_pct = clampf(_tube_display_pct + _tube_fill_vel * delta, 0.0, 104.0)

	if _cauldron_shake > 0.5:
		_tube_slosh_amp = minf(1.25, _tube_slosh_amp + delta * 0.65)
	var slosh_accel: float = -28.0 * _tube_slosh_tilt - 4.2 * _tube_slosh_vel
	_tube_slosh_vel += slosh_accel * delta
	_tube_slosh_tilt = clampf(_tube_slosh_tilt + _tube_slosh_vel * delta, -1.5, 1.5)
	_tube_slosh_amp = maxf(0.0, _tube_slosh_amp - delta * 1.45)
	_tube_pour_glow = maxf(0.0, _tube_pour_glow - delta * 2.4)

	_broth_current_color = _broth_current_color.lerp(_broth_target_color, clampf(delta * 2.8, 0.0, 1.0))
	_tube_color_current = _tube_color_current.lerp(_flask_target_color, clampf(delta * 6.5, 0.0, 1.0))

	if _flask_liquid_mat != null:
		_flask_liquid_mat.set_shader_parameter("fill_ratio", clampf(_tube_display_pct / 100.0, 0.0, 1.0))
		_flask_liquid_mat.set_shader_parameter("liquid_color", _tube_color_current)
		_flask_liquid_mat.set_shader_parameter("slosh_amp", _tube_slosh_amp)
		_flask_liquid_mat.set_shader_parameter("slosh_tilt", _tube_slosh_tilt)
		_flask_liquid_mat.set_shader_parameter("pour_glow", _tube_pour_glow)
		var flash_norm: float = clampf(_tube_flash_timer / 0.45, 0.0, 1.0)
		_flask_liquid_mat.set_shader_parameter("flash_amount", flash_norm)
		_flask_liquid_mat.set_shader_parameter("flash_negative", 0.0 if _tube_flash_positive else 1.0)


func _add_tube_progress(pct: float) -> void:
	_potion_tube_pct += pct
	_tube_flash_timer = 0.45
	_tube_flash_positive = true
	_excite_flask_fluid(pct)
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
	_tube_display_pct = 0.0
	_tube_fill_vel = 0.0
	_tube_slosh_amp = 0.35
	_tube_slosh_tilt = 0.0
	_tube_slosh_vel = 1.8
	_tube_pour_glow = 0.0
	_reset_mix_pigment(first_order)
	if not first_order:
		_tube_color_current = FLASK_NEUTRAL_COLOR
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
	elif _tut_active:
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
	_tube_flash_timer = 0.55
	_tube_flash_positive = false
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
	_toast_timer = duration
	if _toast_lbl != null:
		_toast_lbl.text = txt
		_toast_lbl.visible = true


func _set_trixie_reaction(emotion: String, dur: float, line: String) -> void:
	if emotion != _trixie_emotion or emotion in ["hollin", "sorprendida", "sonrojada"]:
		_trixie_react_anim = 1.0
	_trixie_emotion = emotion
	_trixie_emotion_timer = dur
	if line != "":
		_trixie_line = line
		if not _tut_active and not _closing_active:
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
# UI BUILD (CLEAN CAULDRON HUD + TOP TUTORIAL + CLOSING DIALOGUE + PAUSE)
# ==============================================================================

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)

	# Top Bar (clean single-scene HUD without duplicated Tree or Gallery buttons)
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
	_top_essence_lbl.custom_minimum_size = Vector2(210, 0)
	_top_stop_lbl = _make_label("📍 Afueras del Castillo", 20, Color(0.96, 0.88, 0.98))
	_top_stop_lbl.custom_minimum_size = Vector2(360, 0)
	_top_wave_lbl = _make_label("👥 Clienta: 1 / 2", 20, Color(0.72, 0.94, 1.0))
	_top_wave_lbl.custom_minimum_size = Vector2(230, 0)
	tb_hbox.add_child(_top_essence_lbl)
	tb_hbox.add_child(_top_stop_lbl)
	tb_hbox.add_child(_top_wave_lbl)

	var sp1: Control = Control.new()
	sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_hbox.add_child(sp1)

	_top_timer_lbl = _make_label("0:55", 28, Color(1.0, 0.94, 0.78))
	_top_timer_lbl.custom_minimum_size = Vector2(180, 0)
	_top_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tb_hbox.add_child(_top_timer_lbl)

	var sp2: Control = Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_hbox.add_child(sp2)

	_pause_btn = _make_pill_button("⏸ PAUSA [ESC]", Color(0.24, 0.16, 0.34), Color(0.84, 0.66, 0.38))
	_pause_btn.pressed.connect(func() -> void:
		if _pause_overlay != null and not _fading_out:
			_pause_overlay.visible = true
	)
	tb_hbox.add_child(_pause_btn)

	_build_cauldron_hud()
	_build_speech_bubbles()
	_build_closing_dialogue_ui()
	_build_modals()


func _build_cauldron_hud() -> void:
	_cauldron_hud_root = Control.new()
	_cauldron_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cauldron_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_cauldron_hud_root)

	# Left Frenzy Dock cleanly below Trixie's halfbody
	var left_card: PanelContainer = _make_card_panel(Vector2(20, 952), Vector2(448, 108), Color(0.10, 0.06, 0.16, 0.88), Color(0.92, 0.56, 0.40, 0.85))
	_cauldron_hud_root.add_child(left_card)
	var lv: VBoxContainer = VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	left_card.get_child(0).add_child(lv)

	_frenzy_bar = ProgressBar.new()
	_frenzy_bar.custom_minimum_size = Vector2(416, 16)
	_frenzy_bar.max_value = 100.0
	_frenzy_bar.show_percentage = false
	var fbg: StyleBoxFlat = StyleBoxFlat.new()
	fbg.bg_color = Color(0.08, 0.04, 0.12, 0.92)
	fbg.set_corner_radius_all(6)
	var ffg: StyleBoxFlat = StyleBoxFlat.new()
	ffg.bg_color = Color(1.0, 0.32, 0.44)
	ffg.set_corner_radius_all(6)
	_frenzy_bar.add_theme_stylebox_override("background", fbg)
	_frenzy_bar.add_theme_stylebox_override("fill", ffg)
	lv.add_child(_frenzy_bar)

	_frenzy_btn = _make_pill_button("🔥 FRENESÍ (0%) [ESPACIO]", Color(0.68, 0.14, 0.24), Color(1.0, 0.84, 0.38))
	_frenzy_btn.custom_minimum_size = Vector2(416, 48)
	_frenzy_btn.pressed.connect(try_activate_frenzy)
	lv.add_child(_frenzy_btn)

	# Right Customer Status Strip + Patience Bar + Chemistry Legend (no static dialogue box)
	var cust_hdr_card: PanelContainer = _make_card_panel(Vector2(1412, 886), Vector2(486, 42), Color(0.10, 0.06, 0.16, 0.90), Color(0.92, 0.68, 0.82, 0.85))
	_cauldron_hud_root.add_child(cust_hdr_card)
	var chdr: HBoxContainer = HBoxContainer.new()
	cust_hdr_card.get_child(0).add_child(chdr)

	_cust_name_lbl = _make_label("Sylvi", 19, Color(1.0, 0.93, 0.84))
	_cust_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cust_aff_lbl = _make_label("❤ Nv.0", 17, Color(1.0, 0.64, 0.80))
	chdr.add_child(_cust_name_lbl)
	chdr.add_child(_cust_aff_lbl)

	var pat_card: PanelContainer = _make_card_panel(Vector2(1412, 932), Vector2(486, 46), Color(0.10, 0.06, 0.16, 0.90), Color(0.92, 0.72, 0.36, 0.85))
	_cauldron_hud_root.add_child(pat_card)
	var pat_hbox: HBoxContainer = HBoxContainer.new()
	pat_hbox.add_theme_constant_override("separation", 10)
	pat_card.get_child(0).add_child(pat_hbox)

	_cust_patience_lbl = _make_label("⏳ 30s", 15, Color(1.0, 0.92, 0.65))
	_cust_patience_lbl.custom_minimum_size = Vector2(138, 0)
	pat_hbox.add_child(_cust_patience_lbl)

	_cust_patience_bar = ProgressBar.new()
	_cust_patience_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cust_patience_bar.custom_minimum_size = Vector2(280, 18)
	_cust_patience_bar.max_value = 100.0
	_cust_patience_bar.value = 100.0
	_cust_patience_bar.show_percentage = false
	var pbg: StyleBoxFlat = StyleBoxFlat.new()
	pbg.bg_color = Color(0.08, 0.04, 0.12, 0.94)
	pbg.set_corner_radius_all(6)
	_cust_patience_fill = StyleBoxFlat.new()
	_cust_patience_fill.bg_color = Color(0.32, 0.88, 0.56)
	_cust_patience_fill.set_corner_radius_all(6)
	_cust_patience_bar.add_theme_stylebox_override("background", pbg)
	_cust_patience_bar.add_theme_stylebox_override("fill", _cust_patience_fill)
	pat_hbox.add_child(_cust_patience_bar)

	var chem_card: PanelContainer = _make_card_panel(Vector2(1412, 984), Vector2(486, 68), Color(0.10, 0.06, 0.16, 0.88), Color(0.76, 0.60, 0.92, 0.85))
	_cauldron_hud_root.add_child(chem_card)
	_chem_visual_canvas = Control.new()
	_chem_visual_canvas.custom_minimum_size = Vector2(450, 44)
	_chem_visual_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chem_visual_canvas.draw.connect(_draw_chem_visual_strip)
	chem_card.get_child(0).add_child(_chem_visual_canvas)

	_toast_lbl = _make_label("", 20, Color(1.0, 0.90, 0.42))
	_toast_lbl.position = Vector2(825, 86)
	_toast_lbl.size = Vector2(420, 64)
	_toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_lbl.visible = false
	_cauldron_hud_root.add_child(_toast_lbl)


func _build_speech_bubbles() -> void:
	# Trixie parchment speech bubble (top-left above cauldron, handles tutorials & quick reactions)
	_trixie_bubble = Control.new()
	_trixie_bubble.position = TRIXIE_BUBBLE_POS
	_trixie_bubble.size = SPEECH_BUBBLE_SIZE
	_trixie_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trixie_bubble.draw.connect(_draw_trixie_bubble)
	_trixie_bubble.visible = false
	_ui_layer.add_child(_trixie_bubble)

	_trixie_bubble_title = Label.new()
	_trixie_bubble_title.position = Vector2(36, 18)
	_trixie_bubble_title.size = Vector2(388, 26)
	_trixie_bubble_title.add_theme_font_size_override("font_size", 18)
	_trixie_bubble_title.add_theme_color_override("font_color", Color(0.68, 0.14, 0.34))
	_trixie_bubble.add_child(_trixie_bubble_title)

	_trixie_bubble_body = Label.new()
	_trixie_bubble_body.position = Vector2(36, 46)
	_trixie_bubble_body.size = Vector2(388, 118)
	_trixie_bubble_body.add_theme_font_size_override("font_size", 19)
	_trixie_bubble_body.add_theme_color_override("font_color", Color(0.18, 0.10, 0.07))
	_trixie_bubble_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trixie_bubble.add_child(_trixie_bubble_body)

	_trixie_bubble_ack_btn = _make_pill_button("¡LISTO! ▶", Color(0.18, 0.52, 0.30), Color(0.56, 1.0, 0.62))
	_trixie_bubble_ack_btn.position = Vector2(288, 120)
	_trixie_bubble_ack_btn.custom_minimum_size = Vector2(138, 42)
	_trixie_bubble_ack_btn.size = Vector2(138, 42)
	_trixie_bubble_ack_btn.visible = false
	_trixie_bubble_ack_btn.pressed.connect(_acknowledge_basic_tutorial_summary)
	_trixie_bubble.add_child(_trixie_bubble_ack_btn)

	# Customer ephemeral speech bubble (mirrored parchment bubble pointing down-right toward customer)
	_cust_bubble = Control.new()
	_cust_bubble.position = CUSTOMER_BUBBLE_POS
	_cust_bubble.size = SPEECH_BUBBLE_SIZE
	_cust_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cust_bubble.draw.connect(_draw_customer_bubble)
	_cust_bubble.visible = false
	_ui_layer.add_child(_cust_bubble)

	_cust_bubble_name = Label.new()
	_cust_bubble_name.position = Vector2(36, 18)
	_cust_bubble_name.size = Vector2(388, 26)
	_cust_bubble_name.add_theme_font_size_override("font_size", 18)
	_cust_bubble_name.add_theme_color_override("font_color", Color(0.56, 0.12, 0.28))
	_cust_bubble.add_child(_cust_bubble_name)

	_cust_bubble_body = Label.new()
	_cust_bubble_body.position = Vector2(36, 48)
	_cust_bubble_body.size = Vector2(388, 114)
	_cust_bubble_body.add_theme_font_size_override("font_size", 19)
	_cust_bubble_body.add_theme_color_override("font_color", Color(0.18, 0.10, 0.07))
	_cust_bubble_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cust_bubble.add_child(_cust_bubble_body)


func _draw_speech_bubble_art(ctrl: Control, flip_x: bool, tint: Color) -> void:
	if flip_x:
		ctrl.draw_set_transform(Vector2(SPEECH_BUBBLE_SIZE.x, 0.0), 0.0, Vector2(-1.0, 1.0))
	if _speech_bubble_tex != null:
		if _speech_bubble_shadow_tex != null:
			var sh_off: Vector2 = Vector2(-SPEECH_BUBBLE_SHADOW_OFFSET.x, SPEECH_BUBBLE_SHADOW_OFFSET.y) if flip_x else SPEECH_BUBBLE_SHADOW_OFFSET
			ctrl.draw_texture_rect(
				_speech_bubble_shadow_tex,
				Rect2(-SPEECH_BUBBLE_SHADOW_PAD + sh_off, SPEECH_BUBBLE_SIZE + SPEECH_BUBBLE_SHADOW_PAD * 2.0),
				false,
				Color(1.0, 1.0, 1.0, 0.48)
			)
		ctrl.draw_texture_rect(_speech_bubble_tex, Rect2(Vector2.ZERO, SPEECH_BUBBLE_SIZE), false, tint)
	else:
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(10, 8), Vector2(SPEECH_BUBBLE_SIZE.x - 10, 8),
			Vector2(SPEECH_BUBBLE_SIZE.x - 10, SPEECH_BUBBLE_BODY_H),
			Vector2(106, SPEECH_BUBBLE_BODY_H), Vector2(44, SPEECH_BUBBLE_SIZE.y - 6),
			Vector2(60, SPEECH_BUBBLE_BODY_H), Vector2(10, SPEECH_BUBBLE_BODY_H),
		])
		ctrl.draw_colored_polygon(pts, Color(0.93, 0.84, 0.68, 0.97) * tint)
		ctrl.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.32, 0.18, 0.11), 4.0)
	if flip_x:
		ctrl.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_trixie_bubble() -> void:
	var tint: Color = Color(1.0, 0.97, 0.88) if _trixie_bubble_is_tutorial else Color.WHITE
	_draw_speech_bubble_art(_trixie_bubble, false, tint)


func _draw_customer_bubble() -> void:
	_draw_speech_bubble_art(_cust_bubble, true, Color.WHITE)


func _show_trixie_bubble(title: String, text: String, duration: float, is_tutorial: bool = false, show_ack: bool = false) -> void:
	if _trixie_bubble == null or _closing_active or text == "":
		return
	if _tut_active and not is_tutorial:
		return
	var was_hidden: bool = not _trixie_bubble_showing or not _trixie_bubble.visible
	_trixie_bubble_is_tutorial = is_tutorial
	_trixie_bubble_showing = true
	_trixie_bubble_timer = -1.0 if is_tutorial else maxf(1.8, duration)
	_trixie_bubble_title.text = title
	_trixie_bubble_title.add_theme_color_override("font_color", Color(0.62, 0.30, 0.04) if is_tutorial else Color(0.68, 0.14, 0.34))
	_trixie_bubble_body.text = text
	_trixie_bubble_body.size = Vector2(246, 118) if show_ack else Vector2(388, 118)
	_trixie_bubble_ack_btn.visible = show_ack
	_trixie_bubble.queue_redraw()
	if _trixie_bubble_tween != null and _trixie_bubble_tween.is_valid():
		_trixie_bubble_tween.kill()
	_trixie_bubble.visible = true
	if was_hidden:
		_trixie_bubble.position = TRIXIE_BUBBLE_POS + Vector2(-24.0, 18.0)
		_trixie_bubble.modulate.a = 0.0
	else:
		_trixie_bubble.position = TRIXIE_BUBBLE_POS + Vector2(0.0, 8.0)
	_trixie_bubble_tween = create_tween()
	_trixie_bubble_tween.set_parallel(true)
	_trixie_bubble_tween.tween_property(_trixie_bubble, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_trixie_bubble_tween.tween_property(_trixie_bubble, "position", TRIXIE_BUBBLE_POS, 0.38).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _hide_trixie_bubble(instant: bool = false) -> void:
	if _trixie_bubble == null:
		return
	_trixie_bubble_showing = false
	_trixie_bubble_timer = 0.0
	_trixie_bubble_is_tutorial = false
	if _trixie_bubble_ack_btn != null:
		_trixie_bubble_ack_btn.visible = false
	if _trixie_bubble_tween != null and _trixie_bubble_tween.is_valid():
		_trixie_bubble_tween.kill()
	if instant or not _trixie_bubble.visible:
		_trixie_bubble.visible = false
		_trixie_bubble.modulate.a = 1.0
		_trixie_bubble.position = TRIXIE_BUBBLE_POS
		return
	_trixie_bubble_tween = create_tween()
	_trixie_bubble_tween.tween_property(_trixie_bubble, "modulate:a", 0.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_trixie_bubble_tween.tween_callback(func() -> void:
		if is_instance_valid(_trixie_bubble) and not _trixie_bubble_showing:
			_trixie_bubble.visible = false
	)


func _show_customer_bubble(speaker_name: String, text: String, duration: float = 3.2) -> void:
	if _cust_bubble == null or _closing_active or text == "":
		return
	var was_hidden: bool = not _cust_bubble_showing or not _cust_bubble.visible
	_cust_bubble_showing = true
	_cust_bubble_timer = maxf(1.8, duration)
	_cust_bubble_name.text = speaker_name
	_cust_bubble_body.text = text
	_cust_bubble.queue_redraw()
	if _cust_bubble_tween != null and _cust_bubble_tween.is_valid():
		_cust_bubble_tween.kill()
	_cust_bubble.visible = true
	if was_hidden:
		_cust_bubble.position = CUSTOMER_BUBBLE_POS + Vector2(24.0, 18.0)
		_cust_bubble.modulate.a = 0.0
	else:
		_cust_bubble.position = CUSTOMER_BUBBLE_POS + Vector2(0.0, 8.0)
	_cust_bubble_tween = create_tween()
	_cust_bubble_tween.set_parallel(true)
	_cust_bubble_tween.tween_property(_cust_bubble, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cust_bubble_tween.tween_property(_cust_bubble, "position", CUSTOMER_BUBBLE_POS, 0.38).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _hide_customer_bubble(instant: bool = false) -> void:
	if _cust_bubble == null:
		return
	_cust_bubble_showing = false
	_cust_bubble_timer = 0.0
	if _cust_bubble_tween != null and _cust_bubble_tween.is_valid():
		_cust_bubble_tween.kill()
	if instant or not _cust_bubble.visible:
		_cust_bubble.visible = false
		_cust_bubble.modulate.a = 1.0
		_cust_bubble.position = CUSTOMER_BUBBLE_POS
		return
	_cust_bubble_tween = create_tween()
	_cust_bubble_tween.tween_property(_cust_bubble, "modulate:a", 0.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_cust_bubble_tween.tween_callback(func() -> void:
		if is_instance_valid(_cust_bubble) and not _cust_bubble_showing:
			_cust_bubble.visible = false
	)


func _update_speech_bubbles(delta: float) -> void:
	if _trixie_bubble_showing and not _trixie_bubble_is_tutorial and _trixie_bubble_timer > 0.0:
		_trixie_bubble_timer -= delta
		if _trixie_bubble_timer <= 0.0:
			_hide_trixie_bubble(false)
	if _cust_bubble_showing and _cust_bubble_timer > 0.0:
		_cust_bubble_timer -= delta
		if _cust_bubble_timer <= 0.0:
			_hide_customer_bubble(false)


func _build_closing_dialogue_ui() -> void:
	_closing_overlay = Control.new()
	_closing_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_closing_overlay.visible = false
	_closing_overlay.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var mb: InputEventMouseButton = ev as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				_handle_closing_advance_input()
	)
	_ui_layer.add_child(_closing_overlay)

	_closing_parchment = Control.new()
	_closing_parchment.position = CLOSING_PARCHMENT_POS
	_closing_parchment.size = CLOSING_PARCHMENT_SIZE
	_closing_parchment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_closing_parchment.draw.connect(_draw_closing_parchment)
	_closing_overlay.add_child(_closing_parchment)

	_closing_speaker_lbl = Label.new()
	_closing_speaker_lbl.position = Vector2(78, 38)
	_closing_speaker_lbl.add_theme_font_size_override("font_size", 28)
	_closing_speaker_lbl.add_theme_color_override("font_color", Color(0.68, 0.14, 0.34))
	_closing_parchment.add_child(_closing_speaker_lbl)

	_closing_text_lbl = Label.new()
	_closing_text_lbl.position = Vector2(78, 88)
	_closing_text_lbl.size = Vector2(1230, 142)
	_closing_text_lbl.add_theme_font_size_override("font_size", 26)
	_closing_text_lbl.add_theme_color_override("font_color", Color(0.18, 0.10, 0.07))
	_closing_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_closing_parchment.add_child(_closing_text_lbl)

	_closing_continue_lbl = Label.new()
	_closing_continue_lbl.text = "Clic / Espacio para ir al Mapa ▾"
	_closing_continue_lbl.position = Vector2(948, 238)
	_closing_continue_lbl.size = Vector2(360, 28)
	_closing_continue_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_closing_continue_lbl.add_theme_font_size_override("font_size", 18)
	_closing_continue_lbl.add_theme_color_override("font_color", Color(0.45, 0.26, 0.16))
	_closing_parchment.add_child(_closing_continue_lbl)


func _draw_closing_parchment() -> void:
	if _dialog_bg_tex != null:
		if _dialog_shadow_tex != null:
			_closing_parchment.draw_texture_rect(
				_dialog_shadow_tex,
				Rect2(-DIALOG_SHADOW_PAD + DIALOG_SHADOW_OFFSET, _closing_parchment.size + DIALOG_SHADOW_PAD * 2.0),
				false,
				Color(1.0, 1.0, 1.0, 0.56)
			)
		_closing_parchment.draw_texture_rect(_dialog_bg_tex, Rect2(Vector2.ZERO, _closing_parchment.size), false)
		return

	var w: float = _closing_parchment.size.x
	var h: float = _closing_parchment.size.y
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(14, 6), Vector2(300, 4), Vector2(320, 14), Vector2(340, 4),
		Vector2(w - 28, 8), Vector2(w - 8, 28), Vector2(w - 14, 110), Vector2(w - 4, 130),
		Vector2(w - 12, h - 14), Vector2(w - 120, h - 6), Vector2(w - 140, h - 18), Vector2(w - 162, h - 6),
		Vector2(210, h - 8), Vector2(188, h - 16), Vector2(168, h - 6), Vector2(14, h - 10),
		Vector2(4, 140), Vector2(16, 120), Vector2(6, 36),
	])
	_closing_parchment.draw_colored_polygon(pts, Color(0.93, 0.84, 0.68, 0.97))
	_closing_parchment.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.32, 0.18, 0.11), 4.0)


func _build_modals() -> void:
	_pause_overlay = ColorRect.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.color = Color(0.04, 0.02, 0.08, 0.84)
	_pause_overlay.visible = false
	_ui_layer.add_child(_pause_overlay)

	var p_center: CenterContainer = CenterContainer.new()
	p_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(p_center)
	var p_panel: PanelContainer = _make_card_panel(Vector2.ZERO, Vector2(460, 430), Color(0.12, 0.08, 0.19, 0.98), Color(0.88, 0.68, 0.36))
	p_panel.custom_minimum_size = Vector2(460, 430)
	p_center.add_child(p_panel)

	var p_vbox: VBoxContainer = VBoxContainer.new()
	p_vbox.add_theme_constant_override("separation", 16)
	p_panel.get_child(0).add_child(p_vbox)
	var p_hdr: Label = _make_label("PAUSA", 34, Color(1.0, 0.88, 0.44))
	p_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_vbox.add_child(p_hdr)

	var res_btn: Button = _make_pill_button("REANUDAR", Color(0.18, 0.46, 0.28), Color(0.56, 1.0, 0.60))
	res_btn.custom_minimum_size = Vector2(0, 54)
	res_btn.pressed.connect(func() -> void: _pause_overlay.visible = false)

	_pause_map_btn = _make_pill_button("🗺 VOLVER AL MAPA", Color(0.20, 0.32, 0.48), Color(0.55, 0.88, 1.0))
	_pause_map_btn.custom_minimum_size = Vector2(0, 54)
	_pause_map_btn.pressed.connect(func() -> void:
		if _fading_out or _tut_active:
			return
		_pause_overlay.visible = false
		_fading_out = true
		var fader: Node = _fader()
		if fader != null:
			fader.call("fade_to_scene", "res://scenes/meta/WorldMap.tscn", 0.45, 0.45)
		else:
			get_tree().change_scene_to_file("res://scenes/meta/WorldMap.tscn")
	)

	var rst_btn: Button = _make_pill_button("REINICIAR PARTIDA", Color(0.46, 0.24, 0.16), Color(1.0, 0.72, 0.40))
	rst_btn.custom_minimum_size = Vector2(0, 54)
	rst_btn.pressed.connect(func() -> void:
		_pause_overlay.visible = false
		_state().reset_run()
		get_tree().reload_current_scene()
	)

	var menu_btn: Button = _make_pill_button("MENÚ PRINCIPAL", Color(0.28, 0.16, 0.38), Color(0.88, 0.66, 0.98))
	menu_btn.custom_minimum_size = Vector2(0, 54)
	menu_btn.pressed.connect(func() -> void:
		_pause_overlay.visible = false
		var fader: Node = _fader()
		if fader != null:
			fader.call("fade_to_scene", "res://scenes/ui/MainMenu.tscn", 0.4, 0.4)
		else:
			get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	)
	p_vbox.add_child(res_btn)
	p_vbox.add_child(_pause_map_btn)
	p_vbox.add_child(rst_btn)
	p_vbox.add_child(menu_btn)


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
	var liq_col: Color = _broth_current_color.lightened(0.08 + 0.04 * sin(_time * 8.0)) if _frenzy_timer > 0.0 else _broth_current_color
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
	if not _tut_active or round_ending or _closing_active or _tut_step == CauldronTutStep.NONE or _tut_step == CauldronTutStep.BASIC_READY_SUMMARY:
		return

	var pulse: float = 0.5 + 0.5 * sin(_time * 7.5)
	if _tut_step == CauldronTutStep.MIX_DRAG_COMBINE:
		var liked_k: int = int(get_customer_chemistry()["liked"])
		if not is_mixed_kind(liked_k):
			return
		var comps: Array[int] = get_recipe_components(liked_k)
		var pos_a: Vector2 = Vector2.ZERO
		var rad_a: float = ORB_RADIUS
		var found_a: bool = false
		var pos_b: Vector2 = Vector2.ZERO
		var rad_b: float = ORB_RADIUS
		var found_b: bool = false
		for o: Dictionary in _orbs:
			if int(o["id"]) == _lifted_orb_id:
				continue
			var k: int = int(o["kind"])
			if not found_a and k == comps[0]:
				pos_a = (o["pos"] as Vector2) + shake_v
				rad_a = float(o["radius"])
				found_a = true
			elif not found_b and k == comps[1]:
				pos_b = (o["pos"] as Vector2) + shake_v
				rad_b = float(o["radius"])
				found_b = true
		if found_a and found_b:
			var c_guide: Color = Color(0.45, 0.96, 1.0)
			draw_arc(pos_a, rad_a + 12.0 + pulse * 5.0, 0.0, TAU, 28, c_guide, 3.6)
			draw_arc(pos_b, rad_b + 12.0 + pulse * 5.0, 0.0, TAU, 28, Color(1.0, 0.88, 0.36), 3.6)
			draw_line(pos_a, pos_b, Color(1.0, 0.92, 0.46, 0.72), 3.0)
			var mid: Vector2 = (pos_a + pos_b) * 0.5
			draw_string(font, mid + Vector2(-75, -18), "¡Arrastra y junta!", HORIZONTAL_ALIGNMENT_CENTER, 150, 16, Color(1.0, 0.94, 0.52))
		return

	var target_rel: StringName = &"liked"
	var guide_txt: String = "¡3 clics!"
	var guide_col: Color = Color(1.0, 0.90, 0.34)
	if _tut_step == CauldronTutStep.BASIC_PURGE_DISLIKED:
		target_rel = &"disliked"
		guide_txt = "¡Clic Der!"
		guide_col = Color(1.0, 0.42, 0.50)
	elif _tut_step == CauldronTutStep.MIX_BREAK_RESULT:
		guide_txt = "¡Rómpelo!"
		guide_col = Color(1.0, 0.88, 0.36)

	for o: Dictionary in _orbs:
		if int(o["id"]) == _lifted_orb_id:
			continue
		if get_orb_relation(int(o["kind"])) == target_rel:
			var pos: Vector2 = (o["pos"] as Vector2) + shake_v
			var rad: float = float(o["radius"])
			draw_arc(pos, rad + 13.0 + pulse * 5.0, 0.0, TAU, 28, guide_col, 3.6)
			draw_string(font, pos + Vector2(-60, -rad - 20.0), guide_txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, guide_col)
			break


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
	var font: Font = ThemeDB.fallback_font
	if _flask_glass_tex != null and _flask_liquid_mat != null:
		var pct_txt: String = "%d%%" % int(roundf(_potion_tube_pct))
		var lbl_pos: Vector2 = Vector2(FLASK_RECT.position.x - 4.0, FLASK_RECT.end.y + 30.0)
		var lbl_w: int = int(FLASK_RECT.size.x + 8.0)
		draw_string(font, lbl_pos + Vector2(2, 2), pct_txt, HORIZONTAL_ALIGNMENT_CENTER, lbl_w, 24, Color(0.05, 0.02, 0.10, 0.90))
		draw_string(font, lbl_pos, pct_txt, HORIZONTAL_ALIGNMENT_CENTER, lbl_w, 24, Color(1.0, 0.94, 0.78))
		return

	var r: Rect2 = TUBE_RECT
	var liked_col: Color = get_element_color(int(get_customer_chemistry()["liked"]))
	var pct: float = clampf(_potion_tube_pct / 100.0, 0.0, 1.0)

	# Fallback procedural tube if flask textures are missing
	draw_rect(r.grow(5.0), Color(liked_col.r, liked_col.g, liked_col.b, 0.16))
	draw_rect(r, Color(0.08, 0.06, 0.14, 0.90))
	draw_rect(r, Color(liked_col.r, liked_col.g, liked_col.b, 0.16))
	if pct > 0.0:
		var fill_h: float = r.size.y * pct
		var fill_rect: Rect2 = Rect2(r.position.x + 5, r.position.y + r.size.y - fill_h, r.size.x - 10, fill_h)
		var fill_col: Color = liked_col.lightened(0.18) if (_tube_flash_timer > 0.0 and _tube_flash_positive) else (Color(1.0, 0.24, 0.28) if (_tube_flash_timer > 0.0 and not _tube_flash_positive) else liked_col)
		draw_rect(fill_rect, fill_col)
		draw_rect(Rect2(fill_rect.position.x, fill_rect.position.y, fill_rect.size.x, 6.0), Color(1, 1, 1, 0.65))

	for mark: float in [0.25, 0.50, 0.75]:
		var my: float = r.position.y + r.size.y * (1.0 - mark)
		draw_line(Vector2(r.position.x + 4, my), Vector2(r.position.x + 20, my), Color(1, 1, 1, 0.45), 2.0)

	draw_rect(r, liked_col.lightened(0.28), false, 3.5)
	draw_rect(Rect2(r.position.x + 8, r.position.y - 16, r.size.x - 16, 16), Color(0.68, 0.46, 0.26))
	draw_string(font, Vector2(r.position.x - 12, r.position.y + r.size.y + 34), "%d%%" % int(roundf(_potion_tube_pct)), HORIZONTAL_ALIGNMENT_CENTER, 78, 24, Color(1.0, 0.94, 0.78))


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
	if _active_customer == null:
		return
	var chem: Dictionary = get_customer_chemistry()
	var liked_k: int = int(chem["liked"])
	var liked_col: Color = get_element_color(liked_k)
	var box: Rect2 = Rect2(1256.0, 102.0, 164.0, 134.0)
	var pulse: float = 0.5 + 0.5 * sin(_time * 4.5)

	# Glowing beam connecting requested color bubble into the flask cork
	var flask_cork: Vector2 = Vector2(FLASK_RECT.position.x + FLASK_RECT.size.x * 0.5, FLASK_RECT.position.y + 8.0)
	draw_line(Vector2(1338.0, box.end.y), flask_cork, Color(liked_col.r, liked_col.g, liked_col.b, 0.55), 4.0)

	# Bubble backdrop + pointer tail toward customer on the right
	draw_rect(box, Color(0.11, 0.07, 0.19, 0.94))
	draw_rect(box, liked_col.lightened(0.25), false, 3.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(box.end.x, 152.0),
		Vector2(box.end.x + 22.0, 166.0),
		Vector2(box.end.x, 180.0),
	]), Color(0.11, 0.07, 0.19, 0.94))
	draw_polyline(PackedVector2Array([
		Vector2(box.end.x, 152.0),
		Vector2(box.end.x + 22.0, 166.0),
		Vector2(box.end.x, 180.0),
	]), liked_col.lightened(0.25), 2.8)

	var font: Font = ThemeDB.fallback_font
	if is_mixed_kind(liked_k):
		var main_c: Vector2 = Vector2(box.position.x + box.size.x * 0.5, box.position.y + 42.0)
		draw_circle(main_c, 31.0 + pulse * 4.0, Color(liked_col.r, liked_col.g, liked_col.b, 0.24))
		draw_arc(main_c, 28.0, 0.0, TAU, 28, Color(1.0, 0.90, 0.38, 0.90), 2.6)
		_draw_mini_orb_badge(self, main_c, 25.0, liked_k, false)

		var comps: Array[int] = get_recipe_components(liked_k)
		var y_rec: float = box.position.y + 104.0
		_draw_mini_orb_badge(self, Vector2(box.position.x + 44.0, y_rec), 15.0, comps[0], false)
		draw_string(font, Vector2(box.position.x + 71.0, y_rec + 7.0), "+", HORIZONTAL_ALIGNMENT_CENTER, 22, 20, Color(1.0, 0.92, 0.65))
		_draw_mini_orb_badge(self, Vector2(box.position.x + 120.0, y_rec), 15.0, comps[1], false)
	else:
		var main_c: Vector2 = box.position + box.size * 0.5 + Vector2(0.0, 4.0)
		draw_circle(main_c, 42.0 + pulse * 5.0, Color(liked_col.r, liked_col.g, liked_col.b, 0.24))
		draw_arc(main_c, 37.0, 0.0, TAU, 28, Color(1.0, 0.90, 0.38, 0.92), 3.0)
		_draw_mini_orb_badge(self, main_c, 33.0, liked_k, false)
		draw_string(font, Vector2(box.position.x, box.position.y + 20.0), "PIDE", HORIZONTAL_ALIGNMENT_CENTER, int(box.size.x), 14, Color(1.0, 0.92, 0.65))


func _draw_chem_visual_strip() -> void:
	if _chem_visual_canvas == null:
		return
	var chem: Dictionary = get_customer_chemistry()
	var liked_k: int = int(chem["liked"])
	var disliked_k: int = int(chem["disliked"])
	var font: Font = ThemeDB.fallback_font
	var cy: float = _chem_visual_canvas.size.y * 0.5

	_chem_visual_canvas.draw_string(font, Vector2(4.0, cy + 5.0), "PIDE:", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.55, 1.0, 0.68))
	_draw_mini_orb_badge(_chem_visual_canvas, Vector2(72.0, cy), 17.0, liked_k, false)

	if is_mixed_kind(liked_k):
		var comps: Array[int] = get_recipe_components(liked_k)
		_chem_visual_canvas.draw_string(font, Vector2(96.0, cy + 6.0), "=", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.92, 0.65))
		_draw_mini_orb_badge(_chem_visual_canvas, Vector2(130.0, cy), 14.0, comps[0], false)
		_chem_visual_canvas.draw_string(font, Vector2(150.0, cy + 6.0), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.92, 0.65))
		_draw_mini_orb_badge(_chem_visual_canvas, Vector2(182.0, cy), 14.0, comps[1], false)
	else:
		var neutral_k: int = int(chem["neutral"])
		_chem_visual_canvas.draw_string(font, Vector2(106.0, cy + 5.0), "OK:", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.84, 0.88, 0.96))
		_draw_mini_orb_badge(_chem_visual_canvas, Vector2(152.0, cy), 14.0, neutral_k, false)

	_chem_visual_canvas.draw_line(Vector2(276.0, 6.0), Vector2(276.0, _chem_visual_canvas.size.y - 6.0), Color(1, 1, 1, 0.16), 2.0)
	_chem_visual_canvas.draw_string(font, Vector2(294.0, cy + 5.0), "EVITA:", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.45, 0.50))
	_draw_mini_orb_badge(_chem_visual_canvas, Vector2(374.0, cy), 17.0, disliked_k, true)


func _draw_trixie_stage_left() -> void:
	CharacterArt.draw_trixie_halfbody(self, Rect2(-8, 124, 520, 816), _trixie_emotion, _time, 1.0, _trixie_react_anim)


func _draw_customer_stage_right() -> void:
	var slide_off: float = (1.0 - _customer_slide_t) * 140.0
	if _active_customer != null:
		if CharacterArt.has_customer_halfbody(_active_customer.customer_id):
			var stage: Rect2 = Rect2(1404 + slide_off, 108, 520, 822)
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
	if _top_essence_lbl == null:
		return
	_top_essence_lbl.text = "✦ %d" % essence_gold
	var stop_icon: String = String(_active_stop.get("icon", "📍"))
	var stop_name: String = String(_active_stop.get("name", "Parada"))
	_top_stop_lbl.text = "%s %s" % [stop_icon, stop_name]
	var shown_wave: int = mini(_wave_index + 1, _wave_customers.size())
	_top_wave_lbl.text = "👥 Clienta: %d/%d  (✅%d ❌%d)" % [shown_wave, _wave_customers.size(), _wave_served_count, _wave_missed_count]

	var p_ratio: float = clampf(customer_patience_left / maxf(1.0, customer_patience_max), 0.0, 1.0)
	if _is_patience_paused_for_tutorial():
		_top_timer_lbl.text = "⏸ Tutorial"
		_top_timer_lbl.modulate = Color(1.0, 0.88, 0.42)
	else:
		var secs_int: int = ceili(customer_patience_left)
		_top_timer_lbl.text = "⏳ Paciencia: %ds" % secs_int
		_top_timer_lbl.modulate = Color(1.0, 0.38, 0.42) if p_ratio <= CUSTOMER_IMPATIENT_RATIO else Color(1.0, 0.94, 0.78)

	if _cust_patience_bar != null:
		_cust_patience_bar.value = p_ratio * 100.0
	if _cust_patience_fill != null:
		if _is_patience_paused_for_tutorial():
			_cust_patience_fill.bg_color = Color(0.45, 0.82, 1.0)
		elif p_ratio > 0.55:
			_cust_patience_fill.bg_color = Color(0.32, 0.88, 0.56)
		elif p_ratio > CUSTOMER_IMPATIENT_RATIO:
			_cust_patience_fill.bg_color = Color(0.98, 0.74, 0.24)
		else:
			_cust_patience_fill.bg_color = Color(1.0, 0.30, 0.38)
	if _cust_patience_lbl != null:
		if _is_patience_paused_for_tutorial():
			_cust_patience_lbl.text = "⏸ Pausado"
			_cust_patience_lbl.modulate = Color(0.65, 0.92, 1.0)
		else:
			var p_secs: int = ceili(customer_patience_left)
			_cust_patience_lbl.text = "⏳ Paciencia: %ds" % p_secs
			_cust_patience_lbl.modulate = Color(1.0, 0.42, 0.46) if p_ratio <= CUSTOMER_IMPATIENT_RATIO else Color(1.0, 0.92, 0.65)

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
		_cust_name_lbl.text = "%s (%s)" % [_active_customer.display_name, _active_customer.species_archetype]
		_cust_aff_lbl.text = "❤ Nv.%d · +%d✦" % [get_affinity_level(cid), _customer_order_reward]
	if _chem_visual_canvas != null:
		_chem_visual_canvas.queue_redraw()


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
	var initial_cap_ok: bool = (spawn_cap == 6 and _orbs.size() == 6 and click_damage == 1 and not hold_auto_hit_unlocked)
	var cauldron_tex_ok: bool = (_cauldron_tex != null and _cauldron_tex.resource_path == CAULDRON_TEX_PATH)
	var stop_bg_tex_ok: bool = (_stop_bg_tex != null and _stop_bg_tex.resource_path == "res://assets/backgrounds/bg_01_castillo.jpg" and _bg_sprite != null and _bg_sprite.visible)
	var flask_assets_ok: bool = (_flask_glass_tex != null and _flask_mask_tex != null and _flask_liquid_mat != null and _flask_glass_sprite != null and _flask_liquid_sprite != null)
	var orb_sprites_ok: bool = (_orb_textures.size() == 8 and _crack_textures.size() == 2 and _crack_glow_textures.size() == 2)
	var dialog_bg_tex_ok: bool = (_dialog_bg_tex != null and _dialog_shadow_tex != null and _speech_bubble_tex != null and _speech_bubble_shadow_tex != null)
	var pueblo_bg_exists_ok: bool = ResourceLoader.exists("res://assets/backgrounds/bg_02_pueblo.jpg")
	var no_duplicate_meta_buttons_in_main: bool = (
		get("_tab_tree_btn") == null
		and get("_tab_gallery_btn") == null
		and get("_end_round_btn") == null
	)

	var hb_paths: Dictionary = {}
	var all_hb_ok: bool = true
	for emo: String in ["normal", "confiada", "nerviosa", "sonrojada", "hollin", "sorprendida"]:
		var hb_tex: Texture2D = CharacterArt.get_trixie_halfbody(emo)
		if hb_tex == null:
			all_hb_ok = false
		else:
			hb_paths[hb_tex.resource_path] = true
	var all_halfbodies_distinct_ok: bool = all_hb_ok and hb_paths.size() == 6

	var sylvi_paths: Dictionary = {}
	var all_sylvi_ok: bool = true
	for s_emo: String in ["normal", "sonrojada_picante", "impaciente"]:
		var s_tex: Texture2D = CharacterArt.get_customer_halfbody(&"sylvi", s_emo)
		if s_tex == null:
			all_sylvi_ok = false
		else:
			sylvi_paths[s_tex.resource_path] = true
	var sylvi_halfbodies_distinct_ok: bool = all_sylvi_ok and sylvi_paths.size() == 3

	var velvet_paths: Dictionary = {}
	var all_velvet_ok: bool = true
	for v_emo: String in ["normal", "sonrojada_picante", "impaciente"]:
		var v_tex: Texture2D = CharacterArt.get_customer_halfbody(&"velvet", v_emo)
		if v_tex == null:
			all_velvet_ok = false
		else:
			velvet_paths[v_tex.resource_path] = true
	var velvet_halfbodies_distinct_ok: bool = all_velvet_ok and velvet_paths.size() == 3

	var seraphina_paths: Dictionary = {}
	var all_seraphina_ok: bool = true
	for sp_emo: String in ["normal", "sonrojada_picante", "impaciente"]:
		var sp_tex: Texture2D = CharacterArt.get_customer_halfbody(&"seraphina", sp_emo)
		if sp_tex == null:
			all_seraphina_ok = false
		else:
			seraphina_paths[sp_tex.resource_path] = true
	var seraphina_halfbodies_distinct_ok: bool = all_seraphina_ok and seraphina_paths.size() == 3

	var mona_paths: Dictionary = {}
	var all_mona_ok: bool = true
	for mn_emo: String in ["normal", "sonrojada_picante", "impaciente"]:
		var mn_tex: Texture2D = CharacterArt.get_customer_halfbody(&"mona", mn_emo)
		if mn_tex == null:
			all_mona_ok = false
		else:
			mona_paths[mn_tex.resource_path] = true
	var mona_halfbodies_distinct_ok: bool = all_mona_ok and mona_paths.size() == 3

	var roxy_paths: Dictionary = {}
	var all_roxy_ok: bool = true
	for rx_emo: String in ["normal", "sonrojada_picante", "impaciente"]:
		var rx_tex: Texture2D = CharacterArt.get_customer_halfbody(&"roxy", rx_emo)
		if rx_tex == null:
			all_roxy_ok = false
		else:
			roxy_paths[rx_tex.resource_path] = true
	var roxy_halfbodies_distinct_ok: bool = all_roxy_ok and roxy_paths.size() == 3

	var st: Node = _state()
	var tut_step_1_ok: bool = _tut_active and _tut_step == CauldronTutStep.BASIC_BREAK_LIKED and _trixie_bubble != null and _trixie_bubble.visible and not st.mix_tutorial_done
	var banner_above_cauldron_ok: bool = (_trixie_bubble != null and (_trixie_bubble.position.y + SPEECH_BUBBLE_BODY_H) < (CAULDRON_CENTER.y - CAULDRON_ELLIPSE_RY))

	# 1) Verify idle frame causes zero passive extraction AND tutorial pauses patience!
	var tube_before: float = _potion_tube_pct
	var ess_before: int = essence_gold
	var pat_before: float = customer_patience_left
	_process_cauldron_gameplay(5.0)
	var no_autoclicker_ok: bool = (_potion_tube_pct == tube_before and essence_gold == ess_before)
	var tutorial_pauses_patience_ok: bool = (customer_patience_left == pat_before)

	# 2) Verify 3 hits break a tier-1 orb initially (advances basic tutorial 1 -> 2)
	var chem: Dictionary = get_customer_chemistry()
	var liked_k: int = int(chem["liked"])
	var disliked_k: int = int(chem["disliked"])

	_orbs.clear()
	var red_orb: Dictionary = _make_orb_dict(liked_k, CAULDRON_CENTER, 1)
	var red_id: int = int(red_orb["id"])
	_orbs.append(red_orb)
	var h1_broke: bool = _hit_orb_by_id(red_id, click_damage, true)
	var h2_broke: bool = _hit_orb_by_id(red_id, click_damage, true)
	var hp_before_3: int = int(_orbs[0]["hp"]) if _orbs.size() == 1 else -1
	var h3_broke: bool = _hit_orb_by_id(red_id, click_damage, true)
	var three_clicks_to_break_ok: bool = (not h1_broke and not h2_broke and hp_before_3 == 1 and h3_broke and _potion_tube_pct > 15.0 and _combo == 1)
	var tut_step_2_ok: bool = (_tut_step == CauldronTutStep.BASIC_PURGE_DISLIKED)

	# 3) Verify lift-and-drop color combining & concentration mechanics
	_orbs.clear()
	var mix_a: Dictionary = _make_orb_dict(BubbleKind.RED, CAULDRON_CENTER + Vector2(-60, 0), 1)
	var mix_b: Dictionary = _make_orb_dict(BubbleKind.GREEN, CAULDRON_CENTER + Vector2(60, 0), 1)
	_orbs.append(mix_a)
	_orbs.append(mix_b)
	var combined_color: bool = _combine_orbs_by_id(int(mix_a["id"]), int(mix_b["id"]))
	var lift_combine_color_ok: bool = (combined_color and _orbs.size() >= 1 and int(_orbs[0]["kind"]) == BubbleKind.YELLOW and int(_orbs[0]["hp"]) == BASE_ORB_HP)

	_orbs.clear()
	var conc_a: Dictionary = _make_orb_dict(BubbleKind.RED, CAULDRON_CENTER + Vector2(-60, 0), 1)
	var conc_b: Dictionary = _make_orb_dict(BubbleKind.RED, CAULDRON_CENTER + Vector2(60, 0), 1)
	_orbs.append(conc_a)
	_orbs.append(conc_b)
	var combined_same: bool = _combine_orbs_by_id(int(conc_a["id"]), int(conc_b["id"]))
	var lift_concentrate_ok: bool = (combined_same and _orbs.size() == 1 and int(_orbs[0]["kind"]) == BubbleKind.RED and int(_orbs[0]["tier"]) == 2)

	# 4) Purge a Disliked orb with Right-click -> preserves combo & advances basic tutorial 2 -> 3 (summary)
	_orbs.clear()
	var bad_p: Dictionary = _make_orb_dict(disliked_k, CAULDRON_CENTER + Vector2(90, 0), 1)
	_orbs.append(bad_p)
	_purge_orb_by_id(int(bad_p["id"]))
	var purge_kept_combo: bool = (_combo == 1 and _potion_tube_pct > 15.0)
	var tut_step_3_ok: bool = (_tut_step == CauldronTutStep.BASIC_READY_SUMMARY and _trixie_bubble_ack_btn != null and _trixie_bubble_ack_btn.visible)

	# Acknowledge summary -> basic tutorial done and patience starts counting down
	_acknowledge_basic_tutorial_summary()
	var pat_pre_tick: float = customer_patience_left
	_process_cauldron_gameplay(2.0)
	var patience_ticks_after_tut_ok: bool = (not _tut_active and st.cauldron_basics_tutorial_done and customer_patience_left < pat_pre_tick)

	# 5) Break Disliked orb -> lowers tube, resets combo to 0, triggers nerviosa & customer impaciente
	_orbs.clear()
	var bad_1: Dictionary = _make_orb_dict(disliked_k, CAULDRON_CENTER, 1)
	bad_1["hp"] = 1
	_orbs.append(bad_1)
	var tube_pre_bad: float = _potion_tube_pct
	_hit_orb_by_id(int(bad_1["id"]), 1, true)
	var disliked_lowered_tube: bool = _potion_tube_pct < tube_pre_bad
	var disliked_reset_combo: bool = (_combo == 0)
	var nerviosa_ok: bool = (_trixie_emotion == "nerviosa")
	var cust_impaciente_ok: bool = (_customer_emotion == "impaciente")

	# Second consecutive Disliked backfire -> triggers hollin
	_orbs.clear()
	var bad_2: Dictionary = _make_orb_dict(disliked_k, CAULDRON_CENTER, 1)
	bad_2["hp"] = 1
	_orbs.append(bad_2)
	_hit_orb_by_id(int(bad_2["id"]), 1, true)
	var hollin_triggered: bool = (_trixie_emotion == "hollin")

	# 6) Break GOLD Star orb -> triggers sorprendida
	_orbs.clear()
	var gold_o: Dictionary = _make_orb_dict(BubbleKind.GOLD, CAULDRON_CENTER, 1)
	gold_o["hp"] = 1
	_orbs.append(gold_o)
	_hit_orb_by_id(int(gold_o["id"]), 1, true)
	var sorprendida_triggered: bool = (_trixie_emotion == "sorprendida")

	# 7) Complete Sylvi's order -> Velvet arrives with mixed color order & JUST-IN-TIME MIX TUTORIAL pops and pauses time!
	_orbs.clear()
	var finisher: Dictionary = _make_orb_dict(liked_k, CAULDRON_CENTER, 3)
	finisher["hp"] = 1
	_orbs.append(finisher)
	_hit_orb_by_id(int(finisher["id"]), 1, true)
	var mixed_order_velvet_ok: bool = (orders_completed >= 1 and _active_customer != null and _active_customer.customer_id == &"velvet" and is_mixed_kind(int(get_customer_chemistry()["liked"])))
	var mix_tut_started_ok: bool = (_tut_active and _tut_step == CauldronTutStep.MIX_DRAG_COMBINE)
	var v_pat_before: float = customer_patience_left
	_process_cauldron_gameplay(4.0)
	var mix_tut_paused_ok: bool = (customer_patience_left == v_pat_before)

	# Complete the contextual mix tutorial by combining RED + BLUE -> PURPLE and breaking it
	var v_comps: Array[int] = get_recipe_components(int(get_customer_chemistry()["liked"]))
	_orbs.clear()
	var vm_a: Dictionary = _make_orb_dict(v_comps[0], CAULDRON_CENTER + Vector2(-50, 0), 1)
	var vm_b: Dictionary = _make_orb_dict(v_comps[1], CAULDRON_CENTER + Vector2(50, 0), 1)
	_orbs.append(vm_a)
	_orbs.append(vm_b)
	_combine_orbs_by_id(int(vm_a["id"]), int(vm_b["id"]))
	var mix_tut_step2_ok: bool = (_tut_step == CauldronTutStep.MIX_BREAK_RESULT)
	_orbs[0]["hp"] = 1
	_hit_orb_by_id(int(_orbs[0]["id"]), 1, true)
	var mix_tut_done_ok: bool = (not _tut_active and st.mix_tutorial_done)

	# 8) Append temporary 3rd customer (&"seraphina") to test Frenzy + Velvet serve + Seraphina patience timeout
	_wave_customers.append(&"seraphina")

	# Trigger Frenzy on Velvet -> sonrojada on both girls
	_orbs.clear()
	var v_bad: Dictionary = _make_orb_dict(int(get_customer_chemistry()["disliked"]), CAULDRON_CENTER, 1)
	_orbs.append(v_bad)
	if _frenzy_charge < 100.0:
		_frenzy_charge = 100.0
	var frenzy_triggered: bool = try_activate_frenzy()
	var sonrojada_triggered: bool = (_trixie_emotion == "sonrojada")
	var cust_sonrojada_ok: bool = (_customer_emotion == "sonrojada")

	# Serve Velvet -> Seraphina arrives
	var v_liked: int = int(get_customer_chemistry()["liked"])
	_orbs.clear()
	var v_fin: Dictionary = _make_orb_dict(v_liked, CAULDRON_CENTER, 3)
	v_fin["hp"] = 1
	_orbs.append(v_fin)
	_hit_orb_by_id(int(v_fin["id"]), 1, true)
	var seraphina_arrived_ok: bool = (_active_customer != null and _active_customer.customer_id == &"seraphina" and _wave_served_count == 2)

	# Drain Seraphina's patience -> customer leaves, missed count=1, combo=0, 2/3 served -> wave victory & closing dialogue!
	_combo = 3
	customer_patience_left = 0.05
	_process_cauldron_gameplay(0.2)
	var customer_timeout_advances_ok: bool = (seraphina_arrived_ok and _wave_missed_count == 1 and _combo == 0)

	var end_triggered_gracefully: bool = round_ending and _wave_victory and not _closing_active
	_round_end_timer = 0.0
	_process_cauldron_gameplay(0.05)
	var closing_opened_ok: bool = _closing_active and _closing_overlay != null and _closing_overlay.visible and _closing_lines.size() == 1 and String(_closing_lines[0].get("speaker", "")) == "trixie"

	for _step: int in range(10):
		if not _closing_active or _fading_out:
			break
		_closing_shown_chars = float(_closing_full_text.length())
		_handle_closing_advance_input()

	var wave_closing_dialogue_ok: bool = (
		end_triggered_gracefully
		and closing_opened_ok
		and st.is_map_node_completed(&"castillo")
		and st.is_map_node_unlocked(&"pueblo")
		and st.cauldron_tutorial_done
	)

	# 9) Verify dynamic varied customer orders & Mona Elfa Noble archetype
	var rolled_kinds: Dictionary = {}
	var roll_valid: bool = true
	for _r: int in range(10):
		var c_chem: Dictionary = _roll_order_chemistry_for_customer(&"sylvi", false)
		var lk: int = int(c_chem["liked"])
		var dk: int = int(c_chem["disliked"])
		_last_order_liked_kind = lk
		rolled_kinds[lk] = true
		if is_mixed_kind(lk) and get_recipe_components(lk).has(dk):
			roll_valid = false
	var varied_customer_orders_ok: bool = (rolled_kinds.size() >= 2 and roll_valid)

	var mona_c: CustomerArchetypeData = _find_customer_by_id(&"mona")
	var mona_elf_archetype_ok: bool = (
		mona_c != null
		and mona_c.species_archetype.contains("Elfa")
		and not mona_c.species_archetype.contains("Bruja")
	)

	_reset_mix_pigment(true)
	var reset_clean_ok: bool = (_mix_weight == 0.0 and _broth_target_color == BROTH_NEUTRAL_COLOR)
	_inject_mix_pigment(BubbleKind.BLUE, 1)
	var h_blue: float = _flask_target_color.h
	_inject_mix_pigment(BubbleKind.RED, 1)
	var h_purple: float = _flask_target_color.h
	_inject_mix_pigment(BubbleKind.BLUE, 1)
	var h_bluish: float = _flask_target_color.h
	_reset_mix_pigment(false)
	var mix_pigment_blending_ok: bool = (
		reset_clean_ok
		and h_blue >= 0.50 and h_blue <= 0.66
		and h_purple >= 0.72 and h_purple <= 0.90
		and h_bluish >= 0.58 and h_bluish < h_purple - 0.05
		and _mix_weight == 0.0
		and _broth_target_color == BROTH_NEUTRAL_COLOR
	)

	return {
		"initial_cap_ok": initial_cap_ok,
		"cauldron_tex_ok": cauldron_tex_ok,
		"stop_bg_tex_ok": stop_bg_tex_ok,
		"flask_assets_ok": flask_assets_ok,
		"orb_sprites_ok": orb_sprites_ok,
		"dialog_bg_tex_ok": dialog_bg_tex_ok,
		"pueblo_bg_exists_ok": pueblo_bg_exists_ok,
		"mix_pigment_blending_ok": mix_pigment_blending_ok,
		"no_duplicate_meta_buttons_in_main": no_duplicate_meta_buttons_in_main,
		"all_halfbodies_distinct_ok": all_halfbodies_distinct_ok,
		"sylvi_halfbodies_distinct_ok": sylvi_halfbodies_distinct_ok,
		"velvet_halfbodies_distinct_ok": velvet_halfbodies_distinct_ok,
		"seraphina_halfbodies_distinct_ok": seraphina_halfbodies_distinct_ok,
		"mona_halfbodies_distinct_ok": mona_halfbodies_distinct_ok,
		"roxy_halfbodies_distinct_ok": roxy_halfbodies_distinct_ok,
		"cauldron_tutorial_flow_ok": tut_step_1_ok and banner_above_cauldron_ok and tut_step_2_ok and tut_step_3_ok and patience_ticks_after_tut_ok,
		"tutorial_pauses_patience_ok": tutorial_pauses_patience_ok,
		"mix_tutorial_contextual_ok": mix_tut_started_ok and mix_tut_paused_ok and mix_tut_step2_ok and mix_tut_done_ok,
		"customer_timeout_advances_ok": customer_timeout_advances_ok,
		"varied_customer_orders_ok": varied_customer_orders_ok,
		"mona_elf_archetype_ok": mona_elf_archetype_ok,
		"no_autoclicker_ok": no_autoclicker_ok,
		"three_clicks_to_break_ok": three_clicks_to_break_ok,
		"lift_combine_color_ok": lift_combine_color_ok,
		"lift_concentrate_ok": lift_concentrate_ok,
		"purge_kept_combo": purge_kept_combo,
		"disliked_lowered_tube": disliked_lowered_tube,
		"disliked_reset_combo": disliked_reset_combo,
		"nerviosa_ok": nerviosa_ok,
		"cust_impaciente_ok": cust_impaciente_ok,
		"hollin_triggered": hollin_triggered,
		"sorprendida_triggered": sorprendida_triggered,
		"orders_completed": orders_completed,
		"mixed_order_velvet_ok": mixed_order_velvet_ok,
		"frenzy_triggered": frenzy_triggered,
		"sonrojada_triggered": sonrojada_triggered,
		"cust_sonrojada_ok": cust_sonrojada_ok,
		"wave_closing_dialogue_ok": wave_closing_dialogue_ok,
		"nodes_count": tree_nodes.size(),
	}
