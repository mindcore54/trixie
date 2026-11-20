class_name CustomerEntity
extends Area2D
## 2.5D semi-chibi customer standing at the service counter queue with order speech bubble & patience.

signal customer_clicked(customer: CustomerEntity)

var archetype: CustomerArchetypeData
var requested_recipe: PotionRecipeData
var queue_slot: int = 0
var patience_remaining: float = 28.0
var patience_max: float = 28.0
var patience_frozen_timer: float = 0.0
var patience_slow_mult: float = 1.0
var hovered: bool = false
var is_served: bool = false

var _bob_time: float = 0.0
var _target_pos: Vector2 = Vector2.ZERO
var _warned_impatient: bool = false


func _ready() -> void:
	input_pickable = true
	monitoring = false
	monitorable = false
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(96.0, 118.0)
	shape.shape = rect
	add_child(shape)
	mouse_entered.connect(func() -> void:
		hovered = true
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		hovered = false
		queue_redraw()
	)


func setup(data: CustomerArchetypeData, recipe: PotionRecipeData, slot_idx: int, slot_world_pos: Vector2, patience_mult: float = 1.0) -> void:
	archetype = data
	requested_recipe = recipe
	queue_slot = slot_idx
	_target_pos = slot_world_pos
	patience_max = data.base_patience_sec * patience_mult
	patience_remaining = patience_max
	position = slot_world_pos + Vector2(180.0, 0.0)
	var tw: Tween = create_tween()
	tw.tween_property(self, "position", _target_pos, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	queue_redraw()


func move_to_slot(slot_idx: int, slot_world_pos: Vector2) -> void:
	queue_slot = slot_idx
	_target_pos = slot_world_pos
	var tw: Tween = create_tween()
	tw.tween_property(self, "position", _target_pos, 0.25).set_ease(Tween.EASE_OUT)


func freeze_patience(sec: float) -> void:
	patience_frozen_timer = maxf(patience_frozen_timer, sec)
	queue_redraw()


func boost_patience(sec: float) -> void:
	patience_remaining = minf(patience_max, patience_remaining + sec)
	queue_redraw()


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if is_served:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			get_viewport().set_input_as_handled()
			customer_clicked.emit(self)


func _process(delta: float) -> void:
	if is_served or archetype == null:
		return
	_bob_time += delta
	if EventBus.timers_paused:
		queue_redraw()
		return
	if patience_frozen_timer > 0.0:
		patience_frozen_timer -= delta
	else:
		var slot_drain_mult: float = 1.0 if queue_slot == 0 else 0.40
		patience_remaining -= delta * patience_slow_mult * slot_drain_mult

	if patience_remaining <= patience_max * 0.28 and not _warned_impatient:
		_warned_impatient = true
		if not archetype.impatient_lines.is_empty():
			EventBus.customer_dialogue_requested.emit(
				archetype.customer_id,
				archetype.portrait_impatient,
				archetype.impatient_lines[0],
				false
			)
	queue_redraw()


func get_patience_ratio() -> float:
	return clampf(patience_remaining / maxf(1.0, patience_max), 0.0, 1.0)


func play_exit_anim(happy: bool) -> void:
	is_served = true
	var tw: Tween = create_tween()
	var end_pos: Vector2 = position + (Vector2(140.0, -25.0) if happy else Vector2(180.0, 20.0))
	tw.tween_property(self, "position", end_pos, 0.28)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.28)
	tw.tween_callback(queue_free)


