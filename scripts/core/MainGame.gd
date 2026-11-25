class_name MainGame
extends Node2D
## Tactical 2D Alchemy Incremental Cauldron Stage Coordinator.
## Wires CauldronBoard, WaveDirector, PotionFlaskView, TutorialDirector, and StageHUD.

const BubbleKind = ChemistryRules.BubbleKind
const GameStateScript: GDScript = preload("res://scripts/autoloads/GameState.gd")

const VIEWPORT_SIZE: Vector2 = Vector2(1920.0, 1080.0)
const CAULDRON_CENTER: Vector2 = Vector2(880.0, 564.0)

# Local fallback state when instantiated standalone without autoloads
var _local_state: Node = null

# Catalogs
var witches: Array[WitchCharacterData] = []
var customers_catalog: Array[CustomerArchetypeData] = []
var tree_nodes: Array[Dictionary] = []

# Proxied progression properties
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

# Derived tactical stats pushed to CauldronBoard & WaveDirector
var order_bonus_mult: float = 1.0
var crit_potion_lvl: int = 0

# Runtime stage state
var _time: float = 0.0
var _fading_out: bool = false
var _popups: Array[Dictionary] = []
var _trixie_emotion: String = "normal"
var _trixie_emotion_timer: float = 0.0
var _trixie_react_anim: float = 0.0
var _trixie_stage_rect: Rect2 = Rect2(-8.0, 124.0, 520.0, 816.0)
var _customer_stage_rect: Rect2 = Rect2(1404.0, 108.0, 520.0, 822.0)

var _stop_bg_tex: Texture2D = null
var _bg_shader_mat: ShaderMaterial = null
var _bg_frenzy_mix: float = 0.0
var _fire_shader_mat: ShaderMaterial = null

var _wave: WaveDirector = WaveDirector.new()
var _tutorial: TutorialDirector = TutorialDirector.new()

@onready var camera: Camera2D = $Camera2D
@onready var _bg_sprite: Sprite2D = $StageBackground
@onready var _trixie_stage_slot: TextureRect = $TrixieStageSlot
@onready var _customer_stage_slot: TextureRect = $CustomerStageSlot
@onready var _fire_glow_rect: ColorRect = $CauldronFireGlow
@onready var _board: CauldronBoard = $CauldronAnchor
@onready var _flask_view: PotionFlaskView = $PotionFlask
@onready var _hud: StageHUD = $UILayer


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

	var audio: Node = _audio()
	if audio != null and camera != null:
		audio.call("register_camera", camera)

	_connect_board()
	_connect_hud()
	_recalc_stats()
	_start_stop()

	var fader: Node = _fader()
	if fader != null and bool(fader.call("is_black")):
		fader.call("fade_in", 0.45)

	if OS.get_cmdline_user_args().has("--smoke-test"):
		call_deferred("_run_cmdline_smoke_and_quit")


func _connect_board() -> void:
	if _board == null:
		return
	_board.get_chemistry_fn = get_customer_chemistry
	_board.is_tube_empty_fn = func(penalty: float) -> bool:
		return _wave.potion_tube_pct - penalty <= 0.0
	_board.orb_lifted.connect(func() -> void: _play_pentatonic(1, -9.0))
	_board.orb_hit_damaged.connect(_on_board_orb_hit_damaged)
	_board.orb_combined.connect(_on_board_orb_combined)
	_board.orb_pigment_injected.connect(_on_board_pigment_injected)
	_board.orb_shattered_disliked.connect(_on_board_orb_shattered_disliked)
	_board.orb_shattered_good.connect(_on_board_orb_shattered_good)
	_board.orb_purged.connect(_on_board_orb_purged)
	_board.bomb_detonated.connect(_on_board_bomb_detonated)
	_board.frenzy_activated.connect(_on_board_frenzy_activated)
	_board.bat_extracted.connect(_on_board_bat_extracted)


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
	_hud.closing_typewriter_tick.connect(func() -> void: _play_pentatonic(3, -12.0))
	_hud.return_to_map_requested.connect(_on_pause_return_to_map)
	_hud.restart_requested.connect(_on_pause_restart)
	_hud.main_menu_requested.connect(_on_pause_main_menu)
	if _hud.chem_visual_canvas != null:
		_hud.chem_visual_canvas.draw.connect(_draw_chem_visual_strip)


func _run_cmdline_smoke_and_quit() -> void:
	await get_tree().process_frame
	var res: Dictionary = run_incremental_smoke_step()
	print("INCREMENTAL SMOKE => ", res)
	get_tree().quit(0)


