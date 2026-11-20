class_name KitchenStation
extends Area2D
## Interactive 2.5D potion kitchen station: Ingredient Bins, Mortar, Cauldrons, Bottling, Trash.

enum StationType {
	INGREDIENT_BIN,
	MORTAR,
	CAULDRON,
	BOTTLING,
	DISPLAY_STAND,
	TRASH,
	SUPPLY_SOURCE,
	CRATE_RACK,
	ROOM_DOOR,
}

const MAX_DISPLAY_SLOTS: int = 2
const MAX_BOTTLING_SLOTS: int = 2
const MAX_BIN_STOCK: int = 10
const SUPPLY_CRATE_AMOUNT: int = 20
const MAX_CRATE_RACK_SLOTS: int = 3

enum CauldronState {
	IDLE,
	BREWING,
	READY,
	OVERBOIL_WARNING,
	EXPLODED_COOLDOWN,
}

signal station_clicked(station: KitchenStation)

@export var station_id: StringName = &""
@export var station_type: StationType = StationType.INGREDIENT_BIN
@export var ingredient_id: StringName = &""
@export var display_label: String = ""
@export var cauldron_index: int = -1
@export var accent_color: Color = Color(0.85, 0.32, 0.45)

var hovered: bool = false
var hovered_slot: int = -1
var last_clicked_slot: int = 0
var held_ingredients: Array[StringName] = []
var ingredient_stock: int = MAX_BIN_STOCK
var display_slots: Array[String] = ["", ""]
var bottling_slots: Array[String] = ["", ""]
var crate_slots: Array[String] = ["", "", ""]
var cauldron_state: CauldronState = CauldronState.IDLE
var active_recipe: PotionRecipeData = null
var brew_elapsed: float = 0.0
var brew_duration: float = 3.0
var overheat_elapsed: float = 0.0
var overheat_duration: float = 16.0
var is_stirred_hot: bool = false
var has_mortar_bonus: bool = false
var familiar_protected: bool = false
var _cooldown_timer: float = 0.0
var _pulse_time: float = 0.0
var _recipes_ref: Array[PotionRecipeData] = []
var _unlocked_day: int = 1
var _brew_speed_mult: float = 1.0
var _overheat_grace_mult: float = 1.0


func _ready() -> void:
	input_pickable = true
	monitoring = false
	monitorable = false
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	if station_type == StationType.CAULDRON:
		rect.size = Vector2(138.0, 118.0)
	elif station_type == StationType.CRATE_RACK:
		rect.size = Vector2(210.0, 96.0)
	elif station_type == StationType.SUPPLY_SOURCE:
		rect.size = Vector2(126.0, 108.0)
	elif station_type == StationType.ROOM_DOOR:
		rect.size = Vector2(96.0, 152.0)
	else:
		rect.size = Vector2(126.0, 108.0)
	shape.shape = rect
	add_child(shape)
	mouse_entered.connect(func() -> void:
		hovered = true
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		hovered = false
		hovered_slot = -1
		queue_redraw()
	)


func configure_catalog(recipes: Array[PotionRecipeData], current_day: int, brew_mult: float, overheat_mult: float = 1.0) -> void:
	_recipes_ref = recipes
	_unlocked_day = current_day
	_brew_speed_mult = brew_mult
	_overheat_grace_mult = overheat_mult


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if station_type == StationType.DISPLAY_STAND or station_type == StationType.BOTTLING:
				last_clicked_slot = 0 if get_local_mouse_position().x < 0.0 else 1
			elif station_type == StationType.CRATE_RACK:
				last_clicked_slot = _crate_rack_slot_from_x(get_local_mouse_position().x)
			get_viewport().set_input_as_handled()
			station_clicked.emit(self)


