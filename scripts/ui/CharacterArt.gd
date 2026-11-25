class_name CharacterArt
extends RefCounted
## Cargador, caché y animador de sprites reales (Trixie y clientas),
## con un placeholder mínimo por si falta algún PNG futuro.

const TRIXIE_ART_DIR: String = "res://assets/characters/playable/trixie"
const CUSTOMERS_ART_DIR: String = "res://assets/characters/customers"
static var _tex_cache: Dictionary = {}


static func _get_cached_tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path] as Texture2D
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_tex_cache[path] = tex
	return tex


static func get_trixie_fullbody() -> Texture2D:
	return _get_cached_tex("%s/trixie_fullbody.png" % TRIXIE_ART_DIR)


static func get_trixie_expression(emotion: String, size_tier: String = "dialogue") -> Texture2D:
	var fname: String = "trixie_normal.png"
	match emotion:
		"confiada":
			fname = "trixie_confiada.png"
		"nerviosa", "nerviosa_sudando":
			fname = "trixie_nerviosa_sudando.png"
		"sonrojada", "sonrojada_picante":
			fname = "trixie_sonrojada_picante.png"
		"hollin", "hollin_derrota":
			fname = "trixie_hollin_derrota.png"
		"sorprendida":
			fname = "trixie_sorprendida.png"
	var tier: String = size_tier if size_tier in ["cutscene", "dialogue", "hud"] else "dialogue"
	return _get_cached_tex("%s/portraits/%s/%s" % [TRIXIE_ART_DIR, tier, fname])


static func get_trixie_halfbody(emotion: String) -> Texture2D:
	var emo_key: String = "normal"
	match emotion:
		"confiada":
			emo_key = "confiada"
		"nerviosa", "nerviosa_sudando":
			emo_key = "nerviosa_sudando"
		"sonrojada", "sonrojada_picante":
			emo_key = "sonrojada_picante"
		"hollin", "hollin_derrota":
			emo_key = "hollin_derrota"
		"sorprendida":
			emo_key = "sorprendida"
	var tex: Texture2D = _get_cached_tex("%s/halfbody/trixie_halfbody_%s.png" % [TRIXIE_ART_DIR, emo_key])
	if tex != null:
		return tex
	# Graceful fallback to core half-body expressions until Sheet 2 is exported
	if emo_key == "sonrojada_picante":
		var conf: Texture2D = _get_cached_tex("%s/halfbody/trixie_halfbody_confiada.png" % TRIXIE_ART_DIR)
		if conf != null:
			return conf
	elif emo_key in ["hollin_derrota", "sorprendida"]:
		var nerv: Texture2D = _get_cached_tex("%s/halfbody/trixie_halfbody_nerviosa_sudando.png" % TRIXIE_ART_DIR)
		if nerv != null:
			return nerv
	return _get_cached_tex("%s/halfbody/trixie_halfbody_normal.png" % TRIXIE_ART_DIR)


static func _draw_halfbody_tex(ci: CanvasItem, rect: Rect2, tex: Texture2D, off_x: float, off_y: float, sx: float, sy: float, bob: float, dim: float) -> void:
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	var scale_f: float = minf(rect.size.x / maxf(1.0, tw), rect.size.y / maxf(1.0, th))
	var dw: float = roundf(tw * scale_f * sx)
	var dh: float = roundf(th * scale_f * sy)
	var anchor_x: float = rect.position.x + rect.size.x * 0.5
	var anchor_y: float = rect.position.y + rect.size.y
	var dst: Rect2 = Rect2(
		roundf(anchor_x - dw * 0.5 + off_x),
		roundf(anchor_y - dh + bob + off_y),
		dw,
		dh
	)
	ci.draw_texture_rect(tex, dst, false, Color(dim, dim, dim, 1.0))


