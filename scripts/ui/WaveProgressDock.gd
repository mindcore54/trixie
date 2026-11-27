@tool
class_name WaveProgressDock
extends Control
## Visual customer wave progress dock using miniature tilted flask icons.

@export var flask_empty_tex: Texture2D = preload("res://assets/ui/hud/empty_bottle_icon.png"):
	set(value):
		flask_empty_tex = value
		_refresh_current_slots()
@export var flask_done_tex: Texture2D = preload("res://assets/ui/hud/completed_bottle_icon.png"):
	set(value):
		flask_done_tex = value
		_refresh_current_slots()
@export var flask_failed_tex: Texture2D = preload("res://assets/ui/hud/failure_bottle_icon.png"):
	set(value):
		flask_failed_tex = value
		_refresh_current_slots()

@onready var _slots_row: HBoxContainer = $SlotsRow

var _slots: Array[Control] = []
var _current_states: Array[int] = []
var _last_states: Array[int] = []
var _pop_tweens: Dictionary = {}
var _pulse_time: float = 0.0


func _ready() -> void:
	_collect_slots()
	if Engine.is_editor_hint() and _current_states.is_empty():
		update_slots([
			WaveDirector.SlotState.SERVED,
			WaveDirector.SlotState.ACTIVE,
			WaveDirector.SlotState.PENDING,
		])


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_pulse_time += delta * 4.5
	var pulse_t: float = 0.5 + 0.5 * sin(_pulse_time)
	for i: int in range(_slots.size()):
		var slot: Control = _slots[i]
		if not slot.visible:
			continue
		if _pop_tweens.has(i):
			var tw: Tween = _pop_tweens[i] as Tween
			if tw != null and is_instance_valid(tw) and tw.is_running():
				continue
		var st: int = _current_states[i] if i < _current_states.size() else WaveDirector.SlotState.PENDING
		if st == WaveDirector.SlotState.ACTIVE:
			slot.scale = Vector2.ONE * lerpf(1.06, 1.16, pulse_t)
			slot.modulate = Color(1.0, 0.96, 0.86).lerp(Color(1.18, 1.12, 0.98), pulse_t)
		elif st == WaveDirector.SlotState.PENDING:
			slot.scale = Vector2.ONE
			slot.modulate = Color(0.82, 0.85, 0.92, 0.88)
		else:
			slot.scale = Vector2.ONE
			slot.modulate = Color.WHITE


func _collect_slots() -> void:
	_slots.clear()
	if _slots_row == null:
		return
	for child: Node in _slots_row.get_children():
		if child is Control:
			_slots.append(child as Control)


func _create_extra_slot(idx: int) -> Control:
	var slot: Control = Control.new()
	slot.name = "Slot%d" % idx
	slot.custom_minimum_size = Vector2(56.0, 64.0)
	slot.pivot_offset = Vector2(28.0, 32.0)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_tex: TextureRect = TextureRect.new()
	icon_tex.name = "IconTex"
	icon_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon_tex)

	_slots_row.add_child(slot)
	_slots.append(slot)
	return slot


func _refresh_current_slots() -> void:
	if not _current_states.is_empty():
		update_slots(_current_states)


func update_slots(states: Array[int]) -> void:
	if _slots_row == null:
		return
	if _slots.is_empty():
		_collect_slots()

	while _slots.size() < states.size():
		_create_extra_slot(_slots.size())

	var can_animate_pop: bool = (not Engine.is_editor_hint()) and (_last_states.size() == states.size())
	for i: int in range(_slots.size()):
		var slot: Control = _slots[i]
		if i >= states.size():
			slot.visible = false
			continue
		slot.visible = true
		var st: int = states[i]
		_apply_slot_visual(slot, st)

		if can_animate_pop and _last_states[i] != st and (st == WaveDirector.SlotState.SERVED or st == WaveDirector.SlotState.FAILED):
			_trigger_pop_tween(i, slot)

	_current_states = states.duplicate()
	_last_states = states.duplicate()


func _apply_slot_visual(slot: Control, st: int) -> void:
	var icon_tex: TextureRect = slot.get_node_or_null("IconTex") as TextureRect
	if icon_tex == null:
		return
	var chosen_tex: Texture2D = flask_empty_tex
	if st == WaveDirector.SlotState.SERVED and flask_done_tex != null:
		chosen_tex = flask_done_tex
	elif st == WaveDirector.SlotState.FAILED and flask_failed_tex != null:
		chosen_tex = flask_failed_tex
	icon_tex.texture = chosen_tex
	icon_tex.visible = chosen_tex != null


func _trigger_pop_tween(idx: int, slot: Control) -> void:
	if _pop_tweens.has(idx):
		var old_tw: Tween = _pop_tweens[idx] as Tween
		if old_tw != null and is_instance_valid(old_tw):
			old_tw.kill()
	slot.scale = Vector2(1.38, 1.38)
	slot.modulate = Color.WHITE
	var tw: Tween = create_tween()
	tw.tween_property(slot, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop_tweens[idx] = tw


func has_textures() -> bool:
	return flask_empty_tex != null and flask_done_tex != null and flask_failed_tex != null


func get_visible_slot_count() -> int:
	var count: int = 0
	for slot: Control in _slots:
		if slot.visible:
			count += 1
	return count


func get_slot_states() -> Array[int]:
	return _current_states.duplicate()
