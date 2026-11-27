class_name WaveDirector
extends RefCounted
## Manages stop progression, customer wave queue, individual patience countdown,
## order completion/rewards, and closing dialogue state.

enum SlotState { PENDING, ACTIVE, SERVED, FAILED }

const BASE_CUSTOMER_PATIENCE: float = 30.0
const USE_PER_CUSTOMER_PATIENCE: bool = false
const CUSTOMER_IMPATIENT_RATIO: float = 0.30

var active_stop: Dictionary = {}
var stop_essence_mult: float = 1.0
var stop_affinity_bonus: int = 0
var stop_spawn_rate_mult: float = 1.0
var stop_bg_tint: Color = Color(0.08, 0.05, 0.13)

var wave_customers: Array[StringName] = []
var wave_results: Array[int] = []
var wave_index: int = 0
var wave_served_count: int = 0
var wave_missed_count: int = 0
var wave_victory: bool = false

var round_number: int = 1
var round_ending: bool = false
var round_end_timer: float = 0.0
var round_essence_gained: int = 0
var round_orders_completed: int = 0

var active_customer: CustomerArchetypeData = null
var last_served_customer: CustomerArchetypeData = null
var current_order_chemistry: Dictionary = {}
var last_order_liked_kind: int = -1
var potion_tube_pct: float = 0.0
var customer_order_reward: int = 24

var customer_patience_max: float = BASE_CUSTOMER_PATIENCE
var customer_patience_left: float = BASE_CUSTOMER_PATIENCE
var customer_impatient_warned: bool = false

var customer_line: String = "¡Necesito algo bien fuerte para esta noche!"
var customer_spicy_mode: bool = false
var customer_flash_timer: float = 0.0
var customer_slide_t: float = 1.0
var customer_emotion: String = "normal"
var customer_emotion_timer: float = 0.0
var customer_react_anim: float = 0.0

var closing_active: bool = false
var closing_lines: Array[Dictionary] = []
var closing_idx: int = -1


func start_stop(stop_dict: Dictionary, round_num: int) -> void:
	round_number = round_num
	active_stop = stop_dict
	stop_essence_mult = float(active_stop.get("essence_mult", 1.0))
	stop_affinity_bonus = int(active_stop.get("affinity_bonus", 0))
	stop_spawn_rate_mult = float(active_stop.get("spawn_rate_mult", 1.0))
	stop_bg_tint = active_stop.get("bg_tint", Color(0.08, 0.05, 0.13)) as Color

	round_ending = false
	round_end_timer = 0.0
	wave_victory = false
	closing_active = false
	round_essence_gained = 0
	round_orders_completed = 0
	wave_served_count = 0
	wave_missed_count = 0

	wave_customers.clear()
	var raw_custs: Array = active_stop.get("customers", [&"sylvi", &"velvet"]) as Array
	for cv: Variant in raw_custs:
		wave_customers.append(cv as StringName)
	if wave_customers.is_empty():
		wave_customers.append(&"sylvi")
	wave_results.clear()
	for _i: int in range(wave_customers.size()):
		wave_results.append(SlotState.PENDING)
	wave_index = 0


func _ensure_wave_results_synced() -> void:
	while wave_results.size() < wave_customers.size():
		wave_results.append(SlotState.PENDING)


func get_wave_slot_states() -> Array[int]:
	_ensure_wave_results_synced()
	var states: Array[int] = wave_results.duplicate()
	if not round_ending and not closing_active and wave_index >= 0 and wave_index < states.size() and states[wave_index] == SlotState.PENDING:
		states[wave_index] = SlotState.ACTIVE
	return states


func find_customer_by_id(catalog: Array[CustomerArchetypeData], cid: StringName) -> CustomerArchetypeData:
	for c: CustomerArchetypeData in catalog:
		if c.customer_id == cid:
			return c
	return catalog[0] if not catalog.is_empty() else null


func get_customer_chemistry() -> Dictionary:
	if not current_order_chemistry.is_empty():
		return current_order_chemistry
	if active_customer != null:
		return ChemistryRules.get_default_chemistry_for_customer(active_customer.customer_id)
	return {
		"liked": ChemistryRules.BubbleKind.RED,
		"neutral": ChemistryRules.BubbleKind.GREEN,
		"disliked": ChemistryRules.BubbleKind.BLUE,
	}


