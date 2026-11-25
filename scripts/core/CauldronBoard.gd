class_name CauldronBoard
extends Node2D
## Tactical 2D alchemy cauldron board: manages orb spawning, motion, lift-and-drop
## combining, multi-hit cracking, right-click purging, chain sparks, bombs,
## Scarlet Frenzy transmutation, familiars, and cauldron rendering.

signal orb_lifted()
signal orb_hit_damaged(pos: Vector2, dmg_step: int, hits_left: int, by_player: bool)
signal orb_combined(res_kind: int, new_tier: int, is_star_boost: bool, is_same_merge: bool, final_pos: Vector2, star_ess: int)
signal orb_pigment_injected(kind: int, tier: int)
signal orb_shattered_disliked(pos: Vector2, kind: int, tier: int, penalty: float, severe_backfire: bool)
signal orb_shattered_good(pos: Vector2, kind: int, tier: int, rel: StringName, tube_gain: float, ess_gain: int, frenzy_just_ready: bool, combo: int)
signal orb_purged(pos: Vector2, rel: StringName, recycled_ess: int)
signal bomb_detonated(bpos: Vector2, hit_count: int)
signal frenzy_activated(transmuted_count: int, duration_sec: float)
signal bat_extracted(pos: Vector2, tube_pct: float, essence: int)

const ELLIPSE_RX: float = 296.0
const ELLIPSE_RY: float = 260.0
const CAULDRON_DRAW_SIZE: Vector2 = Vector2(840.0, 804.0)
const CAULDRON_HOLE_OFFSET: Vector2 = Vector2(419.0, 351.0)
const ORB_RADIUS: float = 34.0
const CAULDRON_TEX_PATH: String = "res://assets/props/stations/cauldron_main.png"
const ORB_TEX_DIR: String = "res://assets/props/items/orbs/"
const ORB_CANVAS_MULT: float = 1.067
const ORB_BOMB_DRAW_MULT: float = 1.467
const DRAG_LIFT_THRESHOLD: float = 12.0
const HOLD_HIT_START_DELAY: float = 0.16
const RIGHT_PURGE_HOLD_INTERVAL: float = 0.13
const BASE_ORB_HP: int = 3

@onready var _fire_glow: ColorRect = get_node_or_null("FireGlow") as ColorRect
@onready var _broth_layer: Node2D = get_node_or_null("BrothLayer") as Node2D
@onready var _cauldron_sprite: Sprite2D = get_node_or_null("CauldronSprite") as Sprite2D
@onready var _orbs_layer: Node2D = get_node_or_null("OrbsLayer") as Node2D
@onready var _combo_box: Control = get_node_or_null("ComboBox") as Control
@onready var _combo_value_lbl: Label = get_node_or_null("ComboBox/ComboValueLabel") as Label

var _fire_shader_mat: ShaderMaterial = null
var _cauldron_base_pos: Vector2 = Vector2.ZERO
var _render_broth_color: Color = Color(0.11, 0.09, 0.22)
var _render_time: float = 0.0
var _render_tutorial: TutorialDirector = null
var _render_round_ending: bool = false
var _render_closing_active: bool = false
var _frame_shake: Vector2 = Vector2.ZERO

var get_chemistry_fn: Callable = Callable()
var is_tube_empty_fn: Callable = Callable()

# Derived tactical stats pushed from GameState via MainGame
var spawn_cap: int = 6
var spawn_interval: float = 1.15
var hold_auto_hit_unlocked: bool = false
var hold_hit_interval: float = 0.36
var click_damage: int = 1
var strength_tube_bonus: float = 0.0
var aroma_essence_mult: float = 1.0
var stop_essence_mult: float = 1.0
var purge_recycle_lvl: int = 0
var frenzy_gain_mult: float = 1.0
var frenzy_duration_sec: float = 5.0
var chain_spark_jumps: int = 0
var bomb_chance: float = 0.0
var star_chance: float = 0.0
var fam_michi_lvl: int = 0
var fam_imp_lvl: int = 0
var fam_bat_lvl: int = 0

# Assets
var cauldron_tex: Texture2D = null
var orb_textures: Dictionary = {}
var crack_textures: Array[Texture2D] = []
var crack_glow_textures: Array[Texture2D] = []

# Runtime board state
var orbs: Array[Dictionary] = []
var lightning_arcs: Array[Dictionary] = []
var shockwaves: Array[Dictionary] = []
var ambient_steam: Array[Dictionary] = []

var cauldron_shake: float = 0.0
var combo: int = 0
var combo_timer: float = 0.0
var frenzy_charge: float = 0.0
var frenzy_timer: float = 0.0
var spawn_accum: float = 0.0
var michi_timer: float = 1.2
var imp_timer: float = 1.6
var bat_timer: float = 1.8
var disliked_mistake_streak: int = 0
var disliked_streak_timer: float = 0.0

var mouse_pos: Vector2 = Vector2(880.0, 564.0)
var next_orb_id: int = 1
var hovered_orb_id: int = -1
var left_down: bool = false
var pressed_orb_id: int = -1
var press_pos: Vector2 = Vector2.ZERO
var press_elapsed: float = 0.0
var is_lifting: bool = false
var lifted_orb_id: int = -1
var lift_hover_target_id: int = -1
var hold_hitting: bool = false
var hold_orb_id: int = -1
var hold_hit_accum: float = 0.0
var right_down: bool = false
var right_purge_accum: float = 0.0


func _ready() -> void:
	mouse_pos = get_center()
	if _cauldron_sprite != null:
		_cauldron_base_pos = _cauldron_sprite.position
		cauldron_tex = _cauldron_sprite.texture
		_cauldron_sprite.visible = true
	if cauldron_tex == null and ResourceLoader.exists(CAULDRON_TEX_PATH):
		cauldron_tex = load(CAULDRON_TEX_PATH) as Texture2D
		if _cauldron_sprite != null:
			_cauldron_sprite.texture = cauldron_tex
	if _fire_glow != null:
		_fire_shader_mat = _fire_glow.material as ShaderMaterial
	if _combo_box != null:
		_combo_box.visible = false
	if _broth_layer != null:
		_broth_layer.draw.connect(_on_broth_layer_draw)
	if _orbs_layer != null:
		_orbs_layer.draw.connect(_on_orbs_layer_draw)
	_load_orb_textures()
	for _i: int in range(20):
		ambient_steam.append({
			"x": randf_range(-ELLIPSE_RX * 0.78, ELLIPSE_RX * 0.78),
			"y": randf_range(-ELLIPSE_RY * 0.62, ELLIPSE_RY * 0.62),
			"r": randf_range(4.0, 12.0),
			"spd": randf_range(16.0, 34.0),
			"phase": randf_range(0.0, TAU),
		})


func _load_orb_textures() -> void:
	orb_textures.clear()
	crack_textures.clear()
	crack_glow_textures.clear()
	var orb_files: Dictionary = {
		ChemistryRules.BubbleKind.RED: "orb_red.png",
		ChemistryRules.BubbleKind.BLUE: "orb_blue.png",
		ChemistryRules.BubbleKind.GREEN: "orb_green.png",
		ChemistryRules.BubbleKind.YELLOW: "orb_yellow.png",
		ChemistryRules.BubbleKind.PURPLE: "orb_purple.png",
		ChemistryRules.BubbleKind.CYAN: "orb_cyan.png",
		ChemistryRules.BubbleKind.GOLD: "orb_gold.png",
		ChemistryRules.BubbleKind.BOMB: "orb_bomb.png",
	}
	for k_var: Variant in orb_files.keys():
		var k: int = int(k_var)
		var p: String = ORB_TEX_DIR + String(orb_files[k])
		if ResourceLoader.exists(p):
			var t: Texture2D = load(p) as Texture2D
			if t != null:
				orb_textures[k] = t

	for stage_idx: int in [1, 2]:
		var cp: String = "%sorb_crack_%d.png" % [ORB_TEX_DIR, stage_idx]
		var gp: String = "%sorb_crack_%d_glow.png" % [ORB_TEX_DIR, stage_idx]
		if ResourceLoader.exists(cp):
			var ct: Texture2D = load(cp) as Texture2D
			if ct != null:
				crack_textures.append(ct)
		if ResourceLoader.exists(gp):
			var gt: Texture2D = load(gp) as Texture2D
			if gt != null:
				crack_glow_textures.append(gt)


