class_name MainGame
extends Node2D
## Coordinates the 2.5D potion kitchen arena, wave director, customers, familiars,
## floating juice popups, roguelite upgrades, and HUD.

const MAX_CUSTOMERS_IN_QUEUE: int = 5
const COMBO_WINDOW_SEC: float = 15.0

var witches: Array[WitchCharacterData] = []
var customers_catalog: Array[CustomerArchetypeData] = []
var recipes_catalog: Array[PotionRecipeData] = []
var upgrades_catalog: Array[RogueliteUpgradeData] = []

var stations: Array[KitchenStation] = []
var active_customers: Array[CustomerEntity] = []
var active_familiars: Array[FamiliarEntity] = []
var acquired_upgrades: Dictionary = {}
var customer_affinity: Dictionary = {}

var witch: WitchController
var hud: KitchenHUD
var camera: Camera2D

var day_number: int = 1
var day_time_left: float = 65.0
var spawn_timer: float = 2.0
var gold: int = 0
var combo: int = 0
var combo_timer: float = 0.0
var hearts: int = 3
var max_hearts: int = 3
var reroll_cost: int = 35
var run_active: bool = true
var mirror_clone_enabled: bool = false
var _selected_witch_idx: int = 0
var _popups: Array[Dictionary] = []

var _queue_slots: Array[Vector2] = [
	Vector2(1380, 560),
	Vector2(1425, 480),
	Vector2(1470, 405),
	Vector2(1515, 335),
	Vector2(1560, 265),
]


