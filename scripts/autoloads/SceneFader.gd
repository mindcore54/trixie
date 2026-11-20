extends CanvasLayer
## Global fade-to-black transitions between Menu, Cutscenes and Gameplay.

var _rect: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 1)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	add_child(_rect)


func is_busy() -> bool:
	return _busy


func is_black() -> bool:
	return _rect.modulate.a > 0.99


func set_black() -> void:
	_rect.modulate.a = 1.0
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP


func fade_out(duration: float = 0.45) -> void:
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw: Tween = create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_rect, "modulate:a", 1.0, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await tw.finished


func fade_in(duration: float = 0.45) -> void:
	var tw: Tween = create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_rect, "modulate:a", 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	await tw.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func fade_to_scene(scene_path: String, out_duration: float = 0.55, in_duration: float = 0.55) -> void:
	if _busy:
		return
	_busy = true
	await fade_out(out_duration)
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	await fade_in(in_duration)
	_busy = false