## Frameless tall vertical half-body Trixie fitted inside `rect` (bottom-aligned, crisp 1:1 or gently fitted).
static func draw_trixie_halfbody(ci: CanvasItem, rect: Rect2, emotion: String, t: float, dim: float = 1.0, react_progress: float = 0.0) -> void:
	var tex: Texture2D = get_trixie_halfbody(emotion)
	if tex != null:
		var p: float = clampf(react_progress, 0.0, 1.0)
		var pop: float = sin(p * PI)
		var off_x: float = 0.0
		var off_y: float = -pop * 5.0
		var sx: float = 1.0
		var sy: float = 1.0
		var bob: float = roundf(sin(t * 2.1) * 3.0)
		match emotion:
			"sorprendida":
				off_y = -pop * 16.0
				sx = 1.0 - pop * 0.035
				sy = 1.0 + pop * 0.055
				bob = roundf(sin(t * 3.0) * 2.5)
			"hollin", "hollin_derrota":
				off_x = sin(t * 48.0) * 6.5 * p
				off_y = 6.0 + pop * 5.0
				sx = 1.0 + pop * 0.035
				sy = 1.0 - pop * 0.045
				bob = roundf(sin(t * 1.4) * 2.0)
			"sonrojada", "sonrojada_picante":
				off_x = sin(t * 2.2) * 3.0
				off_y = -pop * 8.0
				sx = 1.0 + pop * 0.025
				sy = 1.0 + pop * 0.025
				bob = roundf(sin(t * 2.1) * 3.0)
			"confiada":
				off_y = -pop * 12.0
				sx = 1.0 - pop * 0.02
				sy = 1.0 + pop * 0.035
				bob = roundf(sin(t * 2.4) * 3.0)
			"nerviosa", "nerviosa_sudando":
				off_x = sin(t * 34.0) * (2.2 + 4.0 * p)
				off_y = -pop * 5.0
				bob = roundf(sin(t * 2.1) * 2.5)
		_draw_halfbody_tex(ci, rect, tex, off_x, off_y, sx, sy, bob, dim)
		return
	draw_trixie_bust(ci, rect, emotion, t, dim, "cutscene")


static func get_customer_halfbody(customer_id: StringName, emotion: String) -> Texture2D:
	var cid: String = String(customer_id)
	var emo_key: String = "normal"
	match emotion:
		"sonrojada", "sonrojada_picante":
			emo_key = "sonrojada_picante"
		"impaciente", "molesta":
			emo_key = "impaciente"
	var tex: Texture2D = _get_cached_tex("%s/%s/halfbody/%s_halfbody_%s.png" % [CUSTOMERS_ART_DIR, cid, cid, emo_key])
	if tex != null:
		return tex
	return _get_cached_tex("%s/%s/halfbody/%s_halfbody_normal.png" % [CUSTOMERS_ART_DIR, cid, cid])


static func has_customer_halfbody(customer_id: StringName) -> bool:
	return get_customer_halfbody(customer_id, "normal") != null


static func draw_customer_halfbody(ci: CanvasItem, rect: Rect2, customer_id: StringName, emotion: String, t: float, dim: float = 1.0, react_progress: float = 0.0) -> bool:
	var tex: Texture2D = get_customer_halfbody(customer_id, emotion)
	if tex == null:
		return false
	var p: float = clampf(react_progress, 0.0, 1.0)
	var pop: float = sin(p * PI)
	var off_x: float = 0.0
	var off_y: float = -pop * 6.0
	var sx: float = 1.0
	var sy: float = 1.0
	var bob: float = roundf(sin(t * 1.8) * 3.0)
	match emotion:
		"sonrojada", "sonrojada_picante":
			off_x = sin(t * 2.0) * 3.0
			off_y = -pop * 8.0
			sx = 1.0 + pop * 0.025
			sy = 1.0 + pop * 0.025
			bob = roundf(sin(t * 1.9) * 3.0)
		"impaciente", "molesta":
			off_x = sin(t * 36.0) * 5.0 * p
			off_y = -pop * 9.0
			sx = 1.0 - pop * 0.02
			sy = 1.0 + pop * 0.03
			bob = roundf(sin(t * 2.4) * 2.0)
	_draw_halfbody_tex(ci, rect, tex, off_x, off_y, sx, sy, bob, dim)
	return true


