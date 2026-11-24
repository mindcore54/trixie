class_name CharacterArt
extends RefCounted
## Procedural placeholder character art (Trixie & Doña Remedios) shared by the main menu,
## cutscenes and HUD dialogue portraits until final sprites from raw_assets/ replace them.

const OUTLINE: Color = Color(0.08, 0.05, 0.12)
const SKIN: Color = Color(1.0, 0.87, 0.79)
const EYE_DARK: Color = Color(0.12, 0.08, 0.15)
const TRIXIE_DRESS: Color = Color(0.66, 0.18, 0.38)
const TRIXIE_HAIR: Color = Color(0.24, 0.13, 0.18)
const GOLD: Color = Color(1.0, 0.82, 0.32)

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


static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color, dim: float, outline_w: float = 2.8) -> void:
	ci.draw_colored_polygon(pts, dim_color(col, dim))
	if outline_w > 0.0:
		ci.draw_polyline(pts + PackedVector2Array([pts[0]]), dim_color(OUTLINE, dim), outline_w)


static func _off(pts: PackedVector2Array, o: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in pts:
		out.append(p + o)
	return out


static func _ellipse(c: Vector2, rx: float, ry: float, n: int = 20) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(n):
		var a: float = TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _sparkle(ci: CanvasItem, c: Vector2, r: float, dim: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		c + Vector2(0, -r), c + Vector2(r * 0.28, -r * 0.28), c + Vector2(r, 0), c + Vector2(r * 0.28, r * 0.28),
		c + Vector2(0, r), c + Vector2(-r * 0.28, r * 0.28), c + Vector2(-r, 0), c + Vector2(-r * 0.28, -r * 0.28),
	])
	ci.draw_colored_polygon(pts, dim_color(Color(1.0, 0.94, 0.55), dim))


static func _sweat(ci: CanvasItem, c: Vector2, k: float, t: float, dim: float) -> void:
	var cycle: float = fmod(t * 1.7, 1.0)
	var p: Vector2 = c + Vector2(0, cycle * 10.0 * k)
	var a: float = 1.0 - maxf(0.0, (cycle - 0.7) / 0.3)
	var drop: PackedVector2Array = PackedVector2Array([
		p + Vector2(0, -7.0 * k), p + Vector2(4.5 * k, 1.5 * k), p + Vector2(0, 5.5 * k), p + Vector2(-4.5 * k, 1.5 * k),
	])
	ci.draw_colored_polygon(drop, Color(0.45, 0.85, 1.0, a * dim))
	ci.draw_polyline(drop + PackedVector2Array([drop[0]]), Color(0.10, 0.26, 0.48, a * dim), 1.4 * k)


