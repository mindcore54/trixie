class_name WitchStageSlot
extends CharacterStageSlot
## Playable witch stage slot (left side) with emotion-driven bounce, shake, and soot squash.


func update_witch(emotion: String, t: float, react_progress: float, dim: float = 1.0) -> void:
	var tex: Texture2D = CharacterArt.get_trixie_halfbody(emotion)
	apply_texture(tex)
	if tex == null:
		return
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
	apply_motion(off_x, off_y, sx, sy, bob, dim)
