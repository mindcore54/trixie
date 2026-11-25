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
		_sort_by_id_order(loaded, "witch_id", [&"trixie", &"lyra", &"nyxara", &"morrigan"])
		return loaded
	return _build_default_witches()


static func get_customers() -> Array[CustomerArchetypeData]:
	var loaded: Array[CustomerArchetypeData] = []
	for res: Resource in _load_tres_in_dir(CUSTOMERS_DIR):
		if res is CustomerArchetypeData:
			loaded.append(res as CustomerArchetypeData)
	if not loaded.is_empty():
		_sort_by_id_order(loaded, "customer_id", [&"sylvi", &"velvet", &"seraphina", &"mona", &"roxy"])
		return loaded
	return _build_default_customers()


static func _sort_by_id_order(items: Array, id_prop: String, order: Array[StringName]) -> void:
	items.sort_custom(func(a: Resource, b: Resource) -> bool:
		var ia: int = order.find(a.get(id_prop) as StringName)
		var ib: int = order.find(b.get(id_prop) as StringName)
		return (999 if ia == -1 else ia) < (999 if ib == -1 else ib)
	)


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


static func combine_two_colors(a: StringName, b: StringName) -> StringName:
	var pair: Array[String] = [String(a), String(b)]
	pair.sort()
	if pair[0] == "blue" and pair[1] == "red":
		return &"mix_purple"
	if pair[0] == "green" and pair[1] == "red":
		return &"mix_yellow"
	if pair[0] == "blue" and pair[1] == "green":
		return &"mix_cyan"
	return &""


static func get_raw_components(ing: StringName) -> Array[StringName]:
	match ing:
		&"mix_purple":
			return [&"red", &"blue"]
		&"mix_yellow":
			return [&"red", &"green"]
		&"mix_cyan":
			return [&"blue", &"green"]
	return [ing]


static func match_exact_recipe(ingredients: Array[StringName], recipes: Array[PotionRecipeData], _max_day: int = 99) -> PotionRecipeData:
	var sorted_in: Array[String] = []
	for ing: StringName in ingredients:
		sorted_in.append(String(ing))
	sorted_in.sort()
	for r: PotionRecipeData in recipes:
		var sorted_req: Array[String] = []
		for req: StringName in r.required_ingredients:
			sorted_req.append(String(req))
		sorted_req.sort()
		if sorted_in == sorted_req:
			return r
	return null


static func can_extend_ingredients(current: Array[StringName], candidate_ing: StringName, recipes: Array[PotionRecipeData], _max_day: int = 99) -> bool:
	var test_list: Array[StringName] = current.duplicate()
	test_list.append(candidate_ing)
	for r: PotionRecipeData in recipes:
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
	sylvi.base_patience_sec = 62.0
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
	sylvi.display_tempted_lines = PackedStringArray([
		"¡Ooh, esa de la vitrina brilla riquísimo! ¡Pásamela, brujita!"
	])

	var velvet: CustomerArchetypeData = CustomerArchetypeData.new()
	velvet.customer_id = &"velvet"
	velvet.display_name = "Velvet"
	velvet.species_archetype = "Súcubo Ejecutiva"
	velvet.base_patience_sec = 52.0
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
	velvet.display_tempted_lines = PackedStringArray([
		"Veo que ya tienes una lista en vitrina... dámela, linda."
	])

	var seraphina: CustomerArchetypeData = CustomerArchetypeData.new()
	seraphina.customer_id = &"seraphina"
	seraphina.display_name = "Seraphina"
	seraphina.species_archetype = "Paladín Reprimida"
	seraphina.is_vip_boss = true
	seraphina.base_patience_sec = 56.0
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
	seraphina.display_tempted_lines = PackedStringArray([
		"¡E-esa botella expuesta se ve muy tentadora! ¡Dámela para inspeccionarla!"
	])

	var mona: CustomerArchetypeData = CustomerArchetypeData.new()
	mona.customer_id = &"mona"
	mona.display_name = "Mona"
	mona.species_archetype = "Elfa Noble Tsundere"
	mona.base_patience_sec = 70.0
	mona.tip_generosity_mult = 1.15
	mona.preferred_recipes = [&"bruma_lunar", &"tonico_silvestre"]
	mona.greeting_lines = PackedStringArray([
		"Solo vine porque mi boticario real cerró temprano. ¡Hazme algo decente!",
		"¡No creas que hago fila en un puesto callejero porque me gusten tus mezclas!"
	])
	mona.satisfied_lines = PackedStringArray([
		"¡Hmph! Pasable para ser alquimia ambulante... te dejo el cambio.",
		"N-no está nada mal... ¡pero no te confíes!"
	])
	mona.spicy_affinity_lines = PackedStringArray([
		"¡Hmph! ¡Deja de sonreír tan coqueta solo porque me gustó tu elixir, tonta!",
		"Oye... si pasas cerca de mi mansión esta noche, trae un frasco privado... ¡s-solo por cortesía noble!"
	])
	mona.impatient_lines = PackedStringArray([
		"¡Inaceptable! ¡Una dama noble no espera tanto!"
	])
	mona.display_tempted_lines = PackedStringArray([
		"¿Ese frasco brillante está disponible? ¡Pásamelo antes de que alguien más lo vea!"
	])

	var roxy: CustomerArchetypeData = CustomerArchetypeData.new()
	roxy.customer_id = &"roxy"
	roxy.display_name = "Roxy"
	roxy.species_archetype = "Cazadora Lupina"
	roxy.base_patience_sec = 65.0
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
	roxy.display_tempted_lines = PackedStringArray([
		"¡Eso de la vitrina huele brutal! ¡Dámelo ya!"
	])

	return [sylvi, velvet, seraphina, mona, roxy]


