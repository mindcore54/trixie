extends Node
## Persistent campaign & incremental progression state shared across MainMenu, MainGame, and WorldMap.

const AFFINITY_THRESHOLDS: Array[int] = [3, 7, 12]
const BASE_CUSTOMER_PATIENCE: float = 30.0

# Economy & progression
var essence_gold: int = 0
var total_essence_earned: int = 0
var orders_completed: int = 0
var rounds_played: int = 0
var victory_achieved: bool = false
var victory_banner_shown: bool = false

var node_levels: Dictionary = {
	&"root_cauldron": 1,
}
var customer_affinity_pts: Dictionary = {}

# Catalogs cached
var tree_nodes: Array[Dictionary] = []
var _node_by_id: Dictionary = {}
var map_nodes: Array[Dictionary] = []
var _map_node_by_id: Dictionary = {}
var customers_catalog: Array[CustomerArchetypeData] = []
var witches_catalog: Array[WitchCharacterData] = []

# Derived tactical stats
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
var customer_patience_sec: float = BASE_CUSTOMER_PATIENCE

# World map & campaign state
var active_witch_id: StringName = &"trixie"
var active_map_node_id: StringName = &"castillo"
var last_visited_map_node_id: StringName = &"castillo"
var completed_map_nodes: Dictionary = {}
var recruited_witches: Dictionary = {
	&"trixie": true,
}

# Tutorial state
var cauldron_basics_tutorial_done: bool = false
var mix_tutorial_done: bool = false
var cauldron_tutorial_done: bool = false
var map_tutorial_done: bool = false
var map_tutorial_stage: int = 0 # 0 = OPEN_TREE, 1 = BUY_HOLD_CLICK, 2 = DONE


func _ready() -> void:
	_load_catalogs()
	reset_run()


func _load_catalogs() -> void:
	if tree_nodes.is_empty():
		tree_nodes = GameCatalog.get_incremental_nodes()
		_node_by_id.clear()
		for nd: Dictionary in tree_nodes:
			_node_by_id[nd["id"] as StringName] = nd
	if map_nodes.is_empty():
		map_nodes = GameCatalog.get_map_nodes()
		_map_node_by_id.clear()
		for mn: Dictionary in map_nodes:
			_map_node_by_id[mn["id"] as StringName] = mn
	if customers_catalog.is_empty():
		customers_catalog = GameCatalog.get_customers()
	if witches_catalog.is_empty():
		witches_catalog = GameCatalog.get_witches()


func ensure_loaded() -> void:
	if tree_nodes.is_empty() or map_nodes.is_empty() or customers_catalog.is_empty() or witches_catalog.is_empty():
		_load_catalogs()
	if not node_levels.has(&"root_cauldron"):
		node_levels[&"root_cauldron"] = 1
	for c: CustomerArchetypeData in customers_catalog:
		if not customer_affinity_pts.has(c.customer_id):
			customer_affinity_pts[c.customer_id] = 0
	if not customer_affinity_pts.has(&"trixie"):
		customer_affinity_pts[&"trixie"] = 0
	recalc_stats()


func reset_run() -> void:
	_load_catalogs()
	essence_gold = 0
	total_essence_earned = 0
	orders_completed = 0
	rounds_played = 0
	victory_achieved = false
	victory_banner_shown = false

	node_levels = {
		&"root_cauldron": 1,
	}
	customer_affinity_pts.clear()
	for c: CustomerArchetypeData in customers_catalog:
		customer_affinity_pts[c.customer_id] = 0
	customer_affinity_pts[&"trixie"] = 0

	active_witch_id = &"trixie"
	active_map_node_id = &"castillo"
	last_visited_map_node_id = &"castillo"
	completed_map_nodes.clear()
	recruited_witches = {
		&"trixie": true,
	}

	cauldron_basics_tutorial_done = false
	mix_tutorial_done = false
	cauldron_tutorial_done = false
	map_tutorial_done = false
	map_tutorial_stage = 0
	recalc_stats()


