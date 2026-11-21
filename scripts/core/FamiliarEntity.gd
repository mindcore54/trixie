class_name FamiliarEntity
extends Node2D
## Autonomous roguelite helper creature (Michi Alado, Diablillo Carmesí, Murciélago Sombrío).

var familiar_type: String = "michi_alado"
var move_speed: float = 290.0
var work_cooldown: float = 0.0
var speed_buff_mult: float = 1.0

var _stations: Array[KitchenStation] = []
var _customers_provider: Callable
var _recipes: Array[PotionRecipeData] = []
var _unlocked_day: int = 1
var _carrying_item: String = ""
var _target_pos: Vector2 = Vector2.ZERO
var _hover_time: float = 0.0
var _on_deliver_callback: Callable
var _status_hint: String = ""
var _is_blocked: bool = false


func configure(
	type_id: String,
	stations: Array[KitchenStation],
	customers_getter: Callable,
	recipes: Array[PotionRecipeData],
	day_num: int,
	deliver_cb: Callable
) -> void:
	familiar_type = type_id
	_stations = stations
	_customers_provider = customers_getter
	_recipes = recipes
	_unlocked_day = day_num
	_on_deliver_callback = deliver_cb
	_target_pos = global_position


func _process(delta: float) -> void:
	_hover_time += delta
	if EventBus.timers_paused:
		queue_redraw()
		return
	if work_cooldown > 0.0:
		work_cooldown -= delta
	else:
		_decide_and_act()

	var dist: float = global_position.distance_to(_target_pos)
	if dist > 6.0:
		global_position = global_position.move_toward(_target_pos, move_speed * speed_buff_mult * delta)
	queue_redraw()


func _decide_and_act() -> void:
	match familiar_type:
		"michi_alado":
			_act_michi()
		"diablillo_carmesi":
			_act_diablillo()
		"murcielago_sombrio":
			_act_murcielago()


func _act_michi() -> void:
	var best_cauldron: KitchenStation = null
	for st: KitchenStation in _stations:
		if st.station_type != KitchenStation.StationType.CAULDRON:
			continue
		st.familiar_protected = true
		if st.cauldron_state == KitchenStation.CauldronState.BREWING:
			best_cauldron = st
			break
		if best_cauldron == null:
			best_cauldron = st
	if best_cauldron != null:
		_target_pos = best_cauldron.global_position + Vector2(36, -24)
		_status_hint = "Cuidando" if best_cauldron.cauldron_state != KitchenStation.CauldronState.BREWING else "Revolviendo"
		if global_position.distance_to(_target_pos) <= 18.0 and best_cauldron.cauldron_state == KitchenStation.CauldronState.BREWING:
			best_cauldron.stir_cauldron()
			work_cooldown = 1.1 / speed_buff_mult


func _act_diablillo() -> void:
	_is_blocked = false
	var customers: Array = _customers_provider.call() if _customers_provider.is_valid() else []
	if customers.is_empty():
		_status_hint = ""
		return
	var raw_c0: Variant = customers[0]
	if not is_instance_valid(raw_c0) or not (raw_c0 is CustomerEntity):
		return
	var target_cust: CustomerEntity = raw_c0 as CustomerEntity
	if target_cust.requested_recipe == null:
		return

	if _carrying_item == "":
		var needed_ing: StringName = _find_missing_ingredient_for(target_cust.requested_recipe)
		if needed_ing == &"":
			_status_hint = ""
			return
		for st: KitchenStation in _stations:
			if st.station_type == KitchenStation.StationType.INGREDIENT_BIN and (st.ingredient_id == needed_ing or ("crushed_" + String(st.ingredient_id)) == String(needed_ing)):
				if not st.has_ingredient_stock():
					_is_blocked = true
					_status_hint = ""
					return
				_target_pos = st.global_position + Vector2(0, -20)
				_status_hint = "Buscando ing."
				if global_position.distance_to(_target_pos) <= 18.0:
					if st.consume_ingredient_stock():
						_carrying_item = String(needed_ing)
						work_cooldown = 0.45 / speed_buff_mult
				return
	else:
		for st: KitchenStation in _stations:
			if st.station_type == KitchenStation.StationType.CAULDRON and st.can_accept_ingredient(StringName(_carrying_item)):
				_target_pos = st.global_position + Vector2(-28, -20)
				_status_hint = "Llevando ing."
				if global_position.distance_to(_target_pos) <= 22.0:
					st.add_ingredient(StringName(_carrying_item))
					_carrying_item = ""
					work_cooldown = 0.6 / speed_buff_mult
				return
		_carrying_item = ""