static func _build_default_recipes() -> Array[PotionRecipeData]:
	var r1: PotionRecipeData = PotionRecipeData.new()
	r1.recipe_id = &"elixir_ignis"
	r1.display_name = "Elixir Ignis"
	r1.required_ingredients = [&"red"]
	r1.base_brew_time_sec = 2.2
	r1.overheat_grace_sec = 16.0
	r1.base_gold_value = 35
	r1.unlock_day = 1
	r1.potion_color = Color(0.96, 0.25, 0.30)

	var r2: PotionRecipeData = PotionRecipeData.new()
	r2.recipe_id = &"bruma_lunar"
	r2.display_name = "Bruma Lunar"
	r2.required_ingredients = [&"blue"]
	r2.base_brew_time_sec = 2.2
	r2.overheat_grace_sec = 16.0
	r2.base_gold_value = 35
	r2.unlock_day = 1
	r2.potion_color = Color(0.24, 0.65, 1.0)

	var r3: PotionRecipeData = PotionRecipeData.new()
	r3.recipe_id = &"savia_pura"
	r3.display_name = "Savia Pura"
	r3.required_ingredients = [&"green"]
	r3.base_brew_time_sec = 2.2
	r3.overheat_grace_sec = 16.0
	r3.base_gold_value = 35
	r3.unlock_day = 1
	r3.potion_color = Color(0.22, 0.88, 0.45)

	var r4: PotionRecipeData = PotionRecipeData.new()
	r4.recipe_id = &"filtro_estelar"
	r4.display_name = "Filtro Estelar"
	r4.required_ingredients = [&"mix_purple"]
	r4.requires_mortar = true
	r4.base_brew_time_sec = 3.0
	r4.overheat_grace_sec = 15.0
	r4.base_gold_value = 75
	r4.unlock_day = 2
	r4.potion_color = Color(0.76, 0.30, 0.98)

	var r5: PotionRecipeData = PotionRecipeData.new()
	r5.recipe_id = &"tonico_silvestre"
	r5.display_name = "Tónico Silvestre"
	r5.required_ingredients = [&"mix_yellow"]
	r5.requires_mortar = true
	r5.base_brew_time_sec = 3.0
	r5.overheat_grace_sec = 15.0
	r5.base_gold_value = 80
	r5.unlock_day = 2
	r5.potion_color = Color(0.98, 0.84, 0.16)

	var r6: PotionRecipeData = PotionRecipeData.new()
	r6.recipe_id = &"nectar_acuatico"
	r6.display_name = "Néctar Acuático"
	r6.required_ingredients = [&"mix_cyan"]
	r6.requires_mortar = true
	r6.base_brew_time_sec = 3.0
	r6.overheat_grace_sec = 15.0
	r6.base_gold_value = 85
	r6.unlock_day = 3
	r6.potion_color = Color(0.18, 0.90, 0.86)

	return [r1, r2, r3, r4, r5, r6]


