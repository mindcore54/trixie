@tool
class_name CustomerHudPanel
extends Control
## Compact customer name parchment ribbon and glass/brass patience vial HUD.

const COLOR_LIME: Color = Color(0.56, 0.94, 0.18, 1.0)
const COLOR_YELLOW: Color = Color(1.0, 0.88, 0.14, 1.0)
const COLOR_RED: Color = Color(0.98, 0.22, 0.24, 1.0)
const COLOR_PAUSED: Color = Color(0.42, 0.80, 0.98, 1.0)
const CRITICAL_BLINK_RATIO: float = 0.18

@export var hourglass_icon_tex: Texture2D = preload("res://assets/ui/hud/hourglass_icon.png"):
	set(value):
		hourglass_icon_tex = value
		if is_node_ready():
			_sync_icon_slots()
@export var heart_icon_tex: Texture2D = preload("res://assets/ui/hud/heart_icon.png"):
	set(value):
		heart_icon_tex = value
		if is_node_ready():
			_sync_icon_slots()
@export var essence_icon_tex: Texture2D = preload("res://assets/ui/hud/essence_icon.png"):
	set(value):
		essence_icon_tex = value
		if is_node_ready():
			_sync_icon_slots()
@export var hourglass_flip_interval: float = 3.0
@export var hourglass_flip_duration: float = 0.72
@export var hourglass_anticipation_deg: float = 12.0

@onready var _ribbon_bg: TextureRect = $NameRibbon/RibbonBg
@onready var _name_lbl: Label = $NameRibbon/ContentRow/CustomerNameLabel
@onready var _heart_icon: TextureRect = $NameRibbon/ContentRow/AffinityBox/HeartIcon
@onready var _affinity_lbl: Label = $NameRibbon/ContentRow/AffinityBox/CustomerAffinityLabel
@onready var _essence_mini_icon: TextureRect = $NameRibbon/ContentRow/AffinityBox/EssenceMiniIcon
@onready var _reward_lbl: Label = $NameRibbon/ContentRow/AffinityBox/CustomerRewardLabel
@onready var _hourglass_icon: TextureRect = $PatienceAmpoule/HBox/HourglassIcon
@onready var _glass_tube: Control = $PatienceAmpoule/HBox/GlassTube
@onready var _liquid_rect: TextureRect = $PatienceAmpoule/HBox/GlassTube/LiquidMask
@onready var _vial_glass_rect: TextureRect = $PatienceAmpoule/HBox/GlassTube/VialGlass

var _liquid_mat: ShaderMaterial = null
var _is_urgent: bool = false
var _is_patience_paused: bool = false
var _pulse_time: float = 0.0
var _hourglass_flip_timer: float = 0.0
var _hourglass_flip_tween: Tween = null
var _hourglass_target_rot: float = 0.0


func _ready() -> void:
	if _liquid_rect != null and _liquid_rect.material is ShaderMaterial:
		_liquid_mat = _liquid_rect.material as ShaderMaterial

	_sync_icon_slots()
	_sync_shadow_sizes()
	if not resized.is_connected(_sync_shadow_sizes):
		resized.connect(_sync_shadow_sizes)
	if _ribbon_bg != null and not _ribbon_bg.resized.is_connected(_sync_shadow_sizes):
		_ribbon_bg.resized.connect(_sync_shadow_sizes)
	if _vial_glass_rect != null and not _vial_glass_rect.resized.is_connected(_sync_shadow_sizes):
		_vial_glass_rect.resized.connect(_sync_shadow_sizes)
	if _hourglass_icon != null and not _hourglass_icon.resized.is_connected(_sync_shadow_sizes):
		_hourglass_icon.resized.connect(_sync_shadow_sizes)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _glass_tube != null:
		if _is_urgent:
			_pulse_time += delta * 7.0
			var pulse_t: float = 0.5 + 0.5 * sin(_pulse_time)
			_glass_tube.modulate = Color(1.0, 0.78, 0.80).lerp(Color.WHITE, pulse_t)
		else:
			_pulse_time = 0.0
			_glass_tube.modulate = Color.WHITE

	if _hourglass_icon != null and _hourglass_icon.visible and not _is_patience_paused:
		var flipping: bool = _hourglass_flip_tween != null and is_instance_valid(_hourglass_flip_tween) and _hourglass_flip_tween.is_running()
		if not flipping:
			_hourglass_flip_timer += delta
			if _hourglass_flip_timer >= hourglass_flip_interval:
				_hourglass_flip_timer = 0.0
				_trigger_hourglass_flip()


func _sync_icon_slots() -> void:
	if _hourglass_icon != null:
		_hourglass_icon.texture = hourglass_icon_tex
		_hourglass_icon.visible = hourglass_icon_tex != null
	if _heart_icon != null:
		_heart_icon.texture = heart_icon_tex
		_heart_icon.visible = heart_icon_tex != null
	if _essence_mini_icon != null:
		_essence_mini_icon.texture = essence_icon_tex
		_essence_mini_icon.visible = essence_icon_tex != null


func _sync_shadow_sizes() -> void:
	if _ribbon_bg != null and _ribbon_bg.material is ShaderMaterial:
		(_ribbon_bg.material as ShaderMaterial).set_shader_parameter("render_size", _ribbon_bg.size)
	if _vial_glass_rect != null and _vial_glass_rect.material is ShaderMaterial:
		(_vial_glass_rect.material as ShaderMaterial).set_shader_parameter("render_size", _vial_glass_rect.size)
	if _hourglass_icon != null:
		_hourglass_icon.pivot_offset = _hourglass_icon.size * 0.5