func _process(delta: float) -> void:
	_pulse_time += delta
	if (station_type == StationType.DISPLAY_STAND or station_type == StationType.BOTTLING) and hovered:
		var new_slot: int = 0 if get_local_mouse_position().x < 0.0 else 1
		if new_slot != hovered_slot:
			hovered_slot = new_slot
			queue_redraw()
	elif station_type == StationType.CRATE_RACK and hovered:
		var new_c_slot: int = _crate_rack_slot_from_x(get_local_mouse_position().x)
		if new_c_slot != hovered_slot:
			hovered_slot = new_c_slot
			queue_redraw()
	elif station_type == StationType.INGREDIENT_BIN and ingredient_stock <= 0:
		queue_redraw()
	if station_type != StationType.CAULDRON:
		return
	if EventBus.timers_paused:
		queue_redraw()
		return

	match cauldron_state:
		CauldronState.BREWING:
			var stir_bonus: float = 1.65 if is_stirred_hot else 1.0
			var fam_bonus: float = 1.35 if familiar_protected else 1.0
			brew_elapsed += delta * _brew_speed_mult * stir_bonus * fam_bonus
			var brew_ratio: float = clampf(brew_elapsed / maxf(0.1, brew_duration), 0.0, 1.0)
			EventBus.cauldron_progress_updated.emit(cauldron_index, brew_ratio, 0.0)
			if brew_elapsed >= brew_duration:
				cauldron_state = CauldronState.READY
				overheat_elapsed = 0.0
				EventBus.cauldron_potion_ready.emit(cauldron_index, active_recipe.recipe_id, is_stirred_hot)
			queue_redraw()

		CauldronState.READY, CauldronState.OVERBOIL_WARNING:
			if familiar_protected:
				queue_redraw()
				return
			overheat_elapsed += delta
			var ratio: float = clampf(overheat_elapsed / maxf(0.1, overheat_duration), 0.0, 1.0)
			if ratio >= 0.65:
				cauldron_state = CauldronState.OVERBOIL_WARNING
			EventBus.cauldron_progress_updated.emit(cauldron_index, 1.0, ratio)
			if overheat_elapsed >= overheat_duration:
				_trigger_explosion()
			queue_redraw()

		CauldronState.EXPLODED_COOLDOWN:
			_cooldown_timer -= delta
			if _cooldown_timer <= 0.0:
				cauldron_state = CauldronState.IDLE
				held_ingredients.clear()
				active_recipe = null
			queue_redraw()


func can_accept_ingredient(ing: StringName) -> bool:
	if station_type != StationType.CAULDRON:
		return false
	if cauldron_state != CauldronState.IDLE or not held_ingredients.is_empty():
		return false
	return GameCatalog.match_exact_recipe([ing], _recipes_ref) != null


func add_ingredient(ing: StringName) -> bool:
	if not can_accept_ingredient(ing):
		return false
	held_ingredients.append(ing)
	var matched: PotionRecipeData = GameCatalog.match_exact_recipe(held_ingredients, _recipes_ref)
	if matched != null:
		active_recipe = matched
		brew_duration = matched.base_brew_time_sec
		overheat_duration = matched.overheat_grace_sec * _overheat_grace_mult
		overheat_elapsed = 0.0
		brew_elapsed = 0.0
		cauldron_state = CauldronState.BREWING
		EventBus.cauldron_brew_started.emit(cauldron_index, matched.recipe_id)
	queue_redraw()
	return true


func stir_cauldron() -> void:
	if cauldron_state == CauldronState.BREWING:
		is_stirred_hot = true
		brew_elapsed += 0.45
		AudioJuiceManager.play_stir()
		queue_redraw()


func finish_instant() -> void:
	if station_type == StationType.CAULDRON and cauldron_state == CauldronState.BREWING and active_recipe != null:
		brew_elapsed = brew_duration
		cauldron_state = CauldronState.READY
		overheat_elapsed = 0.0
		is_stirred_hot = true
		EventBus.cauldron_potion_ready.emit(cauldron_index, active_recipe.recipe_id, true)
		queue_redraw()