func is_tutorial_enabled() -> bool:
	var gs: Node = get_node_or_null("/root/GameSettings")
	if gs != null:
		return bool(gs.get("show_tutorial"))
	return true


func should_run_cauldron_basics_tutorial() -> bool:
	return is_tutorial_enabled() and not cauldron_basics_tutorial_done


func should_run_mix_tutorial() -> bool:
	return is_tutorial_enabled() and not mix_tutorial_done


func should_run_cauldron_tutorial() -> bool:
	return should_run_cauldron_basics_tutorial()


func should_run_map_tutorial() -> bool:
	return is_tutorial_enabled() and not map_tutorial_done and get_node_level(&"toque_continuo") == 0


func recalc_stats() -> void:
	var l_hold: int = get_node_level(&"toque_continuo")
	var l_strength: int = get_node_level(&"fuerza_molienda")
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

	hold_auto_hit_unlocked = (l_hold >= 1)
	hold_hit_interval = maxf(0.10, 0.36 - float(maxi(0, l_hold - 1)) * 0.055)
	aroma_essence_mult = 1.0 + (0.15 if l_hold >= 1 else 0.0) + float(maxi(0, l_hold - 1)) * 0.20
	click_damage = 1 if l_strength <= 0 else (2 if l_strength == 1 else (3 if l_strength == 2 else 5))
	strength_tube_bonus = float(l_strength) * 0.25

	frenzy_gain_mult = 1.0 + float(l_frenzy) * 0.25
	frenzy_duration_sec = 5.0 + float(l_frenzy) * 1.2

	spawn_cap = 6 + l_boil * 2
	spawn_interval = maxf(0.32, 1.15 - float(l_boil) * 0.10)
	chain_spark_jumps = 0 if l_spark <= 0 else (1 + int(floor(float(l_spark) * 0.5)))
	bomb_chance = 0.0 if l_bomb <= 0 else (0.09 + float(l_bomb - 1) * 0.03)
	star_chance = 0.0 if l_star <= 0 else (0.07 + float(l_star - 1) * 0.03)

	customer_patience_sec = BASE_CUSTOMER_PATIENCE + float(l_time) * 4.0
	order_bonus_mult = 1.0 + float(l_charm) * 0.25


func get_node_dict(node_id: StringName) -> Dictionary:
	ensure_loaded()
	return _node_by_id.get(node_id, {}) as Dictionary


func get_node_level(node_id: StringName) -> int:
	return int(node_levels.get(node_id, 0))


func get_node_cost(node_id: StringName) -> int:
	ensure_loaded()
	if not _node_by_id.has(node_id):
		return 999999
	var nd: Dictionary = _node_by_id[node_id] as Dictionary
	var lvl: int = get_node_level(node_id)
	var base_cost: int = int(nd.get("base_cost", 10))
	var mult: float = float(nd.get("cost_mult", 1.5))
	return int(roundf(float(base_cost) * pow(mult, float(lvl))))


func is_node_unlocked(node_id: StringName) -> bool:
	ensure_loaded()
	if not _node_by_id.has(node_id):
		return false
	var nd: Dictionary = _node_by_id[node_id] as Dictionary
	var parent_id: StringName = nd.get("parent_id", &"") as StringName
	if parent_id == &"":
		return true
	return get_node_level(parent_id) > 0


func can_buy_node(node_id: StringName) -> bool:
	ensure_loaded()
	if not _node_by_id.has(node_id):
		return false
	var nd: Dictionary = _node_by_id[node_id] as Dictionary
	if get_node_level(node_id) >= int(nd.get("max_level", 1)):
		return false
	if not is_node_unlocked(node_id):
		return false
	return essence_gold >= get_node_cost(node_id)


func count_affordable_nodes() -> int:
	ensure_loaded()
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
	recalc_stats()

	if node_id == &"elixir_supremo" and not victory_achieved:
		victory_achieved = true
		add_affinity(&"trixie", 12)
	return true


func grant_essence(amount: int) -> void:
	if amount <= 0:
		return
	essence_gold += amount
	total_essence_earned += amount
	_emit_gold_changed(essence_gold, amount)


