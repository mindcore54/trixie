class_name PotionFlaskView
extends Node2D
## Manages the vertical potion flask's liquid spring/slosh physics, circular hue
## pigment mixing synced with the cauldron broth, shader uniforms, and order bubble drawing.

const FLASK_SIZE: Vector2 = Vector2(88.0, 501.0)
const TUBE_RECT: Rect2 = Rect2(1312.0, 265.0, 54.0, 445.0)
const BROTH_NEUTRAL_COLOR: Color = Color(0.11, 0.09, 0.22)
const FLASK_NEUTRAL_COLOR: Color = Color(0.42, 0.36, 0.58)

@onready var liquid_sprite: Sprite2D = $LiquidSprite
@onready var glass_sprite: Sprite2D = $GlassSprite

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

	if liquid_mat != null:
		liquid_mat.set_shader_parameter("fill_ratio", clampf(display_pct / 100.0, 0.0, 1.0))
		liquid_mat.set_shader_parameter("liquid_color", tube_color_current)
		liquid_mat.set_shader_parameter("slosh_amp", slosh_amp)
		liquid_mat.set_shader_parameter("slosh_tilt", slosh_tilt)
		liquid_mat.set_shader_parameter("pour_glow", pour_glow)
		var flash_norm: float = clampf(flash_timer / 0.45, 0.0, 1.0)
		liquid_mat.set_shader_parameter("flash_amount", flash_norm)
		liquid_mat.set_shader_parameter("flash_negative", 0.0 if flash_positive else 1.0)


func draw_potion_tube(ci: CanvasItem, potion_pct: float, liked_col: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var f_rect: Rect2 = get_flask_rect()
	if glass_tex != null and liquid_mat != null:
		var pct_txt: String = "%d%%" % int(roundf(potion_pct))
		var lbl_pos: Vector2 = Vector2(f_rect.position.x - 4.0, f_rect.end.y + 30.0)
		var lbl_w: int = int(f_rect.size.x + 8.0)
		ci.draw_string(font, lbl_pos + Vector2(2, 2), pct_txt, HORIZONTAL_ALIGNMENT_CENTER, lbl_w, 24, Color(0.05, 0.02, 0.10, 0.90))
		ci.draw_string(font, lbl_pos, pct_txt, HORIZONTAL_ALIGNMENT_CENTER, lbl_w, 24, Color(1.0, 0.94, 0.78))
		return

	var r: Rect2 = TUBE_RECT
	var pct: float = clampf(potion_pct / 100.0, 0.0, 1.0)

	ci.draw_rect(r.grow(5.0), Color(liked_col.r, liked_col.g, liked_col.b, 0.16))
	ci.draw_rect(r, Color(0.08, 0.06, 0.14, 0.90))
	ci.draw_rect(r, Color(liked_col.r, liked_col.g, liked_col.b, 0.16))
	if pct > 0.0:
		var fill_h: float = r.size.y * pct
		var fill_rect: Rect2 = Rect2(r.position.x + 5, r.position.y + r.size.y - fill_h, r.size.x - 10, fill_h)
		var fill_col: Color = liked_col.lightened(0.18) if (flash_timer > 0.0 and flash_positive) else (Color(1.0, 0.24, 0.28) if (flash_timer > 0.0 and not flash_positive) else liked_col)
		ci.draw_rect(fill_rect, fill_col)
		ci.draw_rect(Rect2(fill_rect.position.x, fill_rect.position.y, fill_rect.size.x, 6.0), Color(1, 1, 1, 0.65))

	for mark: float in [0.25, 0.50, 0.75]:
		var my: float = r.position.y + r.size.y * (1.0 - mark)
		ci.draw_line(Vector2(r.position.x + 4, my), Vector2(r.position.x + 20, my), Color(1, 1, 1, 0.45), 2.0)

	ci.draw_rect(r, liked_col.lightened(0.28), false, 3.5)
	ci.draw_rect(Rect2(r.position.x + 8, r.position.y - 16, r.size.x - 16, 16), Color(0.68, 0.46, 0.26))
	ci.draw_string(font, Vector2(r.position.x - 12, r.position.y + r.size.y + 34), "%d%%" % int(roundf(potion_pct)), HORIZONTAL_ALIGNMENT_CENTER, 78, 24, Color(1.0, 0.94, 0.78))


func draw_order_bubble(ci: CanvasItem, chem: Dictionary, time_sec: float, draw_badge_fn: Callable) -> void:
	var liked_k: int = int(chem["liked"])
	var liked_col: Color = ChemistryRules.get_element_color(liked_k)
	var box: Rect2 = Rect2(1256.0, 102.0, 164.0, 134.0)
	var pulse: float = 0.5 + 0.5 * sin(time_sec * 4.5)

	var f_rect: Rect2 = get_flask_rect()
	var flask_cork: Vector2 = Vector2(f_rect.position.x + f_rect.size.x * 0.5, f_rect.position.y + 8.0)
	ci.draw_line(Vector2(1338.0, box.end.y), flask_cork, Color(liked_col.r, liked_col.g, liked_col.b, 0.55), 4.0)

	ci.draw_rect(box, Color(0.11, 0.07, 0.19, 0.94))
	ci.draw_rect(box, liked_col.lightened(0.25), false, 3.0)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(box.end.x, 152.0),
		Vector2(box.end.x + 22.0, 166.0),
		Vector2(box.end.x, 180.0),
	]), Color(0.11, 0.07, 0.19, 0.94))
	ci.draw_polyline(PackedVector2Array([
		Vector2(box.end.x, 152.0),
		Vector2(box.end.x + 22.0, 166.0),
		Vector2(box.end.x, 180.0),
	]), liked_col.lightened(0.25), 2.8)

	var font: Font = ThemeDB.fallback_font
	if ChemistryRules.is_mixed_kind(liked_k):
		var main_c: Vector2 = Vector2(box.position.x + box.size.x * 0.5, box.position.y + 42.0)
		ci.draw_circle(main_c, 31.0 + pulse * 4.0, Color(liked_col.r, liked_col.g, liked_col.b, 0.24))
		ci.draw_arc(main_c, 28.0, 0.0, TAU, 28, Color(1.0, 0.90, 0.38, 0.90), 2.6)
		draw_badge_fn.call(ci, main_c, 25.0, liked_k, false)

		var comps: Array[int] = ChemistryRules.get_recipe_components(liked_k)
		var y_rec: float = box.position.y + 104.0
		draw_badge_fn.call(ci, Vector2(box.position.x + 44.0, y_rec), 15.0, comps[0], false)
		ci.draw_string(font, Vector2(box.position.x + 71.0, y_rec + 7.0), "+", HORIZONTAL_ALIGNMENT_CENTER, 22, 20, Color(1.0, 0.92, 0.65))
		draw_badge_fn.call(ci, Vector2(box.position.x + 120.0, y_rec), 15.0, comps[1], false)
	else:
		var main_c: Vector2 = box.position + box.size * 0.5 + Vector2(0.0, 4.0)
		ci.draw_circle(main_c, 42.0 + pulse * 5.0, Color(liked_col.r, liked_col.g, liked_col.b, 0.24))
		ci.draw_arc(main_c, 37.0, 0.0, TAU, 28, Color(1.0, 0.90, 0.38, 0.92), 3.0)
		draw_badge_fn.call(ci, main_c, 33.0, liked_k, false)
		ci.draw_string(font, Vector2(box.position.x, box.position.y + 20.0), "PIDE", HORIZONTAL_ALIGNMENT_CENTER, int(box.size.x), 14, Color(1.0, 0.92, 0.65))