func take_ready_potion() -> Dictionary:
	if cauldron_state != CauldronState.READY and cauldron_state != CauldronState.OVERBOIL_WARNING:
		return {}
	if active_recipe == null:
		return {}
	var res: Dictionary = {
		"recipe": active_recipe,
		"is_hot": is_stirred_hot,
		"is_mortar": has_mortar_bonus,
	}
	held_ingredients.clear()
	active_recipe = null
	brew_elapsed = 0.0
	overheat_elapsed = 0.0
	is_stirred_hot = false
	has_mortar_bonus = false
	cauldron_state = CauldronState.IDLE
	queue_redraw()
	return res


func _trigger_explosion() -> void:
	cauldron_state = CauldronState.EXPLODED_COOLDOWN
	_cooldown_timer = 2.4
	held_ingredients.clear()
	active_recipe = null
	is_stirred_hot = false
	has_mortar_bonus = false
	EventBus.cauldron_exploded.emit(cauldron_index, -1)
	queue_redraw()


func _draw() -> void:
	var outline_col: Color = Color(1.0, 0.92, 0.45) if hovered else Color(0.11, 0.08, 0.14)
	var outline_w: float = 4.5 if hovered else 3.0

	match station_type:
		StationType.INGREDIENT_BIN:
			_draw_crate(outline_col, outline_w)
		StationType.MORTAR:
			_draw_mortar(outline_col, outline_w)
		StationType.CAULDRON:
			_draw_cauldron(outline_col, outline_w)
		StationType.BOTTLING:
			_draw_bottling(outline_col, outline_w)
		StationType.DISPLAY_STAND:
			_draw_display_stand(outline_col, outline_w)
		StationType.TRASH:
			_draw_trash(outline_col, outline_w)
		StationType.SUPPLY_SOURCE:
			_draw_supply_source(outline_col, outline_w)
		StationType.CRATE_RACK:
			_draw_crate_rack(outline_col, outline_w)
		StationType.ROOM_DOOR:
			_draw_room_door(outline_col, outline_w)


func has_ingredient_stock() -> bool:
	return station_type == StationType.INGREDIENT_BIN and ingredient_stock > 0


func consume_ingredient_stock() -> bool:
	if not has_ingredient_stock():
		return false
	ingredient_stock -= 1
	queue_redraw()
	return true


func refill_ingredient_stock(amount: int) -> int:
	if station_type != StationType.INGREDIENT_BIN or amount <= 0:
		return 0
	var space: int = maxi(0, MAX_BIN_STOCK - ingredient_stock)
	var added: int = mini(space, amount)
	if added > 0:
		ingredient_stock += added
		queue_redraw()
	return added


func reset_ingredient_stock() -> void:
	ingredient_stock = MAX_BIN_STOCK
	queue_redraw()


func _crate_rack_slot_from_x(local_x: float) -> int:
	if local_x < -34.0:
		return 0
	if local_x > 34.0:
		return 2
	return 1


func is_crate_slot_occupied(slot_idx: int) -> bool:
	if station_type != StationType.CRATE_RACK or slot_idx < 0 or slot_idx >= MAX_CRATE_RACK_SLOTS:
		return false
	return crate_slots[slot_idx] != ""


func store_crate_in_slot(slot_idx: int, crate_item: String) -> bool:
	if station_type != StationType.CRATE_RACK or slot_idx < 0 or slot_idx >= MAX_CRATE_RACK_SLOTS:
		return false
	if crate_slots[slot_idx] != "" or not crate_item.begins_with("crate:"):
		return false
	crate_slots[slot_idx] = crate_item
	queue_redraw()
	return true


func take_crate_from_slot(slot_idx: int) -> String:
	if station_type != StationType.CRATE_RACK or slot_idx < 0 or slot_idx >= MAX_CRATE_RACK_SLOTS:
		return ""
	var item: String = crate_slots[slot_idx]
	if item != "":
		crate_slots[slot_idx] = ""
		queue_redraw()
	return item


func get_occupied_crate_count() -> int:
	var count: int = 0
	for s: String in crate_slots:
		if s != "":
			count += 1
	return count


