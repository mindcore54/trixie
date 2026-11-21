class_name MainGame
extends Node2D
## Coordinates the 2.5D potion kitchen arena, wave director, customers, familiars,
## floating juice popups, roguelite upgrades, and HUD.

const MAX_CUSTOMERS_IN_QUEUE: int = 5
const COMBO_WINDOW_SEC: float = 15.0
const DAY_DURATION_SEC: float = 300.0
const MAX_FAMILIAR_SLOTS: int = 1
const MAX_PASSIVE_SLOTS: int = 3
const MAX_ACTIVE_SLOTS: int = 3
const KITCHEN_BG_TEX_PATH: String = "res://assets/backgrounds/kitchen_bg.jpg"
const KITCHEN_DESK_TEX_PATH: String = "res://assets/backgrounds/kitchen_desk.png"
const KITCHEN_DESK_POS: Vector2 = Vector2(1170.0, 353.0)
const BINS_TABLE_TEX_PATH: String = "res://assets/props/stations/station_bins_table_empty.png"
const BINS_TABLE_POS: Vector2 = Vector2(360.0, 905.0)

enum TutorialStep {
	NONE,
	PICK_INGREDIENT,
	ADD_TO_CAULDRON,
	STIR_OR_COLLECT,
	BOTTLE_POTION,
	DELIVER_CUSTOMER,
	RESTOCK_DOOR,
	RESTOCK_PICK_CRATE,
	RESTOCK_RETURN,
	RESTOCK_POUR,
}

var witches: Array[WitchCharacterData] = []
var customers_catalog: Array[CustomerArchetypeData] = []
var recipes_catalog: Array[PotionRecipeData] = []
var upgrades_catalog: Array[RogueliteUpgradeData] = []

var stations: Array[KitchenStation] = []
var active_customers: Array[CustomerEntity] = []
var active_familiars: Array[FamiliarEntity] = []
var acquired_upgrades: Dictionary = {}
var upgrade_levels: Dictionary = {}
var equipped_familiar_ids: Array[StringName] = []
var equipped_passive_ids: Array[StringName] = []
var equipped_active_ids: Array[StringName] = []
var active_skill_cooldowns: Dictionary = {}
var seismic_mortar_boost: float = 0.25
var build_levels: Dictionary = {
	"move_speed": 0,
	"brew_speed": 0,
	"cauldron_grace": 0,
	"gold_tips": 0,
	"ability_cdr": 0,
	"extra_heart": 0,
}
var unlocked_witch_ids: Array[StringName] = [&"trixie"]
var customer_affinity: Dictionary = {}

var witch: WitchController
var hud: KitchenHUD
var camera: Camera2D

var day_number: int = 1
var day_time_left: float = DAY_DURATION_SEC
var shop_closing: bool = false
var rush_hour_active: bool = false
var current_room: StringName = &"kitchen"
var _camera_tween: Tween
var spawn_timer: float = 2.0
var _tutorial_step: TutorialStep = TutorialStep.NONE
var _first_potion_tutorial_done: bool = false
var _restock_tutorial_done: bool = false
var _tutorial_restock_ing: StringName = &""
var _tutorial_target_pos: Vector2 = Vector2.ZERO
var _tutorial_has_target: bool = false
var _tutorial_pulse_time: float = 0.0
var gold: int = 0
var xp_level: int = 1
var current_xp: int = 0
var xp_to_next_level: int = 80
var _pending_level_drafts: int = 0
var combo: int = 0
var combo_timer: float = 0.0
var hearts: int = 3
var max_hearts: int = 3
var reroll_cost: int = 35
var run_active: bool = true
var mirror_clone_enabled: bool = false
var mirror_clone_chance: float = 0.0
var _selected_witch_idx: int = 0
var _popups: Array[Dictionary] = []
var _kitchen_bg_tex: Texture2D = null
var _kitchen_desk_tex: Texture2D = null
var _customers_layer: Node2D
var _desk_sprite: Sprite2D
var _kitchen_layer: Node2D
var _bins_table_sprite: Sprite2D
var _familiars_layer: Node2D
var _world_overlay: Node2D

var _queue_slots: Array[Vector2] = [
	Vector2(1415, 650),
	Vector2(1400, 575),
	Vector2(1385, 505),
	Vector2(1385, 440),
	Vector2(1420, 385),
]