func get_center() -> Vector2:
	return position


func _chem() -> Dictionary:
	if get_chemistry_fn.is_valid():
		return get_chemistry_fn.call() as Dictionary
	return {
		"liked": ChemistryRules.BubbleKind.RED,
		"neutral": ChemistryRules.BubbleKind.GREEN,
		"disliked": ChemistryRules.BubbleKind.BLUE,
	}


func get_orb_relation(kind: int) -> StringName:
	return ChemistryRules.get_orb_relation(kind, _chem())


func get_effective_click_damage() -> int:
	return maxi(click_damage, 3) if frenzy_timer > 0.0 else click_damage


func reset_for_stop() -> void:
	disliked_mistake_streak = 0
	disliked_streak_timer = 0.0
	combo = 0
	combo_timer = 0.0
	frenzy_timer = 0.0
	spawn_accum = 0.0
	michi_timer = 1.6
	imp_timer = 2.0
	bat_timer = 2.2
	reset_pointer_state()
	orbs.clear()
	lightning_arcs.clear()
	shockwaves.clear()


func reset_pointer_state() -> void:
	left_down = false
	pressed_orb_id = -1
	press_elapsed = 0.0
	is_lifting = false
	lifted_orb_id = -1
	lift_hover_target_id = -1
	hold_hitting = false
	hold_orb_id = -1
	hold_hit_accum = 0.0
	right_down = false
	right_purge_accum = 0.0


func clamp_to_ellipse(pos: Vector2, inset: float) -> Vector2:
	var c: Vector2 = get_center()
	var rx: float = maxf(20.0, ELLIPSE_RX - inset)
	var ry: float = maxf(20.0, ELLIPSE_RY - inset)
	var rel: Vector2 = pos - c
	var norm_r2: float = (rel.x * rel.x) / (rx * rx) + (rel.y * rel.y) / (ry * ry)
	if norm_r2 <= 1.0:
		return pos
	return c + rel / sqrt(norm_r2)


func is_inside_ellipse(pos: Vector2, inset: float) -> bool:
	var c: Vector2 = get_center()
	var rx: float = maxf(20.0, ELLIPSE_RX - inset)
	var ry: float = maxf(20.0, ELLIPSE_RY - inset)
	var rel: Vector2 = pos - c
	return (rel.x * rel.x) / (rx * rx) + (rel.y * rel.y) / (ry * ry) <= 1.0


func get_orb_depth_scale(pos: Vector2) -> float:
	var ny: float = clampf((pos.y - get_center().y) / ELLIPSE_RY, -1.0, 1.0)
	return lerpf(0.93, 1.06, (ny + 1.0) * 0.5)


func step_ambient(delta: float) -> void:
	if cauldron_shake > 0.0:
		cauldron_shake = maxf(0.0, cauldron_shake - delta * 26.0)
	if disliked_streak_timer > 0.0:
		disliked_streak_timer = maxf(0.0, disliked_streak_timer - delta)
		if disliked_streak_timer <= 0.0:
			disliked_mistake_streak = 0
	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
	if frenzy_timer > 0.0:
		frenzy_timer = maxf(0.0, frenzy_timer - delta)
	for st: Dictionary in ambient_steam:
		st["y"] = float(st["y"]) - float(st["spd"]) * delta
		if float(st["y"]) < -ELLIPSE_RY * 0.74:
			st["y"] = ELLIPSE_RY * 0.66
			st["x"] = randf_range(-ELLIPSE_RX * 0.76, ELLIPSE_RX * 0.76)


func step_active(delta: float, time_sec: float = 0.0) -> void:
	if left_down:
		if is_lifting:
			var l_idx: int = find_orb_idx_by_id(lifted_orb_id)
			if l_idx != -1:
				lift_hover_target_id = find_merge_target_id(lifted_orb_id, orbs[l_idx]["pos"] as Vector2)
			else:
				is_lifting = false
				lifted_orb_id = -1
				lift_hover_target_id = -1
		elif pressed_orb_id != -1 and not hold_hitting:
			press_elapsed += delta
			if hold_auto_hit_unlocked and press_elapsed >= HOLD_HIT_START_DELAY:
				var p_idx: int = find_orb_idx_by_id(pressed_orb_id)
				if p_idx != -1:
					var opos: Vector2 = orbs[p_idx]["pos"] as Vector2
					var orad: float = float(orbs[p_idx]["radius"])
					if mouse_pos.distance_to(opos) <= orad + 28.0:
						hold_hitting = true
						hold_orb_id = pressed_orb_id
						hold_hit_accum = 0.0
						if hit_orb_by_id(hold_orb_id, get_effective_click_damage(), true):
							hold_orb_id = -1
		elif hold_hitting and hold_orb_id != -1:
			var h_idx: int = find_orb_idx_by_id(hold_orb_id)
			if h_idx == -1:
				hold_orb_id = -1
			else:
				var h_pos: Vector2 = orbs[h_idx]["pos"] as Vector2
				var h_rad: float = float(orbs[h_idx]["radius"])
				if mouse_pos.distance_to(h_pos) > h_rad + 36.0:
					hold_orb_id = -1
				else:
					hold_hit_accum += delta
					while hold_hit_accum >= hold_hit_interval:
						hold_hit_accum -= hold_hit_interval
						if hit_orb_by_id(hold_orb_id, get_effective_click_damage(), true):
							hold_orb_id = -1
							break

	if right_down:
		right_purge_accum += delta
		while right_purge_accum >= RIGHT_PURGE_HOLD_INTERVAL:
			right_purge_accum -= RIGHT_PURGE_HOLD_INTERVAL
			var r_id: int = find_orb_id_at(mouse_pos, 10.0, lifted_orb_id)
			if r_id != -1:
				purge_orb_by_id(r_id)

	spawn_accum += delta
	while spawn_accum >= spawn_interval:
		spawn_accum -= spawn_interval
		if orbs.size() < spawn_cap:
			spawn_orb(false)

	update_orbs_motion(delta)
	hovered_orb_id = -1 if is_lifting else find_orb_id_at(mouse_pos, 10.0, lifted_orb_id)
	update_familiars(delta, time_sec)
	update_vfx(delta)


func update_vfx(delta: float) -> void:
	var l_idx: int = 0
	while l_idx < lightning_arcs.size():
		lightning_arcs[l_idx]["life"] = float(lightning_arcs[l_idx]["life"]) - delta
		if float(lightning_arcs[l_idx]["life"]) <= 0.0:
			lightning_arcs.remove_at(l_idx)
			continue
		l_idx += 1

	var s_idx: int = 0
	while s_idx < shockwaves.size():
		var sw: Dictionary = shockwaves[s_idx]
		sw["life"] = float(sw["life"]) - delta
		var t: float = 1.0 - clampf(float(sw["life"]) / maxf(0.01, float(sw["max_life"])), 0.0, 1.0)
		sw["radius"] = lerpf(12.0, float(sw["max_radius"]), t)
		if float(sw["life"]) <= 0.0:
			shockwaves.remove_at(s_idx)
			continue
		s_idx += 1