static func _build_default_upgrades() -> Array[RogueliteUpgradeData]:
	var u1: RogueliteUpgradeData = RogueliteUpgradeData.new()
	u1.upgrade_id = &"michi_alado"
	u1.display_name = "Michi Alado (Familiar)"
	u1.kind = RogueliteUpgradeData.UpgradeKind.FAMILIAR_SUMMON
	u1.rarity = RogueliteUpgradeData.Rarity.RARE
	u1.synergy_tags = PackedStringArray(["Familiar", "Caldero"])
	u1.description = "• Nv.1: Invoca Michi (+35% cocción y protege caldero)\n• Nv.2+: +35% velocidad del Michi"
	u1.max_stacks = 3
	u1.effect_params = {"familiar_type": "michi_alado"}

	var u2: RogueliteUpgradeData = RogueliteUpgradeData.new()
	u2.upgrade_id = &"botas_tacon_arcano"
	u2.display_name = "Botas de Tacón Arcano"
	u2.kind = RogueliteUpgradeData.UpgradeKind.RELIC_PASSIVE
	u2.rarity = RogueliteUpgradeData.Rarity.COMMON
	u2.synergy_tags = PackedStringArray(["Velocidad"])
	u2.description = "• +12% Velocidad al caminar por nivel"
	u2.max_stacks = 5
	u2.effect_params = {"speed_bonus": 0.12}

	var u3: RogueliteUpgradeData = RogueliteUpgradeData.new()
	u3.upgrade_id = &"corse_magnetico"
	u3.display_name = "Corsé Magnético"
	u3.kind = RogueliteUpgradeData.UpgradeKind.RELIC_PASSIVE
	u3.rarity = RogueliteUpgradeData.Rarity.RARE
	u3.synergy_tags = PackedStringArray(["Velocidad", "Carga"])
	u3.description = "• Nv.1: +1 Ranura de mano y embotellado rápido\n• Nv.2+: +1 Ranura adicional"
	u3.max_stacks = 3
	u3.effect_params = {"carry_bonus": 1, "instant_bottle": true}

	var u4: RogueliteUpgradeData = RogueliteUpgradeData.new()
	u4.upgrade_id = &"diablillo_carmesi"
	u4.display_name = "Diablillo Carmesí (Familiar)"
	u4.kind = RogueliteUpgradeData.UpgradeKind.FAMILIAR_SUMMON
	u4.rarity = RogueliteUpgradeData.Rarity.RARE
	u4.synergy_tags = PackedStringArray(["Familiar", "Ingredientes"])
	u4.description = "• Nv.1: Invoca Diablillo (carga ingredientes)\n• Nv.2+: +35% velocidad del Diablillo"
	u4.max_stacks = 3
	u4.effect_params = {"familiar_type": "diablillo_carmesi"}

	var u5: RogueliteUpgradeData = RogueliteUpgradeData.new()
	u5.upgrade_id = &"murcielago_sombrio"
	u5.display_name = "Murciélago Mensajero (Familiar)"
	u5.kind = RogueliteUpgradeData.UpgradeKind.FAMILIAR_SUMMON
	u5.rarity = RogueliteUpgradeData.Rarity.EPIC
	u5.synergy_tags = PackedStringArray(["Familiar", "Entrega"])
	u5.description = "• Nv.1: Invoca Murciélago (embotella y entrega)\n• Nv.2+: +35% velocidad del Murciélago"
	u5.max_stacks = 3
	u5.effect_params = {"familiar_type": "murcielago_sombrio"}

	var u6: RogueliteUpgradeData = RogueliteUpgradeData.new()
	u6.upgrade_id = &"espejo_duplicador"
	u6.display_name = "Espejo Duplicador"
	u6.kind = RogueliteUpgradeData.UpgradeKind.RELIC_PASSIVE
	u6.rarity = RogueliteUpgradeData.Rarity.BROKEN_SYNERGY
	u6.synergy_tags = PackedStringArray(["Cadena", "Encanto"])
	u6.description = "• Entrega ¡CALIENTE! clona en Vitrina (35% / 65% / 100% por nivel)"
	u6.max_stacks = 3
	u6.effect_params = {"clone_on_hot": true, "clone_chance_per_level": 0.35}

	var u7: RogueliteUpgradeData = RogueliteUpgradeData.new()
	u7.upgrade_id = &"mortero_sismico"
	u7.display_name = "Mortero Sísmico"
	u7.kind = RogueliteUpgradeData.UpgradeKind.RELIC_PASSIVE
	u7.rarity = RogueliteUpgradeData.Rarity.RARE
	u7.synergy_tags = PackedStringArray(["Mortero", "Caldero"])
	u7.description = "• Mezclar en Mortero acelera calderos (+25% / +40% / +55%)"
	u7.max_stacks = 3
	u7.effect_params = {"seismic_mortar": true, "seismic_boost_per_level": 0.15}

	var u8: RogueliteUpgradeData = RogueliteUpgradeData.new()
	u8.upgrade_id = &"hechizo_ebullicion"
	u8.display_name = "Destello de Ebullición"
	u8.kind = RogueliteUpgradeData.UpgradeKind.ACTIVE_SKILL
	u8.rarity = RogueliteUpgradeData.Rarity.RARE
	u8.synergy_tags = PackedStringArray(["Activa", "Caldero"])
	u8.description = "• Activa: Termina todos los calderos al instante (CD: 18s/14s/10s)"
	u8.max_stacks = 3
	u8.effect_params = {"active_type": "instant_brew", "base_cd": 18.0, "cd_per_level": 4.0}

	var u9: RogueliteUpgradeData = RogueliteUpgradeData.new()
	u9.upgrade_id = &"hechizo_aroma"
	u9.display_name = "Perfume Hipnótico"
	u9.kind = RogueliteUpgradeData.UpgradeKind.ACTIVE_SKILL
	u9.rarity = RogueliteUpgradeData.Rarity.RARE
	u9.synergy_tags = PackedStringArray(["Activa", "Fila"])
	u9.description = "• Activa: Congela paciencia de clientas por 6s/8s/10s (CD: 18s)"
	u9.max_stacks = 3
	u9.effect_params = {"active_type": "freeze_queue", "base_cd": 18.0, "cd_per_level": 2.0}

	var u10: RogueliteUpgradeData = RogueliteUpgradeData.new()
	u10.upgrade_id = &"hechizo_paso_astral"
	u10.display_name = "Paso Astral"
	u10.kind = RogueliteUpgradeData.UpgradeKind.ACTIVE_SKILL
	u10.rarity = RogueliteUpgradeData.Rarity.RARE
	u10.synergy_tags = PackedStringArray(["Activa", "Velocidad"])
	u10.description = "• Activa: Embotella tus manos y da +70% velocidad por 5s/7s/9s (CD: 16s)"
	u10.max_stacks = 3
	u10.effect_params = {"active_type": "astral_step", "base_cd": 16.0, "cd_per_level": 2.0}

	var u11: RogueliteUpgradeData = RogueliteUpgradeData.new()
	u11.upgrade_id = &"hechizo_lluvia_oro"
	u11.display_name = "Alquimia Dorada"
	u11.kind = RogueliteUpgradeData.UpgradeKind.ACTIVE_SKILL
	u11.rarity = RogueliteUpgradeData.Rarity.EPIC
	u11.synergy_tags = PackedStringArray(["Activa", "Oro"])
	u11.description = "• Activa: Otorga +25g/+45g/+65g al instante y +1 Combo (CD: 20s)"
	u11.max_stacks = 3
	u11.effect_params = {"active_type": "gold_alchemy", "base_cd": 20.0, "cd_per_level": 2.0}

	return [u1, u2, u3, u4, u5, u6, u7, u8, u9, u10, u11]