func _ready() -> void:
	_kitchen_bg_tex = load(KITCHEN_BG_TEX_PATH) as Texture2D
	_kitchen_desk_tex = load(KITCHEN_DESK_TEX_PATH) as Texture2D
	witches = GameCatalog.get_witches()
	_selected_witch_idx = _find_witch_index(&"trixie")
	customers_catalog = GameCatalog.get_customers()
	recipes_catalog = GameCatalog.get_recipes()
	upgrades_catalog = GameCatalog.get_upgrades()

	camera = Camera2D.new()
	camera.position = Vector2(960, 540)
	add_child(camera)
	AudioJuiceManager.register_camera(camera)

	# 2.5D depth layers: customers behind desk -> desk cutout -> kitchen Y-sort -> flying familiars -> popups/tutorial
	_customers_layer = Node2D.new()
	_customers_layer.y_sort_enabled = true
	_customers_layer.z_index = 1
	add_child(_customers_layer)

	_desk_sprite = Sprite2D.new()
	_desk_sprite.texture = _kitchen_desk_tex
	_desk_sprite.centered = false
	_desk_sprite.position = KITCHEN_DESK_POS
	_desk_sprite.z_index = 2
	_desk_sprite.visible = _kitchen_bg_tex != null and _kitchen_desk_tex != null
	add_child(_desk_sprite)

	_kitchen_layer = Node2D.new()
	_kitchen_layer.y_sort_enabled = true
	_kitchen_layer.z_index = 3
	add_child(_kitchen_layer)

	var bins_tex: Texture2D = load(BINS_TABLE_TEX_PATH) as Texture2D if ResourceLoader.exists(BINS_TABLE_TEX_PATH) else null
	_bins_table_sprite = Sprite2D.new()
	_bins_table_sprite.texture = bins_tex
	_bins_table_sprite.centered = true
	_bins_table_sprite.position = BINS_TABLE_POS
	_bins_table_sprite.visible = bins_tex != null
	_kitchen_layer.add_child(_bins_table_sprite)

	_familiars_layer = Node2D.new()
	_familiars_layer.z_index = 10
	add_child(_familiars_layer)

	_world_overlay = Node2D.new()
	_world_overlay.z_index = 20
	_world_overlay.draw.connect(_draw_world_overlay)
	add_child(_world_overlay)

	_build_kitchen_stations()

	witch = WitchController.new()
	witch.position = Vector2(740, 640)
	witch.bottling_station_pos = _find_station(&"bottling").global_position
	witch.seismic_mortar_callback = _on_seismic_mortar
	witch.wanted_recipes_getter = _get_wanted_recipes
	witch.potion_delivered_to_customer.connect(_on_potion_delivered)
	witch.popup_requested.connect(_spawn_popup)
	witch.room_transition_requested.connect(_on_room_transition_requested)
	_kitchen_layer.add_child(witch)

	hud = KitchenHUD.new()
	add_child(hud)
	hud.configure_witches(witches, _selected_witch_idx)
	hud.force_draft_requested.connect(_on_force_xp_level_requested)
	hud.force_end_day_requested.connect(_finish_day)
	hud.toggle_fullscreen_requested.connect(_toggle_fullscreen)
	hud.upgrade_chosen.connect(_on_upgrade_chosen)
	hud.reroll_requested.connect(_on_reroll_requested)
	hud.build_upgrade_purchased.connect(_on_build_upgrade_purchased)
	hud.witch_selected_between_days.connect(_on_witch_selected_between_days)
	hud.active_skill_slot_pressed.connect(trigger_equipped_active_skill)
	hud.next_day_requested.connect(_on_next_day_requested)
	hud.restart_run_requested.connect(_restart_run)
	hud.return_to_menu_requested.connect(_return_to_menu)

	EventBus.cauldron_exploded.connect(_on_cauldron_exploded)

	_start_new_run()
	if OS.get_cmdline_user_args().has("--smoke-test"):
		call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var starts_with_trixie_ok: bool = not witches.is_empty() and witches[_selected_witch_idx].witch_id == &"trixie"
	var day_duration_ok: bool = is_equal_approx(DAY_DURATION_SEC, 300.0) and day_time_left > 298.0 and day_time_left <= 300.0
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
		await get_tree().physics_frame
		if gold > 0:
			break

	var xp_after_delivery_ok: bool = current_xp > 0 or xp_level > 1

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
		raw_blocked_ok = raw_blocked_ok and not c1.can_accept_ingredient(&"green")
		c1.finish_instant()
		c1.take_ready_potion()
	var upgrade_ready_ok: bool = raw_blocked_ok

	# Verify Display Stand per-slot pick/place + customer pre-reveal decision
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
		for old_c: CustomerEntity in active_customers:
			if is_instance_valid(old_c):
				old_c.queue_free()
		active_customers.clear()
		_spawn_customer()
		var new_cust: CustomerEntity = active_customers[0] if not active_customers.is_empty() else null
		var hidden_initially: bool = new_cust != null and not new_cust.order_revealed
		for _w: int in range(120):
			await get_tree().physics_frame
			if new_cust != null and new_cust.order_revealed:
				break
		var locked_onto_vitrina: bool = new_cust != null and new_cust.order_revealed and new_cust.tempted_by_display and new_cust.requested_recipe.recipe_id == &"bruma_lunar"
		display_st.store_potion_in_slot(0, "bot:savia_pura:0:0")
		await get_tree().physics_frame
		var stayed_locked: bool = new_cust != null and new_cust.requested_recipe.recipe_id == &"bruma_lunar"
		witch.held_items.clear()
		witch._interact_with_display_stand(display_st, 1)
		var gold_before_disp: int = gold
		witch._try_deliver_to(new_cust)
		var disp_gold_ok: bool = gold > gold_before_disp
		display_ok = picked_both_ok and placed_in_slot1_ok and hidden_initially and locked_onto_vitrina and stayed_locked and disp_gold_ok
		if not display_ok:
			print("DISPLAY DEBUG => picked=%s placed=%s hidden=%s locked=%s stayed=%s gold_ok=%s revealed=%s" % [
				str(picked_both_ok), str(placed_in_slot1_ok), str(hidden_initially), str(locked_onto_vitrina), str(stayed_locked), str(disp_gold_ok), str(new_cust != null and new_cust.order_revealed)
			])
		display_st.clear_display_slots()

	# Clear any organic level-up draft opened by the display delivery before testing explicit XP draft pause
	var botas_upg: RogueliteUpgradeData = null
	for u: RogueliteUpgradeData in upgrades_catalog:
		if u.upgrade_id == &"botas_tacon_arcano":
			botas_upg = u
			break
	var safety_drafts: int = 0
	while not run_active and botas_upg != null and safety_drafts < 5:
		_on_upgrade_chosen(botas_upg)
		safety_drafts += 1

	# Verify XP level-up pauses timers, opens Draft without advancing day, and upgrades skill levels
	cauldron.add_ingredient(&"red")
	var paused_day_before: float = day_time_left
	var paused_brew_before: float = cauldron.brew_elapsed
	var cust_patience_before: float = active_customers[0].patience_remaining if not active_customers.is_empty() else 0.0
	var lvl_before_xp: int = xp_level
	_gain_xp(xp_to_next_level - current_xp)
	for _p: int in range(12):
		await get_tree().physics_frame
	var timers_stayed_paused: bool = (
		EventBus.timers_paused
		and xp_level == lvl_before_xp + 1
		and is_equal_approx(day_time_left, paused_day_before)
		and is_equal_approx(cauldron.brew_elapsed, paused_brew_before)
		and (active_customers.is_empty() or is_equal_approx(active_customers[0].patience_remaining, cust_patience_before))
	)

	var michi_upg: RogueliteUpgradeData = _find_upgrade_by_id(&"michi_alado")
	if michi_upg != null:
		_on_upgrade_chosen(michi_upg)
	await get_tree().process_frame
	var stayed_same_day_ok: bool = day_number == 1 and run_active and int(upgrade_levels.get(&"michi_alado", 0)) == 1 and active_familiars.size() == 1

	# Level up again and upgrade the same skill to Lv. 2
	_gain_xp(xp_to_next_level - current_xp)
	if michi_upg != null:
		_on_upgrade_chosen(michi_upg)
	var skill_leveled_up_ok: bool = int(upgrade_levels.get(&"michi_alado", 0)) == 2 and active_familiars.size() == 1

	# Verify 1 Familiar / 3 Passives / 3 Actives slot limits
	var diablillo_upg: RogueliteUpgradeData = _find_upgrade_by_id(&"diablillo_carmesi")
	var murcielago_upg: RogueliteUpgradeData = _find_upgrade_by_id(&"murcielago_sombrio")
	var familiar_limit_ok: bool = (
		equipped_familiar_ids.size() == 1
		and not can_acquire_or_upgrade_card(diablillo_upg)
		and not can_acquire_or_upgrade_card(murcielago_upg)
		and can_acquire_or_upgrade_card(michi_upg)
	)

	for pid: StringName in [&"botas_tacon_arcano", &"corse_magnetico", &"espejo_duplicador"]:
		if not equipped_passive_ids.has(pid):
			var p_upg: RogueliteUpgradeData = _find_upgrade_by_id(pid)
			if p_upg != null:
				_on_upgrade_chosen(p_upg)
	var mortero_upg: RogueliteUpgradeData = _find_upgrade_by_id(&"mortero_sismico")
	var botas_check: RogueliteUpgradeData = _find_upgrade_by_id(&"botas_tacon_arcano")
	var passive_limit_ok: bool = (
		equipped_passive_ids.size() == 3
		and not can_acquire_or_upgrade_card(mortero_upg)
		and can_acquire_or_upgrade_card(botas_check)
	)

	for aid: StringName in [&"hechizo_ebullicion", &"hechizo_aroma", &"hechizo_paso_astral"]:
		var a_upg: RogueliteUpgradeData = _find_upgrade_by_id(aid)
		if a_upg != null:
			_on_upgrade_chosen(a_upg)
	var oro_upg: RogueliteUpgradeData = _find_upgrade_by_id(&"hechizo_lluvia_oro")
	var active_triggered_ok: bool = trigger_equipped_active_skill(0)
	var active_limit_ok: bool = (
		equipped_active_ids.size() == 3
		and not can_acquire_or_upgrade_card(oro_upg)
		and active_triggered_ok
		and float(active_skill_cooldowns.get(&"hechizo_ebullicion", 0.0)) > 0.0
	)

	# Verify Bat (Murcielago) workflow: cauldron -> raw -> Bottling -> store unwanted in Bottling slot -> pick from Vitrina & deliver
	var bat_flow_ok: bool = false
	var test_bat: FamiliarEntity = spawn_familiar("murcielago_sombrio")
	test_bat.speed_buff_mult = 4.0
	for old_c2: CustomerEntity in active_customers:
		if is_instance_valid(old_c2):
			old_c2.queue_free()
	active_customers.clear()
	bottling.clear_bottling_slots()
	if display_st != null:
		display_st.clear_display_slots()
	cauldron.held_ingredients.clear()
	cauldron.active_recipe = null
	cauldron.cauldron_state = KitchenStation.CauldronState.IDLE
	cauldron.add_ingredient(&"red")
	cauldron.finish_instant()
	test_bat.global_position = cauldron.global_position + Vector2(0, -32)
	var saw_raw_carry: bool = false
	var dropped_in_bottling: bool = false
	for _b: int in range(180):
		await get_tree().physics_frame
		if test_bat._carrying_item.begins_with("raw:"):
			saw_raw_carry = true
		if saw_raw_carry and test_bat._carrying_item == "" and bottling.get_occupied_bottling_count() == 1:
			dropped_in_bottling = true
			break
	var bat_vitrina_ok: bool = false
	if dropped_in_bottling and display_st != null:
		display_st.store_potion_in_slot(0, "bot:savia_pura:0:0")
		_spawn_customer()
		var bat_cust: CustomerEntity = active_customers[0] if not active_customers.is_empty() else null
		for _bw: int in range(120):
			await get_tree().physics_frame
			if bat_cust != null and bat_cust.order_revealed:
				break
		var gold_before_bat: int = gold
		for _bd: int in range(240):
			await get_tree().physics_frame
			if gold > gold_before_bat:
				bat_vitrina_ok = true
				break
		# Clear any organic level-up draft from bat delivery
		var bat_safety: int = 0
		while not run_active and botas_check != null and can_acquire_or_upgrade_card(botas_check) and bat_safety < 5:
			_on_upgrade_chosen(botas_check)
			bat_safety += 1
	bat_flow_ok = saw_raw_carry and dropped_in_bottling and bat_vitrina_ok
	# Verify Bat blocked sweat animation state when Bottling (2/2) and Vitrina (2/2) are full
	for old_cb: CustomerEntity in active_customers:
		if is_instance_valid(old_cb):
			old_cb.queue_free()
	active_customers.clear()
	bottling.clear_bottling_slots()
	bottling.store_bottled_in_slot(0, "bot:elixir_ignis:0:0")
	bottling.store_bottled_in_slot(1, "bot:bruma_lunar:0:0")
	if display_st != null:
		display_st.clear_display_slots()
		display_st.store_potion_in_slot(0, "bot:elixir_ignis:0:0")
		display_st.store_potion_in_slot(1, "bot:bruma_lunar:0:0")
	test_bat._carrying_item = "bot:savia_pura:0:0"
	test_bat.work_cooldown = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	var bat_blocked_ok: bool = test_bat._is_blocked
	active_familiars.erase(test_bat)
	test_bat.queue_free()
	bottling.clear_bottling_slots()
	if display_st != null:
		display_st.clear_display_slots()

	# Verify Ingredient Bin Stock (10 max), Bodega Crate (20), Crate Rack (3 slots), and Crate disappearance at 0
	var bin_red: KitchenStation = _find_station(&"bin_red")
	var crate_rack: KitchenStation = _find_station(&"crate_rack")
	var crate_stock_ok: bool = false
	if bin_red != null and crate_rack != null:
		bin_red.ingredient_stock = 0
		witch.held_items.clear()
		witch.held_items.append("crate:red:20")
		witch._try_refill_bin_with_crate(bin_red)
		var first_refill_ok: bool = bin_red.ingredient_stock == 10 and witch.held_items.size() == 1 and witch.held_items[0] == "crate:red:10"
		witch._interact_with_crate_rack(crate_rack, 0)
		var rack_store_ok: bool = witch.held_items.is_empty() and crate_rack.is_crate_slot_occupied(0)
		witch._interact_with_crate_rack(crate_rack, 0)
		var rack_pick_ok: bool = witch.held_items.size() == 1 and witch.held_items[0] == "crate:red:10" and not crate_rack.is_crate_slot_occupied(0)
		bin_red.ingredient_stock = 0
		witch._try_refill_bin_with_crate(bin_red)
		var crate_vanished_ok: bool = bin_red.ingredient_stock == 10 and witch.held_items.is_empty()
		crate_stock_ok = first_refill_ok and rack_store_ok and rack_pick_ok and crate_vanished_ok

	# Verify Room Transition: Kitchen -> Storage Room -> Kitchen
	_on_room_transition_requested(&"door_to_storage")
	var entered_storage_ok: bool = current_room == &"storage" and witch.global_position.x < 0.0
	_on_room_transition_requested(&"door_to_kitchen")
	var returned_kitchen_ok: bool = current_room == &"kitchen" and witch.global_position.x > 0.0
	var storage_room_ok: bool = entered_storage_ok and returned_kitchen_ok

	# Verify Rush Hour triggers in rush window
	day_time_left = 180.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	var rush_hour_ok: bool = rush_hour_active and storage_room_ok

	# Verify Shop Closing at 00:00: blocks new customers, waits until last customer is served, then opens Build Screen
	var shop_closing_ok: bool = false
	for old_c3: CustomerEntity in active_customers:
		if is_instance_valid(old_c3):
			old_c3.queue_free()
	active_customers.clear()
	_spawn_customer()
	var last_cust: CustomerEntity = active_customers[0] if not active_customers.is_empty() else null
	for _lw: int in range(120):
		await get_tree().physics_frame
		if last_cust != null and last_cust.order_revealed:
			break
	day_time_left = 0.02
	await get_tree().physics_frame
	await get_tree().physics_frame
	var count_before_blocked_spawn: int = active_customers.size()
	_spawn_customer()
	var closing_waits_ok: bool = shop_closing and active_customers.size() == count_before_blocked_spawn and not hud.is_build_screen_visible() and run_active
	if last_cust != null and is_instance_valid(last_cust) and last_cust.requested_recipe != null:
		witch.held_items.clear()
		witch.held_items.append("bot:%s:0:0" % String(last_cust.requested_recipe.recipe_id))
		witch._try_deliver_to(last_cust)
		var close_safety: int = 0
		while not run_active and not hud.is_build_screen_visible() and botas_check != null and can_acquire_or_upgrade_card(botas_check) and close_safety < 5:
			_on_upgrade_chosen(botas_check)
			close_safety += 1
	await get_tree().physics_frame
	await get_tree().physics_frame
	shop_closing_ok = closing_waits_ok and hud.is_build_screen_visible() and not run_active

	var build_screen_ok: bool = hud.is_build_screen_visible() and not run_active
	var gold_before_build: int = gold
	_on_build_upgrade_purchased(&"move_speed")
	var build_purchase_ok: bool = int(build_levels.get("move_speed", 0)) == 1 and gold < gold_before_build
	_on_next_day_requested()
	await get_tree().process_frame
	var day2_persisted_ok: bool = (
		day_number == 2
		and run_active
		and not shop_closing
		and day_time_left > 298.0
		and xp_level >= 3
		and int(upgrade_levels.get(&"michi_alado", 0)) == 2
		and active_familiars.size() == 1
		and equipped_familiar_ids.size() == 1
		and equipped_passive_ids.size() == 3
		and equipped_active_ids.size() == 3
	)

	Engine.time_scale = 1.0
	print("SMOKE STATS => gold=%d combo=%d day=%d xp_lvl=%d familiars=%d starts_trixie=%s day_300s=%s xp_delivery=%s ability_ok=%s max_buf=%d mortar=%s mortar_caul=%s display=%s timers_paused_ok=%s same_day=%s skill_lv2=%s fam_lim=%s pas_lim=%s act_lim=%s bat_flow=%s bat_sweat=%s crate_stock=%s rush=%s shop_close=%s build_screen=%s build_buy=%s day2_persist=%s" % [
		gold, combo, day_number, xp_level, active_familiars.size(), str(starts_with_trixie_ok), str(day_duration_ok), str(xp_after_delivery_ok), str(ability_ok), max_queue_seen, str(mortar_mix_ok), str(upgrade_ready_ok), str(display_ok), str(timers_stayed_paused), str(stayed_same_day_ok), str(skill_leveled_up_ok), str(familiar_limit_ok), str(passive_limit_ok), str(active_limit_ok), str(bat_flow_ok), str(bat_blocked_ok), str(crate_stock_ok), str(rush_hour_ok), str(shop_closing_ok), str(build_screen_ok), str(build_purchase_ok), str(day2_persisted_ok)
	])
	var ok: bool = (
		gold > 0
		and combo >= 1
		and starts_with_trixie_ok
		and day_duration_ok
		and xp_after_delivery_ok
		and ability_ok
		and max_queue_seen <= WitchController.MAX_NEXT_BUFFER
		and mortar_mix_ok
		and upgrade_ready_ok
		and display_ok
		and timers_stayed_paused
		and stayed_same_day_ok
		and skill_leveled_up_ok
		and familiar_limit_ok
		and passive_limit_ok
		and active_limit_ok
		and bat_flow_ok
		and bat_blocked_ok
		and crate_stock_ok
		and rush_hour_ok
		and shop_closing_ok
		and build_screen_ok
		and build_purchase_ok
		and day2_persisted_ok
	)
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
	upgrade_levels.clear()
	equipped_familiar_ids.clear()
	equipped_passive_ids.clear()
	equipped_active_ids.clear()
	active_skill_cooldowns.clear()
	seismic_mortar_boost = 0.25
	build_levels = {
		"move_speed": 0,
		"brew_speed": 0,
		"cauldron_grace": 0,
		"gold_tips": 0,
		"ability_cdr": 0,
		"extra_heart": 0,
	}
	unlocked_witch_ids = [&"trixie"]
	_selected_witch_idx = _find_witch_index(&"trixie")
	mirror_clone_enabled = false
	mirror_clone_chance = 0.0
	witch.move_speed_mult = 1.0
	witch.cooldown_reduction_mult = 1.0
	witch.carry_bonus = 0
	witch.instant_bottle_enabled = false
	witch.seismic_mortar_enabled = false

	var active_w: WitchCharacterData = witches[_selected_witch_idx]
	witch.setup_witch(active_w)
	hud.configure_witches(witches, _selected_witch_idx)
	max_hearts = active_w.max_stability_hearts
	hearts = max_hearts
	gold = 0
	xp_level = 1
	current_xp = 0
	xp_to_next_level = 80
	_pending_level_drafts = 0
	combo = 0
	combo_timer = 0.0
	day_number = 1
	reroll_cost = 35
	_set_run_active(true)
	hud.hide_overlays()
	hud.hide_trixie_dialogue()
	var enable_tut: bool = GameSettings.show_tutorial and not OS.get_cmdline_user_args().has("--smoke-test")
	_first_potion_tutorial_done = not enable_tut
	_restock_tutorial_done = not enable_tut
	_tutorial_step = TutorialStep.NONE
	_tutorial_restock_ing = &""
	_tutorial_has_target = false

	for st: KitchenStation in stations:
		st.familiar_protected = false
		st.has_mortar_bonus = false
		st.held_ingredients.clear()
		st.reset_ingredient_stock()
		st.clear_display_slots()
		st.clear_bottling_slots()
		st.clear_crate_slots()
		st.active_recipe = null
		st.cauldron_state = KitchenStation.CauldronState.IDLE
		st.queue_redraw()

	_start_day(1)
	EventBus.gold_changed.emit(gold, 0)
	EventBus.xp_changed.emit(xp_level, current_xp, xp_to_next_level)
	EventBus.combo_changed.emit(0, 1.0)