func handle_mouse_button(mb: InputEventMouseButton, mpos: Vector2) -> bool:
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		var hit_id: int = find_orb_id_at(mpos, 10.0)
		if hit_id != -1:
			left_down = true
			pressed_orb_id = hit_id
			press_pos = mpos
			press_elapsed = 0.0
			is_lifting = false
			lifted_orb_id = -1
			lift_hover_target_id = -1
			hold_hitting = false
			hold_orb_id = -1
			hold_hit_accum = 0.0
			return true
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		right_down = true
		right_purge_accum = 0.0
		var r_id: int = find_orb_id_at(mpos, 10.0, lifted_orb_id)
		if r_id != -1:
			purge_orb_by_id(r_id)
			return true
	return false


func handle_mouse_motion(mpos: Vector2) -> bool:
	if not left_down:
		return false
	if is_lifting:
		var l_idx: int = find_orb_idx_by_id(lifted_orb_id)
		if l_idx != -1:
			var clamped_pos: Vector2 = clamp_to_ellipse(mpos, -18.0)
			orbs[l_idx]["pos"] = clamped_pos
			orbs[l_idx]["vel"] = Vector2.ZERO
			lift_hover_target_id = find_merge_target_id(lifted_orb_id, clamped_pos)
		else:
			is_lifting = false
			lifted_orb_id = -1
			lift_hover_target_id = -1
		return true
	elif hold_hitting:
		if hold_orb_id != -1:
			var h_idx: int = find_orb_idx_by_id(hold_orb_id)
			if h_idx == -1:
				hold_orb_id = -1
			else:
				var h_pos: Vector2 = orbs[h_idx]["pos"] as Vector2
				var h_rad: float = float(orbs[h_idx]["radius"])
				if mpos.distance_to(h_pos) > h_rad + 36.0:
					hold_orb_id = -1
	elif pressed_orb_id != -1 and mpos.distance_to(press_pos) > DRAG_LIFT_THRESHOLD:
		var p_idx: int = find_orb_idx_by_id(pressed_orb_id)
		if p_idx != -1 and int(orbs[p_idx]["kind"]) != ChemistryRules.BubbleKind.BOMB:
			is_lifting = true
			lifted_orb_id = pressed_orb_id
			var clamped_pos: Vector2 = clamp_to_ellipse(mpos, -18.0)
			orbs[p_idx]["pos"] = clamped_pos
			orbs[p_idx]["vel"] = Vector2.ZERO
			lift_hover_target_id = find_merge_target_id(lifted_orb_id, clamped_pos)
			orb_lifted.emit()
			return true
	return false


func on_left_mouse_released(mpos: Vector2, allow_gameplay: bool) -> void:
	if is_lifting and lifted_orb_id != -1 and allow_gameplay:
		var l_idx: int = find_orb_idx_by_id(lifted_orb_id)
		if l_idx != -1:
			var drop_pos: Vector2 = orbs[l_idx]["pos"] as Vector2
			var target_id: int = find_merge_target_id(lifted_orb_id, drop_pos)
			if target_id != -1:
				combine_orbs_by_id(lifted_orb_id, target_id)
			else:
				var r: float = float(orbs[l_idx]["radius"])
				orbs[l_idx]["pos"] = clamp_to_ellipse(drop_pos, r + 12.0)
				var ang: float = randf_range(0.0, TAU)
				orbs[l_idx]["vel"] = Vector2(cos(ang), sin(ang)) * randf_range(12.0, 22.0)
				orbs[l_idx]["scale_pop"] = 0.88
	elif not hold_hitting and pressed_orb_id != -1 and allow_gameplay:
		var p_idx: int = find_orb_idx_by_id(pressed_orb_id)
		if p_idx != -1:
			var opos: Vector2 = orbs[p_idx]["pos"] as Vector2
			var orad: float = float(orbs[p_idx]["radius"])
			if mpos.distance_to(opos) <= orad + 28.0:
				hit_orb_by_id(pressed_orb_id, get_effective_click_damage(), true)

	left_down = false
	pressed_orb_id = -1
	press_elapsed = 0.0
	is_lifting = false
	lifted_orb_id = -1
	lift_hover_target_id = -1
	hold_hitting = false
	hold_orb_id = -1
	hold_hit_accum = 0.0


func count_orbs_of_kind(target_kind: int) -> int:
	var c: int = 0
	for o: Dictionary in orbs:
		if int(o["kind"]) == target_kind:
			c += 1
	return c


func make_orb_dict(kind: int, pos: Vector2, tier: int = 1) -> Dictionary:
	var oid: int = next_orb_id
	next_orb_id += 1
	var clamped_tier: int = clampi(tier, 1, 3)
	var max_hp: int = 1 if kind == ChemistryRules.BubbleKind.BOMB else (2 if kind == ChemistryRules.BubbleKind.GOLD else (BASE_ORB_HP + (clamped_tier - 1)))
	var rad: float = ORB_RADIUS + (5.0 if ChemistryRules.is_mixed_kind(kind) else 0.0) + float(clamped_tier - 1) * 6.0
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


func setup_tutorial_initial_orbs() -> void:
	orbs.clear()
	var c: Vector2 = get_center()
	var ch: Dictionary = _chem()
	var liked_k: int = int(ch["liked"])
	var neutral_k: int = int(ch["neutral"])
	var disliked_k: int = int(ch["disliked"])
	var positions: Array[Vector2] = [
		c + Vector2(-125, -45),
		c + Vector2(125, -45),
		c + Vector2(-90, 95),
		c + Vector2(90, 95),
		c + Vector2(0, -145),
		c + Vector2(0, 145),
	]
	var kinds: Array[int] = [liked_k, liked_k, neutral_k, neutral_k, disliked_k, neutral_k]
	for i: int in range(mini(spawn_cap, positions.size())):
		orbs.append(make_orb_dict(kinds[i], positions[i], 1))


func ensure_tutorial_orb(target_kind: int) -> void:
	if count_orbs_of_kind(target_kind) > 0:
		return
	var pos: Vector2 = get_center() + Vector2(randf_range(-130.0, 130.0), randf_range(-110.0, 110.0))
	orbs.append(make_orb_dict(target_kind, pos, 1))


func ensure_mix_ingredients(liked_k: int) -> void:
	if not ChemistryRules.is_mixed_kind(liked_k):
		return
	var c: Vector2 = get_center()
	var comps: Array[int] = ChemistryRules.get_recipe_components(liked_k)
	if count_orbs_of_kind(comps[0]) == 0:
		orbs.append(make_orb_dict(comps[0], c + Vector2(-95, 10), 1))
	if count_orbs_of_kind(comps[1]) == 0:
		orbs.append(make_orb_dict(comps[1], c + Vector2(95, 10), 1))