## Expressive anime face. Emotions: normal, confiada, nerviosa, sonrojada, hollin, sorprendida.
static func draw_face(ci: CanvasItem, c: Vector2, r: float, emotion: String, t: float, dim: float = 1.0) -> void:
	var k: float = r / 34.0
	var eye_l: Vector2 = c + Vector2(-12, -2) * k
	var eye_r: Vector2 = c + Vector2(12, -2) * k
	var dark: Color = dim_color(EYE_DARK, dim)
	var white: Color = dim_color(Color(1, 1, 1), dim)
	var mouth_col: Color = dim_color(Color(0.62, 0.14, 0.22), dim)
	var blush: Color = Color(1.0, 0.45, 0.56, 0.40 * dim)
	match emotion:
		"confiada":
			ci.draw_arc(eye_l + Vector2(0, 2) * k, 5.0 * k, PI + 0.35, TAU - 0.35, 10, dark, 2.6 * k)
			ci.draw_arc(eye_r + Vector2(0, 2) * k, 5.0 * k, PI + 0.35, TAU - 0.35, 10, dark, 2.6 * k)
			var grin: PackedVector2Array = PackedVector2Array()
			for i: int in range(9):
				var a: float = PI * float(i) / 8.0
				grin.append(c + Vector2(cos(a) * 9.0, 8.0 + sin(a) * 7.0) * k)
			ci.draw_colored_polygon(grin, mouth_col)
			ci.draw_colored_polygon(_ellipse(c + Vector2(-19, 9) * k, 6.0 * k, 3.5 * k), blush)
			ci.draw_colored_polygon(_ellipse(c + Vector2(19, 9) * k, 6.0 * k, 3.5 * k), blush)
			_sparkle(ci, c + Vector2(r * 1.3, -r * 0.95), 7.0 * k * (0.8 + 0.3 * sin(t * 6.0)), dim)
		"nerviosa":
			var jitter: Vector2 = Vector2(sin(t * 23.0), 0.0) * 0.8 * k
			for e: Vector2 in [eye_l, eye_r]:
				ci.draw_circle(e, 6.0 * k, white)
				ci.draw_circle(e, 6.0 * k, dark, false, 1.8 * k)
				ci.draw_circle(e + jitter, 2.3 * k, dark)
			var wave: PackedVector2Array = PackedVector2Array()
			for i: int in range(6):
				wave.append(c + Vector2(-9.0 + float(i) * 3.6, 12.0 + (2.0 if i % 2 == 0 else -1.5)) * k)
			ci.draw_polyline(wave, mouth_col, 2.2 * k)
			ci.draw_colored_polygon(_ellipse(c + Vector2(-19, 8) * k, 5.0 * k, 3.0 * k), blush)
			ci.draw_colored_polygon(_ellipse(c + Vector2(19, 8) * k, 5.0 * k, 3.0 * k), blush)
			_sweat(ci, c + Vector2(r * 0.98, -r * 0.62), k, t, dim)
		"sonrojada":
			for e: Vector2 in [eye_l, eye_r]:
				ci.draw_circle(e, 4.4 * k, dark)
				ci.draw_circle(e + Vector2(2.4, -0.6) * k, 1.6 * k, white)
			var strong: Color = Color(1.0, 0.36, 0.50, 0.78 * dim)
			ci.draw_colored_polygon(_ellipse(c + Vector2(-18, 9) * k, 9.0 * k, 5.0 * k), strong)
			ci.draw_colored_polygon(_ellipse(c + Vector2(18, 9) * k, 9.0 * k, 5.0 * k), strong)
			for i: int in range(3):
				var ox: float = -22.0 + float(i) * 4.0
				ci.draw_line(c + Vector2(ox, 6) * k, c + Vector2(ox + 2.5, 11) * k, dim_color(Color(0.85, 0.20, 0.32), dim), 1.3 * k)
				ci.draw_line(c + Vector2(-ox, 6) * k, c + Vector2(-ox - 2.5, 11) * k, dim_color(Color(0.85, 0.20, 0.32), dim), 1.3 * k)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-5, 12) * k, c + Vector2(-2, 14.5) * k, c + Vector2(0, 12) * k, c + Vector2(2, 14.5) * k, c + Vector2(5, 12) * k]), mouth_col, 2.0 * k)
		"hollin":
			ci.draw_circle(c + Vector2(-15, 9) * k, 8.0 * k, Color(0.12, 0.10, 0.12, 0.6 * dim))
			ci.draw_circle(c + Vector2(16, -12) * k, 6.0 * k, Color(0.12, 0.10, 0.12, 0.55 * dim))
			for e: Vector2 in [eye_l, eye_r]:
				ci.draw_line(e + Vector2(-4, -4) * k, e + Vector2(4, 4) * k, dark, 2.4 * k)
				ci.draw_line(e + Vector2(4, -4) * k, e + Vector2(-4, 4) * k, dark, 2.4 * k)
			ci.draw_arc(c + Vector2(0, 19) * k, 7.0 * k, PI + 0.45, TAU - 0.45, 10, mouth_col, 2.4 * k)
			var puff: float = fmod(t * 0.9, 1.0)
			ci.draw_circle(c + Vector2(-r * 0.6, -r * 1.3 - puff * 16.0 * k), (5.0 + puff * 4.0) * k, Color(0.35, 0.33, 0.36, (1.0 - puff) * 0.6 * dim))
		"sorprendida":
			for e: Vector2 in [eye_l, eye_r]:
				ci.draw_circle(e, 6.6 * k, white)
				ci.draw_circle(e, 6.6 * k, dark, false, 1.8 * k)
				ci.draw_circle(e, 3.2 * k, dark)
				ci.draw_circle(e + Vector2(-1.2, -1.4) * k, 1.2 * k, white)
			ci.draw_circle(c + Vector2(0, 13) * k, 4.2 * k, mouth_col)
			ci.draw_colored_polygon(_ellipse(c + Vector2(-19, 8) * k, 5.0 * k, 3.0 * k), blush)
			ci.draw_colored_polygon(_ellipse(c + Vector2(19, 8) * k, 5.0 * k, 3.0 * k), blush)
		_:
			for e: Vector2 in [eye_l, eye_r]:
				ci.draw_circle(e, 4.4 * k, dark)
				ci.draw_circle(e + Vector2(-1.4, -1.6) * k, 1.5 * k, white)
			ci.draw_arc(c + Vector2(0, 9) * k, 7.5 * k, 0.2, PI - 0.2, 10, mouth_col, 2.4 * k)
			ci.draw_colored_polygon(_ellipse(c + Vector2(-18, 8) * k, 5.0 * k, 3.0 * k), Color(1.0, 0.48, 0.58, 0.30 * dim))
			ci.draw_colored_polygon(_ellipse(c + Vector2(18, 8) * k, 5.0 * k, 3.0 * k), Color(1.0, 0.48, 0.58, 0.30 * dim))