func _process(delta: float) -> void:
	_time += delta
	if _board != null:
		_board.mouse_pos = get_global_mouse_position()
	_update_popups(delta)

	var frenzy_active: bool = _board != null and _board.frenzy_timer > 0.0
	var target_frenzy: float = 1.0 if frenzy_active else 0.0
	_bg_frenzy_mix = lerpf(_bg_frenzy_mix, target_frenzy, clampf(delta * 5.0, 0.0, 1.0))
	if _bg_shader_mat != null:
		_bg_shader_mat.set_shader_parameter("frenzy_amount", _bg_frenzy_mix)
	if _fire_shader_mat != null:
		_fire_shader_mat.set_shader_parameter("frenzy_amount", _bg_frenzy_mix)
	if _flask_view != null:
		var shake_val: float = _board.cauldron_shake if _board != null else 0.0
		_flask_view.step_fluid(delta, _wave.potion_tube_pct, shake_val)

	if _trixie_react_anim > 0.0:
		_trixie_react_anim = maxf(0.0, _trixie_react_anim - delta * 3.2)
	if _trixie_emotion_timer > 0.0:
		_trixie_emotion_timer = maxf(0.0, _trixie_emotion_timer - delta)
	var patience_low: bool = (not _is_patience_paused_for_tutorial()) and (not _wave.round_ending) and (_wave.customer_patience_left <= 7.0)
	if _trixie_emotion_timer <= 0.0 and not _wave.closing_active:
		var combo_val: int = _board.combo if _board != null else 0
		var desired_idle: String = "sonrojada" if frenzy_active else ("nerviosa" if patience_low else ("confiada" if combo_val >= 4 else "normal"))
		if _trixie_emotion != desired_idle:
			_trixie_emotion = desired_idle
			_trixie_react_anim = 1.0

	_wave.step_customer_visuals(delta, _is_patience_paused_for_tutorial(), frenzy_active)

	if not _wave.closing_active and not _is_modal_open():
		_process_cauldron_gameplay(delta)

	_refresh_hud_labels()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _board == null:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _board.left_down:
			_board.on_left_mouse_released(get_global_mouse_position(), not _wave.round_ending and not _wave.closing_active)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed:
			_board.right_down = false


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
			if _wave.closing_active:
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

	if _wave.closing_active:
		if event is InputEventMouseButton:
			var mbc: InputEventMouseButton = event as InputEventMouseButton
			if mbc.button_index == MOUSE_BUTTON_LEFT and mbc.pressed:
				_handle_closing_advance_input()
				get_viewport().set_input_as_handled()
		return

	if _is_modal_open() or _wave.round_ending or _board == null:
		return

	if event is InputEventMouseButton:
		if _board.handle_mouse_button(event as InputEventMouseButton, get_global_mouse_position()):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _board.handle_mouse_motion(get_global_mouse_position()):
			get_viewport().set_input_as_handled()


func _is_modal_open() -> bool:
	return (_hud != null and _hud.is_pause_open()) or _fading_out


func get_customer_chemistry() -> Dictionary:
	return _wave.get_customer_chemistry()


func get_orb_relation(kind: int) -> StringName:
	return ChemistryRules.get_orb_relation(kind, get_customer_chemistry())


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
	order_bonus_mult = st.order_bonus_mult
	crit_potion_lvl = st.crit_potion_lvl
	if _board == null:
		return
	_board.hold_auto_hit_unlocked = st.hold_auto_hit_unlocked
	_board.hold_hit_interval = st.hold_hit_interval
	_board.aroma_essence_mult = st.aroma_essence_mult
	_board.stop_essence_mult = _wave.stop_essence_mult
	_board.click_damage = st.click_damage
	_board.strength_tube_bonus = st.strength_tube_bonus
	_board.purge_recycle_lvl = st.purge_recycle_lvl
	_board.frenzy_gain_mult = st.frenzy_gain_mult
	_board.frenzy_duration_sec = st.frenzy_duration_sec
	_board.spawn_cap = st.spawn_cap
	_board.spawn_interval = maxf(0.26, float(st.spawn_interval) / maxf(0.5, _wave.stop_spawn_rate_mult))
	_board.chain_spark_jumps = st.chain_spark_jumps
	_board.bomb_chance = st.bomb_chance
	_board.star_chance = st.star_chance
	_board.fam_michi_lvl = st.fam_michi_lvl
	_board.fam_imp_lvl = st.fam_imp_lvl
	_board.fam_bat_lvl = st.fam_bat_lvl