func spawn_orb(avoid_disliked: bool) -> void:
	var chem: Dictionary = _chem()
	var liked_k: int = int(chem["liked"])
	var neutral_k: int = int(chem["neutral"])
	var disliked_k: int = int(chem["disliked"])

	var kind: int = liked_k
	var roll: float = randf()
	if roll < star_chance:
		kind = ChemistryRules.BubbleKind.GOLD
	elif roll < star_chance + bomb_chance:
		kind = ChemistryRules.BubbleKind.BOMB
	elif ChemistryRules.is_mixed_kind(liked_k):
		var comps: Array[int] = ChemistryRules.get_recipe_components(liked_k)
		var c0: int = comps[0]
		var c1: int = comps[1]
		var have_mixed: int = count_orbs_of_kind(liked_k)
		var have_c0: int = count_orbs_of_kind(c0)
		var have_c1: int = count_orbs_of_kind(c1)
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
	elif count_orbs_of_kind(liked_k) < 2:
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

	var c: Vector2 = get_center()
	var pos: Vector2 = c
	var max_rx: float = maxf(24.0, ELLIPSE_RX - ORB_RADIUS - 22.0)
	var max_ry: float = maxf(24.0, ELLIPSE_RY - ORB_RADIUS - 22.0)
	for _attempt: int in range(12):
		var ang: float = randf_range(0.0, TAU)
		var dist: float = sqrt(randf())
		var cand: Vector2 = c + Vector2(cos(ang) * max_rx, sin(ang) * max_ry) * dist
		var clear: bool = true
		for o: Dictionary in orbs:
			if cand.distance_to(o["pos"] as Vector2) < ORB_RADIUS * 2.25:
				clear = false
				break
		pos = cand
		if clear:
			break

	orbs.append(make_orb_dict(kind, pos, 1))


func update_orbs_motion(delta: float) -> void:
	var c: Vector2 = get_center()
	for i: int in range(orbs.size()):
		var o: Dictionary = orbs[i]
		o["scale_pop"] = lerpf(float(o["scale_pop"]), 1.0, clampf(delta * 10.0, 0.0, 1.0))
		o["hit_flash"] = maxf(0.0, float(o["hit_flash"]) - delta * 6.5)
		o["hit_wobble"] = maxf(0.0, float(o["hit_wobble"]) - delta * 7.5)
		if int(o["id"]) == lifted_orb_id:
			continue

		var rad: float = float(o["radius"])
		var lim_x: float = maxf(20.0, ELLIPSE_RX - rad - 12.0)
		var lim_y: float = maxf(20.0, ELLIPSE_RY - rad - 12.0)
		var pos: Vector2 = o["pos"] as Vector2
		var vel: Vector2 = o["vel"] as Vector2
		pos += vel * delta

		var rel: Vector2 = pos - c
		var norm_r2: float = (rel.x * rel.x) / (lim_x * lim_x) + (rel.y * rel.y) / (lim_y * lim_y)
		if norm_r2 > 1.0:
			var scale_back: float = 1.0 / sqrt(norm_r2)
			rel *= scale_back
			pos = c + rel
			var n: Vector2 = Vector2(rel.x / (lim_x * lim_x), rel.y / (lim_y * lim_y)).normalized()
			vel = vel.bounce(n)

		o["pos"] = pos
		o["vel"] = vel

	for i: int in range(orbs.size()):
		if int(orbs[i]["id"]) == lifted_orb_id:
			continue
		for j: int in range(i + 1, orbs.size()):
			if int(orbs[j]["id"]) == lifted_orb_id:
				continue
			var pi: Vector2 = orbs[i]["pos"] as Vector2
			var pj: Vector2 = orbs[j]["pos"] as Vector2
			var diff: Vector2 = pj - pi
			var d: float = diff.length()
			var min_d: float = (float(orbs[i]["radius"]) + float(orbs[j]["radius"])) * 1.08
			if d > 0.01 and d < min_d:
				var push: Vector2 = diff.normalized() * (min_d - d) * 0.5 * clampf(delta * 8.0, 0.0, 1.0)
				orbs[i]["pos"] = pi - push
				orbs[j]["pos"] = pj + push


func find_orb_idx_by_id(oid: int) -> int:
	if oid == -1:
		return -1
	for i: int in range(orbs.size()):
		if int(orbs[i]["id"]) == oid:
			return i
	return -1


func find_orb_id_at(pos: Vector2, extra_pad: float = 8.0, exclude_id: int = -1) -> int:
	for i: int in range(orbs.size() - 1, -1, -1):
		var oid: int = int(orbs[i]["id"])
		if oid == exclude_id:
			continue
		var opos: Vector2 = orbs[i]["pos"] as Vector2
		var orad: float = float(orbs[i]["radius"])
		if pos.distance_to(opos) <= orad + extra_pad:
			return oid
	return -1


func can_combine_orbs(a: Dictionary, b: Dictionary) -> bool:
	var ak: int = int(a["kind"])
	var bk: int = int(b["kind"])
	if ChemistryRules.get_combine_result(ak, bk) == -1:
		return false
	if ak == bk and ak != ChemistryRules.BubbleKind.GOLD:
		return maxi(int(a["tier"]), int(b["tier"])) < 3
	if ak == ChemistryRules.BubbleKind.GOLD and bk != ChemistryRules.BubbleKind.GOLD:
		return int(b["tier"]) < 3 or int(b["hp"]) > 1
	if bk == ChemistryRules.BubbleKind.GOLD and ak != ChemistryRules.BubbleKind.GOLD:
		return int(a["tier"]) < 3 or int(a["hp"]) > 1
	return true


func find_merge_target_id(lifted_id: int, pos: Vector2) -> int:
	var l_idx: int = find_orb_idx_by_id(lifted_id)
	if l_idx == -1:
		return -1
	var lifted: Dictionary = orbs[l_idx]
	var lifted_r: float = float(lifted["radius"])
	var best_id: int = -1
	var best_dist: float = 999999.0
	for o: Dictionary in orbs:
		var oid: int = int(o["id"])
		if oid == lifted_id:
			continue
		if not can_combine_orbs(lifted, o):
			continue
		var opos: Vector2 = o["pos"] as Vector2
		var orad: float = float(o["radius"])
		var d: float = pos.distance_to(opos)
		if d <= orad + lifted_r * 0.78 and d < best_dist:
			best_dist = d
			best_id = oid
	return best_id


func combine_orbs_by_id(src_id: int, dst_id: int) -> bool:
	if src_id == dst_id:
		return false
	var s_idx: int = find_orb_idx_by_id(src_id)
	var d_idx: int = find_orb_idx_by_id(dst_id)
	if s_idx == -1 or d_idx == -1:
		return false
	var src: Dictionary = orbs[s_idx]
	var dst: Dictionary = orbs[d_idx]
	if not can_combine_orbs(src, dst):
		return false

	var sk: int = int(src["kind"])
	var dk: int = int(dst["kind"])
	var stier: int = int(src["tier"])
	var dtier: int = int(dst["tier"])
	var dpos: Vector2 = dst["pos"] as Vector2
	var res_kind: int = ChemistryRules.get_combine_result(sk, dk)
	if res_kind == -1:
		return false

	var is_star_boost: bool = (sk == ChemistryRules.BubbleKind.GOLD or dk == ChemistryRules.BubbleKind.GOLD) and not (sk == ChemistryRules.BubbleKind.GOLD and dk == ChemistryRules.BubbleKind.GOLD)
	var is_same_merge: bool = (sk == dk)
	var new_tier: int = 1
	if is_star_boost:
		var base_tier: int = dtier if sk == ChemistryRules.BubbleKind.GOLD else stier
		new_tier = mini(3, base_tier + 1)
	elif is_same_merge:
		new_tier = mini(3, maxi(stier, dtier) + 1)
	else:
		new_tier = mini(3, maxi(stier, dtier))

	var new_hp: int = 1 if is_star_boost else (2 if res_kind == ChemistryRules.BubbleKind.GOLD else (BASE_ORB_HP + (new_tier - 1)))
	var new_rad: float = ORB_RADIUS + (5.0 if ChemistryRules.is_mixed_kind(res_kind) else 0.0) + float(new_tier - 1) * 6.0

	dst["kind"] = res_kind
	dst["tier"] = new_tier
	dst["max_hp"] = new_hp
	dst["hp"] = new_hp
	dst["radius"] = new_rad
	dst["scale_pop"] = 1.38
	dst["hit_flash"] = 0.85
	dst["hit_wobble"] = 0.0
	dst["pos"] = clamp_to_ellipse(dpos, new_rad + 12.0)

	orbs.remove_at(s_idx)
	var final_pos: Vector2 = dst["pos"] as Vector2

	lightning_arcs.append({
		"from": src["pos"] as Vector2,
		"to": final_pos,
		"color": Color(1.0, 0.88, 0.38),
		"life": 0.24,
		"max_life": 0.24,
	})
	shockwaves.append({
		"pos": final_pos,
		"radius": 14.0,
		"max_radius": 92.0,
		"color": ChemistryRules.get_element_color(res_kind),
		"life": 0.30,
		"max_life": 0.30,
	})
	if combo > 0:
		combo_timer = 5.0

	var star_ess: int = int(roundf(10.0 * aroma_essence_mult * stop_essence_mult)) if is_star_boost else 0
	orb_combined.emit(res_kind, new_tier, is_star_boost, is_same_merge, final_pos, star_ess)
	return true


