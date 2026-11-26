class_name TutorialDirector
extends RefCounted
## Manages paused just-in-time cauldron tutorials (basic break/purge/summary and
## contextual color mixing), banner copy, and orb guide overlays.

enum Step {
	NONE = 0,
	BASIC_BREAK_LIKED = 1,
	BASIC_PURGE_DISLIKED = 2,
	MIX_DRAG_COMBINE = 3,
	MIX_BREAK_RESULT = 4,
}

var active: bool = false
var step: Step = Step.NONE


func reset() -> void:
	active = false
	step = Step.NONE


func is_pausing_patience() -> bool:
	return active and step != Step.NONE


func start_basics() -> void:
	active = true
	step = Step.BASIC_BREAK_LIKED


func start_mix() -> void:
	active = true
	step = Step.MIX_DRAG_COMBINE


func advance_to(next_step: Step) -> bool:
	if not active or int(next_step) <= int(step):
		return false
	step = next_step
	return true


func finish_basics(state: Node) -> void:
	state.cauldron_basics_tutorial_done = true
	state.cauldron_tutorial_done = true
	reset()


func finish_mix(state: Node) -> void:
	state.mix_tutorial_done = true
	reset()


func get_step_reaction(s: Step) -> Dictionary:
	match s:
		Step.BASIC_PURGE_DISLIKED:
			return {
				"emotion": "nerviosa",
				"dur": 3.0,
				"line": "¡Bien! Ahora purga el orbe con ❌ usando Clic Derecho sin romper el combo.",
			}
		Step.MIX_BREAK_RESULT:
			return {
				"emotion": "confiada",
				"dur": 2.8,
				"line": "¡Mezcla lograda! Ahora rompe ese orbe combinado para llenar el tubo mucho más rápido.",
			}
	return {}


func get_banner_payload(chem: Dictionary) -> Dictionary:
	var tut_title: String = "✨ Tutorial · Pausado"
	var tut_body: String = ""
	match step:
		Step.BASIC_BREAK_LIKED:
			var liked_k: int = int(chem["liked"])
			tut_title = "✨ Tutorial 1/2 · Pausado"
			tut_body = "Haz 3 CLICS IZQ en un orbe %s para llenar el matraz." % ChemistryRules.get_element_name(liked_k)
		Step.BASIC_PURGE_DISLIKED:
			var disliked_k: int = int(chem["disliked"])
			tut_title = "✨ Tutorial 2/2 · Pausado"
			tut_body = "Los orbes oscuros con ❌ arruinan el elixir: haz CLIC DER en %s ❌ para purgarlo sin perder combo." % ChemistryRules.get_element_name(disliked_k)
		Step.MIX_DRAG_COMBINE:
			var liked_m: int = int(chem["liked"])
			var comps: Array[int] = ChemistryRules.get_recipe_components(liked_m)
			tut_title = "✨ Mezcla · Pausado"
			tut_body = "ARRASTRA %s sobre %s para crear %s." % [
				ChemistryRules.get_element_name(comps[0]),
				ChemistryRules.get_element_name(comps[1]),
				ChemistryRules.get_element_name(liked_m),
			]
		Step.MIX_BREAK_RESULT:
			var liked_m2: int = int(chem["liked"])
			tut_title = "✨ ¡Mezcla lista!"
			tut_body = "¡Genial! Ahora rompe ese orbe %s a clics." % ChemistryRules.get_element_name(liked_m2)
	return {
		"title": tut_title,
		"body": tut_body,
	}


func draw_orb_guide(
	ci: CanvasItem,
	orbs: Array[Dictionary],
	lifted_orb_id: int,
	chem: Dictionary,
	orb_relation_fn: Callable,
	orb_radius: float,
	shake_v: Vector2,
	time_sec: float,
	font: Font,
	round_ending: bool,
	closing_active: bool
) -> void:
	if not active or round_ending or closing_active or step == Step.NONE:
		return

	var pulse: float = 0.5 + 0.5 * sin(time_sec * 7.5)
	if step == Step.MIX_DRAG_COMBINE:
		var liked_k: int = int(chem["liked"])
		if not ChemistryRules.is_mixed_kind(liked_k):
			return
		var comps: Array[int] = ChemistryRules.get_recipe_components(liked_k)
		var pos_a: Vector2 = Vector2.ZERO
		var rad_a: float = orb_radius
		var found_a: bool = false
		var pos_b: Vector2 = Vector2.ZERO
		var rad_b: float = orb_radius
		var found_b: bool = false
		for o: Dictionary in orbs:
			if int(o["id"]) == lifted_orb_id:
				continue
			var k: int = int(o["kind"])
			if not found_a and k == comps[0]:
				pos_a = (o["pos"] as Vector2) + shake_v
				rad_a = float(o["radius"])
				found_a = true
			elif not found_b and k == comps[1]:
				pos_b = (o["pos"] as Vector2) + shake_v
				rad_b = float(o["radius"])
				found_b = true
		if found_a and found_b:
			var c_guide: Color = Color(0.45, 0.96, 1.0)
			ci.draw_arc(pos_a, rad_a + 12.0 + pulse * 5.0, 0.0, TAU, 28, c_guide, 3.6)
			ci.draw_arc(pos_b, rad_b + 12.0 + pulse * 5.0, 0.0, TAU, 28, Color(1.0, 0.88, 0.36), 3.6)
			ci.draw_line(pos_a, pos_b, Color(1.0, 0.92, 0.46, 0.72), 3.0)
			var mid: Vector2 = (pos_a + pos_b) * 0.5
			ci.draw_string(font, mid + Vector2(-75, -18), "¡Arrastra y junta!", HORIZONTAL_ALIGNMENT_CENTER, 150, 16, Color(1.0, 0.94, 0.52))
		return

	var target_rel: StringName = &"liked"
	var guide_txt: String = "¡3 clics!"
	var guide_col: Color = Color(1.0, 0.90, 0.34)
	if step == Step.BASIC_PURGE_DISLIKED:
		target_rel = &"disliked"
		guide_txt = "¡Clic Der!"
		guide_col = Color(1.0, 0.42, 0.50)
	elif step == Step.MIX_BREAK_RESULT:
		guide_txt = "¡Rómpelo!"
		guide_col = Color(1.0, 0.88, 0.36)

	for o: Dictionary in orbs:
		if int(o["id"]) == lifted_orb_id:
			continue
		if (orb_relation_fn.call(int(o["kind"])) as StringName) == target_rel:
			var pos: Vector2 = (o["pos"] as Vector2) + shake_v
			var rad: float = float(o["radius"])
			ci.draw_arc(pos, rad + 13.0 + pulse * 5.0, 0.0, TAU, 28, guide_col, 3.6)
			ci.draw_string(font, pos + Vector2(-60, -rad - 20.0), guide_txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, guide_col)
			break