func _find_witch_index(target_id: StringName) -> int:
	for i: int in range(witches.size()):
		if witches[i].witch_id == target_id:
			return i
	return 0


func _restart_run() -> void:
	_start_new_run()


func _start_day(day: int) -> void:
	day_number = day
	day_time_left = DAY_DURATION_SEC
	shop_closing = false
	rush_hour_active = false
	current_room = &"kitchen"
	if camera != null:
		camera.position = Vector2(960, 540)
	if witch != null and witch.position.x < 0.0:
		witch.position = Vector2(740, 640)
	spawn_timer = 14.0
	reroll_cost = 35
	for aid: StringName in active_skill_cooldowns.keys():
		active_skill_cooldowns[aid] = 0.0
	var active_w: WitchCharacterData = witches[_selected_witch_idx]
	witch.witch_data = active_w
	hud.configure_witches(witches, _selected_witch_idx)
	var brew_mult: float = active_w.brew_speed_mult + float(build_levels.get("brew_speed", 0)) * 0.10
	var overheat_mult: float = 1.0 + float(build_levels.get("cauldron_grace", 0)) * 0.20
	for st: KitchenStation in stations:
		st.held_ingredients.clear()
		st.active_recipe = null
		st.cauldron_state = KitchenStation.CauldronState.IDLE
		st.is_stirred_hot = false
		st.has_mortar_bonus = false
		st.configure_catalog(recipes_catalog, day_number, brew_mult, overheat_mult)
		st.queue_redraw()
	EventBus.day_started.emit(day_number, day_time_left, day_number == 3 or day_number == 8)
	_spawn_customer()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_ev: InputEventKey = event as InputEventKey
		if key_ev.pressed and not key_ev.echo:
			if key_ev.keycode == KEY_F11:
				_toggle_fullscreen()
				return
			if run_active:
				if key_ev.keycode == KEY_1 or key_ev.keycode == KEY_KP_1:
					trigger_equipped_active_skill(0)
					return
				if key_ev.keycode == KEY_2 or key_ev.keycode == KEY_KP_2:
					trigger_equipped_active_skill(1)
					return
				if key_ev.keycode == KEY_3 or key_ev.keycode == KEY_KP_3:
					trigger_equipped_active_skill(2)
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
	_tutorial_pulse_time += delta
	if _world_overlay != null:
		_world_overlay.queue_redraw()
	if not run_active:
		return

	_update_guided_tutorial()

	if day_time_left > 0.0:
		day_time_left = maxf(0.0, day_time_left - delta)
		if day_time_left <= 0.0 and not shop_closing:
			shop_closing = true
			rush_hour_active = false
			if not active_customers.is_empty():
				_spawn_popup(Vector2(960, 260), "¡TIENDA CERRADA! Atiende a las últimas clientas", Color(1.0, 0.72, 0.25))
		else:
			var in_rush: bool = (day_time_left <= 195.0 and day_time_left > 140.0) or (day_time_left <= 75.0 and day_time_left > 15.0)
			if in_rush != rush_hour_active:
				rush_hour_active = in_rush
				if rush_hour_active:
					spawn_timer = minf(spawn_timer, 1.8)
	for aid: StringName in active_skill_cooldowns.keys():
		var cd_val: float = float(active_skill_cooldowns[aid])
		if cd_val > 0.0:
			active_skill_cooldowns[aid] = maxf(0.0, cd_val - delta)
	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
			EventBus.combo_changed.emit(0, 1.0)

	if not shop_closing:
		if active_customers.is_empty() and spawn_timer > 2.2:
			spawn_timer = 2.2
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_customer()
			var base_interval: float = maxf(7.5, 16.5 - float(day_number - 1) * 1.3)
			spawn_timer = maxf(4.2, base_interval * 0.50) if rush_hour_active else base_interval

	# Check customer patience expirations
	var i: int = 0
	while i < active_customers.size():
		var cust: CustomerEntity = active_customers[i]
		if is_instance_valid(cust) and not cust.is_served and cust.patience_remaining <= 0.0:
			_handle_customer_timeout(cust)
			continue
		i += 1

	if shop_closing and active_customers.is_empty() and run_active:
		_finish_day()

	var relic_names: PackedStringArray = PackedStringArray()
	for k: String in acquired_upgrades.keys():
		relic_names.append("%s Nv.%d" % [k, int(acquired_upgrades[k])])
	var slot_counts: Vector3i = Vector3i(equipped_familiar_ids.size(), equipped_passive_ids.size(), equipped_active_ids.size())
	var active_slots_info: Array[Dictionary] = []
	for aid: StringName in equipped_active_ids:
		var upg: RogueliteUpgradeData = _find_upgrade_by_id(aid)
		active_slots_info.append({
			"id": aid,
			"name": upg.display_name if upg != null else String(aid),
			"level": int(upgrade_levels.get(aid, 1)),
			"cd_left": float(active_skill_cooldowns.get(aid, 0.0)),
		})
	hud.update_runtime_stats(
		day_number,
		day_time_left,
		hearts,
		max_hearts,
		active_customers.size(),
		witch.get_ability_cooldown_ratio(),
		relic_names,
		witch.get_ability_cooldown_seconds_left(),
		slot_counts,
		active_slots_info,
		rush_hour_active
	)
	queue_redraw()


