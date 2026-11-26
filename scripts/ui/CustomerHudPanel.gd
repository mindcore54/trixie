@tool
class_name CustomerHudPanel
extends Control
## Compact customer name parchment ribbon and glass/brass patience vial HUD.

const COLOR_LIME: Color = Color(0.56, 0.94, 0.18, 1.0)
const COLOR_YELLOW: Color = Color(1.0, 0.88, 0.14, 1.0)
const COLOR_RED: Color = Color(0.98, 0.22, 0.24, 1.0)
const COLOR_PAUSED: Color = Color(0.42, 0.80, 0.98, 1.0)
const CRITICAL_BLINK_RATIO: float = 0.18

@onready var _ribbon_bg: TextureRect = $NameRibbon/RibbonBg
@onready var _name_lbl: Label = $NameRibbon/ContentRow/CustomerNameLabel
@onready var _affinity_lbl: Label = $NameRibbon/ContentRow/CustomerAffinityLabel
@onready var _patience_prefix: Label = $PatienceAmpoule/HBox/PatiencePrefixLabel
@onready var _glass_tube: Control = $PatienceAmpoule/HBox/GlassTube
@onready var _liquid_rect: TextureRect = $PatienceAmpoule/HBox/GlassTube/LiquidMask
@onready var _vial_glass_rect: TextureRect = $PatienceAmpoule/HBox/GlassTube/VialGlass

var _liquid_mat: ShaderMaterial = null
var _is_urgent: bool = false
var _pulse_time: float = 0.0


func _ready() -> void:
	if _liquid_rect != null and _liquid_rect.material is ShaderMaterial:
		_liquid_mat = _liquid_rect.material as ShaderMaterial

	_sync_shadow_sizes()
	if not resized.is_connected(_sync_shadow_sizes):
		resized.connect(_sync_shadow_sizes)
	if _ribbon_bg != null and not _ribbon_bg.resized.is_connected(_sync_shadow_sizes):
		_ribbon_bg.resized.connect(_sync_shadow_sizes)
	if _vial_glass_rect != null and not _vial_glass_rect.resized.is_connected(_sync_shadow_sizes):
		_vial_glass_rect.resized.connect(_sync_shadow_sizes)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _glass_tube == null:
		return
	if _is_urgent:
		_pulse_time += delta * 7.0
		var pulse_t: float = 0.5 + 0.5 * sin(_pulse_time)
		_glass_tube.modulate = Color(1.0, 0.78, 0.80).lerp(Color.WHITE, pulse_t)
	else:
		_pulse_time = 0.0
		_glass_tube.modulate = Color.WHITE


func _sync_shadow_sizes() -> void:
	if _ribbon_bg != null and _ribbon_bg.material is ShaderMaterial:
		(_ribbon_bg.material as ShaderMaterial).set_shader_parameter("render_size", _ribbon_bg.size)
	if _vial_glass_rect != null and _vial_glass_rect.material is ShaderMaterial:
		(_vial_glass_rect.material as ShaderMaterial).set_shader_parameter("render_size", _vial_glass_rect.size)


func has_textures() -> bool:
	return (
		_ribbon_bg != null and _ribbon_bg.texture != null
		and _liquid_rect != null and _liquid_rect.texture != null
		and _vial_glass_rect != null and _vial_glass_rect.texture != null
	)


func has_custom_name_font() -> bool:
	return _name_lbl != null and _name_lbl.has_theme_font_override("font") and _name_lbl.get_theme_font("font") != null


func get_displayed_name() -> String:
	return _name_lbl.text if _name_lbl != null else ""


func get_patience_prefix_text() -> String:
	return _patience_prefix.text if _patience_prefix != null else ""


func get_fill_ratio() -> float:
	if _liquid_mat != null:
		return float(_liquid_mat.get_shader_parameter("fill_ratio"))
	return 0.0


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

	if _patience_prefix != null:
		if patience_paused:
			_patience_prefix.modulate = Color(0.76, 0.92, 1.0)
		elif p_ratio <= impatient_ratio:
			_patience_prefix.modulate = Color(1.0, 0.48, 0.50)
		else:
			_patience_prefix.modulate = Color(0.98, 0.91, 0.74)

	_is_urgent = urgent
