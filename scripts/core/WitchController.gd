class_name WitchController
extends Node2D
## Click-queued playable witch with 2.5D semi-chibi procedural juice, Helltaker bounce,
## hand inventory slots, and smart station chaining.

signal potion_delivered_to_customer(customer: CustomerEntity, recipe_id: StringName, is_hot: bool)
signal popup_requested(world_pos: Vector2, text: String, color: Color)

const MAX_NEXT_BUFFER: int = 1

var witch_data: WitchCharacterData
var move_speed_mult: float = 1.0
var ability_speed_bonus: float = 0.0
var carry_bonus: int = 0
var instant_bottle_enabled: bool = false
var seismic_mortar_enabled: bool = false
var bottling_station_pos: Vector2 = Vector2.ZERO
var seismic_mortar_callback: Callable

var held_items: Array[String] = []
var action_queue: Array[Dictionary] = []

var _current_task: Dictionary = {}
var _work_timer: float = 0.0
var _waiting_cauldron: KitchenStation = null
var _stirring_cauldron: KitchenStation = null
var _walk_time: float = 0.0
var _completed_steps: int = 0
var _ability_cooldown_left: float = 0.0
var _ability_buff_left: float = 0.0
var _facing: float = 1.0
var _squash: Vector2 = Vector2.ONE


func setup_witch(data: WitchCharacterData) -> void:
	witch_data = data
	held_items.clear()
	action_queue.clear()
	_current_task.clear()
	_waiting_cauldron = null
	_stirring_cauldron = null
	_work_timer = 0.0
	_ability_cooldown_left = 0.0
	_ability_buff_left = 0.0
	queue_redraw()


func get_max_carry() -> int:
	var base_cap: int = witch_data.carry_capacity if witch_data else 2
	return base_cap + carry_bonus


func get_ability_cooldown_ratio() -> float:
	if witch_data == null or witch_data.active_cooldown_sec <= 0.0:
		return 0.0
	return clampf(_ability_cooldown_left / witch_data.active_cooldown_sec, 0.0, 1.0)


func can_trigger_ability() -> bool:
	return _ability_cooldown_left <= 0.0 and witch_data != null


func trigger_ability(cauldrons: Array[KitchenStation], customers: Array[CustomerEntity], familiars: Array[FamiliarEntity]) -> bool:
	if not can_trigger_ability():
		popup_requested.emit(global_position + Vector2(0, -56), "¡En recarga!", Color(0.95, 0.65, 0.35))
		return false

	_ability_cooldown_left = witch_data.active_cooldown_sec
	EventBus.witch_ability_triggered.emit(witch_data.witch_id, witch_data.cutin_illustration)
	EventBus.witch_emotion_changed.emit(EventBus.WitchEmotion.CUTIN_HABILIDAD, 1.3)

	match witch_data.witch_id:
		&"trixie":
			_ability_buff_left = 5.0
			ability_speed_bonus = 0.60
			for c: KitchenStation in cauldrons:
				c.finish_instant()
			popup_requested.emit(global_position + Vector2(0, -70), "¡FIEBRE ESCARLATA!", Color(1.0, 0.35, 0.45))
		&"lyra":
			for cust: CustomerEntity in customers:
				cust.freeze_patience(8.0)
			popup_requested.emit(global_position + Vector2(0, -70), "¡ENREDADERAS CALMANTES!", Color(0.35, 0.95, 0.55))
		&"nyxara":
			for f: FamiliarEntity in familiars:
				f.speed_buff_mult = 2.0
			for c: KitchenStation in cauldrons:
				c.stir_cauldron()
			_ability_buff_left = 7.0
			ability_speed_bonus = 0.25
			popup_requested.emit(global_position + Vector2(0, -70), "¡POSESIÓN DEL SABBAT!", Color(0.8, 0.45, 1.0))
		&"morrigan":
			for c: KitchenStation in cauldrons:
				c.finish_instant()
			for cust: CustomerEntity in customers:
				cust.boost_patience(5.0)
			popup_requested.emit(global_position + Vector2(0, -70), "¡TRANSMUTACIÓN CARMESÍ!", Color(1.0, 0.2, 0.4))

	_do_squash(Vector2(1.28, 0.78))
	return true


func enqueue_station(station: KitchenStation) -> void:
	var offset: Vector2 = Vector2(0, 62) if station.station_type == KitchenStation.StationType.CAULDRON else Vector2(0, 54)
	var dest: Vector2 = station.global_position + offset
	_buffer_or_start_task({
		"kind": "station",
		"target": station,
		"pos": dest,
		"id": station.station_id,
	})


