class_name PortraitStage
extends Control
## Escenario de retratos para diálogos con varios interlocutores.
## Las brujas se colocan a la izquierda (miran a la derecha) y las clientas a la derecha
## (miran a la izquierda). El que habla toma protagonismo; los demás quedan pequeños y oscuros.

const PORTRAIT_SCENE: PackedScene = preload("res://scenes/ui/StagePortrait.tscn")
const STAGE_WIDTH: float = 1920.0
const FLOOR_Y: float = 1080.0
const EDGE_CENTER_X: float = 380.0
const SLOT_SPACING: float = 190.0
const FOCUS_SECONDS: float = 0.26
const MOVE_SECONDS: float = 0.35
const ENTER_SECONDS: float = 0.42
const EXIT_SECONDS: float = 0.32

var _members: Dictionary = {}
var _left: Array[StringName] = []
var _right: Array[StringName] = []


func add_member(id: StringName, kind: String, lane: String, emotion: String = "normal") -> void:
	if _members.has(id):
		return
	var portrait: StagePortrait = PORTRAIT_SCENE.instantiate() as StagePortrait
	add_child(portrait)
	portrait.setup(id, kind, lane)
	portrait.set_emotion(emotion)
	portrait.feet_y = FLOOR_Y
	portrait.set_focused(false, 0.0)
	_members[id] = portrait
	var members_in_lane: Array[StringName] = _lane(lane)
	members_in_lane.append(id)
	portrait.feet_x = _slot_x(lane, members_in_lane.size() - 1)
	portrait.appear_in(ENTER_SECONDS)


func remove_member(id: StringName) -> void:
	if not _members.has(id):
		return
	var portrait: StagePortrait = _members[id] as StagePortrait
	_members.erase(id)
	_lane(portrait.side).erase(id)
	portrait.disappear(EXIT_SECONDS)
	_relayout(portrait.side)


func clear_members() -> void:
	for child: Node in get_children():
		child.queue_free()
	_members.clear()
	_left.clear()
	_right.clear()


## Da el protagonismo a `id`; con un id vacío (narrador) todos quedan en segundo plano.
func set_speaker(id: StringName, emotion: String = "") -> void:
	for key: Variant in _members:
		var member_id: StringName = key
		var portrait: StagePortrait = _members[member_id] as StagePortrait
		var is_speaker: bool = member_id == id
		portrait.set_focused(is_speaker, FOCUS_SECONDS)
		if is_speaker and emotion != "":
			portrait.set_emotion(emotion)


func shake_member(id: StringName, seconds: float = 0.35) -> void:
	if _members.has(id):
		(_members[id] as StagePortrait).shake(seconds)


func _lane(lane: String) -> Array[StringName]:
	return _left if lane == "left" else _right


func _slot_x(lane: String, index: int) -> float:
	if lane == "left":
		return EDGE_CENTER_X + float(index) * SLOT_SPACING
	return STAGE_WIDTH - EDGE_CENTER_X - float(index) * SLOT_SPACING


func _relayout(lane: String) -> void:
	var members_in_lane: Array[StringName] = _lane(lane)
	for i: int in members_in_lane.size():
		(_members[members_in_lane[i]] as StagePortrait).move_to(_slot_x(lane, i), MOVE_SECONDS)