func _ready() -> void:
	witches = GameCatalog.get_witches()
	customers_catalog = GameCatalog.get_customers()
	recipes_catalog = GameCatalog.get_recipes()
	upgrades_catalog = GameCatalog.get_upgrades()

	camera = Camera2D.new()
	camera.position = Vector2(960, 540)
	add_child(camera)
	AudioJuiceManager.register_camera(camera)

	_build_kitchen_stations()

	witch = WitchController.new()
	witch.position = Vector2(880, 580)
	witch.bottling_station_pos = _find_station(&"bottling").global_position
	witch.seismic_mortar_callback = _on_seismic_mortar
	witch.wanted_recipes_getter = _get_wanted_recipes
	witch.potion_delivered_to_customer.connect(_on_potion_delivered)
	witch.popup_requested.connect(_spawn_popup)
	add_child(witch)

	hud = KitchenHUD.new()
	add_child(hud)
	hud.configure_witches(witches, _selected_witch_idx)
	hud.witch_switch_requested.connect(_on_witch_switch_requested)
	hud.force_draft_requested.connect(_open_upgrade_draft)
	hud.toggle_fullscreen_requested.connect(_toggle_fullscreen)
	hud.upgrade_chosen.connect(_on_upgrade_chosen)
	hud.reroll_requested.connect(_on_reroll_requested)
	hud.restart_run_requested.connect(_restart_run)

	EventBus.cauldron_exploded.connect(_on_cauldron_exploded)

	_start_new_run()
	if OS.get_cmdline_user_args().has("--smoke-test"):
		call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	if active_customers.is_empty():
		push_error("SMOKE FAIL: no initial customer spawned")
		get_tree().quit(1)
		return

	var cust: CustomerEntity = active_customers[0]
	var reqs: Array[StringName] = cust.requested_recipe.required_ingredients
	var cauldron: KitchenStation = _find_station(&"cauldron_0")
	var bottling: KitchenStation = _find_station(&"bottling")

	var steps: Array[Variant] = []
	for ing: StringName in reqs:
		steps.append(_find_station(StringName("bin_" + String(ing))))
	steps.append(cauldron)
	steps.append(cauldron)
	steps.append(bottling)
	steps.append(cust)

	Engine.time_scale = 5.0
	var max_queue_seen: int = 0
	for step_target: Variant in steps:
		while witch.action_queue.size() >= WitchController.MAX_NEXT_BUFFER:
			await get_tree().process_frame
		if step_target is KitchenStation:
			witch.enqueue_station(step_target as KitchenStation)
		elif step_target is CustomerEntity:
			witch.enqueue_customer(step_target as CustomerEntity)
		max_queue_seen = maxi(max_queue_seen, witch.action_queue.size())
		await get_tree().process_frame

	for _f: int in range(300):
		await get_tree().process_frame
		if gold > 0:
			break

	var cauldrons: Array[KitchenStation] = [cauldron, _find_station(&"cauldron_1")]
	var ability_ok: bool = witch.trigger_ability(cauldrons, active_customers, active_familiars)
	await get_tree().process_frame

	# Verify mortar color-combining (red + green -> mix_yellow circle -> cauldron tonico_silvestre)
	var mortar: KitchenStation = _find_station(&"mortar")
	var c1: KitchenStation = _find_station(&"cauldron_1")
	witch.held_items.clear()
	witch.held_items.append("ing:red")
	witch.held_items.append("ing:green")
	var mortar_mix_ok: bool = witch._perform_mortar_mix(mortar) and witch.held_items.size() == 1 and witch.held_items[0] == "ing:mix_yellow"
	var raw_blocked_ok: bool = false
	if mortar_mix_ok:
		var yellow_ing: StringName = StringName(witch.held_items[0].substr(4))
		witch.held_items.clear()
		raw_blocked_ok = c1.add_ingredient(yellow_ing) and c1.active_recipe != null and c1.active_recipe.recipe_id == &"tonico_silvestre"
		# Second ingredient directly into non-idle cauldron must be rejected
		raw_blocked_ok = raw_blocked_ok and not c1.can_accept_ingredient(&"green")
		c1.finish_instant()
		c1.take_ready_potion()
	var upgrade_ready_ok: bool = raw_blocked_ok

	# Verify Display Stand per-slot pick/place (2 different potions) + customer pre-reveal decision
	var display_st: KitchenStation = _find_station(&"display_stand")
	var display_ok: bool = false
	if display_st != null:
		display_st.store_potion_in_slot(0, "bot:elixir_ignis:0:0")
		display_st.store_potion_in_slot(1, "bot:bruma_lunar:0:0")
		witch.held_items.clear()
		witch._interact_with_display_stand(display_st, 0)
		witch._interact_with_display_stand(display_st, 1)
		var picked_both_ok: bool = witch.held_items.size() == 2 and witch.held_items[0] == "bot:elixir_ignis:0:0" and witch.held_items[1] == "bot:bruma_lunar:0:0" and display_st.get_occupied_slot_count() == 0
		witch._interact_with_display_stand(display_st, 1)
		var placed_in_slot1_ok: bool = display_st.is_slot_occupied(1) and not display_st.is_slot_occupied(0) and witch.held_items.size() == 1
		# Now spawn a fresh customer while bruma_lunar sits in Vitrina slot 1 and wait for her pre-reveal decision
		for old_c: CustomerEntity in active_customers:
			if is_instance_valid(old_c):
				old_c.queue_free()
		active_customers.clear()
		_spawn_customer()
		var new_cust: CustomerEntity = active_customers[0] if not active_customers.is_empty() else null
		var hidden_initially: bool = new_cust != null and not new_cust.order_revealed
		for _w: int in range(90):
			await get_tree().process_frame
			if new_cust != null and new_cust.order_revealed:
				break
		var locked_onto_vitrina: bool = new_cust != null and new_cust.order_revealed and new_cust.tempted_by_display and new_cust.requested_recipe.recipe_id == &"bruma_lunar"
		# Adding another potion afterwards must NOT change her locked order
		display_st.store_potion_in_slot(0, "bot:savia_pura:0:0")
		await get_tree().process_frame
		var stayed_locked: bool = new_cust != null and new_cust.requested_recipe.recipe_id == &"bruma_lunar"
		witch.held_items.clear()
		witch._interact_with_display_stand(display_st, 1)
		var gold_before_disp: int = gold
		witch._try_deliver_to(new_cust)
		display_ok = picked_both_ok and placed_in_slot1_ok and hidden_initially and locked_onto_vitrina and stayed_locked and gold > gold_before_disp
		display_st.clear_display_slots()

	# Verify timers pause while draft cards are open (animations keep ticking, timers do not)
	cauldron.add_ingredient(&"red")
	var paused_day_before: float = day_time_left
	var paused_brew_before: float = cauldron.brew_elapsed
	var cust_patience_before: float = active_customers[0].patience_remaining if not active_customers.is_empty() else 0.0
	_open_upgrade_draft()
	for _p: int in range(12):
		await get_tree().process_frame
	var timers_stayed_paused: bool = (
		EventBus.timers_paused
		and is_equal_approx(day_time_left, paused_day_before)
		and is_equal_approx(cauldron.brew_elapsed, paused_brew_before)
		and (active_customers.is_empty() or is_equal_approx(active_customers[0].patience_remaining, cust_patience_before))
	)

	var michi_upg: RogueliteUpgradeData = null
	for u: RogueliteUpgradeData in upgrades_catalog:
		if u.upgrade_id == &"michi_alado":
			michi_upg = u
			break
	if michi_upg != null:
		_on_upgrade_chosen(michi_upg)
	await get_tree().process_frame

	Engine.time_scale = 1.0
	print("SMOKE STATS => gold=%d combo=%d day=%d familiars=%d ability_ok=%s max_buf=%d timers_paused_ok=%s mortar_mix_ok=%s mortar_cauldron_ok=%s display_ok=%s" % [
		gold, combo, day_number, active_familiars.size(), str(ability_ok), max_queue_seen, str(timers_stayed_paused), str(mortar_mix_ok), str(upgrade_ready_ok), str(display_ok)
	])
	var ok: bool = gold > 0 and combo >= 1 and day_number == 2 and active_familiars.size() >= 1 and ability_ok and max_queue_seen <= WitchController.MAX_NEXT_BUFFER and timers_stayed_paused and mortar_mix_ok and upgrade_ready_ok and display_ok
	print("SMOKE RESULT: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _start_new_run() -> void:
	for c: CustomerEntity in active_customers:
		if is_instance_valid(c):
			c.queue_free()
	active_customers.clear()
	for f: FamiliarEntity in active_familiars:
		if is_instance_valid(f):
			f.queue_free()
	active_familiars.clear()

	acquired_upgrades.clear()
	mirror_clone_enabled = false
	witch.move_speed_mult = 1.0
	witch.carry_bonus = 0
	witch.instant_bottle_enabled = false
	witch.seismic_mortar_enabled = false

	var active_w: WitchCharacterData = witches[_selected_witch_idx]
	witch.setup_witch(active_w)
	max_hearts = active_w.max_stability_hearts
	hearts = max_hearts
	gold = 0
	combo = 0
	combo_timer = 0.0
	day_number = 1
	reroll_cost = 35
	_set_run_active(true)
	hud.hide_overlays()

	for st: KitchenStation in stations:
		st.familiar_protected = false
		st.has_mortar_bonus = false
		st.held_ingredients.clear()
		st.clear_display_slots()
		st.active_recipe = null
		st.cauldron_state = KitchenStation.CauldronState.IDLE
		st.queue_redraw()

	_start_day(1)
	EventBus.gold_changed.emit(gold, 0)
	EventBus.combo_changed.emit(0, 1.0)


func _restart_run() -> void:
	_start_new_run()


func _start_day(day: int) -> void:
	day_number = day
	day_time_left = 75.0 + float(day - 1) * 5.0
	spawn_timer = 14.0
	reroll_cost = 35
	var active_w: WitchCharacterData = witches[_selected_witch_idx]
	for st: KitchenStation in stations:
		st.configure_catalog(recipes_catalog, day_number, active_w.brew_speed_mult)
	EventBus.day_started.emit(day_number, day_time_left, day_number == 3 or day_number == 8)
	_spawn_customer()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_ev: InputEventKey = event as InputEventKey
		if key_ev.pressed and not key_ev.echo and key_ev.keycode == KEY_F11:
			_toggle_fullscreen()
			return
	if not run_active:
		return
	if event.is_action_pressed("ability_cutin_click"):
		var cauldrons: Array[KitchenStation] = []
		for s: KitchenStation in stations:
			if s.station_type == KitchenStation.StationType.CAULDRON:
				cauldrons.append(s)
		witch.trigger_ability(cauldrons, active_customers, active_familiars)
	elif event.is_action_pressed("cancel_queue"):
		witch.clear_queue()


func _process(delta: float) -> void:
	_update_popups(delta)
	if not run_active:
		return

	day_time_left -= delta
	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
			EventBus.combo_changed.emit(0, 1.0)

	if active_customers.is_empty() and spawn_timer > 2.2:
		spawn_timer = 2.2

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_customer()
		spawn_timer = maxf(7.5, 16.5 - float(day_number - 1) * 1.3)

	# Check customer patience expirations
	var i: int = 0
	while i < active_customers.size():
		var cust: CustomerEntity = active_customers[i]
		if is_instance_valid(cust) and not cust.is_served and cust.patience_remaining <= 0.0:
			_handle_customer_timeout(cust)
			continue
		i += 1

	if day_time_left <= 0.0:
		_finish_day()

	var relic_names: PackedStringArray = PackedStringArray()
	for k: String in acquired_upgrades.keys():
		relic_names.append(k)
	hud.update_runtime_stats(
		day_number,
		day_time_left,
		hearts,
		max_hearts,
		active_customers.size(),
		witch.get_ability_cooldown_ratio(),
		relic_names
	)
	queue_redraw()


func _spawn_customer() -> void:
	if not run_active:
		return
	if active_customers.size() >= MAX_CUSTOMERS_IN_QUEUE:
		return

	var valid_recipes: Array[PotionRecipeData] = []
	for r: PotionRecipeData in recipes_catalog:
		if r.unlock_day <= day_number:
			valid_recipes.append(r)
	if valid_recipes.is_empty():
		return

	var arch: CustomerArchetypeData = customers_catalog[randi() % customers_catalog.size()]
	var recipe: PotionRecipeData = valid_recipes[randi() % valid_recipes.size()]
	var slot_idx: int = active_customers.size()

	var cust: CustomerEntity = CustomerEntity.new()
	add_child(cust)
	cust.setup(arch, recipe, slot_idx, _queue_slots[slot_idx])
	cust.customer_clicked.connect(_on_customer_clicked)
	cust.order_decision_ready.connect(_on_customer_order_decision_ready)
	active_customers.append(cust)


func _on_customer_order_decision_ready(cust: CustomerEntity) -> void:
	if not is_instance_valid(cust) or cust.is_served or cust.archetype == null:
		return

	var display_st: KitchenStation = _find_station(&"display_stand")
	if display_st != null:
		var available: Dictionary = {}
		for rec_id: StringName in display_st.get_displayed_recipe_ids():
			available[rec_id] = int(available.get(rec_id, 0)) + 1
		for other: CustomerEntity in active_customers:
			if other != cust and is_instance_valid(other) and not other.is_served and other.order_revealed and other.requested_recipe != null:
				var r_id: StringName = other.requested_recipe.recipe_id
				if int(available.get(r_id, 0)) > 0:
					available[r_id] = int(available[r_id]) - 1
		for rec_id: StringName in available.keys():
			if int(available[rec_id]) > 0:
				var disp_rec: PotionRecipeData = GameCatalog.find_recipe_by_id(rec_id, recipes_catalog)
				if disp_rec != null:
					cust.set_tempted_order(disp_rec)
					_spawn_popup(cust.global_position + Vector2(-35, -108), "¡Quiere la de vitrina!", Color(1.0, 0.86, 0.30))
					EventBus.customer_arrived.emit(cust.archetype.customer_id, cust.queue_slot, disp_rec.recipe_id)
					if not cust.archetype.display_tempted_lines.is_empty():
						var t_line: String = cust.archetype.display_tempted_lines[randi() % cust.archetype.display_tempted_lines.size()]
						EventBus.customer_dialogue_requested.emit(
							cust.archetype.customer_id,
							cust.archetype.portrait_happy if cust.archetype.portrait_happy else cust.archetype.portrait_normal,
							t_line,
							false
						)
						hud.set_customer_affinity(cust.archetype.customer_id, int(customer_affinity.get(cust.archetype.customer_id, 0)))
					return

	EventBus.customer_arrived.emit(cust.archetype.customer_id, cust.queue_slot, cust.requested_recipe.recipe_id)
	if cust.queue_slot == 0 and not cust.archetype.greeting_lines.is_empty():
		var line: String = cust.archetype.greeting_lines[randi() % cust.archetype.greeting_lines.size()]
		EventBus.customer_dialogue_requested.emit(cust.archetype.customer_id, cust.archetype.portrait_normal, line, false)
		hud.set_customer_affinity(cust.archetype.customer_id, int(customer_affinity.get(cust.archetype.customer_id, 0)))


func _on_customer_clicked(cust: CustomerEntity) -> void:
	if run_active and is_instance_valid(cust):
		witch.enqueue_customer(cust)


func _on_station_clicked(st: KitchenStation) -> void:
	if run_active:
		witch.enqueue_station(st)


func _on_potion_delivered(cust: CustomerEntity, recipe_id: StringName, is_hot: bool, is_mortar: bool = false) -> void:
	if not is_instance_valid(cust) or cust.is_served:
		return
	var recipe: PotionRecipeData = GameCatalog.find_recipe_by_id(recipe_id, recipes_catalog)
	if recipe == null:
		return

	combo += 1
	combo_timer = COMBO_WINDOW_SEC
	var combo_mult: float = minf(3.0, 1.0 + float(combo - 1) * 0.15)
	var hot_mult: float = recipe.hot_bonus_multiplier if is_hot else 1.0
	var mortar_mult: float = 1.5 if is_mortar else 1.0
	var cust_mult: float = cust.archetype.tip_generosity_mult if cust.archetype else 1.0
	var earned: int = int(round(float(recipe.base_gold_value) * hot_mult * mortar_mult * combo_mult * cust_mult))
	if witches[_selected_witch_idx].witch_id == &"morrigan":
		earned = int(round(float(earned) * 1.4))

	gold += earned
	EventBus.gold_changed.emit(gold, earned)
	EventBus.combo_changed.emit(combo, combo_mult)

	var cid: StringName = cust.archetype.customer_id
	var aff: int = mini(3, int(customer_affinity.get(cid, 0)) + (1 if is_hot or combo >= 3 else 0))
	customer_affinity[cid] = aff

	var is_spicy: bool = aff >= 2 and not cust.archetype.spicy_affinity_lines.is_empty()
	var line: String = ""
	if is_spicy:
		line = cust.archetype.spicy_affinity_lines[randi() % cust.archetype.spicy_affinity_lines.size()]
	elif not cust.archetype.satisfied_lines.is_empty():
		line = cust.archetype.satisfied_lines[randi() % cust.archetype.satisfied_lines.size()]
	var portrait: Texture2D = cust.archetype.portrait_spicy_blush if is_spicy else cust.archetype.portrait_happy

	hud.set_customer_affinity(cid, aff)
	EventBus.customer_dialogue_requested.emit(cid, portrait, line, is_spicy)
	EventBus.customer_served.emit(cid, earned, hot_mult * combo_mult, aff)

	var pop_txt: String = "+%dg%s%s" % [earned, " ¡CALIENTE!" if is_hot else "", " ¡MORTERO!" if is_mortar else ""]
	_spawn_popup(cust.global_position + Vector2(-30, -80), pop_txt, Color(1.0, 0.86, 0.25))

	_remove_customer_and_advance_queue(cust, true)

	if is_hot and mirror_clone_enabled:
		var disp_st: KitchenStation = _find_station(&"display_stand")
		var cloned_to_vitrina: bool = false
		if disp_st != null:
			for s_idx: int in range(KitchenStation.MAX_DISPLAY_SLOTS):
				if not disp_st.is_slot_occupied(s_idx):
					disp_st.store_potion_in_slot(s_idx, "bot:%s:0:0" % String(recipe_id))
					_spawn_popup(disp_st.global_position + Vector2(0, -64), "¡Clon en Vitrina!", Color(0.7, 0.45, 1.0))
					cloned_to_vitrina = true
					break
		if not cloned_to_vitrina:
			var mirror_gold: int = int(round(float(earned) * 0.5))
			gold += mirror_gold
			EventBus.gold_changed.emit(gold, mirror_gold)
			_spawn_popup(cust.global_position + Vector2(-40, -110), "¡Espejo +%dg!" % mirror_gold, Color(0.7, 0.45, 1.0))


func _handle_customer_timeout(cust: CustomerEntity) -> void:
	hearts -= 1
	combo = 0
	EventBus.combo_changed.emit(0, 1.0)
	EventBus.customer_patience_expired.emit(cust.archetype.customer_id, hearts)
	EventBus.witch_emotion_changed.emit(EventBus.WitchEmotion.NERVIOSA_SUDANDO, 2.0)
	_spawn_popup(cust.global_position + Vector2(-40, -80), "¡Se marchó furiosa! -1 ♥", Color(1.0, 0.25, 0.3))
	_remove_customer_and_advance_queue(cust, false)
	if hearts <= 0:
		_end_run(false, "Te quedaste sin Corazones de Estabilidad tras perder clientas.")


func _remove_customer_and_advance_queue(cust: CustomerEntity, happy: bool) -> void:
	var idx: int = active_customers.find(cust)
	if idx != -1:
		active_customers.remove_at(idx)
	cust.play_exit_anim(happy)
	for i: int in range(active_customers.size()):
		active_customers[i].move_to_slot(i, _queue_slots[i])


func _on_cauldron_exploded(cauldron_id: int, _unused: int) -> void:
	hearts -= 1
	combo = 0
	EventBus.combo_changed.emit(0, 1.0)
	EventBus.witch_emotion_changed.emit(EventBus.WitchEmotion.HOLLIN_DERROTA, 2.2)
	var caul: KitchenStation = _find_station(StringName("cauldron_%d" % cauldron_id))
	if caul:
		_spawn_popup(caul.global_position + Vector2(0, -70), "¡EXPLOSIÓN DE CALDERO! -1 ♥", Color(1.0, 0.28, 0.25))
	if hearts <= 0:
		_end_run(false, "Tu caldero explotó con el último Corazón de Estabilidad.")


func _finish_day() -> void:
	_set_run_active(false)
	EventBus.day_ended.emit(day_number)
	if day_number >= 8:
		_end_run(true, "¡Completaste los 8 días del Sabbat con éxito!")
		return
	_open_upgrade_draft()


func _open_upgrade_draft() -> void:
	_set_run_active(false)
	var pool: Array[RogueliteUpgradeData] = upgrades_catalog.duplicate()
	pool.shuffle()
	var picks: Array[RogueliteUpgradeData] = []
	for i: int in range(mini(3, pool.size())):
		picks.append(pool[i])
	hud.show_draft_modal(picks, reroll_cost, gold >= reroll_cost)


func _on_reroll_requested() -> void:
	if gold < reroll_cost:
		return
	gold -= reroll_cost
	reroll_cost += 20
	EventBus.gold_changed.emit(gold, -reroll_cost)
	_open_upgrade_draft()


func _on_upgrade_chosen(upg: RogueliteUpgradeData) -> void:
	acquired_upgrades[upg.display_name] = int(acquired_upgrades.get(upg.display_name, 0)) + 1
	EventBus.upgrade_selected.emit(upg.upgrade_id)

	var params: Dictionary = upg.effect_params
	if params.has("familiar_type"):
		spawn_familiar(String(params["familiar_type"]))
	if params.has("speed_bonus"):
		witch.move_speed_mult += float(params["speed_bonus"])
	if params.has("carry_bonus"):
		witch.carry_bonus += int(params["carry_bonus"])
	if params.has("instant_bottle"):
		witch.instant_bottle_enabled = true
	if params.has("clone_on_hot"):
		mirror_clone_enabled = true

	_set_run_active(true)
	_start_day(day_number + 1)


func spawn_familiar(familiar_type: String) -> FamiliarEntity:
	var fam: FamiliarEntity = FamiliarEntity.new()
	fam.position = witch.position + Vector2(-70, -40)
	add_child(fam)
	fam.configure(
		familiar_type,
		stations,
		func() -> Array: return active_customers,
		recipes_catalog,
		day_number,
		func(cust: CustomerEntity, rec_id: StringName, hot: bool) -> void:
			_on_potion_delivered(cust, rec_id, hot)
	)
	active_familiars.append(fam)
	return fam


func _on_witch_switch_requested(witch_id: StringName) -> void:
	for i: int in range(witches.size()):
		if witches[i].witch_id == witch_id:
			_selected_witch_idx = i
			_start_new_run()
			return


func _end_run(victory: bool, reason_text: String) -> void:
	_set_run_active(false)
	var essence: int = day_number * 25 + int(gold / 10)
	EventBus.run_ended.emit(victory, StringName(reason_text), essence)
	hud.show_end_screen(victory, reason_text, essence)


func _set_run_active(active: bool) -> void:
	run_active = active
	EventBus.timers_paused = not active


func _toggle_fullscreen() -> void:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _on_seismic_mortar() -> void:
	for st: KitchenStation in stations:
		if st.station_type == KitchenStation.StationType.CAULDRON and st.cauldron_state == KitchenStation.CauldronState.BREWING:
			st.brew_elapsed += st.brew_duration * 0.25


func _build_kitchen_stations() -> void:
	# Layout accurately mirroring stash/imagen3.jpeg
	_add_station(&"bin_red", KitchenStation.StationType.INGREDIENT_BIN, &"red", "Hierba Ignis", Vector2(230, 740), -1, Color(0.95, 0.24, 0.30))
	_add_station(&"bin_blue", KitchenStation.StationType.INGREDIENT_BIN, &"blue", "Cristal Cryo", Vector2(365, 740), -1, Color(0.24, 0.65, 1.0))
	_add_station(&"bin_green", KitchenStation.StationType.INGREDIENT_BIN, &"green", "Savia Silvestre", Vector2(500, 740), -1, Color(0.22, 0.88, 0.45))
	_add_station(&"mortar", KitchenStation.StationType.MORTAR, &"", "Mortero", Vector2(735, 290), -1, Color(0.85, 0.78, 0.7))
	_add_station(&"cauldron_0", KitchenStation.StationType.CAULDRON, &"", "Caldero 1", Vector2(380, 390), 0, Color(0.6, 0.3, 0.9))
	_add_station(&"cauldron_1", KitchenStation.StationType.CAULDRON, &"", "Caldero 2", Vector2(550, 320), 1, Color(0.6, 0.3, 0.9))
	_add_station(&"bottling", KitchenStation.StationType.BOTTLING, &"", "Embotellado", Vector2(1070, 290), -1, Color(0.55, 0.9, 1.0))
	_add_station(&"display_stand", KitchenStation.StationType.DISPLAY_STAND, &"", "Vitrina", Vector2(1070, 540), -1, Color(0.95, 0.80, 0.35))
	_add_station(&"trash", KitchenStation.StationType.TRASH, &"", "Basura", Vector2(720, 820), -1, Color(0.45, 0.4, 0.5))


func _get_wanted_recipes() -> Array[StringName]:
	var list: Array[StringName] = []
	for cust: CustomerEntity in active_customers:
		if is_instance_valid(cust) and not cust.is_served and cust.order_revealed and cust.requested_recipe != null:
			list.append(cust.requested_recipe.recipe_id)
	return list


func _add_station(st_id: StringName, st_type: KitchenStation.StationType, ing: StringName, label_txt: String, pos: Vector2, c_idx: int, col: Color) -> void:
	var st: KitchenStation = KitchenStation.new()
	st.station_id = st_id
	st.station_type = st_type
	st.ingredient_id = ing
	st.display_label = label_txt
	st.cauldron_index = c_idx
	st.accent_color = col
	st.position = pos
	st.station_clicked.connect(_on_station_clicked)
	add_child(st)
	stations.append(st)


func _find_station(st_id: StringName) -> KitchenStation:
	for st: KitchenStation in stations:
		if st.station_id == st_id:
			return st
	return null


func _spawn_popup(world_pos: Vector2, txt: String, col: Color) -> void:
	_popups.append({
		"pos": world_pos,
		"text": txt,
		"color": col,
		"life": 1.15,
	})


func _update_popups(delta: float) -> void:
	var idx: int = 0
	while idx < _popups.size():
		_popups[idx]["life"] = float(_popups[idx]["life"]) - delta
		_popups[idx]["pos"] = (_popups[idx]["pos"] as Vector2) + Vector2(0, -34.0 * delta)
		if float(_popups[idx]["life"]) <= 0.0:
			_popups.remove_at(idx)
			continue
		idx += 1


func _draw() -> void:
	# Cozy dark wooden walls + stone flagstone 2.5D floor
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.20, 0.14, 0.16))
	draw_rect(Rect2(0, 0, 1920, 220), Color(0.32, 0.21, 0.17))
	draw_rect(Rect2(120, 220, 1680, 780), Color(0.43, 0.37, 0.36))
	# Stone tiles grid hint
	for gx: int in range(120, 1800, 120):
		draw_line(Vector2(gx, 220), Vector2(gx, 1000), Color(0.33, 0.28, 0.29, 0.5), 2.0)
	for gy: int in range(220, 1000, 90):
		draw_line(Vector2(120, gy), Vector2(1800, gy), Color(0.33, 0.28, 0.29, 0.5), 2.0)

	# Service Counter separating kitchen & customer line (Right)
	var counter_rect: Rect2 = Rect2(1250, 240, 72, 460)
	draw_rect(Rect2(1258, 248, 72, 464), Color(0, 0, 0, 0.3))
	draw_rect(counter_rect, Color(0.48, 0.30, 0.20))
	draw_rect(counter_rect, Color(0.11, 0.08, 0.14), false, 3.5)

	# Floating juice popups
	var font: Font = ThemeDB.fallback_font
	for p: Dictionary in _popups:
		var pos: Vector2 = p["pos"] as Vector2
		var txt: String = p["text"] as String
		var col: Color = p["color"] as Color
		var alpha: float = clampf(float(p["life"]), 0.0, 1.0)
		draw_string(font, pos + Vector2(2, 2), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(0.05, 0.03, 0.08, alpha))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(col.r, col.g, col.b, alpha))