func clear_crate_slots() -> void:
	crate_slots = ["", "", ""]
	queue_redraw()


func _draw_crate(outline_col: Color, outline_w: float) -> void:
	var box: Rect2 = Rect2(-52, -40, 104, 80)
	draw_rect(Rect2(-48, -32, 104, 82), Color(0, 0, 0, 0.28))
	draw_rect(box, Color(0.46, 0.28, 0.18))
	var empty_flash: bool = ingredient_stock <= 0 and int(_pulse_time * 6.0) % 2 == 0
	var final_outline: Color = Color(1.0, 0.25, 0.25) if empty_flash else outline_col
	draw_rect(box, final_outline, false, 4.5 if empty_flash else outline_w)
	draw_rect(Rect2(-42, -30, 84, 54), Color(0.20, 0.14, 0.15) if ingredient_stock <= 0 else accent_color.darkened(0.35))
	# Draw glowing ingredient gems/herbs proportional to stock
	var vis_gems: int = mini(3, ceili(float(ingredient_stock) / 3.4))
	for i: int in range(vis_gems):
		var ox: float = -22.0 + i * 22.0
		var oy: float = -6.0 + sin(_pulse_time * 2.5 + i) * 2.0
		draw_circle(Vector2(ox, oy), 13.0, accent_color)
		draw_circle(Vector2(ox - 3, oy - 3), 4.0, Color(1, 1, 1, 0.7))
	var stock_col: Color = Color(1.0, 0.28, 0.28) if ingredient_stock <= 0 else (Color(1.0, 0.78, 0.25) if ingredient_stock <= 3 else Color(0.98, 0.96, 0.88))
	_draw_station_caption("%d/%d" % [ingredient_stock, MAX_BIN_STOCK], Vector2(0, -48), stock_col)
	_draw_station_caption(display_label, Vector2(0, 56))


func _draw_mortar(outline_col: Color, outline_w: float) -> void:
	draw_circle(Vector2(3, 8), 46.0, Color(0, 0, 0, 0.28))
	draw_rect(Rect2(-52, -38, 104, 76), Color(0.42, 0.30, 0.24))
	draw_rect(Rect2(-52, -38, 104, 76), outline_col, false, outline_w)
	draw_circle(Vector2.ZERO, 28.0, Color(0.55, 0.56, 0.62))
	draw_circle(Vector2.ZERO, 28.0, Color(0.12, 0.1, 0.16), false, 3.0)
	draw_circle(Vector2.ZERO, 17.0, Color(0.28, 0.24, 0.32))
	if not held_ingredients.is_empty():
		draw_circle(Vector2.ZERO, 11.0, _ingredient_color(held_ingredients[0]))
		draw_circle(Vector2.ZERO, 11.0, Color(0.1, 0.08, 0.14), false, 2.0)
	draw_line(Vector2(4, -2), Vector2(20, -24), Color(0.84, 0.78, 0.70), 7.0)
	_draw_station_caption(display_label, Vector2(0, 56))