func _is_patience_paused_for_tutorial() -> bool:
	return _tutorial.is_pausing_patience()


func _start_stop() -> void:
	var st: Node = _state()
	st.rounds_played += 1
	_wave.start_stop(st.get_active_map_node(), st.rounds_played)
	_fading_out = false
	_apply_stop_background()
	_recalc_stats()

	if _board != null:
		_board.reset_for_stop()
	_tutorial.reset()
	if _hud != null:
		_hud.set_cauldron_hud_visible(true)
		_hud.hide_trixie_bubble(true)
		_hud.hide_customer_bubble(true)

	_pick_customer_by_id(_wave.wave_customers[0], true)

	var liked_k: int = int(get_customer_chemistry()["liked"])
	if st.should_run_cauldron_basics_tutorial() and not ChemistryRules.is_mixed_kind(liked_k):
		_tutorial.start_basics()
		if _board != null:
			_board.setup_tutorial_initial_orbs()
		_update_tutorial_banner()
		_set_trixie_reaction("confiada", 3.0, "¡Primera clienta! El tiempo está pausado mientras aprendemos lo básico.")
	else:
		if not _tutorial.active:
			_update_tutorial_banner()
		if _board != null:
			for _i: int in range(_board.spawn_cap):
				_board.spawn_orb(false)
		if not _tutorial.active:
			var stop_name: String = String(_wave.active_stop.get("name", "Parada"))
			var dmg_base: int = _board.click_damage if _board != null else 1
			_set_trixie_reaction("confiada", 2.5, "¡Llegamos a %s! Rompe %s (%d golpes) para %s." % [
				stop_name,
				ChemistryRules.get_element_name(liked_k),
				maxi(1, ceili(float(CauldronBoard.BASE_ORB_HP) / float(dmg_base))),
				_wave.active_customer.display_name if _wave.active_customer != null else "la clienta",
			])

	if _hud != null:
		_hud.set_map_button_disabled(_tutorial.active)


func _advance_cauldron_tutorial(next_step: TutorialDirector.Step) -> void:
	if not _tutorial.advance_to(next_step):
		return
	_play_pentatonic(4, -2.0)
	if next_step == TutorialDirector.Step.BASIC_PURGE_DISLIKED and _board != null:
		_board.ensure_tutorial_orb(int(get_customer_chemistry()["disliked"]))
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
	if not ChemistryRules.is_mixed_kind(liked_k):
		return
	_tutorial.start_mix()
	if _board != null:
		_board.ensure_mix_ingredients(liked_k)
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
	if not _tutorial.active or _wave.closing_active or _tutorial.step == TutorialDirector.Step.NONE:
		if _hud.is_trixie_bubble_tutorial():
			_hud.hide_trixie_bubble(false)
		return
	var payload: Dictionary = _tutorial.get_banner_payload(get_customer_chemistry())
	_show_trixie_bubble(String(payload["title"]), String(payload["body"]), -1.0, true, bool(payload["show_ack"]))


func _process_cauldron_gameplay(delta: float) -> void:
	if _board != null:
		_board.step_ambient(delta)

	if _wave.round_ending:
		_wave.round_end_timer -= delta
		if _board != null:
			_board.update_vfx(delta)
		if _wave.round_end_timer <= 0.0 and not _wave.closing_active:
			_begin_closing_dialogue(_wave.wave_victory)
		return

	var p_ev: Dictionary = _wave.step_patience(delta, _is_patience_paused_for_tutorial())
	if bool(p_ev["impatient_warn"]):
		_set_customer_reaction("impaciente", 3.5, String(p_ev["warn_line"]))
		var cname: String = _wave.active_customer.display_name if _wave.active_customer != null else "Clienta"
		_set_trixie_reaction("nerviosa", 2.0, "¡%s está perdiendo la paciencia!" % cname)
	if bool(p_ev["expired"]):
		_on_customer_patience_expired()
		return

	if _board != null:
		_board.step_active(delta, _time)


func _on_board_orb_hit_damaged(pos: Vector2, dmg_step: int, hits_left: int, by_player: bool) -> void:
	_play_pentatonic(dmg_step, -5.0)
	if by_player:
		_spawn_popup(pos + Vector2(0, -24), "💥 (%d)" % hits_left, Color(1.0, 0.96, 0.82))