func _spawn_customer() -> void:
	if not run_active or shop_closing:
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
	_customers_layer.add_child(cust)
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
	var tip_build_mult: float = 1.0 + 0.15 * float(build_levels.get("gold_tips", 0))
	var earned: int = int(round(float(recipe.base_gold_value) * hot_mult * mortar_mult * combo_mult * cust_mult * tip_build_mult))
	if witches[_selected_witch_idx].witch_id == &"morrigan":
		earned = int(round(float(earned) * 1.4))

	gold += earned
	EventBus.gold_changed.emit(gold, earned)
	EventBus.combo_changed.emit(combo, combo_mult)

	var base_xp: int = 45 if is_mortar else 35
	var speed_xp: int = int(round(cust.get_patience_ratio() * 25.0))
	var hot_xp: int = 15 if is_hot else 0
	var earned_xp: int = base_xp + speed_xp + hot_xp

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

	var pop_txt: String = "+%dg  +%d XP%s%s" % [earned, earned_xp, " ¡CALIENTE!" if is_hot else "", " ¡MORTERO!" if is_mortar else ""]
	_spawn_popup(cust.global_position + Vector2(-30, -80), pop_txt, Color(1.0, 0.86, 0.25))

	_remove_customer_and_advance_queue(cust, true)

	if not _first_potion_tutorial_done:
		_first_potion_tutorial_done = true
		_set_tutorial_step(TutorialStep.NONE, "¡Lo logré! ¡Mi primera venta real! ¡A seguir así hasta ser la tienda más famosa del pueblo!", "confiada")

	if is_hot and mirror_clone_enabled and randf() <= mirror_clone_chance:
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

	_gain_xp(earned_xp)


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