func compute_customer_patience(c: CustomerArchetypeData, reloj_arena_lvl: int) -> float:
	var base_sec: float = c.base_patience_sec if (USE_PER_CUSTOMER_PATIENCE and c != null) else BASE_CUSTOMER_PATIENCE
	return base_sec + float(reloj_arena_lvl) * 4.0


func pick_customer(next_c: CustomerArchetypeData, first_order: bool, state: Node, order_bonus_mult: float, reloj_arena_lvl: int) -> Dictionary:
	active_customer = next_c
	current_order_chemistry = ChemistryRules.roll_order_chemistry(
		next_c.customer_id,
		first_order,
		bool(state.call("should_run_cauldron_basics_tutorial")),
		bool(state.call("should_run_mix_tutorial")),
		last_order_liked_kind
	)
	last_order_liked_kind = int(current_order_chemistry["liked"])
	potion_tube_pct = 0.0
	customer_patience_max = compute_customer_patience(next_c, reloj_arena_lvl)
	customer_patience_left = customer_patience_max
	customer_impatient_warned = false
	customer_slide_t = 0.0
	customer_spicy_mode = false
	customer_emotion = "normal"
	customer_emotion_timer = 0.0
	customer_react_anim = 1.0
	customer_order_reward = int(roundf(float(24 + int(state.orders_completed) * 12) * next_c.tip_generosity_mult * order_bonus_mult * stop_essence_mult))

	customer_line = DialogueBank.pick_customer_line(next_c.customer_id, "greeting")

	var liked_k: int = int(get_customer_chemistry()["liked"])
	var start_mix_tut: bool = ChemistryRules.is_mixed_kind(liked_k) and bool(state.call("should_run_mix_tutorial"))
	return {
		"greeting_line": customer_line,
		"start_mix_tutorial": start_mix_tut,
	}


func step_customer_visuals(delta: float, patience_paused: bool, frenzy_active: bool) -> void:
	if customer_flash_timer > 0.0:
		customer_flash_timer = maxf(0.0, customer_flash_timer - delta)
	if customer_react_anim > 0.0:
		customer_react_anim = maxf(0.0, customer_react_anim - delta * 3.2)
	if customer_emotion_timer > 0.0:
		customer_emotion_timer = maxf(0.0, customer_emotion_timer - delta)

	var cust_ratio: float = customer_patience_left / maxf(1.0, customer_patience_max)
	if customer_emotion_timer <= 0.0 and not closing_active:
		var desired_cust: String = "impaciente" if ((not patience_paused) and (not round_ending) and cust_ratio <= CUSTOMER_IMPATIENT_RATIO) else ("sonrojada" if (frenzy_active or potion_tube_pct >= 65.0) else "normal")
		if customer_emotion != desired_cust:
			customer_emotion = desired_cust
			customer_react_anim = 1.0

	if customer_slide_t < 1.0:
		customer_slide_t = minf(1.0, customer_slide_t + delta * 3.4)


func set_customer_reaction(emotion: String, dur: float, line: String = "") -> String:
	if emotion != customer_emotion or emotion in ["sonrojada", "impaciente"]:
		customer_react_anim = 1.0
	customer_emotion = emotion
	customer_emotion_timer = dur
	if line != "":
		customer_line = line
		if not closing_active:
			return line
	return ""


func step_patience(delta: float, patience_paused: bool) -> Dictionary:
	var result: Dictionary = {
		"impatient_warn": false,
		"warn_line": "",
		"expired": false,
	}
	if patience_paused or active_customer == null or round_ending or closing_active or delta <= 0.0:
		return result
	customer_patience_left = maxf(0.0, customer_patience_left - delta)
	var p_ratio: float = customer_patience_left / maxf(1.0, customer_patience_max)
	if p_ratio <= CUSTOMER_IMPATIENT_RATIO and not customer_impatient_warned:
		customer_impatient_warned = true
		var imp_line: String = DialogueBank.pick_customer_line(active_customer.customer_id, "impatient")
		result["impatient_warn"] = true
		result["warn_line"] = imp_line
	if customer_patience_left <= 0.0:
		result["expired"] = true
	return result