func _on_board_orb_combined(res_kind: int, new_tier: int, is_star_boost: bool, is_same_merge: bool, final_pos: Vector2, star_ess: int) -> void:
	_play_pentatonic(mini(7, 2 + new_tier), -1.0)
	var liked_k: int = int(get_customer_chemistry()["liked"])
	if is_star_boost:
		_grant_essence(star_ess)
		_spawn_popup(final_pos + Vector2(0, -18), "⭐ ¡POTENCIADO x%d! +%d✦" % [new_tier, star_ess], Color(1.0, 0.90, 0.32))
		_set_trixie_reaction("sorprendida", 1.7, "¡Estrella fusionada! ¡Ese orbe brilla x%d!" % new_tier)
	elif is_same_merge:
		_spawn_popup(final_pos + Vector2(0, -18), "%s ¡CONCENTRADO x%d!" % [ChemistryRules.get_element_name(res_kind), new_tier], ChemistryRules.get_element_color(res_kind).lightened(0.35))
		if new_tier >= 3:
			_set_trixie_reaction("sorprendida", 1.8, "¡Concentrado x3! ¡Ese orbe va a reventar el tubo!")
		elif res_kind == liked_k:
			_set_trixie_reaction("confiada", 1.5, "¡Orbe concentrado x%d! ¡Rómpelo a golpes!" % new_tier)
	else:
		_spawn_popup(final_pos + Vector2(0, -18), "✨ %s!" % ChemistryRules.get_element_name(res_kind), ChemistryRules.get_element_color(res_kind).lightened(0.35))
		if res_kind == liked_k:
			_set_trixie_reaction("confiada", 1.7, "¡Mezcla perfecta! ¡Ahora rómpela a golpes!")

	if _tutorial.active and _tutorial.step == TutorialDirector.Step.MIX_DRAG_COMBINE and res_kind == liked_k:
		_advance_cauldron_tutorial(TutorialDirector.Step.MIX_BREAK_RESULT)


func _on_board_pigment_injected(kind: int, tier: int) -> void:
	if _flask_view != null:
		_flask_view.inject_mix_pigment(kind, tier)


func _on_board_orb_shattered_disliked(pos: Vector2, _kind: int, _tier: int, penalty: float, severe_backfire: bool) -> void:
	_wave.potion_tube_pct = maxf(0.0, _wave.potion_tube_pct - penalty)
	if _flask_view != null:
		_flask_view.excite(-penalty)
		_flask_view.trigger_flash(0.55, false)
	_play_pentatonic(0, 0.0)
	_spawn_popup(pos, "¡❌ -%d%% Poción! Combo 0" % int(penalty), Color(1.0, 0.32, 0.34))
	if severe_backfire:
		_set_trixie_reaction("hollin", 2.4, "¡Puf...! ¡Me explotó en la cara! Purga los ❌ con Clic Der.")
	else:
		_set_trixie_reaction("nerviosa", 1.8, "¡Cuidado! Ese elemento choca con el pedido.")
	var c: CustomerArchetypeData = _wave.active_customer
	var imp_line: String = c.impatient_lines[0] if (c != null and not c.impatient_lines.is_empty()) else ""
	_set_customer_reaction("impaciente", 2.2, imp_line)


func _on_board_orb_shattered_good(pos: Vector2, kind: int, tier: int, rel: StringName, tube_gain: float, ess_gain: int, frenzy_just_ready: bool, combo_val: int) -> void:
	_play_pentatonic(clampi(combo_val % 8 + (1 if tier >= 2 else 0), 0, 7), -1.0 if rel == &"liked" or kind == BubbleKind.GOLD else -4.0)
	if ess_gain > 0:
		_grant_essence(ess_gain)

	if frenzy_just_ready:
		_set_trixie_reaction("sorprendida", 2.0, "¡Caldero al 100%! ¡Pulsa [ESPACIO] para el Frenesí!")
	elif kind == BubbleKind.GOLD:
		_set_trixie_reaction("sorprendida", 1.8, "¡Un Orbe Estrella! ¡Brilla muchísimo!")
	elif rel == &"liked" and (tier >= 2 or ChemistryRules.is_mixed_kind(kind)):
		_set_trixie_reaction("confiada", 1.7, "¡%s pulverizado! ¡Cómo sube el elixir!" % ChemistryRules.get_element_name(kind))
	elif rel == &"liked":
		_set_trixie_reaction("confiada", 1.5, "¡Bien triturado! Sigue buscando los afines.")
	elif rel == &"ingredient":
		_set_trixie_reaction("normal", 1.5, "Tip: ¡arrastra %s sobre el otro color para mezclar!" % ChemistryRules.get_element_name(kind))

	var c: CustomerArchetypeData = _wave.active_customer
	if (rel == &"liked" and (tier >= 2 or ChemistryRules.is_mixed_kind(kind) or combo_val >= 2)) or kind == BubbleKind.GOLD:
		var sat_line: String = ""
		if (tier >= 2 or ChemistryRules.is_mixed_kind(kind) or kind == BubbleKind.GOLD) and c != null and not c.satisfied_lines.is_empty():
			sat_line = c.satisfied_lines[randi() % c.satisfied_lines.size()]
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


