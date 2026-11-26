extends SceneTree
## Validates .tres data catalogs, 17-node tactical tree, 6-node WorldMap catalog,
## MainGame (zero-autoclicker cauldron, tutorial, wave closing dialogue), and WorldMap
## (mandatory Toque Continuo tutorial, Skill Tree, Gallery, and Stop 2 travel).

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var witches: Array[WitchCharacterData] = GameCatalog.get_witches()
	var customers: Array[CustomerArchetypeData] = GameCatalog.get_customers()
	var recipes: Array[PotionRecipeData] = GameCatalog.get_recipes()
	var upgrades: Array[RogueliteUpgradeData] = GameCatalog.get_upgrades()
	var inc_nodes: Array[Dictionary] = GameCatalog.get_incremental_nodes()
	var map_nodes: Array[Dictionary] = GameCatalog.get_map_nodes()

	print("CATALOG CHECK => witches=%d customers=%d recipes=%d upgrades=%d inc_nodes=%d map_nodes=%d" % [
		witches.size(), customers.size(), recipes.size(), upgrades.size(), inc_nodes.size(), map_nodes.size()
	])

	var cat_ok: bool = (
		witches.size() == 4
		and customers.size() == 5
		and recipes.size() == 6
		and upgrades.size() >= 6
		and inc_nodes.size() == 17
		and map_nodes.size() == 6
	)

	var gs: Node = root.get_node_or_null("GameState")
	var owns_gs: bool = false
	if gs == null:
		var gs_script: GDScript = preload("res://scripts/autoloads/GameState.gd")
		gs = gs_script.new() as Node
		gs.name = "GameState"
		root.add_child(gs)
		owns_gs = true
	else:
		gs.call("reset_run")
	await process_frame

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

	main_inst.queue_free()
	await process_frame

	var map_scene: PackedScene = load("res://scenes/meta/WorldMap.tscn") as PackedScene
	if map_scene == null:
		push_error("Failed to load res://scenes/meta/WorldMap.tscn")
		quit(1)
		return

	var map_inst: WorldMap = map_scene.instantiate() as WorldMap
	if map_inst == null:
		push_error("WorldMap.tscn root is not WorldMap")
		quit(1)
		return

	root.add_child(map_inst)
	await process_frame

	var map_res: Dictionary = map_inst.run_worldmap_smoke_step()
	print("WORLDMAP SMOKE STEP => ", map_res)

	map_inst.queue_free()
	if owns_gs:
		gs.queue_free()
	await process_frame

	var sim_ok: bool = (
		bool(res.get("initial_cap_ok", false))
		and bool(res.get("cauldron_tex_ok", false))
		and bool(res.get("stop_bg_tex_ok", false))
		and bool(res.get("flask_assets_ok", false))
		and bool(res.get("orb_sprites_ok", false))
		and bool(res.get("dialog_bg_tex_ok", false))
		and bool(res.get("pueblo_bg_exists_ok", false))
		and bool(res.get("mix_pigment_blending_ok", false))
		and bool(res.get("no_duplicate_meta_buttons_in_main", false))
		and bool(res.get("customer_hud_ok", false))
		and bool(res.get("customer_hud_clean_copy_ok", false))
		and bool(res.get("witch_name_hud_ok", false))
		and bool(res.get("patience_pause_lock_ok", false))
		and bool(res.get("all_halfbodies_distinct_ok", false))
		and bool(res.get("sylvi_halfbodies_distinct_ok", false))
		and bool(res.get("velvet_halfbodies_distinct_ok", false))
		and bool(res.get("seraphina_halfbodies_distinct_ok", false))
		and bool(res.get("mona_halfbodies_distinct_ok", false))
		and bool(res.get("roxy_halfbodies_distinct_ok", false))
		and bool(res.get("cauldron_tutorial_flow_ok", false))
		and bool(res.get("tutorial_pauses_patience_ok", false))
		and bool(res.get("mix_tutorial_contextual_ok", false))
		and bool(res.get("customer_timeout_advances_ok", false))
		and bool(res.get("varied_customer_orders_ok", false))
		and bool(res.get("mona_elf_archetype_ok", false))
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
		and int(res.get("orders_completed", 0)) >= 2
		and bool(res.get("mixed_order_velvet_ok", false))
		and bool(res.get("frenzy_triggered", false))
		and bool(res.get("sonrojada_triggered", false))
		and bool(res.get("cust_sonrojada_ok", false))
		and bool(res.get("wave_closing_dialogue_ok", false))
		and int(res.get("nodes_count", 0)) == 17
	)

	var map_ok: bool = (
		bool(map_res.get("travel_blocked_initially", false))
		and bool(map_res.get("entered_tree_ok", false))
		and bool(map_res.get("other_buy_blocked_ok", false))
		and bool(map_res.get("bought_hold_ok", false))
		and bool(map_res.get("back_unlocked_ok", false))
		and bool(map_res.get("gallery_opened_ok", false))
		and bool(map_res.get("pueblo_travel_ready_ok", false))
		and bool(map_res.get("bought_strength_ok", false))
		and bool(map_res.get("bought_boil_ok", false))
		and bool(map_res.get("reloj_arena_patience_ok", false))
	)

	var all_ok: bool = cat_ok and sim_ok and map_ok
	print("INCREMENTAL SMOKE RESULT: ", "PASS" if all_ok else "FAIL")
	quit(0 if all_ok else 1)