func _draw_cauldron(outline_col: Color, outline_w: float) -> void:
	# Stone hearth glow
	draw_circle(Vector2(0, 8), 58.0, Color(0.25, 0.22, 0.27))
	if cauldron_state == CauldronState.BREWING or cauldron_state == CauldronState.READY:
		draw_circle(Vector2(0, 10), 50.0 + sin(_pulse_time * 6.0) * 3.0, Color(1.0, 0.45, 0.15, 0.32))

	# Iron cauldron pot
	var body_col: Color = Color(0.20, 0.18, 0.24)
	if cauldron_state == CauldronState.EXPLODED_COOLDOWN:
		body_col = Color(0.14, 0.12, 0.14)
	draw_circle(Vector2.ZERO, 44.0, body_col)
	draw_circle(Vector2.ZERO, 44.0, outline_col, false, outline_w)

	# Liquid color inside
	var liq_col: Color = Color(0.30, 0.26, 0.38)
	if active_recipe != null:
		liq_col = active_recipe.potion_color
	elif not held_ingredients.is_empty():
		liq_col = _ingredient_color(held_ingredients[0])
	if cauldron_state == CauldronState.OVERBOIL_WARNING and int(_pulse_time * 10.0) % 2 == 0:
		liq_col = Color(1.0, 0.18, 0.12)
	draw_circle(Vector2(0, -3), 31.0, liq_col)
	draw_circle(Vector2(0, -3), 31.0, Color(0.1, 0.08, 0.14), false, 2.5)

	# Bubbles
	if cauldron_state == CauldronState.BREWING or cauldron_state == CauldronState.READY:
		var b_y: float = -8.0 - fmod(_pulse_time * 24.0, 18.0)
		draw_circle(Vector2(-10, b_y), 4.5, Color(1, 1, 1, 0.65))
		draw_circle(Vector2(11, b_y + 5.0), 3.5, Color(1, 1, 1, 0.55))

	# Progress / Danger rings
	if cauldron_state == CauldronState.BREWING:
		var pct: float = clampf(brew_elapsed / maxf(0.1, brew_duration), 0.0, 1.0)
		draw_arc(Vector2.ZERO, 50.0, -PI / 2.0, -PI / 2.0 + TAU * pct, 32, Color(0.3, 0.95, 0.55), 6.0)
	elif cauldron_state == CauldronState.READY or cauldron_state == CauldronState.OVERBOIL_WARNING:
		var danger: float = clampf(overheat_elapsed / maxf(0.1, overheat_duration), 0.0, 1.0)
		var ring_col: Color = Color(1.0, 0.85, 0.2) if danger < 0.65 else Color(1.0, 0.22, 0.22)
		if familiar_protected:
			ring_col = Color(0.4, 0.92, 1.0)
			danger = 0.0
		draw_arc(Vector2.ZERO, 50.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - danger), 32, ring_col, 6.0)
		_draw_station_caption("¡LISTA!" if danger < 0.65 else "¡VA A EXPLOTAR!", Vector2(0, -58), ring_col)

	if is_stirred_hot and (cauldron_state == CauldronState.BREWING or cauldron_state == CauldronState.READY):
		_draw_station_caption("¡CALIENTE!", Vector2(0, -76), Color(1.0, 0.65, 0.2))
	elif cauldron_state == CauldronState.EXPLODED_COOLDOWN:
		_draw_station_caption("¡CHAMUSCADO!", Vector2(0, -58), Color(0.95, 0.35, 0.35))
	elif not held_ingredients.is_empty() and cauldron_state == CauldronState.IDLE:
		for i: int in range(held_ingredients.size()):
			draw_circle(Vector2(-12 + i * 24, -56), 9.0, _ingredient_color(held_ingredients[i]))

	_draw_station_caption(display_label, Vector2(0, 62))


func is_bottling_slot_occupied(slot_idx: int) -> bool:
	if station_type != StationType.BOTTLING or slot_idx < 0 or slot_idx >= MAX_BOTTLING_SLOTS:
		return false
	return bottling_slots[slot_idx] != ""


func store_bottled_in_slot(slot_idx: int, bot_item: String) -> bool:
	if station_type != StationType.BOTTLING or slot_idx < 0 or slot_idx >= MAX_BOTTLING_SLOTS:
		return false
	if bottling_slots[slot_idx] != "" or not bot_item.begins_with("bot:"):
		return false
	bottling_slots[slot_idx] = bot_item
	queue_redraw()
	return true


func store_bottled_any_slot(bot_item: String) -> bool:
	for i: int in range(MAX_BOTTLING_SLOTS):
		if store_bottled_in_slot(i, bot_item):
			return true
	return false


func has_free_bottling_slot() -> bool:
	if station_type != StationType.BOTTLING:
		return false
	for s: String in bottling_slots:
		if s == "":
			return true
	return false