func has_textures() -> bool:
	return (
		_ribbon_bg != null and _ribbon_bg.texture != null
		and _liquid_rect != null and _liquid_rect.texture != null
		and _vial_glass_rect != null and _vial_glass_rect.texture != null
		and _hourglass_icon != null and _hourglass_icon.texture != null
		and _heart_icon != null and _heart_icon.texture != null
		and _essence_mini_icon != null and _essence_mini_icon.texture != null
	)


func has_custom_name_font() -> bool:
	return _name_lbl != null and _name_lbl.has_theme_font_override("font") and _name_lbl.get_theme_font("font") != null


func get_displayed_name() -> String:
	return _name_lbl.text if _name_lbl != null else ""


func get_patience_prefix_text() -> String:
	if _hourglass_icon != null and _hourglass_icon.texture != null and _hourglass_icon.visible:
		return "icon"
	return ""


func get_fill_ratio() -> float:
	if _liquid_mat != null:
		return float(_liquid_mat.get_shader_parameter("fill_ratio"))
	return 0.0


func update_status_data(
	customer_name: String,
	affinity_level: int,
	reward_gold: int,
	patience_left: float,
	patience_max: float,
	patience_paused: bool,
	impatient_ratio: float
) -> void:
	if customer_name != "" and _name_lbl != null:
		_name_lbl.text = customer_name

	if affinity_level >= 0:
		_sync_icon_slots()
		if _affinity_lbl != null:
			_affinity_lbl.text = "Nv.%d ·" % affinity_level
		if _reward_lbl != null:
			_reward_lbl.text = "+%d" % reward_gold
			_reward_lbl.visible = true

	_apply_patience_visuals(patience_left, patience_max, patience_paused, impatient_ratio)


func update_status(
	customer_name: String,
	affinity_text: String,
	patience_left: float,
	patience_max: float,
	patience_paused: bool,
	impatient_ratio: float
) -> void:
	if customer_name != "" and _name_lbl != null:
		_name_lbl.text = customer_name
	if affinity_text != "" and _affinity_lbl != null:
		_affinity_lbl.text = affinity_text
		if _reward_lbl != null:
			_reward_lbl.visible = false

	_apply_patience_visuals(patience_left, patience_max, patience_paused, impatient_ratio)


func _apply_patience_visuals(
	patience_left: float,
	patience_max: float,
	patience_paused: bool,
	impatient_ratio: float
) -> void:
	var p_ratio: float = clampf(patience_left / maxf(1.0, patience_max), 0.0, 1.0)
	var blink_threshold: float = minf(CRITICAL_BLINK_RATIO, impatient_ratio)
	var urgent: bool = (not patience_paused) and (p_ratio <= blink_threshold)
	if _liquid_mat != null:
		_liquid_mat.set_shader_parameter("fill_ratio", p_ratio)
		_liquid_mat.set_shader_parameter("paused_amount", 1.0 if patience_paused else 0.0)
		_liquid_mat.set_shader_parameter("urgent_amount", 1.0 if urgent else 0.0)
		var col: Color
		if patience_paused:
			col = COLOR_PAUSED
		elif p_ratio >= 0.50:
			col = COLOR_LIME.lerp(COLOR_YELLOW, clampf((0.65 - p_ratio) / 0.15, 0.0, 1.0))
		elif p_ratio >= impatient_ratio:
			col = COLOR_YELLOW.lerp(COLOR_RED, clampf((0.45 - p_ratio) / maxf(0.01, 0.45 - impatient_ratio), 0.0, 1.0))
		else:
			col = COLOR_RED
		_liquid_mat.set_shader_parameter("liquid_color", col)

	var prefix_mod: Color = Color.WHITE
	if patience_paused:
		prefix_mod = Color(0.76, 0.92, 1.0)
	elif p_ratio <= impatient_ratio:
		prefix_mod = Color(1.0, 0.52, 0.54)

	if _hourglass_icon != null:
		_hourglass_icon.modulate = prefix_mod

	if _is_patience_paused != patience_paused:
		_is_patience_paused = patience_paused
		if _hourglass_flip_tween != null and is_instance_valid(_hourglass_flip_tween):
			if _is_patience_paused:
				_hourglass_flip_tween.pause()
			else:
				_hourglass_flip_tween.play()

	_is_urgent = urgent


func _trigger_hourglass_flip() -> void:
	if _hourglass_icon == null:
		return
	if _hourglass_flip_tween != null and is_instance_valid(_hourglass_flip_tween):
		_hourglass_flip_tween.kill()
	_hourglass_icon.pivot_offset = _hourglass_icon.size * 0.5
	var start_rot: float = _hourglass_target_rot
	var end_rot: float = start_rot + PI

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_hourglass_icon, "rotation", start_rot - deg_to_rad(hourglass_anticipation_deg), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_hourglass_icon, "scale", Vector2(1.08, 0.94), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().set_parallel(true)
	tw.tween_property(_hourglass_icon, "rotation", end_rot, hourglass_flip_duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_hourglass_icon, "scale", Vector2(1.14, 1.14), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_hourglass_icon, "scale", Vector2.ONE, 0.36).set_delay(0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void:
		_hourglass_target_rot = fposmod(end_rot, TAU)
		if _hourglass_icon != null:
			_hourglass_icon.rotation = _hourglass_target_rot
			_hourglass_icon.scale = Vector2.ONE
		_hourglass_flip_tween = null
	)
	_hourglass_flip_tween = tw
