extends SceneTree
## Validates .tres data catalogs, 17-node tactical tree, and instantiates Main.tscn
## to verify zero-autoclicker color chemistry, purge, chains, Frenzy, and tree buys.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var witches: Array[WitchCharacterData] = GameCatalog.get_witches()
	var customers: Array[CustomerArchetypeData] = GameCatalog.get_customers()
	var recipes: Array[PotionRecipeData] = GameCatalog.get_recipes()
	var upgrades: Array[RogueliteUpgradeData] = GameCatalog.get_upgrades()
	var inc_nodes: Array[Dictionary] = GameCatalog.get_incremental_nodes()

	print("CATALOG CHECK => witches=%d customers=%d recipes=%d upgrades=%d inc_nodes=%d" % [
		witches.size(), customers.size(), recipes.size(), upgrades.size(), inc_nodes.size()
	])

	var cat_ok: bool = witches.size() == 4 and customers.size() == 5 and recipes.size() == 6 and upgrades.size() >= 6 and inc_nodes.size() == 17

	var main_scene: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load res://scenes/main/Main.tscn")
		quit(1)
		return

	var main_inst: MainGame = main_scene.instantiate() as MainGame
	if main_inst == null:
		push_error("Main.tscn root is not MainGame")
		quit(1)
		return

	root.add_child(main_inst)
	await process_frame

	var res: Dictionary = main_inst.run_incremental_smoke_step()
	print("INCREMENTAL SMOKE STEP => ", res)

	var sim_ok: bool = (
		bool(res.get("initial_cap_ok", false))
		and bool(res.get("all_halfbodies_distinct_ok", false))
		and bool(res.get("sylvi_halfbodies_distinct_ok", false))
		and bool(res.get("no_autoclicker_ok", false))
		and bool(res.get("three_clicks_to_break_ok", false))
		and bool(res.get("lift_combine_color_ok", false))
		and bool(res.get("lift_concentrate_ok", false))
		and bool(res.get("purge_kept_combo", false))
		and bool(res.get("disliked_lowered_tube", false))
		and bool(res.get("disliked_reset_combo", false))
		and bool(res.get("nerviosa_ok", false))
		and bool(res.get("cust_impaciente_ok", false))
		and bool(res.get("hollin_triggered", false))
		and bool(res.get("sorprendida_triggered", false))
		and int(res.get("orders_completed", 0)) >= 1
		and bool(res.get("mixed_order_velvet_ok", false))
		and bool(res.get("frenzy_triggered", false))
		and bool(res.get("sonrojada_triggered", false))
		and bool(res.get("cust_sonrojada_ok", false))
		and bool(res.get("bought_hold_hit", false))
		and bool(res.get("bought_strength", false))
		and bool(res.get("bought_boil", false))
		and int(res.get("nodes_count", 0)) == 17
	)

	main_inst.queue_free()
	await process_frame

	var all_ok: bool = cat_ok and sim_ok
	print("INCREMENTAL SMOKE RESULT: ", "PASS" if all_ok else "FAIL")
	quit(0 if all_ok else 1)