func take_bottled_from_slot(slot_idx: int) -> String:
	if station_type != StationType.BOTTLING or slot_idx < 0 or slot_idx >= MAX_BOTTLING_SLOTS:
		return ""
	var item: String = bottling_slots[slot_idx]
	if item != "":
		bottling_slots[slot_idx] = ""
		queue_redraw()
	return item


func get_occupied_bottling_count() -> int:
	var count: int = 0
	for s: String in bottling_slots:
		if s != "":
			count += 1
	return count


func clear_bottling_slots() -> void:
	bottling_slots = ["", ""]
	queue_redraw()


func _draw_bottling(outline_col: Color, outline_w: float) -> void:
	draw_rect(Rect2(-56, -38, 120, 84), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-58, -42, 116, 80), Color(0.38, 0.27, 0.22))
	draw_rect(Rect2(-58, -42, 116, 80), Color(0.11, 0.08, 0.14) if hovered else outline_col, false, 3.0 if hovered else outline_w)
	# 2 Bottling storage slots (empty flasks when free, colored bottled potion when stored)
	for i: int in range(MAX_BOTTLING_SLOTS):
		var fx: float = -26.0 + float(i) * 52.0
		var is_slot_hovered: bool = hovered and hovered_slot == i
		var ped_border: Color = Color(1.0, 0.94, 0.45) if is_slot_hovered else Color(0.55, 0.88, 0.98, 0.75)
		draw_circle(Vector2(fx, 0), 19.0, Color(0.20, 0.22, 0.28, 0.88))
		draw_circle(Vector2(fx, 0), 19.0, ped_border, false, 3.5 if is_slot_hovered else 2.0)
		if bottling_slots[i] != "":
			var parts: PackedStringArray = bottling_slots[i].split(":")
			var rec_id: String = parts[1] if parts.size() > 1 else ""
			var flask_col: Color = WitchController._recipe_color_hint(rec_id)
			draw_circle(Vector2(fx, 2), 13.0, flask_col)
			draw_circle(Vector2(fx, 2), 13.0, Color(0.95, 0.98, 1.0), false, 2.5)
			draw_rect(Rect2(fx - 4, -16, 8, 6), Color(0.76, 0.52, 0.30))
		else:
			draw_circle(Vector2(fx, 4), 10.0, Color(0.75, 0.92, 1.0, 0.45))
			draw_rect(Rect2(fx - 4, -13, 8, 9), Color(0.75, 0.92, 1.0, 0.55))
			draw_rect(Rect2(fx - 4, -17, 8, 4), Color(0.76, 0.52, 0.30, 0.7))
	_draw_station_caption("%s (%d/2)" % [display_label, get_occupied_bottling_count()], Vector2(0, 56))


func is_slot_occupied(slot_idx: int) -> bool:
	if station_type != StationType.DISPLAY_STAND or slot_idx < 0 or slot_idx >= MAX_DISPLAY_SLOTS:
		return false
	return display_slots[slot_idx] != ""


func store_potion_in_slot(slot_idx: int, bot_item: String) -> bool:
	if station_type != StationType.DISPLAY_STAND or slot_idx < 0 or slot_idx >= MAX_DISPLAY_SLOTS:
		return false
	if display_slots[slot_idx] != "" or not bot_item.begins_with("bot:"):
		return false
	display_slots[slot_idx] = bot_item
	queue_redraw()
	return true


func take_potion_from_slot(slot_idx: int) -> String:
	if station_type != StationType.DISPLAY_STAND or slot_idx < 0 or slot_idx >= MAX_DISPLAY_SLOTS:
		return ""
	var item: String = display_slots[slot_idx]
	if item != "":
		display_slots[slot_idx] = ""
		queue_redraw()
	return item


func get_occupied_slot_count() -> int:
	var count: int = 0
	for s: String in display_slots:
		if s != "":
			count += 1
	return count


func clear_display_slots() -> void:
	display_slots = ["", ""]
	queue_redraw()


func get_displayed_recipe_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for item: String in display_slots:
		if item == "":
			continue
		var parts: PackedStringArray = item.split(":")
		if parts.size() >= 2:
			ids.append(StringName(parts[1]))
	return ids