func enqueue_customer(customer: CustomerEntity) -> void:
	var dest: Vector2 = customer.global_position + Vector2(-84, 0)
	_buffer_or_start_task({
		"kind": "customer",
		"target": customer,
		"pos": dest,
		"id": customer.archetype.customer_id if customer.archetype else &"customer",
	})


func _buffer_or_start_task(task: Dictionary) -> void:
	var st_id: StringName = task.get("id", &"") as StringName
	var dest: Vector2 = task.get("pos", global_position) as Vector2

	if _waiting_cauldron != null:
		var st: KitchenStation = task.get("target") as KitchenStation
		var wants_bottle: bool = task.get("kind", "") == "station" and st != null and st.station_type == KitchenStation.StationType.BOTTLING
		if wants_bottle:
			if action_queue.is_empty():
				action_queue.append(task)
			else:
				action_queue[0] = task
			EventBus.action_queued.emit(st_id, 1, dest)
			queue_redraw()
			return
		_waiting_cauldron = null
		_current_task = task
		action_queue.clear()
		EventBus.action_queued.emit(st_id, 0, dest)
		queue_redraw()
		return

	if _current_task.is_empty() and _work_timer <= 0.0:
		_current_task = task
		EventBus.action_queued.emit(st_id, 0, dest)
	else:
		if action_queue.size() < MAX_NEXT_BUFFER:
			action_queue.append(task)
		else:
			action_queue[0] = task
		EventBus.action_queued.emit(st_id, 1, dest)
	queue_redraw()


func clear_queue() -> void:
	action_queue.clear()
	_current_task.clear()
	_waiting_cauldron = null
	_stirring_cauldron = null
	_work_timer = 0.0
	EventBus.action_queue_cleared.emit()
	queue_redraw()


func _process(delta: float) -> void:
	_squash = _squash.lerp(Vector2.ONE, minf(1.0, delta * 12.0))
	if EventBus.timers_paused:
		_walk_time += delta * 1.6
		queue_redraw()
		return

	if _ability_cooldown_left > 0.0:
		_ability_cooldown_left = maxf(0.0, _ability_cooldown_left - delta)
	if _ability_buff_left > 0.0:
		_ability_buff_left -= delta
		if _ability_buff_left <= 0.0:
			ability_speed_bonus = 0.0

	if _waiting_cauldron != null:
		if not is_instance_valid(_waiting_cauldron) or _waiting_cauldron.cauldron_state == KitchenStation.CauldronState.IDLE or _waiting_cauldron.cauldron_state == KitchenStation.CauldronState.EXPLODED_COOLDOWN:
			_waiting_cauldron = null
			_current_task.clear()
		elif _waiting_cauldron.cauldron_state == KitchenStation.CauldronState.READY or _waiting_cauldron.cauldron_state == KitchenStation.CauldronState.OVERBOIL_WARNING:
			_collect_from_cauldron(_waiting_cauldron)
			_waiting_cauldron = null
			_current_task.clear()
		else:
			_walk_time += delta * 2.0
			queue_redraw()
			return

	if _work_timer > 0.0:
		_work_timer -= delta
		if _work_timer <= 0.0:
			_finish_work_task()
		queue_redraw()
		return

	if _current_task.is_empty():
		if action_queue.is_empty():
			_completed_steps = 0
			_walk_time += delta * 1.6
			queue_redraw()
			return
		_current_task = action_queue.pop_front()

	var target_pos: Vector2 = _get_live_task_pos(_current_task)
	var dist: float = global_position.distance_to(target_pos)
	var base_spd: float = witch_data.move_speed if witch_data else 350.0
	var spd: float = base_spd * (move_speed_mult + ability_speed_bonus)

	if dist > 12.0:
		var dir: Vector2 = (target_pos - global_position).normalized()
		if absf(dir.x) > 0.08:
			_facing = 1.0 if dir.x > 0.0 else -1.0
		global_position = global_position.move_toward(target_pos, spd * delta)
		_walk_time += delta * 11.0 * (move_speed_mult + ability_speed_bonus)
		if instant_bottle_enabled and global_position.distance_to(bottling_station_pos) < 150.0:
			_auto_bottle_held()
	else:
		_arrive_at_task(_current_task)

	queue_redraw()


func _get_live_task_pos(task: Dictionary) -> Vector2:
	var kind: String = task.get("kind", "")
	if kind == "customer":
		var c: CustomerEntity = task.get("target") as CustomerEntity
		if c != null and is_instance_valid(c):
			return c.global_position + Vector2(-84, 0)
	return task.get("pos", global_position) as Vector2