func _gain_xp(amount: int) -> void:
	if amount <= 0:
		return
	current_xp += amount
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		xp_level += 1
		xp_to_next_level = 80 + (xp_level - 1) * 40
		_pending_level_drafts += 1
	EventBus.xp_changed.emit(xp_level, current_xp, xp_to_next_level)
	if _pending_level_drafts > 0 and run_active:
		_pending_level_drafts -= 1
		_open_upgrade_draft()


func _on_force_xp_level_requested() -> void:
	_gain_xp(maxi(1, xp_to_next_level - current_xp))


func _finish_day() -> void:
	_set_run_active(false)
	for cust: CustomerEntity in active_customers:
		if is_instance_valid(cust):
			cust.queue_free()
	active_customers.clear()
	witch.clear_queue()
	EventBus.day_ended.emit(day_number)
	if day_number >= 8:
		_end_run(true, "¡Completaste los 8 días del Sabbat con éxito!")
		return
	_open_between_days_build_screen()


func _find_upgrade_by_id(target_id: StringName) -> RogueliteUpgradeData:
	for u: RogueliteUpgradeData in upgrades_catalog:
		if u.upgrade_id == target_id:
			return u
	return null


func can_acquire_or_upgrade_card(u: RogueliteUpgradeData) -> bool:
	if u == null:
		return false
	var cur_lvl: int = int(upgrade_levels.get(u.upgrade_id, 0))
	if cur_lvl >= u.max_stacks:
		return false
	if cur_lvl > 0:
		return true
	match u.kind:
		RogueliteUpgradeData.UpgradeKind.FAMILIAR_SUMMON:
			return equipped_familiar_ids.size() < MAX_FAMILIAR_SLOTS
		RogueliteUpgradeData.UpgradeKind.ACTIVE_SKILL:
			return equipped_active_ids.size() < MAX_ACTIVE_SLOTS
		_:
			return equipped_passive_ids.size() < MAX_PASSIVE_SLOTS


func _get_eligible_draft_upgrades() -> Array[RogueliteUpgradeData]:
	var pool: Array[RogueliteUpgradeData] = []
	for u: RogueliteUpgradeData in upgrades_catalog:
		if can_acquire_or_upgrade_card(u):
			pool.append(u)
	return pool


func _open_upgrade_draft() -> void:
	var pool: Array[RogueliteUpgradeData] = _get_eligible_draft_upgrades()
	pool.shuffle()
	var picks: Array[RogueliteUpgradeData] = []
	for i: int in range(mini(3, pool.size())):
		picks.append(pool[i])
	if picks.is_empty():
		_pending_level_drafts = 0
		_spawn_popup(witch.global_position + Vector2(0, -70), "¡Build completa al máximo!", Color(1.0, 0.85, 0.35))
		_set_run_active(true)
		return
	_set_run_active(false)
	var slot_counts: Vector3i = Vector3i(equipped_familiar_ids.size(), equipped_passive_ids.size(), equipped_active_ids.size())
	hud.show_draft_modal(picks, reroll_cost, gold >= reroll_cost, upgrade_levels, xp_level, slot_counts)


func _on_reroll_requested() -> void:
	if gold < reroll_cost:
		return
	gold -= reroll_cost
	reroll_cost += 20
	EventBus.gold_changed.emit(gold, -reroll_cost)
	_open_upgrade_draft()


func _on_upgrade_chosen(upg: RogueliteUpgradeData) -> void:
	if not can_acquire_or_upgrade_card(upg):
		return
	var prev_lvl: int = int(upgrade_levels.get(upg.upgrade_id, 0))
	var new_lvl: int = mini(upg.max_stacks, prev_lvl + 1)
	upgrade_levels[upg.upgrade_id] = new_lvl
	acquired_upgrades[upg.display_name] = new_lvl
	if prev_lvl == 0:
		match upg.kind:
			RogueliteUpgradeData.UpgradeKind.FAMILIAR_SUMMON:
				equipped_familiar_ids.append(upg.upgrade_id)
			RogueliteUpgradeData.UpgradeKind.ACTIVE_SKILL:
				equipped_active_ids.append(upg.upgrade_id)
				active_skill_cooldowns[upg.upgrade_id] = 0.0
			_:
				equipped_passive_ids.append(upg.upgrade_id)
	EventBus.upgrade_selected.emit(upg.upgrade_id)

	var params: Dictionary = upg.effect_params
	if params.has("familiar_type"):
		var ftype: String = String(params["familiar_type"])
		if prev_lvl == 0:
			spawn_familiar(ftype)
		else:
			for f: FamiliarEntity in active_familiars:
				if is_instance_valid(f) and f.familiar_type == ftype:
					f.speed_buff_mult += 0.35
	if params.has("speed_bonus"):
		witch.move_speed_mult += float(params["speed_bonus"])
	if params.has("carry_bonus"):
		witch.carry_bonus += int(params["carry_bonus"])
	if params.has("instant_bottle"):
		witch.instant_bottle_enabled = true
	if params.has("seismic_mortar"):
		witch.seismic_mortar_enabled = true
		var boost_step: float = float(params.get("seismic_boost_per_level", 0.15))
		seismic_mortar_boost = 0.25 + float(new_lvl - 1) * boost_step
	if params.has("clone_on_hot"):
		mirror_clone_enabled = true
		if new_lvl >= 3:
			mirror_clone_chance = 1.0
		elif new_lvl == 2:
			mirror_clone_chance = 0.65
		else:
			mirror_clone_chance = float(params.get("clone_chance_per_level", 0.35))

	if _pending_level_drafts > 0:
		_pending_level_drafts -= 1
		_open_upgrade_draft()
		return

	_set_run_active(true)