func _act_murcielago() -> void:
	_is_blocked = false
	var bottling_st: KitchenStation = _find_station_by_type(KitchenStation.StationType.BOTTLING)
	var display_st: KitchenStation = _find_station_by_type(KitchenStation.StationType.DISPLAY_STAND)
	var customers: Array = _customers_provider.call() if _customers_provider.is_valid() else []

	# 1. Carrying an unsealed potion from cauldron -> MUST fly to Bottling station first
	if _carrying_item.begins_with("raw:"):
		if bottling_st == null:
			_carrying_item = "bot:" + _carrying_item.substr(4)
			return
		_target_pos = bottling_st.global_position + Vector2(0, -28)
		_status_hint = "Embotellando"
		if global_position.distance_to(_target_pos) <= 24.0:
			_carrying_item = "bot:" + _carrying_item.substr(4)
			work_cooldown = 0.35 / speed_buff_mult
		return

	# 2. Carrying a bottled potion -> Deliver to matching customer, OR drop in Bottling (fallback Vitrina) so it never stalls
	if _carrying_item.begins_with("bot:"):
		var parts: PackedStringArray = _carrying_item.split(":")
		if parts.size() < 3:
			_carrying_item = ""
			return
		var recipe_id: StringName = StringName(parts[1])
		var hot_flag: bool = parts[2] == "1"
		var target_cust: CustomerEntity = _find_customer_wanting(customers, recipe_id)
		if target_cust != null:
			_target_pos = target_cust.global_position + Vector2(-50, 0)
			_status_hint = "Entregando"
			if global_position.distance_to(_target_pos) <= 26.0:
				if _on_deliver_callback.is_valid():
					_on_deliver_callback.call(target_cust, recipe_id, hot_flag)
				_carrying_item = ""
				_status_hint = ""
				work_cooldown = 0.45 / speed_buff_mult
			return

		# Nobody wants this potion right now -> store in Bottling slots (2/2) or Vitrina (2/2) so Bat can pick another
		if bottling_st != null and bottling_st.has_free_bottling_slot():
			_target_pos = bottling_st.global_position + Vector2(0, -28)
			_status_hint = "Guardando"
			if global_position.distance_to(_target_pos) <= 24.0:
				if bottling_st.store_bottled_any_slot(_carrying_item):
					_carrying_item = ""
					_status_hint = ""
					work_cooldown = 0.3 / speed_buff_mult
			return

		if display_st != null:
			var free_disp: int = _find_free_display_slot(display_st)
			if free_disp != -1:
				_target_pos = display_st.global_position + Vector2(0, -28)
				_status_hint = "A Vitrina"
				if global_position.distance_to(_target_pos) <= 24.0:
					if display_st.store_potion_in_slot(free_disp, _carrying_item):
						_carrying_item = ""
						_status_hint = ""
						work_cooldown = 0.3 / speed_buff_mult
				return

		# All storage full -> hover near Bottling sweating nervously (visual-only blocked animation)
		if bottling_st != null:
			_target_pos = bottling_st.global_position + Vector2(0, -56)
		_is_blocked = true
		_status_hint = ""
		return

	# 3. Empty hands -> Priority A: pick a wanted bottled potion from Vitrina (Display Stand)
	if display_st != null:
		var match_disp_slot: int = _find_wanted_slot(display_st.display_slots, customers)
		if match_disp_slot != -1:
			_target_pos = display_st.global_position + (Vector2(-2, -6) if match_disp_slot == 0 else Vector2(1, 50))
			_status_hint = "De Vitrina"
			if global_position.distance_to(_target_pos) <= 24.0:
				var picked: String = display_st.take_potion_from_slot(match_disp_slot)
				if picked != "":
					_carrying_item = picked
					work_cooldown = 0.25 / speed_buff_mult
			return

	# Priority B: pick a wanted bottled potion already stored on Bottling station
	if bottling_st != null:
		var match_bot_slot: int = _find_wanted_slot(bottling_st.bottling_slots, customers)
		if match_bot_slot != -1:
			_target_pos = bottling_st.global_position + Vector2(-35 + match_bot_slot * 70, 12)
			_status_hint = "De Embotellado"
			if global_position.distance_to(_target_pos) <= 24.0:
				var picked_b: String = bottling_st.take_bottled_from_slot(match_bot_slot)
				if picked_b != "":
					_carrying_item = picked_b
					work_cooldown = 0.25 / speed_buff_mult
			return

	# Priority C: pick a ready potion from a Cauldron (preferring wanted recipes, or any ready cauldron if storage has room)
	var chosen_cauldron: KitchenStation = null
	var has_storage_room: bool = (bottling_st != null and bottling_st.has_free_bottling_slot()) or (display_st != null and _find_free_display_slot(display_st) != -1)
	for st: KitchenStation in _stations:
		if st.station_type != KitchenStation.StationType.CAULDRON:
			continue
		if st.cauldron_state != KitchenStation.CauldronState.READY and st.cauldron_state != KitchenStation.CauldronState.OVERBOIL_WARNING:
			continue
		if st.active_recipe != null and _find_customer_wanting(customers, st.active_recipe.recipe_id) != null:
			chosen_cauldron = st
			break
		if chosen_cauldron == null and (has_storage_room or st.cauldron_state == KitchenStation.CauldronState.OVERBOIL_WARNING):
			chosen_cauldron = st

	if chosen_cauldron != null:
		_target_pos = chosen_cauldron.global_position + Vector2(0, -32)
		_status_hint = "De Caldero"
		if global_position.distance_to(_target_pos) <= 24.0:
			var res: Dictionary = chosen_cauldron.take_ready_potion()
			if not res.is_empty():
				var r: PotionRecipeData = res["recipe"] as PotionRecipeData
				var hot_flag: bool = res["is_hot"] as bool
				var mortar_flag: bool = res.get("is_mortar", false) as bool
				_carrying_item = "raw:%s:%s:%s" % [String(r.recipe_id), "1" if hot_flag else "0", "1" if mortar_flag else "0"]
				work_cooldown = 0.3 / speed_buff_mult
		return

	# Idle hover near Bottling station
	if bottling_st != null:
		_target_pos = bottling_st.global_position + Vector2(0, -64)
	_status_hint = ""