static func dim_color(c: Color, dim: float) -> Color:
	return Color(c.r * dim, c.g * dim, c.b * dim, c.a)


static func _ellipse(c: Vector2, rx: float, ry: float, n: int = 20) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(n):
		var a: float = TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _draw_missing_placeholder(ci: CanvasItem, rect: Rect2, label: String, dim: float = 1.0) -> void:
	ci.draw_rect(rect, dim_color(Color(0.14, 0.10, 0.22, 0.85), dim))
	ci.draw_rect(rect, dim_color(Color(0.86, 0.68, 0.34, 0.9), dim), false, 2.5)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		ci.draw_string(
			font,
			Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			22,
			dim_color(Color(0.98, 0.92, 0.82), dim)
		)


## Full-body Trixie standing with feet at `feet` (design height ~360 units * s).
static func draw_trixie_full(ci: CanvasItem, feet: Vector2, s: float, _emotion: String, t: float, dim: float = 1.0) -> void:
	var full_tex: Texture2D = get_trixie_fullbody()
	if full_tex != null:
		var u_y: float = sin(t * 2.2) * 3.5
		var target_h: float = 385.0 * s
		var aspect: float = float(full_tex.get_width()) / maxf(1.0, float(full_tex.get_height()))
		var target_w: float = target_h * aspect
		ci.draw_colored_polygon(_ellipse(feet + Vector2(0, -2.0 * s), 74.0 * s, 14.0 * s), Color(0, 0, 0, 0.28))
		var dst: Rect2 = Rect2(feet.x - target_w * 0.5, feet.y - target_h + u_y, target_w, target_h)
		ci.draw_texture_rect(full_tex, dst, false, Color(dim, dim, dim, 1.0))
		return
	var ph_size: Vector2 = Vector2(180.0 * s, 320.0 * s)
	_draw_missing_placeholder(ci, Rect2(feet.x - ph_size.x * 0.5, feet.y - ph_size.y, ph_size.x, ph_size.y), "Trixie", dim)


## Framed/frameless chest-up Trixie bust fitted inside `rect` (bottom-aligned for sitting behind parchment).
## `size_tier` selects the 1:1 pre-scaled portrait ("cutscene", "dialogue", or "hud") to avoid runtime downscale artifacts.
static func draw_trixie_bust(ci: CanvasItem, rect: Rect2, emotion: String, t: float, dim: float = 1.0, size_tier: String = "dialogue") -> void:
	var expr_tex: Texture2D = get_trixie_expression(emotion, size_tier)
	if expr_tex != null:
		var tw: float = float(expr_tex.get_width())
		var th: float = float(expr_tex.get_height())
		var scale_f: float = minf(1.0, minf(rect.size.x / maxf(1.0, tw), rect.size.y / maxf(1.0, th)))
		var dw: float = roundf(tw * scale_f)
		var dh: float = roundf(th * scale_f)
		var bob: float = roundf(sin(t * 2.4) * 2.5)
		var dst: Rect2 = Rect2(
			roundf(rect.position.x + (rect.size.x - dw) * 0.5),
			roundf(rect.position.y + (rect.size.y - dh)) + bob,
			dw,
			dh
		)
		ci.draw_texture_rect(expr_tex, dst, false, Color(dim, dim, dim, 1.0))
		return
	_draw_missing_placeholder(ci, rect, "Trixie", dim)


## Respaldo simple si una clienta futura aún no tiene sprite PNG en assets/characters/customers/.
static func draw_expressive_waifu_bust(ci: CanvasItem, rect: Rect2, cid: StringName, _spicy: bool, _t: float) -> void:
	_draw_missing_placeholder(ci, rect, String(cid).capitalize())