func hit_orb_by_id(orb_id: int, dmg: int, by_player: bool = true) -> bool:
	var idx: int = find_orb_idx_by_id(orb_id)
	if idx == -1:
		return false
	var o: Dictionary = orbs[idx]
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
		cauldron_shake = maxf(cauldron_shake, 2.5)
		shockwaves.append({
			"pos": pos,
			"radius": 8.0,
			"max_radius": 44.0,
			"color": ChemistryRules.get_element_color(kind).lightened(0.25),
			"life": 0.16,
			"max_life": 0.16,
		})
		var hits_left: int = ceili(float(new_hp) / float(maxi(1, get_effective_click_damage())))
		orb_hit_damaged.emit(pos, dmg_step, hits_left, by_player)
		return false

	_shatter_orb_at_idx(idx, by_player)
	return true


func _shatter_orb_at_idx(idx: int, _by_player: bool = true) -> void:
	if idx < 0 or idx >= orbs.size():
		return
	var snap: Dictionary = orbs[idx].duplicate()
	var oid: int = int(snap["id"])
	if hold_orb_id == oid:
		hold_orb_id = -1
	if pressed_orb_id == oid:
		pressed_orb_id = -1
	if lifted_orb_id == oid:
		lifted_orb_id = -1
		is_lifting = false
	orbs.remove_at(idx)

	var pos: Vector2 = snap["pos"] as Vector2
	var kind: int = int(snap["kind"])
	var tier: int = int(snap["tier"])
	var rel: StringName = get_orb_relation(kind)
	orb_pigment_injected.emit(kind, tier)
	var frenzy_mult: float = 2.0 if frenzy_timer > 0.0 else 1.0
	var tier_mult: float = 1.0 if tier <= 1 else (2.3 if tier == 2 else 4.2)

	shockwaves.append({
		"pos": pos,
		"radius": 14.0,
		"max_radius": 88.0 if tier >= 2 or ChemistryRules.is_mixed_kind(kind) else 66.0,
		"color": ChemistryRules.get_element_color(kind),
		"life": 0.30,
		"max_life": 0.30,
	})

	if rel == &"disliked":
		var prev_combo: int = combo
		var penalty: float = 18.0
		combo = 0
		disliked_mistake_streak += 1
		disliked_streak_timer = 7.0
		var tube_empty: bool = is_tube_empty_fn.is_valid() and bool(is_tube_empty_fn.call(penalty))
		var severe_backfire: bool = prev_combo >= 2 or disliked_mistake_streak >= 2 or tube_empty
		if severe_backfire:
			cauldron_shake = maxf(cauldron_shake, 14.0)
			shockwaves.append({
				"pos": pos,
				"radius": 16.0,
				"max_radius": 115.0,
				"color": Color(0.24, 0.20, 0.28),
				"life": 0.42,
				"max_life": 0.42,
			})
		else:
			cauldron_shake = maxf(cauldron_shake, 10.0)
		orb_shattered_disliked.emit(pos, kind, tier, penalty, severe_backfire)
		return

	var tube_gain: float = 0.0
	var ess_gain: int = 0
	var frenzy_add: float = 0.0

	if kind == ChemistryRules.BubbleKind.GOLD:
		tube_gain = 22.0 * tier_mult * frenzy_mult
		ess_gain = int(roundf(15.0 * 5.0 * tier_mult * aroma_essence_mult * stop_essence_mult * frenzy_mult))
		combo += 1
		combo_timer = 5.0
		frenzy_add = 22.0 * frenzy_gain_mult
	elif kind == ChemistryRules.BubbleKind.BOMB:
		ess_gain = int(roundf(8.0 * aroma_essence_mult * stop_essence_mult * frenzy_mult))
		frenzy_add = 12.0 * frenzy_gain_mult
	elif rel == &"liked":
		var base_tube: float = 42.0 if ChemistryRules.is_mixed_kind(kind) else 24.0
		var base_ess: float = 14.0 if ChemistryRules.is_mixed_kind(kind) else 7.0
		tube_gain = base_tube * (1.0 + strength_tube_bonus) * tier_mult * frenzy_mult
		ess_gain = int(roundf(base_ess * tier_mult * aroma_essence_mult * stop_essence_mult * frenzy_mult))
		combo += tier
		combo_timer = 5.0
		frenzy_add = (24.0 if ChemistryRules.is_mixed_kind(kind) else 18.0) * tier_mult * frenzy_gain_mult
	else:
		tube_gain = 8.0 * tier_mult * (1.0 + strength_tube_bonus * 0.5) * frenzy_mult
		ess_gain = int(roundf(3.0 * tier_mult * aroma_essence_mult * stop_essence_mult * frenzy_mult))
		combo_timer = 5.0
		if tier >= 2:
			combo += 1

	var prev_frenzy: float = frenzy_charge
	if frenzy_add > 0.0 and frenzy_timer <= 0.0:
		frenzy_charge = minf(100.0, frenzy_charge + frenzy_add)
	var frenzy_just_ready: bool = prev_frenzy < 100.0 and frenzy_charge >= 100.0 and frenzy_timer <= 0.0

	if rel == &"liked" or kind == ChemistryRules.BubbleKind.GOLD:
		disliked_mistake_streak = 0
		disliked_streak_timer = 0.0

	orb_shattered_good.emit(pos, kind, tier, rel, tube_gain, ess_gain, frenzy_just_ready, combo)

	if chain_spark_jumps > 0 and (rel == &"liked" or tier >= 2):
		_trigger_chain_spark_zaps(pos, chain_spark_jumps)

	if kind == ChemistryRules.BubbleKind.BOMB:
		_detonate_alchemy_bomb(pos)


func _trigger_chain_spark_zaps(origin: Vector2, jumps: int) -> void:
	var target_ids: Array[int] = []
	for o: Dictionary in orbs:
		var oid: int = int(o["id"])
		if oid == lifted_orb_id:
			continue
		var rel: StringName = get_orb_relation(int(o["kind"]))
		if rel == &"liked" or rel == &"ingredient" or int(o["kind"]) == ChemistryRules.BubbleKind.GOLD:
			if (o["pos"] as Vector2).distance_to(origin) <= 270.0:
				target_ids.append(oid)
				if target_ids.size() >= jumps:
					break
	for tid: int in target_ids:
		var tidx: int = find_orb_idx_by_id(tid)
		if tidx != -1:
			lightning_arcs.append({
				"from": origin,
				"to": orbs[tidx]["pos"] as Vector2,
				"color": Color(0.36, 0.96, 1.0),
				"life": 0.25,
				"max_life": 0.25,
			})
			hit_orb_by_id(tid, maxi(get_effective_click_damage(), 2), false)