func _on_board_orb_purged(pos: Vector2, rel: StringName, recycled_ess: int) -> void:
	var a: Node = _audio()
	if a != null:
		a.call("play_stir")
	if recycled_ess > 0:
		_grant_essence(recycled_ess)
		_spawn_popup(pos, "Purgado +%d✦" % recycled_ess, Color(0.72, 0.92, 1.0))
	else:
		_spawn_popup(pos, "Purgado", Color(0.80, 0.84, 0.94))
	if _tutorial.active and _tutorial.step == TutorialDirector.Step.BASIC_PURGE_DISLIKED and rel == &"disliked":
		_advance_cauldron_tutorial(TutorialDirector.Step.BASIC_READY_SUMMARY)


func _on_board_bomb_detonated(bpos: Vector2, _hit_count: int) -> void:
	_spawn_popup(bpos + Vector2(0, -28), "¡BOOM ALQUÍMICO!", Color(0.92, 0.56, 1.0))
	if _trixie_emotion != "sonrojada":
		_set_trixie_reaction("sorprendida", 1.9, "¡WHOA! ¡Bomba alquímica en reacción en cadena!")


func _on_board_frenzy_activated(transmuted_count: int, duration_sec: float) -> void:
	var a: Node = _audio()
	if a != null:
		a.call("trigger_screen_shake", 9.0, 0.25)
	var b: Node = _bus()
	if b != null:
		b.emit_signal("witch_ability_triggered", &"trixie", null)
	_set_trixie_reaction("sonrojada", duration_sec, "¡FRENESÍ ESCARLATA! %d ❌ transmutados, 1 golpe y 2x TODO!" % transmuted_count)
	_set_customer_reaction("sonrojada", duration_sec)
	var center: Vector2 = _board.get_center() if _board != null else CAULDRON_CENTER
	_spawn_popup(center, "¡FRENESÍ ESCARLATA x2!", Color(1.0, 0.42, 0.74))


func _on_board_bat_extracted(pos: Vector2, tube_pct: float, essence: int) -> void:
	_grant_essence(essence)
	_add_tube_progress(tube_pct)
	_spawn_popup(pos, "🦇 +%d%% +%d✦" % [int(tube_pct), essence], Color(0.84, 0.68, 1.0))


func try_activate_frenzy() -> bool:
	if _board == null:
		return false
	return _board.try_activate_frenzy(_wave.round_ending, _wave.closing_active)


func _grant_essence(amount: int) -> void:
	_state().grant_essence(amount)
	_wave.round_essence_gained += amount


func _add_tube_progress(pct: float) -> void:
	_wave.potion_tube_pct += pct
	if _flask_view != null:
		_flask_view.trigger_flash(0.45, true)
		_flask_view.excite(pct)
	if _wave.potion_tube_pct >= 100.0:
		_complete_customer_order()


func _pick_customer_by_id(cid: StringName, first_order: bool = false) -> void:
	var next_c: CustomerArchetypeData = _wave.find_customer_by_id(customers_catalog, cid)
	if next_c == null:
		return
	var info: Dictionary = _wave.pick_customer(next_c, first_order, _state(), order_bonus_mult, get_node_level(&"reloj_arena"))
	if _flask_view != null:
		_flask_view.reset_for_new_customer(first_order)
	_show_customer_bubble(next_c.display_name, String(info["greeting_line"]), 3.2)
	if bool(info["start_mix_tutorial"]):
		_start_mix_tutorial()
	elif _tutorial.active:
		_update_tutorial_banner()