## Returns the 17 nodes (1 root + 16 upgrades across 4 branches) of the tactical alchemy incremental tree.
static func get_incremental_nodes() -> Array[Dictionary]:
	return [
		{
			"id": &"root_cauldron",
			"name": "Caldero Alquímico",
			"icon": "🔥",
			"branch": &"core",
			"color": Color(1.0, 0.78, 0.32),
			"pos": Vector2(960.0, 475.0),
			"parent_id": &"",
			"max_level": 1,
			"base_cost": 0,
			"cost_mult": 1.0,
			"short_desc": "Clic Izq (3 golpes) rompe orbes. Arrastra un orbe sobre otro para mezclar colores o concentrar x2. Clic Der (o mantén) purga ❌.",
		},
		# Rama Oeste/Izquierda: Golpes, Toque Continuo y Purga
		{
			"id": &"toque_continuo",
			"name": "Toque Continuo",
			"icon": "👆",
			"branch": &"cursor",
			"color": Color(1.0, 0.38, 0.50),
			"pos": Vector2(690.0, 475.0),
			"parent_id": &"root_cauldron",
			"max_level": 6,
			"base_cost": 8,
			"cost_mult": 1.55,
			"short_desc": "Nv.1: Mantener Clic Izq golpea automáticamente el orbe elegido (+15% Esencia). Nv.2+: golpes más rápidos y +20% Esencia.",
		},
		{
			"id": &"fuerza_molienda",
			"name": "Fuerza Alquímica",
			"icon": "💥",
			"branch": &"cursor",
			"color": Color(1.0, 0.46, 0.58),
			"pos": Vector2(455.0, 390.0),
			"parent_id": &"toque_continuo",
			"max_level": 3,
			"base_cost": 24,
			"cost_mult": 2.20,
			"short_desc": "Reduce los golpes necesarios para romper orbes (3 -> 2 -> 1 golpe) y +25% progreso de poción.",
		},
		{
			"id": &"espuma_veloz",
			"name": "Purga Recicladora",
			"icon": "🫧",
			"branch": &"cursor",
			"color": Color(1.0, 0.52, 0.36),
			"pos": Vector2(455.0, 560.0),
			"parent_id": &"toque_continuo",
			"max_level": 5,
			"base_cost": 20,
			"cost_mult": 1.65,
			"short_desc": "Purgar orbes ❌ (clic o manteniendo Clic Der) los recicla en Esencia y genera un ingrediente útil.",
		},
		{
			"id": &"frenesi_escarlata",
			"name": "Frenesí Escarlata",
			"icon": "💥",
			"branch": &"cursor",
			"color": Color(1.0, 0.24, 0.40),
			"pos": Vector2(225.0, 475.0),
			"parent_id": &"fuerza_molienda",
			"max_level": 5,
			"base_cost": 45,
			"cost_mult": 1.85,
			"short_desc": "Carga Frenesí más rápido; al activarlo, transmuta todos los ❌ al color Afín y rompe de 1 golpe con 2x producción.",
		},
		# Rama Norte: Caldero y Reacciones
		{
			"id": &"hervor_creciente",
			"name": "Hervor Creciente",
			"icon": "🫧",
			"branch": &"alchemy",
			"color": Color(0.28, 0.86, 1.0),
			"pos": Vector2(960.0, 310.0),
			"parent_id": &"root_cauldron",
			"max_level": 8,
			"base_cost": 14,
			"cost_mult": 1.55,
			"short_desc": "+2 Orbes en el caldero (desde 6 iniciales) y aparición más rápida.",
		},
		{
			"id": &"chispa_cadena",
			"name": "Chispa en Cadena",
			"icon": "⚡",
			"branch": &"alchemy",
			"color": Color(0.34, 0.94, 0.96),
			"pos": Vector2(720.0, 215.0),
			"parent_id": &"hervor_creciente",
			"max_level": 6,
			"base_cost": 30,
			"cost_mult": 1.80,
			"short_desc": "Al romper un orbe Afín o Concentrado, dispara rayos cian que golpean otro orbe Afín cercano.",
		},
		{
			"id": &"bomba_alquimica",
			"name": "Bomba Alquímica",
			"icon": "💣",
			"branch": &"alchemy",
			"color": Color(0.72, 0.44, 1.0),
			"pos": Vector2(1200.0, 215.0),
			"parent_id": &"hervor_creciente",
			"max_level": 5,
			"base_cost": 45,
			"cost_mult": 1.85,
			"short_desc": "Aparecen Bombas que al romperlas (1 golpe) explotan Afines e ingredientes cercanos sin activar ❌.",
		},
		{
			"id": &"orbe_estrella",
			"name": "Orbe Estrella",
			"icon": "⭐",
			"branch": &"alchemy",
			"color": Color(1.0, 0.88, 0.28),
			"pos": Vector2(960.0, 155.0),
			"parent_id": &"chispa_cadena",
			"max_level": 5,
			"base_cost": 90,
			"cost_mult": 2.00,
			"short_desc": "Estrellas Doradas: suéltalas sobre cualquier orbe para subirlo de nivel (x2/x3) o rómpelas por x5 Esencia.",
		},
		# Rama Este/Derecha: Familiares Inteligentes y Tiempo
		{
			"id": &"reloj_arena",
			"name": "Reloj de Arena",
			"icon": "⏳",
			"branch": &"familiars",
			"color": Color(0.62, 0.72, 1.0),
			"pos": Vector2(1230.0, 475.0),
			"parent_id": &"root_cauldron",
			"max_level": 6,
			"base_cost": 16,
			"cost_mult": 1.60,
			"short_desc": "+4s de paciencia para cada clienta antes de que se vaya.",
		},
		{
			"id": &"michi_alado",
			"name": "Michi Alado",
			"icon": "🐱",
			"branch": &"familiars",
			"color": Color(0.84, 0.56, 1.0),
			"pos": Vector2(1465.0, 390.0),
			"parent_id": &"reloj_arena",
			"max_level": 5,
			"base_cost": 40,
			"cost_mult": 1.90,
			"short_desc": "Familiar inteligente: mezcla colores compatibles si hace falta y golpea/rompe orbes Afines por ti.",
		},
		{
			"id": &"diablillo_purgador",
			"name": "Diablillo Purgador",
			"icon": "😈",
			"branch": &"familiars",
			"color": Color(0.95, 0.40, 0.72),
			"pos": Vector2(1465.0, 560.0),
			"parent_id": &"reloj_arena",
			"max_level": 5,
			"base_cost": 65,
			"cost_mult": 1.95,
			"short_desc": "Familiar que purga orbes negativos (❌) del caldero automáticamente para mantener espacio.",
		},
		{
			"id": &"murcielago_alquimista",
			"name": "Murciélago Alquimista",
			"icon": "🦇",
			"branch": &"familiars",
			"color": Color(0.70, 0.50, 1.0),
			"pos": Vector2(1695.0, 475.0),
			"parent_id": &"michi_alado",
			"max_level": 5,
			"base_cost": 85,
			"cost_mult": 2.00,
			"short_desc": "Familiar que duplica chispas recolectadas y añade progreso directo al tubo.",
		},
		# Rama Sur: Clientas VIP, Afinidad y Victoria
		{
			"id": &"encanto_mostrador",
			"name": "Encanto de Mostrador",
			"icon": "💋",
			"branch": &"waifus",
			"color": Color(1.0, 0.50, 0.76),
			"pos": Vector2(960.0, 640.0),
			"parent_id": &"root_cauldron",
			"max_level": 6,
			"base_cost": 20,
			"cost_mult": 1.65,
			"short_desc": "+25% Bono de Esencia y más Afinidad al llenar el tubo de una clienta.",
		},
		{
			"id": &"vitrina_picante",
			"name": "Vitrina Picante",
			"icon": "✨",
			"branch": &"waifus",
			"color": Color(1.0, 0.62, 0.84),
			"pos": Vector2(710.0, 725.0),
			"parent_id": &"encanto_mostrador",
			"max_level": 4,
			"base_cost": 55,
			"cost_mult": 2.10,
			"short_desc": "Desbloquea clientas VIP (Velvet, Seraphina, Mona y Roxy) con mayores bonos.",
		},
		{
			"id": &"destilacion_doble",
			"name": "Destilación Doble",
			"icon": "💎",
			"branch": &"waifus",
			"color": Color(0.96, 0.76, 0.40),
			"pos": Vector2(1210.0, 725.0),
			"parent_id": &"encanto_mostrador",
			"max_level": 4,
			"base_cost": 100,
			"cost_mult": 2.15,
			"short_desc": "Completar un tubo con Combo x5+ otorga Poción Crítica (x2 Bono y +1❤).",
		},
		{
			"id": &"elixir_supremo",
			"name": "Elixir Supremo de Trixie",
			"icon": "🏆",
			"branch": &"waifus",
			"color": Color(1.0, 0.90, 0.34),
			"pos": Vector2(960.0, 800.0),
			"parent_id": &"vitrina_picante",
			"max_level": 1,
			"base_cost": 1000,
			"cost_mult": 1.0,
			"short_desc": "Hito final: consagra la Botica de Trixie y desbloquea el Gran Final.",
		},
	]