func trigger_equipped_active_skill(slot_idx: int) -> bool:
	if not run_active or slot_idx < 0 or slot_idx >= equipped_active_ids.size():
		return false
	var aid: StringName = equipped_active_ids[slot_idx]
	if float(active_skill_cooldowns.get(aid, 0.0)) > 0.0:
		_spawn_popup(witch.global_position + Vector2(0, -64), "¡Habilidad en recarga!", Color(0.95, 0.65, 0.35))
		return false
	var upg: RogueliteUpgradeData = _find_upgrade_by_id(aid)
	if upg == null:
		return false
	var lvl: int = maxi(1, int(upgrade_levels.get(aid, 1)))
	var params: Dictionary = upg.effect_params
	var base_cd: float = float(params.get("base_cd", 18.0))
	var cd_per_lvl: float = float(params.get("cd_per_level", 2.0))
	var final_cd: float = maxf(4.0, (base_cd - float(lvl - 1) * cd_per_lvl) * maxf(0.4, witch.cooldown_reduction_mult))
	active_skill_cooldowns[aid] = final_cd

	var active_type: String = String(params.get("active_type", ""))
	match active_type:
		"instant_brew":
			for st: KitchenStation in stations:
				if st.station_type == KitchenStation.StationType.CAULDRON:
					st.finish_instant()
			_spawn_popup(witch.global_position + Vector2(0, -76), "¡DESTELLO DE EBULLICIÓN!", Color(1.0, 0.48, 0.28))
		"freeze_queue":
			var freeze_sec: float = 6.0 + float(lvl - 1) * 2.0
			for cust: CustomerEntity in active_customers:
				if is_instance_valid(cust) and not cust.is_served:
					cust.freeze_patience(freeze_sec)
			_spawn_popup(witch.global_position + Vector2(0, -76), "¡PERFUME HIPNÓTICO (%.0fs)!" % freeze_sec, Color(0.82, 0.55, 1.0))
		"astral_step":
			var buff_sec: float = 5.0 + float(lvl - 1) * 2.0
			witch.apply_astral_step_buff(buff_sec, 0.70)
			_spawn_popup(witch.global_position + Vector2(0, -76), "¡PASO ASTRAL!", Color(0.42, 0.92, 1.0))
		"gold_alchemy":
			var bonus_gold: int = 25 + (lvl - 1) * 20
			gold += bonus_gold
			combo += 1
			combo_timer = COMBO_WINDOW_SEC
			var combo_mult: float = minf(3.0, 1.0 + float(combo - 1) * 0.15)
			EventBus.gold_changed.emit(gold, bonus_gold)
			EventBus.combo_changed.emit(combo, combo_mult)
			_spawn_popup(witch.global_position + Vector2(0, -76), "¡ALQUIMIA DORADA +%dg!" % bonus_gold, Color(1.0, 0.85, 0.25))

	AudioJuiceManager.play_pentatonic(5, 0.0)
	AudioJuiceManager.trigger_screen_shake(6.0, 0.15)
	EventBus.witch_emotion_changed.emit(EventBus.WitchEmotion.CONFIADA, 1.5)
	return true


func spawn_familiar(familiar_type: String) -> FamiliarEntity:
	var fam: FamiliarEntity = FamiliarEntity.new()
	fam.position = witch.position + Vector2(-70, -40)
	_familiars_layer.add_child(fam)
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


func _open_between_days_build_screen() -> void:
	_set_run_active(false)
	var active_w: WitchCharacterData = witches[_selected_witch_idx]
	var xp_parts: PackedStringArray = PackedStringArray()
	for k: String in acquired_upgrades.keys():
		xp_parts.append("%s (Nv.%d)" % [k, int(acquired_upgrades[k])])
	var summary_txt: String = "Habilidades de XP activas (Nv. %d — se conservan para el Día %d): %s" % [
		xp_level,
		day_number + 1,
		", ".join(xp_parts) if not xp_parts.is_empty() else "Ninguna aún"
	]
	hud.show_between_days_screen(
		day_number,
		gold,
		hearts,
		max_hearts,
		active_w,
		witches,
		unlocked_witch_ids,
		_get_build_options(),
		summary_txt
	)


func _get_build_options() -> Array[Dictionary]:
	var defs: Array[Dictionary] = [
		{"id": &"move_speed", "title": "Botas Ligeras", "desc": "+8% Velocidad al caminar por nivel", "max_level": 5, "base_cost": 40, "step": 25},
		{"id": &"brew_speed", "title": "Llama del Caldero", "desc": "+10% Velocidad de cocción por nivel", "max_level": 5, "base_cost": 45, "step": 30},
		{"id": &"cauldron_grace", "title": "Acero Templado", "desc": "+20% Tiempo antes de explotar por nivel", "max_level": 4, "base_cost": 40, "step": 25},
		{"id": &"gold_tips", "title": "Encanto Comercial", "desc": "+15% Propinas de oro por nivel", "max_level": 5, "base_cost": 50, "step": 35},
		{"id": &"ability_cdr", "title": "Reloj de Arena", "desc": "-12% Recarga de habilidad activa por nivel", "max_level": 4, "base_cost": 50, "step": 35},
		{"id": &"extra_heart", "title": "Corazón de Fénix", "desc": "+1 Corazón máximo y cura 1 ♥", "max_level": 3, "base_cost": 70, "step": 45},
	]
	var out: Array[Dictionary] = []
	for d: Dictionary in defs:
		var bid: String = String(d["id"])
		var lvl: int = int(build_levels.get(bid, 0))
		var cost: int = int(d["base_cost"]) + lvl * int(d["step"])
		out.append({
			"id": d["id"],
			"title": d["title"],
			"desc": d["desc"],
			"level": lvl,
			"max_level": d["max_level"],
			"cost": cost,
		})
	return out


func _on_build_upgrade_purchased(build_id: StringName) -> void:
	for opt: Dictionary in _get_build_options():
		if opt["id"] == build_id:
			var lvl: int = int(opt["level"])
			var max_lvl: int = int(opt["max_level"])
			var cost: int = int(opt["cost"])
			if lvl >= max_lvl or gold < cost:
				return
			gold -= cost
			EventBus.gold_changed.emit(gold, -cost)
			build_levels[String(build_id)] = lvl + 1
			match build_id:
				&"move_speed":
					witch.move_speed_mult += 0.08
				&"ability_cdr":
					witch.cooldown_reduction_mult = maxf(0.4, witch.cooldown_reduction_mult - 0.12)
				&"extra_heart":
					max_hearts += 1
					hearts = mini(max_hearts, hearts + 1)
			_open_between_days_build_screen()
			return


func _on_witch_selected_between_days(witch_id: StringName) -> void:
	if not unlocked_witch_ids.has(witch_id):
		return
	for i: int in range(witches.size()):
		if witches[i].witch_id == witch_id:
			_selected_witch_idx = i
			_open_between_days_build_screen()
			return