func _on_customer_patience_expired() -> void:
	if _wave.active_customer == null or _wave.round_ending:
		return
	if _board != null:
		_board.combo = 0
		_board.combo_timer = 0.0
		_board.cauldron_shake = maxf(_board.cauldron_shake, 10.0)
		_board.reset_pointer_state()
	if _flask_view != null:
		_flask_view.trigger_flash(0.55, false)
	_play_pentatonic(0, 0.0)

	var res: Dictionary = _wave.expire_patience()
	var c: CustomerArchetypeData = res["customer"] as CustomerArchetypeData
	var b: Node = _bus()
	if b != null:
		b.emit_signal("customer_patience_expired", c.customer_id, 0)
	_show_customer_bubble(c.display_name, String(res["leave_line"]), 2.5)
	_spawn_popup(Vector2(1620, 440), "💢 ¡%s se fue!" % c.display_name, Color(1.0, 0.32, 0.36))
	if _hud != null:
		_hud.show_toast("💢 ¡%s perdió la paciencia y se marchó!" % c.display_name, 3.0)
	_set_trixie_reaction("nerviosa", 2.2, "¡Ay, %s se cansó de esperar!" % c.display_name)
	_advance_wave_or_finish()


func _complete_customer_order() -> void:
	if _wave.active_customer == null or _wave.round_ending:
		return
	var combo_val: int = _board.combo if _board != null else 0
	var res: Dictionary = _wave.complete_order(_state(), combo_val, crit_potion_lvl, get_node_level(&"encanto_mostrador"))
	var c: CustomerArchetypeData = res["customer"] as CustomerArchetypeData
	var bonus_gold: int = int(res["bonus_gold"])
	var aff_gain: int = int(res["aff_gain"])
	var crit: bool = bool(res["crit"])
	var leveled_up: bool = bool(res["leveled_up"])
	var new_aff_lvl: int = int(res["new_aff_lvl"])

	_grant_essence(bonus_gold)
	var b: Node = _bus()
	if b != null:
		b.emit_signal("customer_served", c.customer_id, bonus_gold, 1.5 if crit else 1.1, 1)

	if leveled_up and _hud != null:
		_hud.show_toast("💋 ¡Afinidad Nv.%d con %s! Escena desbloqueada en Galería." % [new_aff_lvl, c.display_name], 4.0)
		_set_trixie_reaction("sonrojada", 2.6, "¡A %s le encantó! Mira cómo se sonroja..." % c.display_name)
	elif crit and _hud != null:
		_hud.show_toast("💎 ¡POCIÓN CRÍTICA! +%d✦  +%d❤ Afinidad" % [bonus_gold, aff_gain], 2.5)
		_set_trixie_reaction("sorprendida", 2.2, "¡¿POCIÓN CRÍTICA?! ¡Hasta brilló el frasco entero!")
	elif _trixie_emotion != "sorprendida":
		var frenzy_on: bool = _board != null and _board.frenzy_timer > 0.0
		if frenzy_on or new_aff_lvl >= 2:
			_set_trixie_reaction("sonrojada", 1.8, "¡Mmm, %s quedó fascinada con ese elixir!" % c.display_name)
		else:
			_set_trixie_reaction("confiada", 1.6, "¡Elixir listo para %s! +%d✦" % [c.display_name, bonus_gold])

	_spawn_popup(Vector2(1620, 440), "¡ELIXIR LISTO! +%d✦  +%d❤" % [bonus_gold, aff_gain], Color(1.0, 0.78, 0.92))
	_set_customer_reaction("sonrojada", 3.0, String(res["done_line"]))
	_advance_wave_or_finish()


func _advance_wave_or_finish() -> void:
	if _wave.has_next_customer():
		_pick_customer_by_id(_wave.next_customer_id(), false)
	else:
		_trigger_stop_end(_wave.evaluate_wave_victory())


func _trigger_stop_end(victory: bool) -> void:
	if not _wave.trigger_stop_end(victory):
		return
	if _board != null:
		_board.reset_pointer_state()
	_play_pentatonic(6 if victory else 1, -2.0)
	if _hud != null and _hud.is_trixie_bubble_tutorial():
		_hud.hide_trixie_bubble(false)
	_set_trixie_reaction("confiada" if victory else "hollin", 2.2, "")


func _begin_closing_dialogue(victory: bool) -> void:
	if not _wave.begin_closing(victory):
		return
	if _board != null:
		_board.reset_pointer_state()
	if _hud != null:
		_hud.hide_trixie_bubble(true)
		_hud.hide_customer_bubble(true)
		_hud.set_cauldron_hud_visible(false)
		_hud.open_closing_overlay()
	_advance_closing_dialogue(true)