func expire_patience() -> Dictionary:
	var c: CustomerArchetypeData = active_customer
	last_served_customer = c
	_ensure_wave_results_synced()
	if wave_index >= 0 and wave_index < wave_results.size():
		wave_results[wave_index] = SlotState.FAILED
	wave_missed_count += 1
	potion_tube_pct = 0.0
	wave_index += 1
	var cid: StringName = c.customer_id if c != null else &""
	var leave_line: String = DialogueBank.pick_customer_line(cid, "leave")
	if leave_line == "":
		leave_line = DialogueBank.pick_customer_line(cid, "impatient")
	return {
		"customer": c,
		"leave_line": leave_line,
	}


func complete_order(state: Node, combo: int, crit_potion_lvl: int, encanto_lvl: int) -> Dictionary:
	var c: CustomerArchetypeData = active_customer
	last_served_customer = c
	var overflow: float = maxf(0.0, potion_tube_pct - 100.0)
	var crit: bool = crit_potion_lvl > 0 and combo >= 5
	var bonus_gold: int = customer_order_reward * (2 if crit else 1) + int(roundf(overflow * 0.4))
	state.orders_completed += 1
	round_orders_completed += 1
	wave_served_count += 1

	var aff_gain: int = 1 + (1 if encanto_lvl >= 3 else 0) + (1 if crit else 0) + stop_affinity_bonus
	var leveled_up: bool = bool(state.add_affinity(c.customer_id, aff_gain))
	var new_aff_lvl: int = int(state.get_affinity_level(c.customer_id))
	customer_spicy_mode = new_aff_lvl >= 1
	customer_flash_timer = 1.2

	var done_line: String = DialogueBank.pick_customer_line(c.customer_id, "spicy" if customer_spicy_mode else "satisfied")

	_ensure_wave_results_synced()
	if wave_index >= 0 and wave_index < wave_results.size():
		wave_results[wave_index] = SlotState.SERVED
	wave_index += 1
	return {
		"customer": c,
		"crit": crit,
		"bonus_gold": bonus_gold,
		"aff_gain": aff_gain,
		"leveled_up": leveled_up,
		"new_aff_lvl": new_aff_lvl,
		"done_line": done_line,
	}


func has_next_customer() -> bool:
	return wave_index < wave_customers.size()


func next_customer_id() -> StringName:
	return wave_customers[wave_index]


func evaluate_wave_victory() -> bool:
	var min_needed: int = ceili(float(wave_customers.size()) * 0.5)
	var victory: bool = wave_served_count >= min_needed
	if victory:
		potion_tube_pct = 100.0
	return victory


func trigger_stop_end(victory: bool) -> bool:
	if round_ending:
		return false
	round_ending = true
	wave_victory = victory
	round_end_timer = 1.35 if victory else 1.15
	return true


func begin_closing(victory: bool) -> bool:
	if closing_active:
		return false
	closing_active = true
	var stop_id: StringName = active_stop.get("id", &"") as StringName
	var raw_lines: Array[Dictionary] = DialogueBank.get_stop_closing_lines(stop_id, victory)

	closing_lines.clear()
	for ld: Dictionary in raw_lines:
		if String(ld.get("speaker", "trixie")) == "trixie":
			closing_lines.append(ld.duplicate())
			break

	if closing_lines.is_empty():
		closing_lines.append({
			"speaker": "trixie",
			"emotion": "confiada" if victory else "hollin",
			"text": "¡Uf, pude terminar! Ahora a descansar y mejorar el caldero en el {clave}Mapa{/clave}." if victory else "¡Puf...! Toca descansar, mejorar el caldero en el {clave}Mapa{/clave} e intentarlo otra vez.",
		})

	closing_idx = -1
	return true


func next_closing_line() -> Dictionary:
	closing_idx += 1
	if closing_idx >= closing_lines.size():
		return {"done": true}
	var d: Dictionary = closing_lines[closing_idx]
	return {
		"done": false,
		"speaker": String(d.get("speaker", "trixie")),
		"emotion": String(d.get("emotion", "normal")),
		"text": String(d.get("text", "")),
	}