func _draw() -> void:
	if archetype == null:
		return
	var bob: float = sin(_bob_time * 4.2 + float(queue_slot)) * 2.5
	var outline: Color = Color(1.0, 0.92, 0.45) if hovered else Color(0.11, 0.08, 0.14)
	var body_col: Color = _character_color(archetype.customer_id)

	# Ground shadow
	draw_circle(Vector2(0, 32), 20.0, Color(0, 0, 0, 0.28))

	# Curvy ~3-head semi-chibi silhouette
	var torso: PackedVector2Array = PackedVector2Array([
		Vector2(-11, -2 + bob), Vector2(11, -2 + bob),
		Vector2(16, 26 + bob), Vector2(-16, 26 + bob),
	])
	draw_colored_polygon(torso, body_col)
	draw_polyline(torso + PackedVector2Array([torso[0]]), outline, 2.5)

	# Head
	draw_circle(Vector2(0, -18 + bob), 17.0, Color(1.0, 0.87, 0.78))
	draw_circle(Vector2(0, -18 + bob), 17.0, outline, false, 2.5)

	# Species silhouette flair (horns, wolf ears, hat)
	match archetype.customer_id:
		&"sylvi":
			draw_arc(Vector2(-15, -24 + bob), 9.0, 0.2, PI * 1.3, 10, Color(0.75, 0.56, 0.40), 4.0)
			draw_arc(Vector2(15, -24 + bob), 9.0, -PI * 0.3, PI * 0.8, 10, Color(0.75, 0.56, 0.40), 4.0)
		&"velvet":
			draw_colored_polygon(PackedVector2Array([Vector2(-10, -32 + bob), Vector2(-18, -46 + bob), Vector2(-3, -34 + bob)]), Color(0.22, 0.08, 0.15))
			draw_colored_polygon(PackedVector2Array([Vector2(10, -32 + bob), Vector2(18, -46 + bob), Vector2(3, -34 + bob)]), Color(0.22, 0.08, 0.15))
		&"mona":
			draw_colored_polygon(PackedVector2Array([Vector2(-20, -28 + bob), Vector2(20, -28 + bob), Vector2(0, -50 + bob)]), Color(0.18, 0.18, 0.35))
		&"roxy":
			draw_colored_polygon(PackedVector2Array([Vector2(-14, -28 + bob), Vector2(-16, -44 + bob), Vector2(-4, -33 + bob)]), Color(0.55, 0.38, 0.26))
			draw_colored_polygon(PackedVector2Array([Vector2(14, -28 + bob), Vector2(16, -44 + bob), Vector2(4, -33 + bob)]), Color(0.55, 0.38, 0.26))
		&"seraphina":
			draw_rect(Rect2(-11, -36 + bob, 22, 6), Color(1.0, 0.84, 0.3))

	# Eyes
	draw_circle(Vector2(-6, -18 + bob), 2.3, Color(0.12, 0.08, 0.14))
	draw_circle(Vector2(6, -18 + bob), 2.3, Color(0.12, 0.08, 0.14))

	# Order speech bubble above head (especially clear for first 4 slots)
	if requested_recipe != null and not is_served:
		var bub_pos: Vector2 = Vector2(-42, -92 + bob * 0.5)
		draw_rect(Rect2(bub_pos, Vector2(84, 42)), Color(0.98, 0.96, 0.90))
		draw_rect(Rect2(bub_pos, Vector2(84, 42)), Color(0.12, 0.09, 0.14), false, 2.5)
		# Flask color + ingredients dots
		draw_circle(bub_pos + Vector2(22, 21), 11.0, requested_recipe.potion_color)
		draw_circle(bub_pos + Vector2(22, 21), 11.0, Color(0.1, 0.08, 0.12), false, 2.0)
		for i: int in range(requested_recipe.required_ingredients.size()):
			var ing_col: Color = KitchenStation._ingredient_color(requested_recipe.required_ingredients[i])
			var dot_p: Vector2 = bub_pos + Vector2(48 + i * 16, 21)
			draw_circle(dot_p, 6.5, ing_col)
			if String(requested_recipe.required_ingredients[i]).begins_with("crushed_"):
				draw_circle(dot_p, 8.5, Color(1.0, 0.85, 0.2), false, 1.8)

		# Patience bar
		var p_ratio: float = get_patience_ratio()
		var bar_col: Color = Color(0.3, 0.88, 0.45) if p_ratio > 0.5 else (Color(1.0, 0.72, 0.18) if p_ratio > 0.25 else Color(0.96, 0.22, 0.25))
		if patience_frozen_timer > 0.0:
			bar_col = Color(0.42, 0.88, 1.0)
		draw_rect(Rect2(-28, -46, 56, 7), Color(0.12, 0.09, 0.14))
		draw_rect(Rect2(-27, -45, 54 * p_ratio, 5), bar_col)


static func _character_color(cid: StringName) -> Color:
	match cid:
		&"sylvi": return Color(0.30, 0.68, 0.36)
		&"velvet": return Color(0.85, 0.20, 0.36)
		&"seraphina": return Color(0.86, 0.88, 0.96)
		&"mona": return Color(0.24, 0.36, 0.76)
		&"roxy": return Color(0.68, 0.42, 0.24)
	return Color(0.6, 0.4, 0.7)