static func _draw_trixie_hat(ci: CanvasItem, o: Vector2, dim: float) -> void:
	_poly(ci, _off(PackedVector2Array([Vector2(-62, -282), Vector2(62, -282), Vector2(0, -300)]), o), TRIXIE_DRESS.darkened(0.34), dim, 2.8)
	_poly(ci, _off(PackedVector2Array([Vector2(-31, -290), Vector2(31, -290), Vector2(4, -330), Vector2(-14, -354), Vector2(-10, -330)]), o), TRIXIE_DRESS.darkened(0.28), dim, 2.8)
	ci.draw_line(Vector2(-29, -291) + o, Vector2(29, -291) + o, dim_color(GOLD, dim), 5.0)
	_sparkle(ci, Vector2(14, -300) + o, 5.0, dim)


## Full-body Trixie standing with feet at `feet` (design height ~360 units * s).
static func draw_trixie_full(ci: CanvasItem, feet: Vector2, s: float, emotion: String, t: float, dim: float = 1.0) -> void:
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
	var u: Vector2 = Vector2(0.0, sin(t * 2.2) * 2.5)
	ci.draw_set_transform(feet, 0.0, Vector2(s, s))
	ci.draw_colored_polygon(_ellipse(Vector2(0, -2), 74.0, 14.0), Color(0, 0, 0, 0.28))
	# Flowing hair behind shoulders
	_poly(ci, _off(PackedVector2Array([Vector2(-46, -254), Vector2(46, -254), Vector2(60, -134), Vector2(0, -150), Vector2(-60, -134)]), u), TRIXIE_HAIR, dim, 2.4)
	# Legs + thigh-high stockings + arcane boots
	ci.draw_rect(Rect2(-26, -104, 18, 32), dim_color(SKIN, dim))
	ci.draw_rect(Rect2(8, -104, 18, 32), dim_color(SKIN, dim))
	ci.draw_rect(Rect2(-26, -76, 18, 44), dim_color(Color(0.16, 0.11, 0.20), dim))
	ci.draw_rect(Rect2(8, -76, 18, 44), dim_color(Color(0.16, 0.11, 0.20), dim))
	_poly(ci, PackedVector2Array([Vector2(-28, -36), Vector2(-6, -36), Vector2(-4, 0), Vector2(-36, 0)]), Color(0.24, 0.12, 0.30), dim, 2.5)
	_poly(ci, PackedVector2Array([Vector2(6, -36), Vector2(28, -36), Vector2(36, 0), Vector2(4, 0)]), Color(0.24, 0.12, 0.30), dim, 2.5)
	# Flared witch skirt
	_poly(ci, PackedVector2Array([Vector2(-26, -162), Vector2(26, -162), Vector2(66, -90), Vector2(22, -98), Vector2(0, -92), Vector2(-22, -98), Vector2(-66, -90)]), TRIXIE_DRESS, dim, 3.0)
	# Curvy corset bodice + neckline + laces
	_poly(ci, _off(PackedVector2Array([Vector2(-27, -218), Vector2(27, -218), Vector2(18, -160), Vector2(-18, -160)]), u), TRIXIE_DRESS.darkened(0.15), dim, 2.8)
	ci.draw_colored_polygon(_off(PackedVector2Array([Vector2(-14, -218), Vector2(14, -218), Vector2(0, -199)]), u), dim_color(SKIN, dim))
	ci.draw_line(Vector2(-18, -162) + u, Vector2(18, -162) + u, dim_color(GOLD, dim), 4.0)
	for i: int in range(3):
		ci.draw_line(Vector2(-6, -192 + i * 10) + u, Vector2(6, -186 + i * 10) + u, dim_color(Color(1.0, 0.86, 0.52), dim), 1.6)
	# Arms + floating fire spark
	ci.draw_line(Vector2(-24, -210) + u, Vector2(-54, -164) + u, dim_color(SKIN, dim), 10.0)
	ci.draw_line(Vector2(24, -210) + u, Vector2(62, -188) + u, dim_color(SKIN, dim), 10.0)
	var flick: float = 1.0 + sin(t * 9.0) * 0.15
	ci.draw_circle(Vector2(76, -208) + u, 17.0 * flick, Color(1.0, 0.45, 0.25, 0.45 * dim))
	ci.draw_circle(Vector2(76, -208) + u, 9.0 * flick, dim_color(Color(1.0, 0.86, 0.36), dim))
	# Neck + head
	ci.draw_rect(Rect2(Vector2(-7, -234) + u, Vector2(14, 18)), dim_color(SKIN, dim))
	ci.draw_circle(Vector2(0, -258) + u, 34.0, dim_color(SKIN, dim))
	ci.draw_circle(Vector2(0, -258) + u, 34.0, dim_color(OUTLINE, dim), false, 3.0)
	# Side locks + bangs
	_poly(ci, _off(PackedVector2Array([Vector2(-37, -272), Vector2(-24, -274), Vector2(-28, -228), Vector2(-41, -222)]), u), TRIXIE_HAIR, dim, 2.0)
	_poly(ci, _off(PackedVector2Array([Vector2(37, -272), Vector2(24, -274), Vector2(28, -228), Vector2(41, -222)]), u), TRIXIE_HAIR, dim, 2.0)
	_poly(ci, _off(PackedVector2Array([Vector2(-33, -278), Vector2(33, -278), Vector2(27, -264), Vector2(13, -272), Vector2(0, -263), Vector2(-13, -272), Vector2(-27, -264)]), u), TRIXIE_HAIR, dim, 2.0)
	draw_face(ci, Vector2(0, -250) + u, 34.0, emotion, t, dim)
	_draw_trixie_hat(ci, u, dim)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
	var k: float = rect.size.y / 225.0
	var base: Vector2 = rect.position + Vector2(rect.size.x * 0.5, rect.size.y)
	var u: Vector2 = Vector2(0.0, sin(t * 2.2) * 2.0)
	ci.draw_set_transform(base, 0.0, Vector2(k, k))
	_poly(ci, _off(PackedVector2Array([Vector2(-56, -162), Vector2(56, -162), Vector2(66, -48), Vector2(0, -60), Vector2(-66, -48)]), u), TRIXIE_HAIR, 1.0, 2.4)
	_poly(ci, PackedVector2Array([Vector2(-80, 0), Vector2(80, 0), Vector2(58, -64), Vector2(-58, -64)]), TRIXIE_DRESS, 1.0, 3.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-28, -64), Vector2(28, -64), Vector2(0, -26)]), SKIN)
	ci.draw_line(Vector2(-58, -64), Vector2(58, -64), GOLD, 3.0)
	ci.draw_rect(Rect2(Vector2(-9, -102) + u, Vector2(18, 40)), SKIN)
	ci.draw_circle(Vector2(0, -130) + u, 42.0, SKIN)
	ci.draw_circle(Vector2(0, -130) + u, 42.0, OUTLINE, false, 3.2)
	_poly(ci, _off(PackedVector2Array([Vector2(-46, -146), Vector2(-30, -150), Vector2(-34, -92), Vector2(-50, -84)]), u), TRIXIE_HAIR, 1.0, 2.0)
	_poly(ci, _off(PackedVector2Array([Vector2(46, -146), Vector2(30, -150), Vector2(34, -92), Vector2(50, -84)]), u), TRIXIE_HAIR, 1.0, 2.0)
	_poly(ci, _off(PackedVector2Array([Vector2(-41, -152), Vector2(41, -152), Vector2(33, -136), Vector2(16, -146), Vector2(0, -135), Vector2(-16, -146), Vector2(-33, -136)]), u), TRIXIE_HAIR, 1.0, 2.0)
	draw_face(ci, Vector2(0, -121) + u, 42.0, emotion, t, 1.0)
	var hat_o: Vector2 = u + Vector2(0, 128)
	ci.draw_set_transform(base + hat_o * k, 0.0, Vector2(k * 1.18, k * 1.18))
	_draw_trixie_hat(ci, Vector2(0, 0), 1.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Kind, mischievous old lady. Emotions: normal, risa, picara, seria.
static func draw_granny_full(ci: CanvasItem, feet: Vector2, s: float, emotion: String, t: float, dim: float = 1.0) -> void:
	var u: Vector2 = Vector2(0.0, sin(t * 1.6) * 1.8)
	var wood: Color = Color(0.46, 0.30, 0.18)
	var skirt: Color = Color(0.26, 0.36, 0.30)
	var blouse: Color = Color(0.86, 0.78, 0.64)
	var shawl: Color = Color(0.60, 0.46, 0.74)
	var hair: Color = Color(0.84, 0.84, 0.88)
	ci.draw_set_transform(feet, 0.0, Vector2(s, s))
	ci.draw_colored_polygon(_ellipse(Vector2(0, -2), 70.0, 13.0), Color(0, 0, 0, 0.28))
	# Cane
	ci.draw_line(Vector2(54, -150), Vector2(62, 0), dim_color(wood, dim), 6.0)
	ci.draw_arc(Vector2(46, -150), 8.0, PI, TAU, 8, dim_color(wood, dim), 6.0)
	# Shoes + long skirt
	ci.draw_colored_polygon(_ellipse(Vector2(-22, -3), 15.0, 7.0), dim_color(Color(0.20, 0.14, 0.12), dim))
	ci.draw_colored_polygon(_ellipse(Vector2(20, -3), 15.0, 7.0), dim_color(Color(0.20, 0.14, 0.12), dim))
	_poly(ci, PackedVector2Array([Vector2(-46, -132), Vector2(42, -132), Vector2(58, -6), Vector2(-58, -6)]), skirt, dim, 2.8)
	ci.draw_line(Vector2(-54, -22), Vector2(54, -22), dim_color(skirt.lightened(0.25), dim), 3.0)
	# Hunched torso, shawl & arm on cane
	_poly(ci, _off(PackedVector2Array([Vector2(-38, -208), Vector2(32, -210), Vector2(44, -128), Vector2(-44, -128)]), u), blouse, dim, 2.6)
	_poly(ci, _off(PackedVector2Array([Vector2(-54, -206), Vector2(50, -212), Vector2(4, -116)]), u), shawl, dim, 2.6)
	for i: int in range(5):
		var fx: float = -30.0 + float(i) * 15.0
		ci.draw_line(Vector2(fx, -150 + absf(fx) * 0.5) + u, Vector2(fx, -140 + absf(fx) * 0.5) + u, dim_color(shawl.darkened(0.25), dim), 2.0)
	ci.draw_line(Vector2(30, -186) + u, Vector2(46, -154), dim_color(blouse, dim), 11.0)
	ci.draw_circle(Vector2(48, -150), 6.5, dim_color(SKIN, dim))
	# Head, silver hair & bun
	ci.draw_circle(Vector2(8, -252) + u, 31.0, dim_color(hair, dim))
	ci.draw_circle(Vector2(12, -286) + u, 15.0, dim_color(hair, dim))
	ci.draw_circle(Vector2(12, -286) + u, 15.0, dim_color(OUTLINE, dim), false, 2.4)
	ci.draw_circle(Vector2(8, -240) + u, 28.0, dim_color(SKIN, dim))
	ci.draw_circle(Vector2(8, -240) + u, 28.0, dim_color(OUTLINE, dim), false, 2.8)
	ci.draw_arc(Vector2(8, -254) + u, 28.0, PI + 0.1, TAU - 0.1, 16, dim_color(hair, dim), 9.0)
	_draw_granny_face(ci, Vector2(8, -236) + u, emotion, t, dim)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _draw_granny_face(ci: CanvasItem, c: Vector2, emotion: String, t: float, dim: float) -> void:
	var dark: Color = dim_color(EYE_DARK, dim)
	var mouth: Color = dim_color(Color(0.55, 0.20, 0.24), dim)
	var eye_l: Vector2 = c + Vector2(-10, -3)
	var eye_r: Vector2 = c + Vector2(10, -3)
	match emotion:
		"risa":
			ci.draw_arc(eye_l + Vector2(0, 2), 4.0, PI + 0.4, TAU - 0.4, 8, dark, 2.2)
			ci.draw_arc(eye_r + Vector2(0, 2), 4.0, PI + 0.4, TAU - 0.4, 8, dark, 2.2)
			var open_m: PackedVector2Array = PackedVector2Array()
			for i: int in range(9):
				var a: float = PI * float(i) / 8.0
				open_m.append(c + Vector2(cos(a) * 8.0, 9.0 + sin(a) * 7.0))
			ci.draw_colored_polygon(open_m, mouth)
			var hop: float = absf(sin(t * 8.0)) * 4.0
			ci.draw_string(ThemeDB.fallback_font, c + Vector2(30, -26 - hop), "jo jo", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, dim_color(Color(0.95, 0.85, 0.55), dim))
		"picara":
			ci.draw_circle(eye_l, 2.6, dark)
			ci.draw_arc(eye_r + Vector2(0, 1), 4.0, PI + 0.4, TAU - 0.4, 8, dark, 2.2)
			ci.draw_arc(c + Vector2(3, 8), 7.0, 0.1, PI - 0.9, 8, mouth, 2.2)
			_sparkle(ci, c + Vector2(34, -18), 6.0 * (0.8 + 0.3 * sin(t * 6.0)), dim)
		"seria":
			ci.draw_circle(eye_l, 2.4, dark)
			ci.draw_circle(eye_r, 2.4, dark)
			ci.draw_line(eye_l + Vector2(-5, -8), eye_l + Vector2(4, -6), dark, 2.0)
			ci.draw_line(eye_r + Vector2(5, -8), eye_r + Vector2(-4, -6), dark, 2.0)
			ci.draw_line(c + Vector2(-6, 11), c + Vector2(6, 11), mouth, 2.2)
		_:
			ci.draw_circle(eye_l, 2.6, dark)
			ci.draw_circle(eye_r, 2.6, dark)
			ci.draw_arc(c + Vector2(0, 7), 7.0, 0.25, PI - 0.25, 8, mouth, 2.2)
	# Rosy cheeks, wrinkles & round glasses
	ci.draw_colored_polygon(_ellipse(c + Vector2(-16, 6), 5.0, 3.0), Color(1.0, 0.50, 0.55, 0.40 * dim))
	ci.draw_colored_polygon(_ellipse(c + Vector2(16, 6), 5.0, 3.0), Color(1.0, 0.50, 0.55, 0.40 * dim))
	ci.draw_line(c + Vector2(-20, -4), c + Vector2(-23, -1), dark, 1.2)
	ci.draw_line(c + Vector2(20, -4), c + Vector2(23, -1), dark, 1.2)
	var glass: Color = dim_color(Color(0.40, 0.28, 0.16), dim)
	ci.draw_circle(eye_l, 8.0, Color(0.85, 0.95, 1.0, 0.18 * dim))
	ci.draw_circle(eye_r, 8.0, Color(0.85, 0.95, 1.0, 0.18 * dim))
	ci.draw_circle(eye_l, 8.0, glass, false, 1.8)
	ci.draw_circle(eye_r, 8.0, glass, false, 1.8)
	ci.draw_line(eye_l + Vector2(8, 0), eye_r + Vector2(-8, 0), glass, 1.6)
