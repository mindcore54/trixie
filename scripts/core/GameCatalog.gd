class_name GameCatalog
extends RefCounted
## Central data-driven catalog of Witches, Customers, Recipes, and Roguelite Upgrades.
## Loads .tres files when present or builds canonical defaults from GDD.md.

const CHARACTERS_DIR: String = "res://data/characters"
const CUSTOMERS_DIR: String = "res://data/customers"
const RECIPES_DIR: String = "res://data/recipes"
const UPGRADES_DIR: String = "res://data/upgrades"

static func get_witches() -> Array[WitchCharacterData]:
	var loaded: Array[WitchCharacterData] = []
	for res: Resource in _load_tres_in_dir(CHARACTERS_DIR):
		if res is WitchCharacterData:
			loaded.append(res as WitchCharacterData)
	if not loaded.is_empty():
		return loaded
	return _build_default_witches()


static func get_customers() -> Array[CustomerArchetypeData]:
	var loaded: Array[CustomerArchetypeData] = []
	for res: Resource in _load_tres_in_dir(CUSTOMERS_DIR):
		if res is CustomerArchetypeData:
			loaded.append(res as CustomerArchetypeData)
	if not loaded.is_empty():
		return loaded
	return _build_default_customers()


static func get_recipes() -> Array[PotionRecipeData]:
	var loaded: Array[PotionRecipeData] = []
	for res: Resource in _load_tres_in_dir(RECIPES_DIR):
		if res is PotionRecipeData:
			loaded.append(res as PotionRecipeData)
	if not loaded.is_empty():
		return loaded
	return _build_default_recipes()


static func get_upgrades() -> Array[RogueliteUpgradeData]:
	var loaded: Array[RogueliteUpgradeData] = []
	for res: Resource in _load_tres_in_dir(UPGRADES_DIR):
		if res is RogueliteUpgradeData:
			loaded.append(res as RogueliteUpgradeData)
	if not loaded.is_empty():
		return loaded
	return _build_default_upgrades()


static func find_recipe_by_id(recipe_id: StringName, recipes: Array[PotionRecipeData]) -> PotionRecipeData:
	for r: PotionRecipeData in recipes:
		if r.recipe_id == recipe_id:
			return r
	return null


static func match_exact_recipe(ingredients: Array[StringName], recipes: Array[PotionRecipeData], max_day: int = 99) -> PotionRecipeData:
	var sorted_in: Array[StringName] = ingredients.duplicate()
	sorted_in.sort()
	for r: PotionRecipeData in recipes:
		if r.unlock_day > max_day:
			continue
		var sorted_req: Array[StringName] = r.required_ingredients.duplicate()
		sorted_req.sort()
		if sorted_in == sorted_req:
			return r
	return null


static func can_extend_ingredients(current: Array[StringName], candidate_ing: StringName, recipes: Array[PotionRecipeData], max_day: int = 99) -> bool:
	var test_list: Array[StringName] = current.duplicate()
	test_list.append(candidate_ing)
	for r: PotionRecipeData in recipes:
		if r.unlock_day > max_day:
			continue
		if _is_multiset_subset(test_list, r.required_ingredients):
			return true
	return false


static func _is_multiset_subset(sub: Array[StringName], superset: Array[StringName]) -> bool:
	var pool: Array[StringName] = superset.duplicate()
	for item: StringName in sub:
		var idx: int = pool.find(item)
		if idx == -1:
			return false
		pool.remove_at(idx)
	return true


static func save_all_defaults_to_disk() -> void:
	_save_list(_build_default_witches(), CHARACTERS_DIR, "witch_id")
	_save_list(_build_default_customers(), CUSTOMERS_DIR, "customer_id")
	_save_list(_build_default_recipes(), RECIPES_DIR, "recipe_id")
	_save_list(_build_default_upgrades(), UPGRADES_DIR, "upgrade_id")