func _arrive_at_task(task: Dictionary) -> void:
	var kind: String = task.get("kind", "")
	if kind == "customer":
		var cust: CustomerEntity = task.get("target") as CustomerEntity
		if cust != null and is_instance_valid(cust) and not cust.is_served:
			_try_deliver_to(cust)
		_current_task.clear()
		return

	var st: KitchenStation = task.get("target") as KitchenStation
	if st == null or not is_instance_valid(st):
		_current_task.clear()
		return

	match st.station_type:
		KitchenStation.StationType.INGREDIENT_BIN:
			if held_items.size() < get_max_carry():
				held_items.append("ing:" + String(st.ingredient_id))
				_do_squash(Vector2(1.2, 0.82))
				_emit_step(st.station_id)
			else:
				popup_requested.emit(global_position + Vector2(0, -54), "¡Manos llenas!", Color(1.0, 0.7, 0.25))
			_current_task.clear()

		KitchenStation.StationType.MORTAR:
			if _has_raw_ingredient():
				_work_timer = 0.55
				_do_squash(Vector2(0.85, 1.18))
			else:
				popup_requested.emit(global_position + Vector2(0, -54), "Trae un ingrediente", Color(0.85, 0.85, 0.95))
				_current_task.clear()

		KitchenStation.StationType.CAULDRON:
			var deposited: bool = _try_deposit_into_cauldron(st)
			if deposited:
				_do_squash(Vector2(1.18, 0.84))
				_emit_step(st.station_id)
				_current_task.clear()
			elif st.cauldron_state == KitchenStation.CauldronState.READY or st.cauldron_state == KitchenStation.CauldronState.OVERBOIL_WARNING:
				_collect_from_cauldron(st)
				_current_task.clear()
			elif st.cauldron_state == KitchenStation.CauldronState.BREWING:
				st.stir_cauldron()
				popup_requested.emit(st.global_position + Vector2(0, -76), "¡CALIENTE!", Color(1.0, 0.65, 0.2))
				_do_squash(Vector2(1.15, 0.88))
				_stirring_cauldron = st
				_work_timer = 0.35
			else:
				if _has_any_ingredient():
					popup_requested.emit(st.global_position + Vector2(0, -54), "¡Mezcla inválida!", Color(0.85, 0.4, 1.0))
				_current_task.clear()

		KitchenStation.StationType.BOTTLING:
			if _has_unsealed_potion():
				_work_timer = 0.05 if instant_bottle_enabled else 0.42
				_do_squash(Vector2(1.15, 0.86))
			else:
				_current_task.clear()

		KitchenStation.StationType.TRASH:
			if not held_items.is_empty():
				held_items.pop_back()
				popup_requested.emit(st.global_position + Vector2(0, -40), "Descartado", Color(0.8, 0.75, 0.85))
				_emit_step(st.station_id)
			_current_task.clear()


func _finish_work_task() -> void:
	var st: KitchenStation = _current_task.get("target") as KitchenStation
	if st == null or not is_instance_valid(st):
		_current_task.clear()
		return

	if st.station_type == KitchenStation.StationType.MORTAR:
		for i: int in range(held_items.size()):
			if held_items[i].begins_with("ing:") and not held_items[i].begins_with("ing:crushed_"):
				var raw_id: String = held_items[i].substr(4)
				held_items[i] = "ing:crushed_" + raw_id
				popup_requested.emit(st.global_position + Vector2(0, -48), "¡Machacado!", Color(1.0, 0.88, 0.35))
				if seismic_mortar_enabled and seismic_mortar_callback.is_valid():
					seismic_mortar_callback.call()
				_emit_step(st.station_id)
				break
	elif st.station_type == KitchenStation.StationType.BOTTLING:
		_auto_bottle_held()
		popup_requested.emit(st.global_position + Vector2(0, -48), "¡Embotellado!", Color(0.55, 0.95, 1.0))
		_emit_step(st.station_id)
	elif st.station_type == KitchenStation.StationType.CAULDRON and _stirring_cauldron == st:
		_stirring_cauldron = null
		if st.cauldron_state == KitchenStation.CauldronState.READY or st.cauldron_state == KitchenStation.CauldronState.OVERBOIL_WARNING:
			_collect_from_cauldron(st)
		elif st.cauldron_state == KitchenStation.CauldronState.BREWING and _next_queued_wants_potion():
			_waiting_cauldron = st
			return

	_current_task.clear()