func _draw_display_stand(outline_col: Color, outline_w: float) -> void:
	draw_rect(Rect2(-56, -36, 120, 82), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-58, -40, 116, 78), Color(0.42, 0.28, 0.20))
	draw_rect(Rect2(-58, -40, 116, 78), Color(0.11, 0.08, 0.14) if hovered else outline_col, false, 3.0 if hovered else outline_w)
	# Glass showcase top
	draw_rect(Rect2(-50, -32, 100, 58), Color(0.68, 0.88, 0.96, 0.25))
	draw_rect(Rect2(-50, -32, 100, 58), Color(0.75, 0.92, 1.0, 0.6), false, 1.5)
	for i: int in range(MAX_DISPLAY_SLOTS):
		var sx: float = -26.0 + float(i) * 52.0
		var is_slot_hovered: bool = hovered and hovered_slot == i
		var ped_border: Color = Color(1.0, 0.94, 0.45) if is_slot_hovered else Color(0.86, 0.72, 0.36, 0.75)
		draw_circle(Vector2(sx, 0), 19.0, Color(0.24, 0.16, 0.26, 0.9))
		draw_circle(Vector2(sx, 0), 19.0, ped_border, false, 3.5 if is_slot_hovered else 2.0)
		if display_slots[i] != "":
			var parts: PackedStringArray = display_slots[i].split(":")
			var rec_id: String = parts[1] if parts.size() > 1 else ""
			var flask_col: Color = WitchController._recipe_color_hint(rec_id)
			draw_circle(Vector2(sx, 2), 13.0, flask_col)
			draw_circle(Vector2(sx, 2), 13.0, Color(0.95, 0.98, 1.0), false, 2.5)
			draw_rect(Rect2(sx - 4, -16, 8, 6), Color(0.76, 0.52, 0.30))
	_draw_station_caption("%s (%d/2)" % [display_label, get_occupied_slot_count()], Vector2(0, 56))


func _draw_trash(outline_col: Color, outline_w: float) -> void:
	draw_circle(Vector2.ZERO, 34.0, Color(0.28, 0.22, 0.32))
	draw_circle(Vector2.ZERO, 34.0, outline_col, false, outline_w)
	draw_circle(Vector2.ZERO, 22.0, Color(0.12, 0.08, 0.16))
	_draw_station_caption(display_label, Vector2(0, 50))


func _draw_supply_source(outline_col: Color, outline_w: float) -> void:
	var box: Rect2 = Rect2(-42, -36, 84, 72)
	draw_rect(Rect2(-38, -28, 84, 74), Color(0, 0, 0, 0.3))
	draw_rect(box, Color(0.34, 0.22, 0.16))
	draw_rect(box, outline_col, false, outline_w)
	# Crate planks & glowing color emblem
	draw_rect(Rect2(-34, -26, 68, 52), accent_color.darkened(0.45))
	draw_line(Vector2(-34, 0), Vector2(34, 0), Color(0.28, 0.18, 0.12), 4.0)
	draw_circle(Vector2(0, 0), 16.0, accent_color)
	draw_circle(Vector2(0, 0), 16.0, Color(0.10, 0.07, 0.12), false, 2.5)
	_draw_station_caption("x20 ∞", Vector2(0, 5), Color(1.0, 0.98, 0.90))
	_draw_station_caption(display_label, Vector2(0, 52), Color(0.95, 0.88, 0.72))