static func _save_list(items: Array, dir_path: String, id_prop: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	for item: Resource in items:
		var item_id: String = str(item.get(id_prop))
		var full_path: String = "%s/%s.tres" % [dir_path, item_id]
		ResourceSaver.save(item, full_path)


static func _load_tres_in_dir(dir_path: String) -> Array[Resource]:
	var results: Array[Resource] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var loaded: Resource = load("%s/%s" % [dir_path, fname])
			if loaded:
				results.append(loaded)
		fname = dir.get_next()
	dir.list_dir_end()
	return results


static func _build_default_witches() -> Array[WitchCharacterData]:
	var trixie: WitchCharacterData = WitchCharacterData.new()
	trixie.witch_id = &"trixie"
	trixie.display_name = "Trixie"
	trixie.archetype_title = "Bruja de Fuego y Caos"
	trixie.short_bio = "Apasionada, coqueta y adicta a llevar sus calderos al límite."
	trixie.move_speed = 360.0
	trixie.brew_speed_mult = 1.05
	trixie.carry_capacity = 2
	trixie.max_stability_hearts = 3
	trixie.passive_name = "Chispa Ardiente"
	trixie.passive_description = "Mantiene el bono ¡CALIENTE! x1.5 durante más tiempo al entregar."
	trixie.active_name = "Fiebre Escarlata"
	trixie.active_description = "Termina al instante todos los calderos hirviendo y otorga +60% velocidad por 5s."
	trixie.active_cooldown_sec = 16.0
	trixie.unlock_essence_cost = 0

	var lyra: WitchCharacterData = WitchCharacterData.new()
	lyra.witch_id = &"lyra"
	lyra.display_name = "Lyra"
	lyra.archetype_title = "Druida de Floración Salvaje"
	lyra.short_bio = "Dulce y traviesa, rodeada de esporas seductoras del bosque."
	lyra.move_speed = 340.0
	lyra.brew_speed_mult = 1.1
	lyra.carry_capacity = 3
	lyra.max_stability_hearts = 3
	lyra.passive_name = "Cosecha Abundante"
	lyra.passive_description = "Empieza con 3 ranuras de carga en mano."
	lyra.active_name = "Enredaderas Calmantes"
	lyra.active_description = "Congela la paciencia de toda la fila durante 8 segundos."
	lyra.active_cooldown_sec = 20.0
	lyra.unlock_essence_cost = 150

	var nyxara: WitchCharacterData = WitchCharacterData.new()
	nyxara.witch_id = &"nyxara"
	nyxara.display_name = "Nyxara"
	nyxara.archetype_title = "Chamán Domadora"
	nyxara.short_bio = "Misteriosa y elegante, deja que sus familiares hagan el trabajo sucio."
	nyxara.move_speed = 325.0
	nyxara.brew_speed_mult = 0.95
	nyxara.carry_capacity = 2
	nyxara.max_stability_hearts = 4
	nyxara.passive_name = "Vínculo Totémico"
	nyxara.passive_description = "Arranca la run con 1 Michi Alado invocado desde el Día 1 y 4 corazones."
	nyxara.active_name = "Posesión del Sabbat"
	nyxara.active_description = "Potencia velocidad de familiares y cocina todos los calderos x2 por 7s."
	nyxara.active_cooldown_sec = 20.0
	nyxara.unlock_essence_cost = 300

	var morrigan: WitchCharacterData = WitchCharacterData.new()
	morrigan.witch_id = &"morrigan"
	morrigan.display_name = "Morrigan"
	morrigan.archetype_title = "Alquimista Oscura"
	morrigan.short_bio = "Peligrosa, veloz y obsesionada con el oro de alto riesgo."
	morrigan.move_speed = 420.0
	morrigan.brew_speed_mult = 1.35
	morrigan.carry_capacity = 2
	morrigan.max_stability_hearts = 2
	morrigan.passive_name = "Sangre Volátil"
	morrigan.passive_description = "+40% de oro y velocidad, pero solo 2 corazones de estabilidad."
	morrigan.active_name = "Transmutación Carmesí"
	morrigan.active_description = "Sella todos los pedidos de caldero al instante y duplica la paciencia ganada."
	morrigan.active_cooldown_sec = 17.0
	morrigan.unlock_essence_cost = 500

	return [trixie, lyra, nyxara, morrigan]


static func _build_default_customers() -> Array[CustomerArchetypeData]:
	var sylvi: CustomerArchetypeData = CustomerArchetypeData.new()
	sylvi.customer_id = &"sylvi"
	sylvi.display_name = "Sylvi"
	sylvi.species_archetype = "Fauno Fiestera"
	sylvi.base_patience_sec = 29.0
	sylvi.tip_generosity_mult = 1.25
	sylvi.preferred_recipes = [&"elixir_ignis", &"filtro_estelar"]
	sylvi.greeting_lines = PackedStringArray([
		"¡Necesito algo bien fuerte para esta noche!",
		"¿Qué tienes hoy para encender la fiesta del bosque, brujita?"
	])
	sylvi.satisfied_lines = PackedStringArray([
		"¡Mmm! ¡Esto pega directo al corazón!",
		"¡Así me gusta, rápida y ardiente!"
	])
	sylvi.spicy_affinity_lines = PackedStringArray([
		"¿Siempre sudas así detrás del mostrador, o es por verme?",
		"Si funciona la mitad de bien que tu sonrisa, mañana vuelvo por el doble..."
	])
	sylvi.impatient_lines = PackedStringArray([
		"¡Vamos linda, se me enfría la noche!"
	])

	var velvet: CustomerArchetypeData = CustomerArchetypeData.new()
	velvet.customer_id = &"velvet"
	velvet.display_name = "Velvet"
	velvet.species_archetype = "Súcubo Ejecutiva"
	velvet.base_patience_sec = 23.0
	velvet.tip_generosity_mult = 1.6
	velvet.preferred_recipes = [&"filtro_estelar", &"concentrado_carmesi"]
	velvet.greeting_lines = PackedStringArray([
		"Tengo una cita importante en diez minutos. Sorpréndeme.",
		"No me hagas esperar y te cubriré de oro, preciosa."
	])
	velvet.satisfied_lines = PackedStringArray([
		"Servicio impecable. Quédate el cambio.",
		"Exactamente el sabor que adoro."
	])
	velvet.spicy_affinity_lines = PackedStringArray([
		"Me encanta verte correr por toda la cocina solo para complacerme.",
		"La próxima poción quiero probarla directo de tu cucharón..."
	])
	velvet.impatient_lines = PackedStringArray([
		"Tic-tac, brujita. Mi paciencia vale caro."
	])

	var seraphina: CustomerArchetypeData = CustomerArchetypeData.new()
	seraphina.customer_id = &"seraphina"
	seraphina.display_name = "Seraphina"
	seraphina.species_archetype = "Paladín Reprimida"
	seraphina.is_vip_boss = true
	seraphina.base_patience_sec = 25.0
	seraphina.tip_generosity_mult = 1.45
	seraphina.preferred_recipes = [&"savia_pura", &"bruma_lunar"]
	seraphina.greeting_lines = PackedStringArray([
		"E-es para un ritual de purificación... ¡no pienses cosas raras!",
		"¡Vengo a inspeccionar tu licencia... y a llevarme un frasco!"
	])
	seraphina.satisfied_lines = PackedStringArray([
		"¡Q-qué pureza tan cálida! Casi indecente...",
		"Aprobado por la Orden. (Gracias...)"
	])
	seraphina.spicy_affinity_lines = PackedStringArray([
		"¿Por qué esta poción huele a fresas y calor?! ¡Cielos, qué bochorno!",
		"N-no le digas a la Orden que vengo aquí... ni cuánto me gusta mirarte."
	])
	seraphina.impatient_lines = PackedStringArray([
		"¡La Orden no tolera demoras injustificadas!"
	])

	var mona: CustomerArchetypeData = CustomerArchetypeData.new()
	mona.customer_id = &"mona"
	mona.display_name = "Mona"
	mona.species_archetype = "Bruja Rival Tsundere"
	mona.base_patience_sec = 32.0
	mona.tip_generosity_mult = 1.15
	mona.preferred_recipes = [&"bruma_lunar", &"tonico_silvestre"]
	mona.greeting_lines = PackedStringArray([
		"Solo vine a comprobar lo lenta que eres. Hazme un filtro decente.",
		"¡No creas que vengo porque me gusten tus mezclas!"
	])
	mona.satisfied_lines = PackedStringArray([
		"¡Hmph! Pasable. Supongo que tienes algo de técnica.",
		"N-no está mal... ¡pero la mía sale mejor!"
	])
	mona.spicy_affinity_lines = PackedStringArray([
		"¡Hmph! No te pongas tan coqueta solo porque atendiste rápido, tonta!",
		"Oye... si cierras temprano un día, ven a comparar calderos... ¡s-solo por negocio!"
	])
	mona.impatient_lines = PackedStringArray([
		"¡Ja! Sabía que no podías con tantos pedidos!"
	])

	var roxy: CustomerArchetypeData = CustomerArchetypeData.new()
	roxy.customer_id = &"roxy"
	roxy.display_name = "Roxy"
	roxy.species_archetype = "Cazadora Lupina"
	roxy.base_patience_sec = 30.0
	roxy.tip_generosity_mult = 1.3
	roxy.preferred_recipes = [&"elixir_ignis", &"tonico_silvestre", &"concentrado_carmesi"]
	roxy.greeting_lines = PackedStringArray([
		"¡Dame algo que me haga rugir antes de que salga la luna!",
		"¡Huele delicioso aquí dentro, brujita!"
	])
	roxy.satisfied_lines = PackedStringArray([
		"¡Auuu! ¡Esto sí tiene chispa!",
		"¡Rápida como una flecha! ¡Me encanta!"
	])
	roxy.spicy_affinity_lines = PackedStringArray([
		"¡Guau! ¡Agitas ese caldero con una energía que me vuelve loca!",
		"Tienes mejor aroma que cualquier presa del bosque... ¿me guardas un frasco especial?"
	])
	roxy.impatient_lines = PackedStringArray([
		"¡Grrr! ¡Me muero de sed esperando!"
	])

	return [sylvi, velvet, seraphina, mona, roxy]


static func _build_default_recipes() -> Array[PotionRecipeData]:
	var r1: PotionRecipeData = PotionRecipeData.new()
	r1.recipe_id = &"elixir_ignis"
	r1.display_name = "Elixir Ignis"
	r1.required_ingredients = [&"red"]
	r1.base_brew_time_sec = 2.6
	r1.overheat_grace_sec = 5.0
	r1.base_gold_value = 35
	r1.unlock_day = 1
	r1.potion_color = Color(0.96, 0.25, 0.30)

	var r2: PotionRecipeData = PotionRecipeData.new()
	r2.recipe_id = &"bruma_lunar"
	r2.display_name = "Bruma Lunar"
	r2.required_ingredients = [&"blue"]
	r2.base_brew_time_sec = 2.6
	r2.overheat_grace_sec = 5.0
	r2.base_gold_value = 35
	r2.unlock_day = 1
	r2.potion_color = Color(0.24, 0.65, 1.0)

	var r3: PotionRecipeData = PotionRecipeData.new()
	r3.recipe_id = &"savia_pura"
	r3.display_name = "Savia Pura"
	r3.required_ingredients = [&"green"]
	r3.base_brew_time_sec = 2.6
	r3.overheat_grace_sec = 5.0
	r3.base_gold_value = 35
	r3.unlock_day = 1
	r3.potion_color = Color(0.22, 0.88, 0.45)

	var r4: PotionRecipeData = PotionRecipeData.new()
	r4.recipe_id = &"filtro_estelar"
	r4.display_name = "Filtro Estelar"
	r4.required_ingredients = [&"red", &"blue"]
	r4.base_brew_time_sec = 3.4
	r4.overheat_grace_sec = 4.6
	r4.base_gold_value = 70
	r4.unlock_day = 1
	r4.potion_color = Color(0.76, 0.30, 0.98)

	var r5: PotionRecipeData = PotionRecipeData.new()
	r5.recipe_id = &"tonico_silvestre"
	r5.display_name = "Tónico Silvestre"
	r5.required_ingredients = [&"green", &"red"]
	r5.base_brew_time_sec = 3.4
	r5.overheat_grace_sec = 4.6
	r5.base_gold_value = 75
	r5.unlock_day = 2
	r5.potion_color = Color(0.98, 0.65, 0.16)

	var r6: PotionRecipeData = PotionRecipeData.new()
	r6.recipe_id = &"concentrado_carmesi"
	r6.display_name = "Concentrado Carmesí"
	r6.required_ingredients = [&"crushed_red", &"blue"]
	r6.requires_mortar = true
	r6.base_brew_time_sec = 3.8
	r6.overheat_grace_sec = 4.2
	r6.base_gold_value = 120
	r6.unlock_day = 3
	r6.potion_color = Color(1.0, 0.18, 0.56)

	return [r1, r2, r3, r4, r5, r6]


static func _build_default_upgrades() -> Array[RogueliteUpgradeData]:
	var u1: RogueliteUpgradeData = RogueliteUpgradeData.new()
	u1.upgrade_id = &"michi_alado"
	u1.display_name = "Michi Alado (Familiar)"
	u1.kind = RogueliteUpgradeData.UpgradeKind.FAMILIAR_SUMMON
	u1.rarity = RogueliteUpgradeData.Rarity.RARE
	u1.synergy_tags = PackedStringArray(["Familiar", "Caldero"])
	u1.description = "Invoca un gatito alado que remueve tus calderos (+50% velocidad) y evita que exploten."
	u1.max_stacks = 2
	u1.effect_params = {"familiar_type": "michi_alado"}

	var u2: RogueliteUpgradeData = RogueliteUpgradeData.new()
	u2.upgrade_id = &"botas_tacon_arcano"
	u2.display_name = "Botas de Tacón Arcano"
	u2.kind = RogueliteUpgradeData.UpgradeKind.RELIC_PASSIVE
	u2.rarity = RogueliteUpgradeData.Rarity.COMMON
	u2.synergy_tags = PackedStringArray(["Velocidad"])
	u2.description = "+35% velocidad de movimiento y estela de chispas doradas por la cocina."
	u2.max_stacks = 3
	u2.effect_params = {"speed_bonus": 0.35}

	var u3: RogueliteUpgradeData = RogueliteUpgradeData.new()
	u3.upgrade_id = &"corse_magnetico"
	u3.display_name = "Corsé Magnético"
	u3.kind = RogueliteUpgradeData.UpgradeKind.RELIC_PASSIVE
	u3.rarity = RogueliteUpgradeData.Rarity.RARE
	u3.synergy_tags = PackedStringArray(["Velocidad", "Carga"])
	u3.description = "+1 ranura en mano y embotellado instantáneo al recoger o pasar cerca de la mesa."
	u3.max_stacks = 1
	u3.effect_params = {"carry_bonus": 1, "instant_bottle": true}

	var u4: RogueliteUpgradeData = RogueliteUpgradeData.new()
	u4.upgrade_id = &"diablillo_carmesi"
	u4.display_name = "Diablillo Carmesí (Familiar)"
	u4.kind = RogueliteUpgradeData.UpgradeKind.FAMILIAR_SUMMON
	u4.rarity = RogueliteUpgradeData.Rarity.RARE
	u4.synergy_tags = PackedStringArray(["Familiar", "Ingredientes"])
	u4.description = "Invoca un diablillo que llena calderos vacíos con los ingredientes que pide la primera clienta."
	u4.max_stacks = 2
	u4.effect_params = {"familiar_type": "diablillo_carmesi"}

	var u5: RogueliteUpgradeData = RogueliteUpgradeData.new()
	u5.upgrade_id = &"murcielago_sombrio"
	u5.display_name = "Murciélago Mensajero (Familiar)"
	u5.kind = RogueliteUpgradeData.UpgradeKind.FAMILIAR_SUMMON
	u5.rarity = RogueliteUpgradeData.Rarity.EPIC
	u5.synergy_tags = PackedStringArray(["Familiar", "Entrega"])
	u5.description = "Recoge pociones listas del caldero, las embotella al vuelo y las entrega a las clientas."
	u5.max_stacks = 2
	u5.effect_params = {"familiar_type": "murcielago_sombrio"}

	var u6: RogueliteUpgradeData = RogueliteUpgradeData.new()
	u6.upgrade_id = &"espejo_duplicador"
	u6.display_name = "Espejo Duplicador"
	u6.kind = RogueliteUpgradeData.UpgradeKind.RELIC_PASSIVE
	u6.rarity = RogueliteUpgradeData.Rarity.BROKEN_SYNERGY
	u6.synergy_tags = PackedStringArray(["Cadena", "Encanto"])
	u6.description = "Cada entrega con bono ¡CALIENTE! genera una poción espejo gratis para otra clienta en fila."
	u6.max_stacks = 1
	u6.effect_params = {"clone_on_hot": true}

	return [u1, u2, u3, u4, u5, u6]