func _detonate_alchemy_bomb(bpos: Vector2) -> void:
	cauldron_shake = maxf(cauldron_shake, 11.0)
	shockwaves.append({
		"pos": bpos,
		"radius": 18.0,
		"max_radius": 185.0,
		"color": Color(0.88, 0.42, 1.0),
		"life": 0.38,
		"max_life": 0.38,
	})
	var target_ids: Array[int] = []
	for o: Dictionary in orbs:
		var oid: int = int(o["id"])
		if oid == lifted_orb_id:
			continue
		if (o["pos"] as Vector2).distance_to(bpos) <= 185.0:
			if get_orb_relation(int(o["kind"])) != &"disliked":
				target_ids.append(oid)
	if not target_ids.is_empty():
		bomb_detonated.emit(bpos, target_ids.size())
		for tid: int in target_ids:
			hit_orb_by_id(tid, 3, false)


func purge_orb_by_id(orb_id: int) -> void:
	var idx: int = find_orb_idx_by_id(orb_id)
	if idx == -1:
		return
	var o: Dictionary = orbs[idx]
	var pos: Vector2 = o["pos"] as Vector2
	var rel: StringName = get_orb_relation(int(o["kind"]))
	if hold_orb_id == orb_id:
		hold_orb_id = -1
	if pressed_orb_id == orb_id:
		pressed_orb_id = -1
	orbs.remove_at(idx)

	shockwaves.append({
		"pos": pos,
		"radius": 10.0,
		"max_radius": 52.0,
		"color": Color(0.75, 0.78, 0.90),
		"life": 0.22,
		"max_life": 0.22,
	})

	var rec_ess: int = 0
	if purge_recycle_lvl > 0:
		rec_ess = (6 if rel == &"disliked" else 3) * purge_recycle_lvl
		if orbs.size() < spawn_cap:
			spawn_orb(true)

	orb_purged.emit(pos, rel, rec_ess)


func try_activate_frenzy(round_ending: bool, closing_active: bool) -> bool:
	if frenzy_charge < 100.0 or frenzy_timer > 0.0 or round_ending or closing_active:
		return false
	frenzy_charge = 0.0
	frenzy_timer = frenzy_duration_sec
	cauldron_shake = maxf(cauldron_shake, 12.0)

	var liked_k: int = int(_chem()["liked"])
	var transmuted: int = 0
	for o: Dictionary in orbs:
		if get_orb_relation(int(o["kind"])) == &"disliked":
			o["kind"] = liked_k
			o["hp"] = 1
			o["radius"] = ORB_RADIUS + (5.0 if ChemistryRules.is_mixed_kind(liked_k) else 0.0) + float(int(o["tier"]) - 1) * 6.0
			o["scale_pop"] = 1.32
			o["hit_flash"] = 0.75
			transmuted += 1
			shockwaves.append({
				"pos": o["pos"] as Vector2,
				"radius": 10.0,
				"max_radius": 68.0,
				"color": Color(1.0, 0.86, 0.34),
				"life": 0.35,
				"max_life": 0.35,
			})

	frenzy_activated.emit(transmuted, frenzy_timer)
	return true


func update_familiars(delta: float, time_sec: float = 0.0) -> void:
	if fam_michi_lvl > 0 and not orbs.is_empty():
		michi_timer -= delta
		if michi_timer <= 0.0:
			michi_timer = maxf(1.05, 2.5 - float(fam_michi_lvl - 1) * 0.32)
			var struck: bool = false
			for o: Dictionary in orbs:
				var oid: int = int(o["id"])
				if oid == lifted_orb_id:
					continue
				var rel: StringName = get_orb_relation(int(o["kind"]))
				if rel == &"liked" or int(o["kind"]) == ChemistryRules.BubbleKind.GOLD:
					lightning_arcs.append({
						"from": get_michi_pos(time_sec),
						"to": o["pos"] as Vector2,
						"color": Color(1.0, 0.72, 0.92),
						"life": 0.20,
						"max_life": 0.20,
					})
					hit_orb_by_id(oid, maxi(click_damage, 2), false)
					struck = true
					break
			if not struck:
				var liked_k: int = int(_chem()["liked"])
				if ChemistryRules.is_mixed_kind(liked_k):
					var comps: Array[int] = ChemistryRules.get_recipe_components(liked_k)
					var id_a: int = -1
					var id_b: int = -1
					for o: Dictionary in orbs:
						var oid: int = int(o["id"])
						if oid == lifted_orb_id:
							continue
						if id_a == -1 and int(o["kind"]) == comps[0]:
							id_a = oid
						elif id_b == -1 and int(o["kind"]) == comps[1]:
							id_b = oid
					if id_a != -1 and id_b != -1:
						combine_orbs_by_id(id_a, id_b)

	if fam_imp_lvl > 0 and not orbs.is_empty():
		imp_timer -= delta
		if imp_timer <= 0.0:
			imp_timer = maxf(1.2, 2.9 - float(fam_imp_lvl - 1) * 0.35)
			for o: Dictionary in orbs:
				var oid: int = int(o["id"])
				if oid == lifted_orb_id:
					continue
				if get_orb_relation(int(o["kind"])) == &"disliked":
					lightning_arcs.append({
						"from": get_imp_pos(time_sec),
						"to": o["pos"] as Vector2,
						"color": Color(1.0, 0.45, 0.28),
						"life": 0.20,
						"max_life": 0.20,
					})
					purge_orb_by_id(oid)
					break

	if fam_bat_lvl > 0:
		bat_timer -= delta
		if bat_timer <= 0.0:
			bat_timer = maxf(1.0, 2.4 - float(fam_bat_lvl - 1) * 0.30)
			var ess: int = int(roundf(float(4 + fam_bat_lvl * 3) * stop_essence_mult))
			var pct: float = 3.0 + float(fam_bat_lvl) * 1.5
			bat_extracted.emit(get_bat_pos(time_sec), pct, ess)


func get_michi_pos(time_sec: float) -> Vector2:
	return get_center() + Vector2(cos(time_sec * 1.2) * 235.0, sin(time_sec * 1.2) * 185.0)


func get_imp_pos(time_sec: float) -> Vector2:
	return get_center() + Vector2(cos(-time_sec * 1.05 + 2.2) * 245.0, sin(-time_sec * 1.05 + 2.2) * 195.0)


func get_bat_pos(time_sec: float) -> Vector2:
	return get_center() + Vector2(cos(time_sec * 1.5 + 4.1) * 290.0, -255.0 + sin(time_sec * 3.0) * 18.0)