func _advance_closing_dialogue(animate_entrance: bool = false) -> void:
	var line_d: Dictionary = _wave.next_closing_line()
	if bool(line_d.get("done", false)):
		_finish_stop_and_fade_to_map()
		return
	var spk: String = String(line_d["speaker"])
	var emo: String = String(line_d["emotion"])
	var body_txt: String = String(line_d["text"])
	var speaker_name: String = "Trixie"
	var speaker_col: Color = Color(0.68, 0.14, 0.34)
	if spk == "customer":
		var cust_ref: CustomerArchetypeData = _wave.last_served_customer if _wave.last_served_customer != null else _wave.active_customer
		speaker_name = cust_ref.display_name if cust_ref != null else "Clienta"
		if _wave.last_served_customer != null:
			_wave.active_customer = _wave.last_served_customer
		speaker_col = Color(0.56, 0.12, 0.28)
		_set_customer_reaction(emo, 8.0, "")
	else:
		_set_trixie_reaction(emo, 8.0, "")
	if _hud != null:
		_hud.show_closing_line(speaker_name, speaker_col, body_txt, animate_entrance)


func _handle_closing_advance_input() -> void:
	if not _wave.closing_active or _fading_out:
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
	var stop_id: StringName = _wave.active_stop.get("id", &"castillo") as StringName
	if _wave.wave_victory:
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


func _set_trixie_reaction(emotion: String, dur: float, line: String) -> void:
	if emotion != _trixie_emotion or emotion in ["hollin", "sorprendida", "sonrojada"]:
		_trixie_react_anim = 1.0
	_trixie_emotion = emotion
	_trixie_emotion_timer = dur
	if line != "" and not _tutorial.active and not _wave.closing_active:
		_show_trixie_bubble("Trixie", line, clampf(dur, 2.4, 3.6), false, false)


func _set_customer_reaction(emotion: String, dur: float, line: String = "") -> void:
	var shown: String = _wave.set_customer_reaction(emotion, dur, line)
	if shown != "" and _hud != null:
		var cname: String = _wave.active_customer.display_name if _wave.active_customer != null else "Clienta"
		_hud.show_customer_bubble(cname, shown, clampf(dur, 2.4, 3.6))


func _show_trixie_bubble(title: String, text: String, duration: float, is_tutorial: bool = false, show_ack: bool = false) -> void:
	if _hud == null or _wave.closing_active or text == "":
		return
	if _tutorial.active and not is_tutorial:
		return
	_hud.show_trixie_bubble(title, text, duration, is_tutorial, show_ack)


func _show_customer_bubble(speaker_name: String, text: String, duration: float = 3.2) -> void:
	if _hud != null and not _wave.closing_active and text != "":
		_hud.show_customer_bubble(speaker_name, text, duration)


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


func _apply_stop_background() -> void:
	_stop_bg_tex = null
	if _bg_sprite == null:
		return
	var bg_path: String = String(_wave.active_stop.get("bg_path", ""))
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
		draw_rect(Rect2(0, 0, 1920, 1080), _wave.stop_bg_tint)

	CharacterArt.draw_trixie_halfbody(self, _trixie_stage_rect, _trixie_emotion, _time, 1.0, _trixie_react_anim)
	_draw_customer_stage_right()

	if _flask_view != null:
		var chem: Dictionary = get_customer_chemistry()
		var liked_col: Color = ChemistryRules.get_element_color(int(chem["liked"]))
		_flask_view.draw_potion_tube(self, _wave.potion_tube_pct, liked_col)
		if _wave.active_customer != null and _board != null:
			_flask_view.draw_order_bubble(self, chem, _time, _board.draw_mini_orb_badge)

	if _board != null:
		var broth_col: Color = _flask_view.broth_current_color if _flask_view != null else PotionFlaskView.BROTH_NEUTRAL_COLOR
		_board.draw_board(self, broth_col, _time, _tutorial, _wave.round_ending, _wave.closing_active)

	var font: Font = ThemeDB.fallback_font
	for p: Dictionary in _popups:
		var pos: Vector2 = p["pos"] as Vector2
		var txt: String = p["text"] as String
		var pcol: Color = p["color"] as Color
		var alpha: float = clampf(float(p["life"]), 0.0, 1.0)
		draw_string(font, pos + Vector2(2, 2), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(0.04, 0.02, 0.08, alpha))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(pcol.r, pcol.g, pcol.b, alpha))


