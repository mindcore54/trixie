class_name KitchenStation
extends Area2D
## Interactive 2.5D potion kitchen station: Ingredient Bins, Mortar, Cauldrons, Bottling, Trash.

enum StationType {
	INGREDIENT_BIN,
	MORTAR,
	CAULDRON,
	BOTTLING,
	TRASH,
}

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
var held_ingredients: Array[StringName] = []
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


func _ready() -> void:
	input_pickable = true
	monitoring = false
	monitorable = false
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(138.0, 118.0) if station_type == StationType.CAULDRON else Vector2(126.0, 108.0)
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


func configure_catalog(recipes: Array[PotionRecipeData], current_day: int, brew_mult: float) -> void:
	_recipes_ref = recipes
	_unlocked_day = current_day
	_brew_speed_mult = brew_mult


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			get_viewport().set_input_as_handled()
			station_clicked.emit(self)


func _process(delta: float) -> void:
	_pulse_time += delta
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
		overheat_duration = matched.overheat_grace_sec
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
		StationType.TRASH:
			_draw_trash(outline_col, outline_w)


func _draw_crate(outline_col: Color, outline_w: float) -> void:
	var box: Rect2 = Rect2(-52, -40, 104, 80)
	draw_rect(Rect2(-48, -32, 104, 82), Color(0, 0, 0, 0.28))
	draw_rect(box, Color(0.46, 0.28, 0.18))
	draw_rect(box, outline_col, false, outline_w)
	draw_rect(Rect2(-42, -30, 84, 54), accent_color.darkened(0.35))
	# Draw glowing ingredient gems/herbs inside
	for i: int in range(3):
		var ox: float = -22.0 + i * 22.0
		var oy: float = -6.0 + sin(_pulse_time * 2.5 + i) * 2.0
		draw_circle(Vector2(ox, oy), 13.0, accent_color)
		draw_circle(Vector2(ox - 3, oy - 3), 4.0, Color(1, 1, 1, 0.7))
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


func _draw_bottling(outline_col: Color, outline_w: float) -> void:
	draw_rect(Rect2(-56, -38, 120, 84), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-58, -42, 116, 80), Color(0.38, 0.27, 0.22))
	draw_rect(Rect2(-58, -42, 116, 80), outline_col, false, outline_w)
	# Empty glass flasks silhouette
	for i: int in range(3):
		var fx: float = -28.0 + i * 28.0
		draw_circle(Vector2(fx, 4), 11.0, Color(0.75, 0.92, 1.0, 0.75))
		draw_rect(Rect2(fx - 4, -15, 8, 10), Color(0.75, 0.92, 1.0, 0.85))
		draw_rect(Rect2(fx - 4, -19, 8, 5), Color(0.76, 0.52, 0.30))
	_draw_station_caption(display_label, Vector2(0, 56))


func _draw_trash(outline_col: Color, outline_w: float) -> void:
	draw_circle(Vector2.ZERO, 34.0, Color(0.28, 0.22, 0.32))
	draw_circle(Vector2.ZERO, 34.0, outline_col, false, outline_w)
	draw_circle(Vector2.ZERO, 22.0, Color(0.12, 0.08, 0.16))
	_draw_station_caption(display_label, Vector2(0, 50))


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