static func _draw_filled_ellipse(ci: CanvasItem, center: Vector2, rx: float, ry: float, col: Color) -> void:
	ci.draw_set_transform(center, 0.0, Vector2(1.0, ry / maxf(1.0, rx)))
	ci.draw_circle(Vector2.ZERO, rx, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _draw_ellipse_arc(ci: CanvasItem, center: Vector2, rx: float, ry: float, start_a: float, end_a: float, col: Color, width: float) -> void:
	ci.draw_set_transform(center, 0.0, Vector2(1.0, ry / maxf(1.0, rx)))
	ci.draw_arc(Vector2.ZERO, rx, start_a, end_a, 48, col, width)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func get_shake_offset() -> Vector2:
	if cauldron_shake > 0.2:
		return Vector2(randf_range(-cauldron_shake, cauldron_shake), randf_range(-cauldron_shake, cauldron_shake))
	return Vector2.ZERO


func set_frenzy_visual(mix: float) -> void:
	if _fire_shader_mat != null:
		_fire_shader_mat.set_shader_parameter("frenzy_amount", mix)


func sync_visuals(broth_current_color: Color, time_sec: float, tutorial: TutorialDirector, round_ending: bool, closing_active: bool) -> void:
	_render_broth_color = broth_current_color
	_render_time = time_sec
	_render_tutorial = tutorial
	_render_round_ending = round_ending
	_render_closing_active = closing_active
	_frame_shake = get_shake_offset()

	if _cauldron_sprite != null:
		_cauldron_sprite.position = _cauldron_base_pos + _frame_shake
	if _combo_box != null:
		var show_combo: bool = (combo > 0 and not closing_active)
		_combo_box.visible = show_combo
		if show_combo and _combo_value_lbl != null:
			_combo_value_lbl.text = "x%d!" % combo
	if _broth_layer != null:
		_broth_layer.queue_redraw()
	if _orbs_layer != null:
		_orbs_layer.queue_redraw()


func _on_broth_layer_draw() -> void:
	if _broth_layer == null:
		return
	var ci: CanvasItem = _broth_layer
	var c_pos: Vector2 = _frame_shake
	var liq_col: Color = _render_broth_color.lightened(0.08 + 0.04 * sin(_render_time * 8.0)) if frenzy_timer > 0.0 else _render_broth_color
	_draw_filled_ellipse(ci, c_pos, ELLIPSE_RX * 1.035, ELLIPSE_RY * 1.035, liq_col)
	_draw_filled_ellipse(ci, c_pos + Vector2(0.0, 16.0), ELLIPSE_RX * 0.93, ELLIPSE_RY * 0.89, liq_col.lightened(0.10))
	var ripple_base: Color = liq_col.lightened(0.48)
	var ripple_col: Color = Color(1.0, 0.45, 0.78, 0.52) if frenzy_timer > 0.0 else Color(ripple_base.r, ripple_base.g, ripple_base.b, 0.30)
	_draw_ellipse_arc(ci, c_pos + Vector2(0.0, 10.0), ELLIPSE_RX * 0.84, ELLIPSE_RY * 0.80, _render_time * 0.32, _render_time * 0.32 + TAU * 0.55, ripple_col, 2.5)
	_draw_ellipse_arc(ci, c_pos + Vector2(0.0, 10.0), ELLIPSE_RX * 0.62, ELLIPSE_RY * 0.58, -_render_time * 0.24, -_render_time * 0.24 + TAU * 0.45, Color(ripple_col.r, ripple_col.g, ripple_col.b, ripple_col.a * 0.75), 2.0)

	var steam_base: Color = liq_col.lightened(0.56)
	for st: Dictionary in ambient_steam:
		var world_spos: Vector2 = get_center() + Vector2(float(st["x"]), float(st["y"]))
		if is_inside_ellipse(world_spos, 18.0):
			var spos: Vector2 = c_pos + Vector2(float(st["x"]), float(st["y"]))
			var a: float = 0.10 + 0.08 * sin(_render_time * 2.0 + float(st["phase"]))
			ci.draw_circle(spos, float(st["r"]), Color(steam_base.r, steam_base.g, steam_base.b, a))


func _on_orbs_layer_draw() -> void:
	if _orbs_layer == null:
		return
	var ci: CanvasItem = _orbs_layer
	var draw_off: Vector2 = -position + _frame_shake
	var time_sec: float = _render_time
	var font: Font = ThemeDB.fallback_font

	# Layer 4: Orbs Y-sorted with subtle depth scale
	var sorted_orbs: Array[Dictionary] = []
	for o: Dictionary in orbs:
		if int(o["id"]) == lifted_orb_id:
			continue
		sorted_orbs.append(o)
	sorted_orbs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float((a["pos"] as Vector2).y) < float((b["pos"] as Vector2).y)
	)
	for o: Dictionary in sorted_orbs:
		draw_alchemy_orb(ci, o, draw_off, false, time_sec)

	if is_lifting and lifted_orb_id != -1:
		var l_idx: int = find_orb_idx_by_id(lifted_orb_id)
		if l_idx != -1:
			var l_orb: Dictionary = orbs[l_idx]
			var l_pos: Vector2 = (l_orb["pos"] as Vector2) + draw_off
			var l_rad: float = float(l_orb["radius"]) * float(l_orb["scale_pop"]) * 1.16
			if lift_hover_target_id != -1:
				var t_idx: int = find_orb_idx_by_id(lift_hover_target_id)
				if t_idx != -1:
					var t_orb: Dictionary = orbs[t_idx]
					var t_pos: Vector2 = (t_orb["pos"] as Vector2) + draw_off
					var t_rad: float = float(t_orb["radius"])
					var pulse: float = 0.5 + 0.5 * sin(time_sec * 9.0)
					ci.draw_arc(t_pos, t_rad + 12.0 + pulse * 4.0, 0.0, TAU, 32, Color(0.45, 0.96, 1.0, 0.95), 4.0)
					var sk: int = int(l_orb["kind"])
					var dk: int = int(t_orb["kind"])
					var res_k: int = ChemistryRules.get_combine_result(sk, dk)
					var preview_txt: String = ""
					if sk == ChemistryRules.BubbleKind.GOLD or dk == ChemistryRules.BubbleKind.GOLD:
						var nt: int = mini(3, (int(t_orb["tier"]) if sk == ChemistryRules.BubbleKind.GOLD else int(l_orb["tier"])) + 1)
						preview_txt = "⭐ + %s -> x%d!" % [ChemistryRules.get_element_glyph(res_k), nt]
					elif sk == dk:
						var nt: int = mini(3, maxi(int(l_orb["tier"]), int(t_orb["tier"])) + 1)
						preview_txt = "%s + %s -> x%d!" % [ChemistryRules.get_element_glyph(sk), ChemistryRules.get_element_glyph(dk), nt]
					else:
						preview_txt = "%s + %s -> %s" % [ChemistryRules.get_element_glyph(sk), ChemistryRules.get_element_glyph(dk), ChemistryRules.get_element_name(res_k)]
					ci.draw_string(font, t_pos + Vector2(-115, -t_rad - 20.0), preview_txt, HORIZONTAL_ALIGNMENT_CENTER, 230, 17, Color(1.0, 0.95, 0.58))
			ci.draw_circle(l_pos + Vector2(6.0, 16.0), l_rad * 0.92, Color(0.0, 0.0, 0.0, 0.42))
			draw_alchemy_orb(ci, l_orb, draw_off, true, time_sec)

	if _render_tutorial != null:
		_render_tutorial.draw_orb_guide(
			ci,
			orbs,
			lifted_orb_id,
			_chem(),
			get_orb_relation,
			ORB_RADIUS,
			draw_off,
			time_sec,
			font,
			_render_round_ending,
			_render_closing_active
		)

	for sw: Dictionary in shockwaves:
		var alpha: float = clampf(float(sw["life"]) / maxf(0.01, float(sw["max_life"])), 0.0, 1.0)
		var scol: Color = sw["color"] as Color
		ci.draw_arc((sw["pos"] as Vector2) + draw_off, float(sw["radius"]), 0.0, TAU, 36, Color(scol.r, scol.g, scol.b, alpha * 0.85), 4.5 * alpha)

	for arc: Dictionary in lightning_arcs:
		var alpha: float = clampf(float(arc["life"]) / maxf(0.01, float(arc["max_life"])), 0.0, 1.0)
		var acol: Color = arc["color"] as Color
		var p0: Vector2 = (arc["from"] as Vector2) + draw_off
		var p1: Vector2 = (arc["to"] as Vector2) + draw_off
		var mid: Vector2 = (p0 + p1) * 0.5 + Vector2(randf_range(-14, 14), randf_range(-14, 14))
		ci.draw_polyline(PackedVector2Array([p0, mid, p1]), Color(acol.r, acol.g, acol.b, alpha), 3.8)

	if fam_michi_lvl > 0:
		var mp: Vector2 = get_michi_pos(time_sec) + draw_off
		ci.draw_circle(mp, 21.0, Color(1.0, 0.72, 0.92, 0.28))
		ci.draw_circle(mp, 14.0, Color(1.0, 0.86, 0.95))
		ci.draw_colored_polygon(PackedVector2Array([mp + Vector2(-10, -8), mp + Vector2(-14, -20), mp + Vector2(-3, -12)]), Color(0.95, 0.62, 0.85))
		ci.draw_colored_polygon(PackedVector2Array([mp + Vector2(10, -8), mp + Vector2(14, -20), mp + Vector2(3, -12)]), Color(0.95, 0.62, 0.85))
	if fam_imp_lvl > 0:
		var ip: Vector2 = get_imp_pos(time_sec) + draw_off
		ci.draw_circle(ip, 21.0, Color(1.0, 0.36, 0.24, 0.30))
		ci.draw_circle(ip, 14.0, Color(0.92, 0.24, 0.36))
		ci.draw_colored_polygon(PackedVector2Array([ip + Vector2(-9, -9), ip + Vector2(-15, -22), ip + Vector2(-2, -12)]), Color(0.28, 0.08, 0.14))
		ci.draw_colored_polygon(PackedVector2Array([ip + Vector2(9, -9), ip + Vector2(15, -22), ip + Vector2(2, -12)]), Color(0.28, 0.08, 0.14))
	if fam_bat_lvl > 0:
		var bp: Vector2 = get_bat_pos(time_sec) + draw_off
		ci.draw_circle(bp, 18.0, Color(0.70, 0.50, 1.0, 0.30))
		ci.draw_circle(bp, 12.0, Color(0.42, 0.24, 0.66))