func _find_station_by_type(st_type: KitchenStation.StationType) -> KitchenStation:
	for st: KitchenStation in _stations:
		if st.station_type == st_type:
			return st
	return null


func _find_customer_wanting(customers: Array, recipe_id: StringName) -> CustomerEntity:
	for c_var: Variant in customers:
		if not is_instance_valid(c_var) or not (c_var is CustomerEntity):
			continue
		var cust: CustomerEntity = c_var as CustomerEntity
		if not cust.is_served and cust.order_revealed and cust.requested_recipe != null and cust.requested_recipe.recipe_id == recipe_id:
			return cust
	return null


func _find_wanted_slot(slots: Array[String], customers: Array) -> int:
	for i: int in range(slots.size()):
		var item: String = slots[i]
		if item == "" or not item.begins_with("bot:"):
			continue
		var parts: PackedStringArray = item.split(":")
		if parts.size() >= 2 and _find_customer_wanting(customers, StringName(parts[1])) != null:
			return i
	return -1


func _find_free_display_slot(display_st: KitchenStation) -> int:
	for i: int in range(KitchenStation.MAX_DISPLAY_SLOTS):
		if not display_st.is_slot_occupied(i):
			return i
	return -1


func _find_missing_ingredient_for(recipe: PotionRecipeData) -> StringName:
	for st: KitchenStation in _stations:
		if st.station_type == KitchenStation.StationType.CAULDRON and st.cauldron_state == KitchenStation.CauldronState.IDLE:
			for req: StringName in recipe.required_ingredients:
				if not st.held_ingredients.has(req) and st.can_accept_ingredient(req):
					return req
	return &""