func _draw_crate_rack(outline_col: Color, outline_w: float) -> void:
	draw_rect(Rect2(-102, -36, 208, 78), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-104, -40, 208, 76), Color(0.36, 0.24, 0.17))
	draw_rect(Rect2(-104, -40, 208, 76), Color(0.11, 0.08, 0.14) if hovered else outline_col, false, 3.0 if hovered else outline_w)
	for i: int in range(MAX_CRATE_RACK_SLOTS):
		var sx: float = -66.0 + float(i) * 66.0
		var is_slot_hovered: bool = hovered and hovered_slot == i
		var slot_border: Color = Color(1.0, 0.94, 0.45) if is_slot_hovered else Color(0.74, 0.58, 0.36, 0.8)
		var slot_rect: Rect2 = Rect2(sx - 26.0, -28.0, 52.0, 52.0)
		draw_rect(slot_rect, Color(0.22, 0.15, 0.16, 0.9))
		draw_rect(slot_rect, slot_border, false, 3.5 if is_slot_hovered else 2.0)
		if crate_slots[i] != "":
			var parts: PackedStringArray = crate_slots[i].split(":")
			var c_ing: StringName = StringName(parts[1]) if parts.size() >= 2 else &"red"
			var c_amt: String = parts[2] if parts.size() >= 3 else "0"
			var c_col: Color = _ingredient_color(c_ing)
			draw_rect(Rect2(sx - 20.0, -22.0, 40.0, 40.0), Color(0.52, 0.34, 0.20))
			draw_rect(Rect2(sx - 16.0, -18.0, 32.0, 32.0), c_col.darkened(0.25))
			draw_circle(Vector2(sx, -2.0), 11.0, c_col)
			_draw_station_caption(c_amt, Vector2(sx, 5.0), Color(1.0, 0.98, 0.92))
	_draw_station_caption("%s (%d/3)" % [display_label, get_occupied_crate_count()], Vector2(0, 54))


func _draw_room_door(outline_col: Color, outline_w: float) -> void:
	var frame: Rect2 = Rect2(-38, -68, 76, 136)
	draw_rect(Rect2(-34, -62, 76, 138), Color(0, 0, 0, 0.32))
	draw_rect(frame, Color(0.32, 0.20, 0.14))
	draw_rect(frame, outline_col, false, outline_w)
	# Inner wooden door planks
	draw_rect(Rect2(-28, -58, 56, 116), Color(0.48, 0.30, 0.19))
	draw_line(Vector2(-10, -58), Vector2(-10, 58), Color(0.24, 0.14, 0.10), 2.0)
	draw_line(Vector2(10, -58), Vector2(10, 58), Color(0.24, 0.14, 0.10), 2.0)
	# Glowing doorway arrow
	var is_left_door: bool = station_id == &"door_to_storage"
	var arrow_pts: PackedVector2Array
	if is_left_door:
		arrow_pts = PackedVector2Array([Vector2(-16, 0), Vector2(12, -18), Vector2(12, 18)])
	else:
		arrow_pts = PackedVector2Array([Vector2(16, 0), Vector2(-12, -18), Vector2(-12, 18)])
	draw_colored_polygon(arrow_pts, Color(1.0, 0.88, 0.38))
	draw_polyline(arrow_pts + PackedVector2Array([arrow_pts[0]]), Color(0.12, 0.08, 0.14), 2.2)
	_draw_station_caption(display_label, Vector2(0, 86), Color(1.0, 0.92, 0.60))


func _draw_station_caption(txt: String, pos: Vector2, col: Color = Color(0.98, 0.95, 0.88)) -> void:
	var font: Font = ThemeDB.fallback_font
	var fsize: int = 15
	var sz: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
	draw_string(font, pos + Vector2(-sz.x * 0.5 + 1.0, 1.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0.05, 0.03, 0.08, 0.9))
	draw_string(font, pos + Vector2(-sz.x * 0.5, 0.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


static func _ingredient_color(ing: StringName) -> Color:
	var s: String = String(ing)
	if s == "mix_yellow":
		return Color(0.98, 0.84, 0.16)
	if s == "mix_purple":
		return Color(0.76, 0.30, 0.98)
	if s == "mix_cyan":
		return Color(0.18, 0.90, 0.86)
	if s.contains("red"):
		return Color(0.96, 0.26, 0.30)
	if s.contains("blue"):
		return Color(0.25, 0.65, 1.0)
	if s.contains("green"):
		return Color(0.22, 0.88, 0.45)
	return Color(0.8, 0.8, 0.8)