func draw_alchemy_orb(ci: CanvasItem, o: Dictionary, shake_v: Vector2, is_lifted: bool, time_sec: float) -> void:
	var oid: int = int(o["id"])
	var hit_wobble: float = float(o["hit_wobble"])
	var hit_flash: float = float(o["hit_flash"])
	var wobble_off: Vector2 = Vector2(sin(time_sec * 75.0) * 5.0 * hit_wobble, 0.0) if hit_wobble > 0.01 else Vector2.ZERO
	var pos: Vector2 = (o["pos"] as Vector2) + shake_v + wobble_off
	var depth_scale: float = 1.0 if is_lifted else get_orb_depth_scale(o["pos"] as Vector2)
	var hovered: bool = (oid == hovered_orb_id)
	var hover_scale: float = 1.06 if (hovered and not is_lifted) else 1.0
	var scale_mult: float = float(o["scale_pop"]) * depth_scale * hover_scale * (1.16 if is_lifted else 1.0)
	var r: float = float(o["radius"]) * scale_mult
	var kind: int = int(o["kind"])
	var tier: int = int(o["tier"])
	var hp: int = int(o["hp"])
	var max_hp: int = int(o["max_hp"])
	var rel: StringName = get_orb_relation(kind)
	var col: Color = ChemistryRules.get_element_color(kind)

	if not is_lifted:
		_draw_filled_ellipse(ci, pos + Vector2(0.0, r * 0.72), r * 0.76, r * 0.30, Color(0.02, 0.01, 0.06, 0.36))

	var orb_tex: Texture2D = orb_textures.get(kind, null) as Texture2D
	if orb_tex != null:
		var draw_r: float = r * (ORB_BOMB_DRAW_MULT if kind == ChemistryRules.BubbleKind.BOMB else ORB_CANVAS_MULT)
		var mod_col: Color = Color(0.50, 0.44, 0.56, 0.92) if rel == &"disliked" else Color.WHITE
		ci.draw_texture_rect(orb_tex, Rect2(pos - Vector2(draw_r, draw_r), Vector2(draw_r * 2.0, draw_r * 2.0)), false, mod_col)
		if hit_flash > 0.02:
			ci.draw_circle(pos, r, Color(1.0, 1.0, 1.0, clampf(hit_flash * 0.56, 0.0, 0.60)))
		if hp < max_hp and crack_textures.size() >= 2:
			var dmg_ratio: float = clampf(float(max_hp - hp) / float(maxi(1, max_hp)), 0.0, 1.0)
			var stage_idx: int = 1 if (dmg_ratio >= 0.55 or (max_hp >= 3 and hp <= 1)) else 0
			var crack_r: float = r * ORB_CANVAS_MULT
			var crack_rect: Rect2 = Rect2(-Vector2(crack_r, crack_r), Vector2(crack_r * 2.0, crack_r * 2.0))
			ci.draw_set_transform(pos, float(o.get("crack_rot", 0.0)), Vector2.ONE)
			if crack_glow_textures.size() > stage_idx:
				var glow_base: Color = col.lightened(0.60)
				var glow_a: float = clampf((0.62 if stage_idx == 0 else (0.74 + 0.22 * sin(time_sec * 12.0))) + hit_flash * 0.30, 0.0, 1.0)
				ci.draw_texture_rect(crack_glow_textures[stage_idx], crack_rect, false, Color(glow_base.r, glow_base.g, glow_base.b, glow_a))
			ci.draw_texture_rect(crack_textures[stage_idx], crack_rect, false, Color.WHITE)
			if hit_flash > 0.12:
				ci.draw_texture_rect(crack_textures[stage_idx], crack_rect, false, Color(1.0, 1.0, 1.0, clampf(hit_flash * 0.35, 0.0, 0.40)))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var font: Font = ThemeDB.fallback_font
	if tier >= 2:
		ci.draw_circle(pos + Vector2(-r * 0.60, -r * 0.60), 12.0, Color(0.16, 0.08, 0.26, 0.94))
		ci.draw_arc(pos + Vector2(-r * 0.60, -r * 0.60), 12.0, 0.0, TAU, 16, Color(1.0, 0.86, 0.34), 2.0)
		ci.draw_string(font, pos + Vector2(-r * 0.60 - 11, -r * 0.60 + 5), "x%d" % tier, HORIZONTAL_ALIGNMENT_CENTER, 22, 12, Color(1.0, 0.92, 0.52))


func draw_mini_orb_badge(ci: CanvasItem, center: Vector2, rad: float, kind: int, is_forbidden: bool = false) -> void:
	var orb_tex: Texture2D = orb_textures.get(kind, null) as Texture2D
	if orb_tex != null:
		if is_forbidden:
			ci.draw_circle(center, rad + 3.0, Color(0.22, 0.04, 0.08, 0.92))
		var draw_r: float = rad * (ORB_BOMB_DRAW_MULT if kind == ChemistryRules.BubbleKind.BOMB else ORB_CANVAS_MULT)
		var mod_c: Color = Color(0.76, 0.70, 0.82, 1.0) if is_forbidden else Color.WHITE
		ci.draw_texture_rect(orb_tex, Rect2(center - Vector2(draw_r, draw_r), Vector2(draw_r * 2.0, draw_r * 2.0)), false, mod_c)
		if is_forbidden:
			ci.draw_arc(center, rad, 0.0, TAU, 24, Color(1.0, 0.30, 0.36), 2.5)
	if is_forbidden:
		ci.draw_circle(center + Vector2(rad * 0.68, -rad * 0.68), 8.5, Color(0.88, 0.12, 0.20))
		ci.draw_string(ThemeDB.fallback_font, center + Vector2(rad * 0.68 - 5.0, -rad * 0.68 + 4.0), "✕", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