func _auto_bottle_held() -> void:
	for i: int in range(held_items.size()):
		if held_items[i].begins_with("raw:"):
			held_items[i] = "bot:" + held_items[i].substr(4)


func _collect_from_cauldron(st: KitchenStation) -> void:
	if held_items.size() >= get_max_carry():
		popup_requested.emit(global_position + Vector2(0, -56), "¡Manos llenas!", Color(1.0, 0.7, 0.25))
		return
	var res: Dictionary = st.take_ready_potion()
	if res.is_empty():
		return
	var recipe: PotionRecipeData = res["recipe"] as PotionRecipeData
	var is_hot: bool = res["is_hot"] as bool
	var prefix: String = "bot" if instant_bottle_enabled else "raw"
	held_items.append("%s:%s:%s" % [prefix, String(recipe.recipe_id), "1" if is_hot else "0"])
	_do_squash(Vector2(1.22, 0.80))
	_emit_step(st.station_id)


func _try_deposit_into_cauldron(st: KitchenStation) -> bool:
	var deposited_any: bool = false
	var idx: int = 0
	while idx < held_items.size():
		if held_items[idx].begins_with("ing:"):
			var ing_name: StringName = StringName(held_items[idx].substr(4))
			if st.can_accept_ingredient(ing_name):
				st.add_ingredient(ing_name)
				held_items.remove_at(idx)
				deposited_any = true
				continue
		idx += 1
	return deposited_any


func _try_deliver_to(cust: CustomerEntity) -> void:
	if cust.requested_recipe == null:
		return
	var wanted_id: String = String(cust.requested_recipe.recipe_id)
	for i: int in range(held_items.size()):
		if held_items[i].begins_with("bot:" + wanted_id + ":"):
			var parts: PackedStringArray = held_items[i].split(":")
			var is_hot: bool = parts.size() >= 3 and parts[2] == "1"
			held_items.remove_at(i)
			_do_squash(Vector2(1.25, 0.78))
			_emit_step(&"counter")
			potion_delivered_to_customer.emit(cust, cust.requested_recipe.recipe_id, is_hot)
			return

	for i: int in range(held_items.size()):
		if held_items[i].begins_with("raw:" + wanted_id + ":"):
			popup_requested.emit(global_position + Vector2(0, -64), "¡Falta embotellar!", Color(0.55, 0.92, 1.0))
			return

	popup_requested.emit(cust.global_position + Vector2(-40, -64), "¡Pide otra poción!", Color(1.0, 0.5, 0.45))


func _next_queued_wants_potion() -> bool:
	if action_queue.is_empty():
		return false
	var nxt: Dictionary = action_queue[0]
	var kind: String = nxt.get("kind", "")
	if kind == "customer" and instant_bottle_enabled:
		return true
	if kind == "station":
		var st: KitchenStation = nxt.get("target") as KitchenStation
		return st != null and st.station_type == KitchenStation.StationType.BOTTLING
	return false


func _has_raw_ingredient() -> bool:
	for item: String in held_items:
		if item.begins_with("ing:") and not item.begins_with("ing:crushed_"):
			return true
	return false


func _has_any_ingredient() -> bool:
	for item: String in held_items:
		if item.begins_with("ing:"):
			return true
	return false


func _has_unsealed_potion() -> bool:
	for item: String in held_items:
		if item.begins_with("raw:"):
			return true
	return false


func _emit_step(st_id: StringName) -> void:
	EventBus.action_step_completed.emit(st_id, _completed_steps)
	_completed_steps = mini(_completed_steps + 1, 7)


func _do_squash(target_scale: Vector2) -> void:
	_squash = target_scale


