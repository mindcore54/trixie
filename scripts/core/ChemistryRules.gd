class_name ChemistryRules
extends RefCounted
## Pure static alchemy color chemistry rules, combination recipes, and display metadata.

enum BubbleKind {
	RED,
	BLUE,
	GREEN,
	YELLOW,
	PURPLE,
	CYAN,
	GOLD,
	BOMB,
}

const CUSTOMER_CHEMISTRY: Dictionary = {
	&"sylvi": {"liked": BubbleKind.RED, "neutral": BubbleKind.GREEN, "disliked": BubbleKind.BLUE},
	&"velvet": {"liked": BubbleKind.PURPLE, "neutral": BubbleKind.RED, "disliked": BubbleKind.GREEN},
	&"seraphina": {"liked": BubbleKind.YELLOW, "neutral": BubbleKind.GREEN, "disliked": BubbleKind.BLUE},
	&"mona": {"liked": BubbleKind.CYAN, "neutral": BubbleKind.BLUE, "disliked": BubbleKind.RED},
	&"roxy": {"liked": BubbleKind.YELLOW, "neutral": BubbleKind.RED, "disliked": BubbleKind.BLUE},
}


static func get_default_chemistry_for_customer(customer_id: StringName) -> Dictionary:
	if CUSTOMER_CHEMISTRY.has(customer_id):
		return CUSTOMER_CHEMISTRY[customer_id] as Dictionary
	return {"liked": BubbleKind.RED, "neutral": BubbleKind.GREEN, "disliked": BubbleKind.BLUE}


static func build_chemistry_for_liked(liked_k: int, deterministic_neutral: int = -1) -> Dictionary:
	var primaries: Array[int] = [BubbleKind.RED, BubbleKind.BLUE, BubbleKind.GREEN]
	if is_mixed_kind(liked_k):
		var comps: Array[int] = get_recipe_components(liked_k)
		var disliked_k: int = BubbleKind.BLUE
		for p: int in primaries:
			if not comps.has(p):
				disliked_k = p
				break
		return {
			"liked": liked_k,
			"neutral": comps[0],
			"disliked": disliked_k,
		}
	var others: Array[int] = []
	for p: int in primaries:
		if p != liked_k:
			others.append(p)
	var neutral_k: int = deterministic_neutral if (deterministic_neutral != -1 and others.has(deterministic_neutral)) else others[randi() % others.size()]
	var disliked_p: int = others[1] if neutral_k == others[0] else others[0]
	return {
		"liked": liked_k,
		"neutral": neutral_k,
		"disliked": disliked_p,
	}


static func roll_order_chemistry(
	cid: StringName,
	first_order: bool,
	run_basics_tutorial: bool,
	run_mix_tutorial: bool,
	last_liked_kind: int
) -> Dictionary:
	if first_order and run_basics_tutorial:
		return build_chemistry_for_liked(BubbleKind.RED, BubbleKind.GREEN)
	if not first_order and run_mix_tutorial and cid == &"velvet":
		return build_chemistry_for_liked(BubbleKind.PURPLE)

	var pool: Array[int] = [
		BubbleKind.RED, BubbleKind.BLUE, BubbleKind.GREEN,
		BubbleKind.PURPLE, BubbleKind.YELLOW, BubbleKind.CYAN,
	]
	var candidates: Array[int] = []
	for k: int in pool:
		if k != last_liked_kind:
			candidates.append(k)
	if candidates.is_empty():
		candidates = pool
	var chosen: int = candidates[randi() % candidates.size()]
	return build_chemistry_for_liked(chosen)


static func is_primary_kind(kind: int) -> bool:
	return kind == BubbleKind.RED or kind == BubbleKind.BLUE or kind == BubbleKind.GREEN


static func is_mixed_kind(kind: int) -> bool:
	return kind == BubbleKind.YELLOW or kind == BubbleKind.PURPLE or kind == BubbleKind.CYAN


static func get_recipe_components(kind: int) -> Array[int]:
	match kind:
		BubbleKind.YELLOW:
			return [BubbleKind.RED, BubbleKind.GREEN]
		BubbleKind.PURPLE:
			return [BubbleKind.RED, BubbleKind.BLUE]
		BubbleKind.CYAN:
			return [BubbleKind.BLUE, BubbleKind.GREEN]
	return []


static func get_combine_result(a_kind: int, b_kind: int) -> int:
	if a_kind == BubbleKind.BOMB or b_kind == BubbleKind.BOMB:
		return -1
	if a_kind == BubbleKind.GOLD and b_kind == BubbleKind.GOLD:
		return BubbleKind.GOLD
	if a_kind == BubbleKind.GOLD:
		return b_kind
	if b_kind == BubbleKind.GOLD:
		return a_kind
	if a_kind == b_kind:
		return a_kind
	if is_primary_kind(a_kind) and is_primary_kind(b_kind):
		var lo: int = mini(a_kind, b_kind)
		var hi: int = maxi(a_kind, b_kind)
		if lo == BubbleKind.RED and hi == BubbleKind.BLUE:
			return BubbleKind.PURPLE
		if lo == BubbleKind.RED and hi == BubbleKind.GREEN:
			return BubbleKind.YELLOW
		if lo == BubbleKind.BLUE and hi == BubbleKind.GREEN:
			return BubbleKind.CYAN
	return -1


static func get_orb_relation(kind: int, chem: Dictionary) -> StringName:
	if kind == BubbleKind.GOLD or kind == BubbleKind.BOMB:
		return &"special"
	var liked_k: int = int(chem["liked"])
	if kind == liked_k:
		return &"liked"
	if kind == int(chem["disliked"]):
		return &"disliked"
	if is_mixed_kind(liked_k) and get_recipe_components(liked_k).has(kind):
		return &"ingredient"
	return &"neutral"


static func get_element_name(kind: int) -> String:
	match kind:
		BubbleKind.RED: return "🔥 Fuego"
		BubbleKind.BLUE: return "🌙 Luna"
		BubbleKind.GREEN: return "🍃 Savia"
		BubbleKind.YELLOW: return "☀️ Solar"
		BubbleKind.PURPLE: return "🔮 Estelar"
		BubbleKind.CYAN: return "💧 Bruma"
		BubbleKind.GOLD: return "⭐ Estrella"
		BubbleKind.BOMB: return "💣 Bomba"
	return "Orbe"


static func get_element_glyph(kind: int) -> String:
	match kind:
		BubbleKind.RED: return "🔥"
		BubbleKind.BLUE: return "🌙"
		BubbleKind.GREEN: return "🍃"
		BubbleKind.YELLOW: return "☀️"
		BubbleKind.PURPLE: return "🔮"
		BubbleKind.CYAN: return "💧"
		BubbleKind.GOLD: return "⭐"
		BubbleKind.BOMB: return "💣"
	return "●"


static func get_element_color(kind: int) -> Color:
	match kind:
		BubbleKind.RED: return Color(0.98, 0.28, 0.34)
		BubbleKind.BLUE: return Color(0.24, 0.64, 1.0)
		BubbleKind.GREEN: return Color(0.24, 0.88, 0.46)
		BubbleKind.YELLOW: return Color(1.0, 0.80, 0.22)
		BubbleKind.PURPLE: return Color(0.74, 0.34, 1.0)
		BubbleKind.CYAN: return Color(0.18, 0.88, 0.90)
		BubbleKind.GOLD: return Color(1.0, 0.88, 0.28)
		BubbleKind.BOMB: return Color(0.56, 0.22, 0.72)
	return Color.WHITE