func _draw_customer_stage_right() -> void:
	var slide_off: float = (1.0 - _wave.customer_slide_t) * 140.0
	var c: CustomerArchetypeData = _wave.active_customer
	if c == null:
		return
	if CharacterArt.has_customer_halfbody(c.customer_id):
		var stage: Rect2 = Rect2(_customer_stage_rect.position + Vector2(slide_off, 0.0), _customer_stage_rect.size)
		CharacterArt.draw_customer_halfbody(self, stage, c.customer_id, _wave.customer_emotion, _time, 1.0, _wave.customer_react_anim)
	else:
		var stage: Rect2 = Rect2(1408 + slide_off, 150, 486, 580)
		CharacterArt.draw_expressive_waifu_bust(self, stage, c.customer_id, _wave.customer_spicy_mode or _wave.customer_emotion == "sonrojada" or _wave.customer_flash_timer > 0.0, _time)


func _draw_chem_visual_strip() -> void:
	if _hud == null or _hud.chem_visual_canvas == null or _board == null:
		return
	var canvas: Control = _hud.chem_visual_canvas
	var chem: Dictionary = get_customer_chemistry()
	var liked_k: int = int(chem["liked"])
	var disliked_k: int = int(chem["disliked"])
	var font: Font = ThemeDB.fallback_font
	var cy: float = canvas.size.y * 0.5

	canvas.draw_string(font, Vector2(4.0, cy + 5.0), "PIDE:", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.55, 1.0, 0.68))
	_board.draw_mini_orb_badge(canvas, Vector2(72.0, cy), 17.0, liked_k, false)

	if ChemistryRules.is_mixed_kind(liked_k):
		var comps: Array[int] = ChemistryRules.get_recipe_components(liked_k)
		canvas.draw_string(font, Vector2(96.0, cy + 6.0), "=", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.92, 0.65))
		_board.draw_mini_orb_badge(canvas, Vector2(130.0, cy), 14.0, comps[0], false)
		canvas.draw_string(font, Vector2(150.0, cy + 6.0), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.92, 0.65))
		_board.draw_mini_orb_badge(canvas, Vector2(182.0, cy), 14.0, comps[1], false)
	else:
		var neutral_k: int = int(chem["neutral"])
		canvas.draw_string(font, Vector2(106.0, cy + 5.0), "OK:", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.84, 0.88, 0.96))
		_board.draw_mini_orb_badge(canvas, Vector2(152.0, cy), 14.0, neutral_k, false)

	canvas.draw_line(Vector2(276.0, 6.0), Vector2(276.0, canvas.size.y - 6.0), Color(1, 1, 1, 0.16), 2.0)
	canvas.draw_string(font, Vector2(294.0, cy + 5.0), "EVITA:", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.45, 0.50))
	_board.draw_mini_orb_badge(canvas, Vector2(374.0, cy), 17.0, disliked_k, true)


static func draw_expressive_waifu_bust(ci: CanvasItem, rect: Rect2, cid: StringName, spicy: bool, t: float) -> void:
	CharacterArt.draw_expressive_waifu_bust(ci, rect, cid, spicy, t)


func _refresh_hud_labels() -> void:
	if _hud == null:
		return
	var stop_icon: String = String(_wave.active_stop.get("icon", "📍"))
	var stop_name: String = String(_wave.active_stop.get("name", "Parada"))
	var shown_wave: int = mini(_wave.wave_index + 1, _wave.wave_customers.size())
	var cust_title: String = ""
	var aff_txt: String = ""
	if _wave.active_customer != null:
		var cid: StringName = _wave.active_customer.customer_id
		cust_title = "%s (%s)" % [_wave.active_customer.display_name, _wave.active_customer.species_archetype]
		aff_txt = "❤ Nv.%d · +%d✦" % [int(_state().get_affinity_level(cid)), _wave.customer_order_reward]
	var f_charge: float = _board.frenzy_charge if _board != null else 0.0
	var f_timer: float = _board.frenzy_timer if _board != null else 0.0
	_hud.refresh_status(
		essence_gold,
		stop_icon,
		stop_name,
		shown_wave,
		_wave.wave_customers.size(),
		_wave.wave_served_count,
		_wave.wave_missed_count,
		_wave.customer_patience_left,
		_wave.customer_patience_max,
		_is_patience_paused_for_tutorial(),
		WaveDirector.CUSTOMER_IMPATIENT_RATIO,
		f_charge,
		f_timer,
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


func run_incremental_smoke_step() -> Dictionary:
	return MainGameSmokeRunner.run(self)