func spend_essence(amount: int) -> bool:
	if amount <= 0 or essence_gold < amount:
		return false
	essence_gold -= amount
	_emit_gold_changed(essence_gold, -amount)
	return true


func get_affinity_points(char_id: StringName) -> int:
	return int(customer_affinity_pts.get(char_id, 0))


func get_affinity_level(char_id: StringName) -> int:
	var pts: int = get_affinity_points(char_id)
	var lvl: int = 0
	for th: int in AFFINITY_THRESHOLDS:
		if pts >= th:
			lvl += 1
	return lvl


func add_affinity(char_id: StringName, pts: int) -> bool:
	var prev_lvl: int = get_affinity_level(char_id)
	customer_affinity_pts[char_id] = get_affinity_points(char_id) + pts
	return get_affinity_level(char_id) > prev_lvl


func get_map_node(node_id: StringName) -> Dictionary:
	ensure_loaded()
	return _map_node_by_id.get(node_id, {}) as Dictionary


func get_active_map_node() -> Dictionary:
	ensure_loaded()
	var nd: Dictionary = get_map_node(active_map_node_id)
	if nd.is_empty() and not map_nodes.is_empty():
		return map_nodes[0]
	return nd


func is_map_node_completed(node_id: StringName) -> bool:
	return bool(completed_map_nodes.get(node_id, false))


func is_map_node_unlocked(node_id: StringName) -> bool:
	ensure_loaded()
	var nd: Dictionary = get_map_node(node_id)
	if nd.is_empty():
		return false
	var reqs: Array = nd.get("unlock_any_of", []) as Array
	if reqs.is_empty():
		return true
	for req: Variant in reqs:
		if is_map_node_completed(req as StringName):
			return true
	return false


func mark_map_node_completed(node_id: StringName) -> Dictionary:
	ensure_loaded()
	var nd: Dictionary = get_map_node(node_id)
	var first_clear: bool = not is_map_node_completed(node_id)
	completed_map_nodes[node_id] = true
	last_visited_map_node_id = node_id

	var bonus_ess: int = 0
	var recruited: StringName = &""
	if first_clear and not nd.is_empty():
		bonus_ess = int(nd.get("first_clear_bonus", 0))
		if bonus_ess > 0:
			grant_essence(bonus_ess)
		var rw: StringName = nd.get("recruits_witch", &"") as StringName
		if rw != &"" and not bool(recruited_witches.get(rw, false)):
			recruited_witches[rw] = true
			recruited = rw

	return {
		"first_clear": first_clear,
		"bonus_essence": bonus_ess,
		"recruited_witch": recruited,
	}


func count_completed_map_nodes() -> int:
	var total: int = 0
	for k: Variant in completed_map_nodes.keys():
		if bool(completed_map_nodes[k]):
			total += 1
	return total


func get_recommended_next_map_node_id() -> StringName:
	ensure_loaded()
	var current: Dictionary = get_map_node(last_visited_map_node_id)
	if not current.is_empty():
		var next_list: Array = current.get("next_ids", []) as Array
		for nid_v: Variant in next_list:
			var nid: StringName = nid_v as StringName
			if is_map_node_unlocked(nid) and not is_map_node_completed(nid):
				return nid
	for mn: Dictionary in map_nodes:
		var mid: StringName = mn["id"] as StringName
		if is_map_node_unlocked(mid) and not is_map_node_completed(mid):
			return mid
	return last_visited_map_node_id


func get_active_witch() -> WitchCharacterData:
	ensure_loaded()
	for w: WitchCharacterData in witches_catalog:
		if w.witch_id == active_witch_id:
			return w
	return witches_catalog[0] if not witches_catalog.is_empty() else null


func get_active_witch_name() -> String:
	var w: WitchCharacterData = get_active_witch()
	if w != null and w.display_name != "":
		return w.display_name
	return String(active_witch_id).capitalize()


func _emit_gold_changed(new_total: int, delta_val: int) -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.emit_signal("gold_changed", new_total, delta_val)