func _on_next_day_requested() -> void:
	hud.hide_overlays()
	_set_run_active(true)
	_start_day(day_number + 1)


func _end_run(victory: bool, reason_text: String) -> void:
	_set_run_active(false)
	var essence: int = day_number * 25 + int(gold / 10)
	EventBus.run_ended.emit(victory, StringName(reason_text), essence)
	hud.show_end_screen(victory, reason_text, essence)


func _return_to_menu() -> void:
	if SceneFader.is_busy():
		return
	_set_run_active(false)
	SceneFader.fade_to_scene("res://scenes/ui/MainMenu.tscn", 0.45, 0.45)


func _set_run_active(active: bool) -> void:
	run_active = active
	EventBus.timers_paused = not active


func _set_tutorial_step(new_step: TutorialStep, line: String, emotion: String = "normal") -> void:
	if _tutorial_step == new_step:
		return
	_tutorial_step = new_step
	if new_step == TutorialStep.NONE:
		_tutorial_has_target = false
		if line != "":
			hud.show_trixie_dialogue(line, emotion, 4.8)
		else:
			hud.hide_trixie_dialogue()
	else:
		hud.show_trixie_dialogue(line, emotion, 0.0)


func _update_guided_tutorial() -> void:
	_tutorial_has_target = false

	# Part 1: First potion guided walkthrough on Day 1
	if not _first_potion_tutorial_done:
		if not active_customers.is_empty() and is_instance_valid(active_customers[0]):
			var c0: CustomerEntity = active_customers[0]
			c0.patience_frozen_timer = maxf(c0.patience_frozen_timer, 1.0)
			if spawn_timer < 6.0:
				spawn_timer = 6.0
			if not c0.order_revealed or c0.requested_recipe == null:
				return
			var req_ing: StringName = c0.requested_recipe.required_ingredients[0] if not c0.requested_recipe.required_ingredients.is_empty() else &"red"
			var bin_st: KitchenStation = _find_station(StringName("bin_" + String(req_ing)))
			var caul0: KitchenStation = _find_station(&"cauldron_0")
			var bottle_st: KitchenStation = _find_station(&"bottling")

			var has_bot: bool = false
			var has_raw: bool = false
			var has_ing: bool = false
			for it: String in witch.held_items:
				if it.begins_with("bot:"):
					has_bot = true
				elif it.begins_with("raw:"):
					has_raw = true
				elif it.begins_with("ing:"):
					has_ing = true

			var caul_busy: bool = caul0 != null and (caul0.cauldron_state == KitchenStation.CauldronState.BREWING or caul0.cauldron_state == KitchenStation.CauldronState.READY or caul0.cauldron_state == KitchenStation.CauldronState.OVERBOIL_WARNING)

			if has_bot:
				_set_tutorial_step(TutorialStep.DELIVER_CUSTOMER, "¡Quedó preciosa! Ahora haz clic en la clienta para entregársela.", "sonrojada")
				_tutorial_target_pos = c0.global_position + Vector2(0, -108)
				_tutorial_has_target = true
			elif has_raw:
				_set_tutorial_step(TutorialStep.BOTTLE_POTION, "¡Cuidado que quema! Llévala a la mesa de Embotellado para sellarla en un frasco.", "normal")
				if bottle_st != null:
					_tutorial_target_pos = bottle_st.global_position + Vector2(0, -102)
					_tutorial_has_target = true
			elif caul_busy:
				var caul_msg: String = "¡Ya está lista! Haz clic en el caldero para recogerla antes de que se queme." if caul0.cauldron_state != KitchenStation.CauldronState.BREWING else "¡Mira cómo hierve! Haz clic en el caldero para revolverla (¡CALIENTE! = más oro) y recógela al terminar."
				_set_tutorial_step(TutorialStep.STIR_OR_COLLECT, caul_msg, "confiada")
				_tutorial_target_pos = caul0.global_position + Vector2(0, -108)
				_tutorial_has_target = true
			elif has_ing:
				_set_tutorial_step(TutorialStep.ADD_TO_CAULDRON, "¡Bien! Ahora haz clic en el Caldero para empezar a cocinarla.", "normal")
				if caul0 != null:
					_tutorial_target_pos = caul0.global_position + Vector2(0, -108)
					_tutorial_has_target = true
			else:
				_set_tutorial_step(TutorialStep.PICK_INGREDIENT, "¡Mi primera clienta! Mira qué color pide y haz clic en esa caja para tomar el ingrediente.", "nerviosa")
				if bin_st != null:
					_tutorial_target_pos = bin_st.global_position + Vector2(0, -100)
					_tutorial_has_target = true
		return

	# Part 2: Reactive Storage Restock Tutorial (triggers the first time any ingredient bin reaches 0/10)
	if not _restock_tutorial_done:
		var empty_bin: KitchenStation = null
		if _tutorial_restock_ing != &"":
			empty_bin = _find_station(StringName("bin_" + String(_tutorial_restock_ing)))
			if empty_bin != null and empty_bin.ingredient_stock > 0:
				_restock_tutorial_done = true
				_set_tutorial_step(TutorialStep.NONE, "¡Listo, caja llena otra vez! Si te sobran ingredientes en la caja, déjala en el Estante de Cajas abajo.", "confiada")
				return
		else:
			for st: KitchenStation in stations:
				if st.station_type == KitchenStation.StationType.INGREDIENT_BIN and st.ingredient_stock <= 0:
					empty_bin = st
					_tutorial_restock_ing = st.ingredient_id
					break
		if empty_bin == null:
			return

		var door_storage: KitchenStation = _find_station(&"door_to_storage")
		var door_kitchen: KitchenStation = _find_station(&"door_to_kitchen")
		var supply_st: KitchenStation = _find_station(StringName("supply_" + String(_tutorial_restock_ing)))

		if witch.is_carrying_crate():
			if current_room == &"storage":
				_set_tutorial_step(TutorialStep.RESTOCK_RETURN, "¡Uf, sí que pesa! Vuelve rápido por la puerta de la Cocina.", "nerviosa")
				if door_kitchen != null:
					_tutorial_target_pos = door_kitchen.global_position + Vector2(0, -86)
					_tutorial_has_target = true
			else:
				_set_tutorial_step(TutorialStep.RESTOCK_POUR, "¡Ahora haz clic en la caja vacía para rellenarla! Lo que sobre guárdalo en el Estante de Cajas.", "normal")
				_tutorial_target_pos = empty_bin.global_position + Vector2(0, -100)
				_tutorial_has_target = true
		else:
			if current_room == &"kitchen":
				_set_tutorial_step(TutorialStep.RESTOCK_DOOR, "¡Ay no, se acabó esa caja! Haz clic en la puerta del Almacén a la izquierda para reponer.", "sorprendida")
				if door_storage != null:
					_tutorial_target_pos = door_storage.global_position + Vector2(0, -155)
					_tutorial_has_target = true
			else:
				_set_tutorial_step(TutorialStep.RESTOCK_PICK_CRATE, "Aquí están las cajas grandes de x20. ¡Con las manos vacías, haz clic en la caja del color que falta!", "normal")
				if supply_st != null:
					_tutorial_target_pos = supply_st.global_position + Vector2(0, -62)
					_tutorial_has_target = true


func _toggle_fullscreen() -> void:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _on_seismic_mortar() -> void:
	for st: KitchenStation in stations:
		if st.station_type == KitchenStation.StationType.CAULDRON and st.cauldron_state == KitchenStation.CauldronState.BREWING:
			st.brew_elapsed += st.brew_duration * seismic_mortar_boost


