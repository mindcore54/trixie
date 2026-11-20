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

	var dist: float = global_position.distance_to(_target_pos)
	if dist > 10.0:
		global_position = global_position.move_toward(_target_pos, move_speed * speed_buff_mult * delta)
	elif work_cooldown <= 0.0:
		_decide_and_act()
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
		if global_position.distance_to(_target_pos) <= 18.0 and best_cauldron.cauldron_state == KitchenStation.CauldronState.BREWING:
			best_cauldron.stir_cauldron()
			work_cooldown = 1.1 / speed_buff_mult


func _act_diablillo() -> void:
	var customers: Array = _customers_provider.call() if _customers_provider.is_valid() else []
	if customers.is_empty():
		return
	var target_cust: CustomerEntity = customers[0] as CustomerEntity
	if target_cust == null or target_cust.requested_recipe == null:
		return

	if _carrying_item == "":
		var needed_ing: StringName = _find_missing_ingredient_for(target_cust.requested_recipe)
		if needed_ing == &"":
			return
		for st: KitchenStation in _stations:
			if st.station_type == KitchenStation.StationType.INGREDIENT_BIN and (st.ingredient_id == needed_ing or ("crushed_" + String(st.ingredient_id)) == String(needed_ing)):
				_target_pos = st.global_position + Vector2(0, -20)
				if global_position.distance_to(_target_pos) <= 18.0:
					_carrying_item = String(needed_ing)
					work_cooldown = 0.45 / speed_buff_mult
				return
	else:
		for st: KitchenStation in _stations:
			if st.station_type == KitchenStation.StationType.CAULDRON and st.can_accept_ingredient(StringName(_carrying_item)):
				_target_pos = st.global_position + Vector2(-28, -20)
				if global_position.distance_to(_target_pos) <= 22.0:
					st.add_ingredient(StringName(_carrying_item))
					_carrying_item = ""
					work_cooldown = 0.6 / speed_buff_mult
				return
		_carrying_item = ""


func _act_murcielago() -> void:
	if _carrying_item == "":
		for st: KitchenStation in _stations:
			if st.station_type == KitchenStation.StationType.CAULDRON and (st.cauldron_state == KitchenStation.CauldronState.READY or st.cauldron_state == KitchenStation.CauldronState.OVERBOIL_WARNING):
				_target_pos = st.global_position + Vector2(0, -32)
				if global_position.distance_to(_target_pos) <= 20.0:
					var res: Dictionary = st.take_ready_potion()
					if not res.is_empty():
						var r: PotionRecipeData = res["recipe"] as PotionRecipeData
						var hot_flag: bool = res["is_hot"] as bool
						_carrying_item = "bot:%s:%s" % [String(r.recipe_id), "1" if hot_flag else "0"]
						work_cooldown = 0.4 / speed_buff_mult
				return
	else:
		var parts: PackedStringArray = _carrying_item.split(":")
		if parts.size() < 3:
			_carrying_item = ""
			return
		var recipe_id: StringName = StringName(parts[1])
		var hot_flag: bool = parts[2] == "1"
		var customers: Array = _customers_provider.call() if _customers_provider.is_valid() else []
		for c_var: Variant in customers:
			var cust: CustomerEntity = c_var as CustomerEntity
			if cust != null and not cust.is_served and cust.requested_recipe != null and cust.requested_recipe.recipe_id == recipe_id:
				_target_pos = cust.global_position + Vector2(-50, 0)
				if global_position.distance_to(_target_pos) <= 24.0:
					if _on_deliver_callback.is_valid():
						_on_deliver_callback.call(cust, recipe_id, hot_flag)
					_carrying_item = ""
					work_cooldown = 0.5 / speed_buff_mult
				return


func _find_missing_ingredient_for(recipe: PotionRecipeData) -> StringName:
	for st: KitchenStation in _stations:
		if st.station_type == KitchenStation.StationType.CAULDRON and st.cauldron_state == KitchenStation.CauldronState.IDLE:
			for req: StringName in recipe.required_ingredients:
				if not st.held_ingredients.has(req) and st.can_accept_ingredient(req):
					return req
	return &""


func _draw() -> void:
	var float_y: float = sin(_hover_time * 7.0) * 6.0
	var flap: float = sin(_hover_time * 16.0) * 5.0
	var col: Color = Color(0.15, 0.14, 0.20)
	if familiar_type == "diablillo_carmesi":
		col = Color(0.88, 0.20, 0.28)
	elif familiar_type == "murcielago_sombrio":
		col = Color(0.45, 0.24, 0.68)

	# Wings
	draw_colored_polygon(PackedVector2Array([Vector2(-6, float_y), Vector2(-24, -10 + flap + float_y), Vector2(-18, 6 + float_y)]), col.lightened(0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(6, float_y), Vector2(24, -10 + flap + float_y), Vector2(18, 6 + float_y)]), col.lightened(0.2))
	# Cute body & glowing yellow eyes
	draw_circle(Vector2(0, float_y), 12.0, col)
	draw_circle(Vector2(0, float_y), 12.0, Color(0.08, 0.06, 0.1), false, 2.0)
	draw_circle(Vector2(-4, -2 + float_y), 2.5, Color(1.0, 0.88, 0.2))
	draw_circle(Vector2(4, -2 + float_y), 2.5, Color(1.0, 0.88, 0.2))
	if _carrying_item != "":
		draw_circle(Vector2(0, 14 + float_y), 6.0, Color(1.0, 0.5, 0.8))