func _draw() -> void:
	var float_y: float = sin(_hover_time * 7.0) * 6.0
	var tremble_x: float = sin(_hover_time * 38.0) * 2.2 if _is_blocked else 0.0
	var flap: float = sin(_hover_time * (24.0 if _is_blocked else 16.0)) * 5.0
	var col: Color = Color(0.15, 0.14, 0.20)
	if familiar_type == "diablillo_carmesi":
		col = Color(0.88, 0.20, 0.28)
	elif familiar_type == "murcielago_sombrio":
		col = Color(0.45, 0.24, 0.68)

	# Wings
	draw_colored_polygon(PackedVector2Array([Vector2(-6 + tremble_x, float_y), Vector2(-24 + tremble_x, -10 + flap + float_y), Vector2(-18 + tremble_x, 6 + float_y)]), col.lightened(0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(6 + tremble_x, float_y), Vector2(24 + tremble_x, -10 + flap + float_y), Vector2(18 + tremble_x, 6 + float_y)]), col.lightened(0.2))
	# Cute body & glowing yellow eyes
	draw_circle(Vector2(tremble_x, float_y), 12.0, col)
	draw_circle(Vector2(tremble_x, float_y), 12.0, Color(0.08, 0.06, 0.1), false, 2.0)
	draw_circle(Vector2(-4 + tremble_x, -2 + float_y), 2.5, Color(1.0, 0.88, 0.2))
	draw_circle(Vector2(4 + tremble_x, -2 + float_y), 2.5, Color(1.0, 0.88, 0.2))

	# Animated anime sweat drop when blocked (e.g. Bat has no free Bottling/Vitrina slot)
	if _is_blocked:
		var drop_cycle: float = fmod(_hover_time * 1.9, 1.0)
		var drop_y: float = -16.0 + float_y + drop_cycle * 14.0
		var drop_alpha: float = 1.0 - maxf(0.0, (drop_cycle - 0.7) / 0.3)
		var drop_x: float = 13.0 + tremble_x
		var drop_pts: PackedVector2Array = PackedVector2Array([
			Vector2(drop_x, drop_y - 6.5),
			Vector2(drop_x + 4.2, drop_y + 1.5),
			Vector2(drop_x, drop_y + 5.0),
			Vector2(drop_x - 4.2, drop_y + 1.5),
		])
		draw_colored_polygon(drop_pts, Color(0.42, 0.86, 1.0, drop_alpha))
		draw_polyline(drop_pts + PackedVector2Array([drop_pts[0]]), Color(0.10, 0.26, 0.48, drop_alpha), 1.4)
		draw_circle(Vector2(drop_x - 1.2, drop_y + 0.5), 1.2, Color(1.0, 1.0, 1.0, drop_alpha * 0.85))
		# Second smaller effort puff on left side
		var puff_cycle: float = fmod(_hover_time * 1.9 + 0.5, 1.0)
		var puff_alpha: float = (1.0 - puff_cycle) * 0.8
		draw_circle(Vector2(-15.0 + tremble_x, -12.0 + float_y - puff_cycle * 8.0), 2.6, Color(0.65, 0.92, 1.0, puff_alpha))

	if _carrying_item != "":
		var item_pos: Vector2 = Vector2(0, 17 + float_y)
		if _carrying_item.begins_with("raw:") or _carrying_item.begins_with("bot:"):
			var is_bot: bool = _carrying_item.begins_with("bot:")
			var parts: PackedStringArray = _carrying_item.split(":")
			var r_id: String = parts[1] if parts.size() > 1 else ""
			var p_col: Color = WitchController._recipe_color_hint(r_id)
			draw_circle(item_pos, 8.5, p_col)
			draw_circle(item_pos, 8.5, Color(0.95, 0.98, 1.0) if is_bot else Color(0.12, 0.09, 0.14), false, 2.5 if is_bot else 1.8)
			if is_bot:
				draw_rect(Rect2(item_pos.x - 3, item_pos.y - 13, 6, 5), Color(0.76, 0.52, 0.30))
		else:
			draw_circle(item_pos, 7.0, KitchenStation._ingredient_color(StringName(_carrying_item)))
			draw_circle(item_pos, 7.0, Color(0.1, 0.08, 0.14), false, 1.6)

	if _status_hint != "":
		var font: Font = ThemeDB.fallback_font
		var sz: Vector2 = font.get_string_size(_status_hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		draw_string(font, Vector2(-sz.x * 0.5 + 1.0, -18.0 + float_y + 1.0), _status_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.05, 0.03, 0.08, 0.9))
		draw_string(font, Vector2(-sz.x * 0.5, -18.0 + float_y), _status_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.98, 0.94, 0.78))