func _draw() -> void:
	# Draw glowing queued path & numbered waypoints on floor (local coordinates)
	var pts: Array[Vector2] = [Vector2.ZERO]
	if not _current_task.is_empty():
		pts.append(to_local(_get_live_task_pos(_current_task)))
	for t: Dictionary in action_queue:
		pts.append(to_local(_get_live_task_pos(t)))

	for i: int in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], Color(1.0, 0.78, 0.35, 0.65), 4.0)
	var font: Font = ThemeDB.fallback_font
	for i: int in range(1, pts.size()):
		draw_circle(pts[i], 14.0, Color(0.18, 0.12, 0.25, 0.88))
		draw_circle(pts[i], 14.0, Color(1.0, 0.85, 0.35), false, 2.5)
		draw_string(font, pts[i] + Vector2(-4.5, 5.0), str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.94, 0.7))

	# Rhythmic Helltaker-style walk bounce
	var is_moving: bool = not _current_task.is_empty() and _waiting_cauldron == null and _work_timer <= 0.0
	var bounce_y: float = -absf(sin(_walk_time)) * (9.0 if is_moving else 2.2)
	var tilt: float = sin(_walk_time) * (0.07 if is_moving else 0.015)

	draw_circle(Vector2(0, 32), 23.0, Color(0, 0, 0, 0.32))

	var theme_col: Color = Color(0.48, 0.22, 0.68)
	var hair_col: Color = Color(0.28, 0.15, 0.14)
	if witch_data:
		match witch_data.witch_id:
			&"lyra":
				theme_col = Color(0.22, 0.65, 0.38)
				hair_col = Color(0.92, 0.68, 0.34)
			&"nyxara":
				theme_col = Color(0.20, 0.32, 0.58)
				hair_col = Color(0.86, 0.86, 0.95)
			&"morrigan":
				theme_col = Color(0.72, 0.14, 0.28)
				hair_col = Color(0.12, 0.10, 0.16)

	draw_set_transform(Vector2(0, bounce_y), tilt, Vector2(_squash.x * _facing, _squash.y))

	# Flowing hair behind
	draw_circle(Vector2(-6, -12), 18.0, hair_col)
	# Curvy corset dress silhouette (~3 heads semi-chibi)
	var skirt: PackedVector2Array = PackedVector2Array([
		Vector2(-10, 0), Vector2(10, 0), Vector2(20, 28), Vector2(-20, 28)
	])
	draw_colored_polygon(skirt, theme_col)
	draw_polyline(skirt + PackedVector2Array([skirt[0]]), Color(0.09, 0.06, 0.12), 2.5)
	# Fitted waist + bust highlight
	draw_circle(Vector2(4, -2), 9.0, theme_col.lightened(0.15))
	draw_circle(Vector2(5, -7), 6.5, Color(1.0, 0.86, 0.78))
	# Head
	draw_circle(Vector2(0, -24), 19.0, Color(1.0, 0.87, 0.79))
	draw_circle(Vector2(0, -24), 19.0, Color(0.09, 0.06, 0.12), false, 2.5)
	# Eyes
	draw_circle(Vector2(4, -24), 2.6, Color(0.12, 0.08, 0.15))
	draw_circle(Vector2(11, -24), 2.6, Color(0.12, 0.08, 0.15))
	# Pointed witch hat
	draw_colored_polygon(PackedVector2Array([Vector2(-26, -34), Vector2(26, -34), Vector2(0, -40)]), theme_col.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -36), Vector2(14, -36), Vector2(-6, -68)]), theme_col.darkened(0.25))
	draw_line(Vector2(-13, -38), Vector2(13, -38), Color(1.0, 0.78, 0.28), 4.0)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Held items displayed clearly next to hands
	for i: int in range(held_items.size()):
		var item_str: String = held_items[i]
		var hp: Vector2 = Vector2(-26 + i * 26, -64 + bounce_y * 0.4)
		if item_str.begins_with("ing:"):
			var ing: StringName = StringName(item_str.substr(4))
			draw_circle(hp, 11.0, KitchenStation._ingredient_color(ing))
			draw_circle(hp, 11.0, Color(0.1, 0.08, 0.14), false, 2.2)
			if String(ing).begins_with("crushed_"):
				draw_circle(hp, 14.0, Color(1.0, 0.88, 0.2), false, 2.0)
		else:
			var parts: PackedStringArray = item_str.split(":")
			var is_bottled: bool = parts[0] == "bot"
			var r_id: String = parts[1] if parts.size() > 1 else ""
			var col: Color = _recipe_color_hint(r_id)
			draw_circle(hp, 12.0, col)
			draw_circle(hp, 12.0, Color(0.95, 0.98, 1.0) if is_bottled else Color(0.12, 0.09, 0.14), false, 3.0 if is_bottled else 2.0)
			if is_bottled:
				draw_rect(Rect2(hp.x - 4, hp.y - 17, 8, 6), Color(0.76, 0.52, 0.30))


static func _recipe_color_hint(recipe_id: String) -> Color:
	match recipe_id:
		"elixir_ignis": return Color(0.96, 0.25, 0.30)
		"bruma_lunar": return Color(0.24, 0.65, 1.0)
		"savia_pura": return Color(0.22, 0.88, 0.45)
		"filtro_estelar": return Color(0.76, 0.30, 0.98)
		"tonico_silvestre": return Color(0.98, 0.65, 0.16)
		"concentrado_carmesi": return Color(1.0, 0.18, 0.56)
	return Color.MAGENTA
