class_name PotionFlaskView
extends Node2D
## Manages the vertical potion flask's liquid spring/slosh physics, circular hue
## pigment mixing synced with the cauldron broth, shader uniforms, and order bubble drawing.

const FLASK_SIZE: Vector2 = Vector2(88.0, 501.0)
const BROTH_NEUTRAL_COLOR: Color = Color(0.11, 0.09, 0.22)
const FLASK_NEUTRAL_COLOR: Color = Color(0.42, 0.36, 0.58)

@onready var liquid_sprite: Sprite2D = $LiquidSprite
@onready var glass_sprite: Sprite2D = $GlassSprite
@onready var percent_label: Label = get_node_or_null("PercentLabel") as Label

var glass_tex: Texture2D = null
var mask_tex: Texture2D = null
var liquid_mat: ShaderMaterial = null

var display_pct: float = 0.0
var fill_vel: float = 0.0
var slosh_amp: float = 0.0
var slosh_tilt: float = 0.0
var slosh_vel: float = 0.0
var pour_glow: float = 0.0
var tube_color_current: Color = FLASK_NEUTRAL_COLOR
var mix_hue_vec: Vector2 = Vector2.ZERO
var mix_weight: float = 0.0
var broth_target_color: Color = BROTH_NEUTRAL_COLOR
var broth_current_color: Color = BROTH_NEUTRAL_COLOR
var flask_target_color: Color = FLASK_NEUTRAL_COLOR
var flash_timer: float = 0.0
var flash_positive: bool = true


func _ready() -> void:
	if liquid_sprite != null:
		mask_tex = liquid_sprite.texture
		liquid_mat = liquid_sprite.material as ShaderMaterial
	if glass_sprite != null:
		glass_tex = glass_sprite.texture


func has_assets() -> bool:
	return glass_tex != null and mask_tex != null and liquid_mat != null and glass_sprite != null and liquid_sprite != null


func get_flask_rect() -> Rect2:
	return Rect2(position, FLASK_SIZE)


func reset_for_new_customer(first_order: bool) -> void:
	display_pct = 0.0
	fill_vel = 0.0
	slosh_amp = 0.35
	slosh_tilt = 0.0
	slosh_vel = 1.8
	pour_glow = 0.0
	if percent_label != null:
		percent_label.text = "0%"
	reset_mix_pigment(first_order)
	if not first_order:
		tube_color_current = FLASK_NEUTRAL_COLOR


func reset_mix_pigment(instant: bool = false) -> void:
	mix_hue_vec = Vector2.ZERO
	mix_weight = 0.0
	broth_target_color = BROTH_NEUTRAL_COLOR
	flask_target_color = FLASK_NEUTRAL_COLOR
	if instant:
		broth_current_color = BROTH_NEUTRAL_COLOR
		tube_color_current = FLASK_NEUTRAL_COLOR


func inject_mix_pigment(kind: int, tier: int = 1) -> void:
	var c: Color = ChemistryRules.get_element_color(kind)
	var ang: float = c.h * TAU
	var w: float = (0.7 if kind == ChemistryRules.BubbleKind.GOLD else (0.45 if kind == ChemistryRules.BubbleKind.BOMB else 1.0)) * (1.0 + float(maxi(0, tier - 1)) * 0.35)
	mix_hue_vec = mix_hue_vec * 0.85 + Vector2(cos(ang), sin(ang)) * w
	mix_weight = minf(12.0, mix_weight * 0.85 + w)
	var res_h: float = c.h
	if mix_hue_vec.length() >= 0.14:
		res_h = fposmod(atan2(mix_hue_vec.y, mix_hue_vec.x) / TAU, 1.0)
	broth_target_color = Color.from_hsv(res_h, 0.72, 0.34)
	flask_target_color = Color.from_hsv(res_h, 0.82, 0.96)


func trigger_flash(duration: float, positive: bool) -> void:
	flash_timer = duration
	flash_positive = positive


func excite(delta_pct: float) -> void:
	fill_vel += delta_pct * 3.8
	slosh_amp = minf(1.25, slosh_amp + clampf(absf(delta_pct) / 28.0, 0.25, 0.95))
	var impulse_dir: float = 1.0 if delta_pct >= 0.0 else -1.0
	slosh_vel += impulse_dir * randf_range(3.2, 5.2)
	if delta_pct > 0.0:
		pour_glow = minf(1.2, pour_glow + 0.85)


func step_fluid(delta: float, target_potion_pct: float, cauldron_shake: float) -> void:
	if flash_timer > 0.0:
		flash_timer = maxf(0.0, flash_timer - delta)

	var target_pct: float = clampf(target_potion_pct, 0.0, 100.0)
	var fill_force: float = (target_pct - display_pct) * 78.0 - fill_vel * 11.5
	fill_vel += fill_force * delta
	display_pct = clampf(display_pct + fill_vel * delta, 0.0, 104.0)

	if cauldron_shake > 0.5:
		slosh_amp = minf(1.25, slosh_amp + delta * 0.65)
	var slosh_accel: float = -28.0 * slosh_tilt - 4.2 * slosh_vel
	slosh_vel += slosh_accel * delta
	slosh_tilt = clampf(slosh_tilt + slosh_vel * delta, -1.5, 1.5)
	slosh_amp = maxf(0.0, slosh_amp - delta * 1.45)
	pour_glow = maxf(0.0, pour_glow - delta * 2.4)

	broth_current_color = broth_current_color.lerp(broth_target_color, clampf(delta * 2.8, 0.0, 1.0))
	tube_color_current = tube_color_current.lerp(flask_target_color, clampf(delta * 6.5, 0.0, 1.0))

	if percent_label != null:
		percent_label.text = "%d%%" % int(roundf(target_pct))
	if liquid_mat != null:
		liquid_mat.set_shader_parameter("fill_ratio", clampf(display_pct / 100.0, 0.0, 1.0))
		liquid_mat.set_shader_parameter("liquid_color", tube_color_current)
		liquid_mat.set_shader_parameter("slosh_amp", slosh_amp)
		liquid_mat.set_shader_parameter("slosh_tilt", slosh_tilt)
		liquid_mat.set_shader_parameter("pour_glow", pour_glow)
		var flash_norm: float = clampf(flash_timer / 0.45, 0.0, 1.0)
		liquid_mat.set_shader_parameter("flash_amount", flash_norm)
		liquid_mat.set_shader_parameter("flash_negative", 0.0 if flash_positive else 1.0)