func _on_room_transition_requested(door_id: StringName) -> void:
	if door_id == &"door_to_storage":
		current_room = &"storage"
		witch.global_position = Vector2(-245, 540)
		_pan_camera_to(Vector2(-960, 540))
	elif door_id == &"door_to_kitchen":
		current_room = &"kitchen"
		witch.global_position = Vector2(290, 585)
		_pan_camera_to(Vector2(960, 540))


func _pan_camera_to(target_pos: Vector2) -> void:
	if camera == null:
		return
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.tween_property(camera, "position", target_pos, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _build_kitchen_stations() -> void:
	# Doorway from Kitchen to Storage Room (painted arch on left wall)
	_add_station(&"door_to_storage", KitchenStation.StationType.ROOM_DOOR, &"", "Almacén", Vector2(200, 515), -1, Color(0.86, 0.68, 0.36), true)

	# Separate Storage Room (x = -1920..0): Door back to Kitchen + 3 infinite x20 crate supplies
	_add_station(&"door_to_kitchen", KitchenStation.StationType.ROOM_DOOR, &"", "Cocina", Vector2(-155, 540), -1, Color(0.86, 0.68, 0.36))
	_add_station(&"supply_red", KitchenStation.StationType.SUPPLY_SOURCE, &"red", "Cajas Rojo", Vector2(-1280, 540), -1, Color(0.95, 0.24, 0.30))
	_add_station(&"supply_blue", KitchenStation.StationType.SUPPLY_SOURCE, &"blue", "Cajas Azul", Vector2(-960, 540), -1, Color(0.24, 0.65, 1.0))
	_add_station(&"supply_green", KitchenStation.StationType.SUPPLY_SOURCE, &"green", "Cajas Verde", Vector2(-640, 540), -1, Color(0.22, 0.88, 0.45))

	# Kitchen Layout aligned to 1920x1080 painted kitchen_bg.jpg (v02) + exact 1:1 station sprites:
	# 3 Ingredient Bins aligned to the unified 3-bin wooden table at BINS_TABLE_POS
	_add_station(&"bin_red", KitchenStation.StationType.INGREDIENT_BIN, &"red", "Hierba Ignis", Vector2(221, 905), -1, Color(0.95, 0.24, 0.30))
	_add_station(&"bin_blue", KitchenStation.StationType.INGREDIENT_BIN, &"blue", "Cristal Cryo", Vector2(363, 905), -1, Color(0.24, 0.65, 1.0))
	_add_station(&"bin_green", KitchenStation.StationType.INGREDIENT_BIN, &"green", "Savia Silvestre", Vector2(500, 905), -1, Color(0.22, 0.88, 0.45))
	_add_station(&"crate_rack", KitchenStation.StationType.CRATE_RACK, &"", "Estante Cajas", Vector2(765, 905), -1, Color(0.76, 0.56, 0.32))
	_add_station(&"mortar", KitchenStation.StationType.MORTAR, &"", "Mortero", Vector2(800, 395), -1, Color(0.85, 0.78, 0.7))
	_add_station(&"cauldron_0", KitchenStation.StationType.CAULDRON, &"", "Caldero 1", Vector2(415, 405), 0, Color(0.6, 0.3, 0.9))
	_add_station(&"cauldron_1", KitchenStation.StationType.CAULDRON, &"", "Caldero 2", Vector2(605, 395), 1, Color(0.6, 0.3, 0.9))
	_add_station(&"bottling", KitchenStation.StationType.BOTTLING, &"", "Embotellado", Vector2(1010, 395), -1, Color(0.55, 0.9, 1.0))
	_add_station(&"display_stand", KitchenStation.StationType.DISPLAY_STAND, &"", "Vitrina", Vector2(1242, 434), -1, Color(0.95, 0.80, 0.35))
	_add_station(&"trash", KitchenStation.StationType.TRASH, &"", "Basura", Vector2(1155, 865), -1, Color(0.45, 0.4, 0.5))


func _get_wanted_recipes() -> Array[StringName]:
	var list: Array[StringName] = []
	for cust: CustomerEntity in active_customers:
		if is_instance_valid(cust) and not cust.is_served and cust.order_revealed and cust.requested_recipe != null:
			list.append(cust.requested_recipe.recipe_id)
	return list


func _add_station(st_id: StringName, st_type: KitchenStation.StationType, ing: StringName, label_txt: String, pos: Vector2, c_idx: int, col: Color, use_bg_art: bool = false) -> void:
	var st: KitchenStation = KitchenStation.new()
	st.station_id = st_id
	st.station_type = st_type
	st.ingredient_id = ing
	st.display_label = label_txt
	st.cauldron_index = c_idx
	st.accent_color = col
	st.use_background_art = use_bg_art
	st.position = pos
	st.station_clicked.connect(_on_station_clicked)
	if use_bg_art:
		st.z_index = 1
		add_child(st)
	else:
		_kitchen_layer.add_child(st)
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
	var font: Font = ThemeDB.fallback_font

	# Separate Storage Room (x = -1920..0)
	draw_rect(Rect2(-1920, 0, 1920, 1080), Color(0.14, 0.10, 0.12))
	draw_rect(Rect2(-1920, 0, 1920, 240), Color(0.24, 0.16, 0.13))
	draw_rect(Rect2(-1780, 240, 1660, 740), Color(0.32, 0.25, 0.22))
	for sgy: int in range(240, 980, 74):
		draw_line(Vector2(-1780, sgy), Vector2(-120, sgy), Color(0.24, 0.18, 0.16, 0.55), 2.0)
	draw_string(font, Vector2(-1150, 165), "ALMACÉN DE INGREDIENTES", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.95, 0.84, 0.58, 0.85))

	# Painted 1:1 1920x1080 Kitchen Background (with fallback placeholder geometry)
	if _kitchen_bg_tex != null:
		draw_texture_rect(_kitchen_bg_tex, Rect2(0.0, 0.0, 1920.0, 1080.0), false)
	else:
		# Cozy dark wooden walls + stone flagstone 2.5D floor (Kitchen: x = 0..1920)
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


func _draw_world_overlay() -> void:
	if _world_overlay == null:
		return
	var font: Font = ThemeDB.fallback_font

	# Floating juice popups
	for p: Dictionary in _popups:
		var pos: Vector2 = p["pos"] as Vector2
		var txt: String = p["text"] as String
		var col: Color = p["color"] as Color
		var alpha: float = clampf(float(p["life"]), 0.0, 1.0)
		_world_overlay.draw_string(font, pos + Vector2(2, 2), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(0.05, 0.03, 0.08, alpha))
		_world_overlay.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(col.r, col.g, col.b, alpha))

	# Guided tutorial pulsing golden ring & bouncing arrow over target station/customer
	if _tutorial_has_target and run_active:
		var bob_a: float = sin(_tutorial_pulse_time * 7.0) * 10.0
		var ring_r: float = 34.0 + sin(_tutorial_pulse_time * 5.0) * 5.0
		var tip: Vector2 = _tutorial_target_pos + Vector2(0.0, bob_a)
		_world_overlay.draw_arc(_tutorial_target_pos + Vector2(0.0, 56.0), ring_r, 0.0, TAU, 32, Color(1.0, 0.88, 0.30, 0.92), 4.5)
		var arrow: PackedVector2Array = PackedVector2Array([
			tip + Vector2(0, 18),
			tip + Vector2(-20, -10),
			tip + Vector2(-8, -10),
			tip + Vector2(-8, -32),
			tip + Vector2(8, -32),
			tip + Vector2(8, -10),
			tip + Vector2(20, -10),
		])
		_world_overlay.draw_colored_polygon(arrow, Color(1.0, 0.86, 0.28))
		_world_overlay.draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color(0.10, 0.06, 0.14), 3.0)