## Returns the 6 branching stops of Trixie's traveling potion tour (from docs/story_campaign.md).
static func get_map_nodes() -> Array[Dictionary]:
	return [
		{
			"id": &"castillo",
			"name": "Afueras del Castillo",
			"subtitle": "Parada 1 · Primer Día de Gira",
			"route_tag": "Inicio del Viaje",
			"icon": "🏰",
			"pos": Vector2(490.0, 500.0),
			"color": Color(1.0, 0.78, 0.40),
			"bg_tint": Color(0.09, 0.06, 0.16),
			"bg_path": "res://assets/backgrounds/bg_01_castillo.jpg",
			"unlock_any_of": [],
			"next_ids": [&"pueblo"],
			"customers": [&"sylvi", &"velvet"],
			"essence_mult": 1.0,
			"affinity_bonus": 0,
			"spawn_rate_mult": 1.0,
			"first_clear_bonus": 18,
			"recruits_witch": &"",
			"description": "Primer puesto ambulante frente a las murallas del castillo. Ideal para calentar el caldero, probar mezclas de colores y atender a Sylvi y Velvet.",
			"closing_victory_lines": [
				{
					"speaker": "trixie",
					"emotion": "confiada",
					"text": "¡Uf, pude terminar! Primer puesto superado sin volar por los aires... ¡ahora a descansar y mejorar el caldero en el Mapa!",
				},
			],
			"closing_timeout_lines": [
				{
					"speaker": "trixie",
					"emotion": "hollin",
					"text": "¡Puf...! Se cansaron de esperar y toca intentarlo de nuevo. Por suerte conservo toda la Esencia para mejorar en el Mapa.",
				},
			],
		},
		{
			"id": &"pueblo",
			"name": "El Pueblo",
			"subtitle": "Parada 2 · Plaza del Mercado",
			"route_tag": "Ruta Comercial",
			"icon": "🏘",
			"pos": Vector2(760.0, 420.0),
			"color": Color(0.45, 0.88, 1.0),
			"bg_tint": Color(0.10, 0.07, 0.18),
			"bg_path": "res://assets/backgrounds/bg_02_pueblo.jpg",
			"unlock_any_of": [&"castillo"],
			"next_ids": [&"bosque_goblins"],
			"customers": [&"sylvi", &"velvet", &"seraphina"],
			"essence_mult": 1.25,
			"affinity_bonus": 1,
			"spawn_rate_mult": 1.08,
			"first_clear_bonus": 28,
			"recruits_witch": &"",
			"description": "Plaza bulliciosa con 3 clientas seguidas. Llegan pedidos de Sylvi, Velvet y la exigente paladín Seraphina (+25% Esencia).",
			"closing_victory_lines": [
				{
					"speaker": "trixie",
					"emotion": "confiada",
					"text": "¡Uf, plaza superada! Qué clientas más intensas... ¡toca descansar un poco y seguir la ruta en el Mapa!",
				},
			],
			"closing_timeout_lines": [
				{
					"speaker": "trixie",
					"emotion": "nerviosa",
					"text": "¡Uff, cuántas clientas impacientes! Toca mejorar el caldero en el Mapa y volver a intentarlo.",
				},
			],
		},
		{
			"id": &"bosque_goblins",
			"name": "Bosque Tenebroso",
			"subtitle": "Parada 3 · Desvío de la Jefa Goblin",
			"route_tag": "Ruta Volátil · +45% ✦",
			"icon": "🌲",
			"pos": Vector2(1040.0, 520.0),
			"color": Color(0.76, 0.44, 1.0),
			"bg_tint": Color(0.06, 0.05, 0.13),
			"unlock_any_of": [&"pueblo"],
			"next_ids": [&"bosque_profundo", &"arroyo_balsa"],
			"customers": [&"velvet", &"roxy", &"mona", &"sylvi"],
			"essence_mult": 1.45,
			"affinity_bonus": 1,
			"spawn_rate_mult": 1.18,
			"first_clear_bonus": 42,
			"recruits_witch": &"",
			"description": "Árboles sin hojas y cielo cerrado. ¡Trixie tomó un desvío equivocado y debe encantar con pociones a 4 clientas bajo la mirada de la Jefa Goblin!",
			"closing_victory_lines": [
				{
					"speaker": "trixie",
					"emotion": "sorprendida",
					"text": "¡Lo logré! Hasta la Jefa Goblin quedó encantada... ¡ahora a descansar y elegir desvío en el Mapa!",
				},
			],
			"closing_timeout_lines": [
				{
					"speaker": "trixie",
					"emotion": "hollin",
					"text": "¡Casi termino en su olla gigante! Salí con la Esencia intacta: toca mejorar en el Mapa y reintentar.",
				},
			],
		},
		{
			"id": &"bosque_profundo",
			"name": "Sendero de Esporas",
			"subtitle": "Bifurcación A · Recluta a Lyra",
			"route_tag": "Ruta Arcana · +Lyra 🌿",
			"icon": "🍄",
			"pos": Vector2(1370.0, 340.0),
			"color": Color(0.36, 0.94, 0.58),
			"bg_tint": Color(0.05, 0.11, 0.12),
			"unlock_any_of": [&"bosque_goblins"],
			"next_ids": [&"nuevo_pueblo"],
			"customers": [&"sylvi", &"seraphina", &"roxy", &"mona"],
			"essence_mult": 1.55,
			"affinity_bonus": 2,
			"spawn_rate_mult": 1.20,
			"first_clear_bonus": 55,
			"recruits_witch": &"lyra",
			"description": "Esporas luminosas en lo hondo del bosque. Atiende esta ola de 4 clientas para conocer y reclutar a Lyra, la druida traviesa (+2 Afinidad extra).",
			"closing_victory_lines": [
				{
					"speaker": "trixie",
					"emotion": "sonrojada",
					"text": "¡Con Lyra uniéndose a nosotras la botica es imparable! Descansemos y sigamos el camino en el Mapa.",
				},
			],
			"closing_timeout_lines": [
				{
					"speaker": "trixie",
					"emotion": "nerviosa",
					"text": "¡Estas esporas me marearon y perdimos el ritmo! Volvamos al Mapa a mejorar el caldero y reintentar.",
				},
			],
		},
		{
			"id": &"arroyo_balsa",
			"name": "Arroyo en Balsa",
			"subtitle": "Bifurcación B · Aguas de Sirenas",
			"route_tag": "Ruta Fluvial · +70% ✦",
			"icon": "🌊",
			"pos": Vector2(1370.0, 660.0),
			"color": Color(0.24, 0.86, 0.96),
			"bg_tint": Color(0.05, 0.09, 0.19),
			"unlock_any_of": [&"bosque_goblins"],
			"next_ids": [&"nuevo_pueblo"],
			"customers": [&"mona", &"velvet", &"sylvi", &"roxy"],
			"essence_mult": 1.70,
			"affinity_bonus": 1,
			"spawn_rate_mult": 1.26,
			"first_clear_bonus": 65,
			"recruits_witch": &"",
			"description": "Trixie conjura una balsa mágica y hierve pociones corriente abajo frente a 4 clientas. Ritmo veloz con enorme recompensa de Esencia (+70%).",
			"closing_victory_lines": [
				{
					"speaker": "trixie",
					"emotion": "hollin",
					"text": "¡Woooosh! Empapada tras la cascada, pero con el bolso lleno de Esencia... ¡ahora a secarme y ver el Mapa!",
				},
			],
			"closing_timeout_lines": [
				{
					"speaker": "trixie",
					"emotion": "hollin",
					"text": "¡La balsa dio demasiadas vueltas y se fueron molestas! Volvamos al Mapa a mejorar antes de reintentar el río.",
				},
			],
		},
		{
			"id": &"nuevo_pueblo",
			"name": "Nuevo Pueblo Costero",
			"subtitle": "Parada 5 · Gran Feria Nocturna",
			"route_tag": "Gran Ola · x2.0 ✦",
			"icon": "🏮",
			"pos": Vector2(1710.0, 495.0),
			"color": Color(1.0, 0.56, 0.78),
			"bg_tint": Color(0.13, 0.06, 0.16),
			"unlock_any_of": [&"bosque_profundo", &"arroyo_balsa"],
			"next_ids": [],
			"customers": [&"sylvi", &"velvet", &"seraphina", &"mona", &"roxy"],
			"essence_mult": 2.0,
			"affinity_bonus": 2,
			"spawn_rate_mult": 1.32,
			"first_clear_bonus": 110,
			"recruits_witch": &"",
			"description": "Tras dejar atrás el bosque y la cascada, Trixie despliega su caldero en la gran feria nocturna frente a las cinco clientas VIP.",
			"closing_victory_lines": [
				{
					"speaker": "trixie",
					"emotion": "sonrojada",
					"text": "¡Uf, pude terminar la gran feria nocturna! Cinco clientas encantadas... ¡ahora sí a descansar y revisar el Mapa!",
				},
			],
			"closing_timeout_lines": [
				{
					"speaker": "trixie",
					"emotion": "nerviosa",
					"text": "¡Cinco clientas juntas son pura adrenalina! Toca mejorar un poco más en el Mapa y volver a arrasar la feria.",
				},
			],
		},
	]
