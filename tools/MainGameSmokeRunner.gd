class_name MainGameSmokeRunner
extends RefCounted
## Headless verification harness for MainGame cauldron mechanics, tutorials,
## pigment mixing, wave closing dialogue, and character expression assets.


static func run(m: MainGame) -> Dictionary:
	var initial_cap_ok: bool = (m.spawn_cap == 6 and m._orbs.size() == 6 and m.click_damage == 1 and not m.hold_auto_hit_unlocked)
	var cauldron_tex_ok: bool = (m._cauldron_tex != null and m._cauldron_tex.resource_path == MainGame.CAULDRON_TEX_PATH)
	var stop_bg_tex_ok: bool = (m._stop_bg_tex != null and m._stop_bg_tex.resource_path == "res://assets/backgrounds/bg_01_castillo.jpg" and m._bg_sprite != null and m._bg_sprite.visible)
	var flask_assets_ok: bool = (m._flask_view != null and m._flask_view.has_assets())
	var orb_sprites_ok: bool = (m._orb_textures.size() == 8 and m._crack_textures.size() == 2 and m._crack_glow_textures.size() == 2)
	var dialog_bg_tex_ok: bool = (m._hud != null and m._hud.has_dialog_and_bubble_textures())
	var pueblo_bg_exists_ok: bool = ResourceLoader.exists("res://assets/backgrounds/bg_02_pueblo.jpg")
	var no_duplicate_meta_buttons_in_main: bool = (
		m.get("_tab_tree_btn") == null
		and m.get("_tab_gallery_btn") == null
		and m.get("_end_round_btn") == null
	)

	var hb_paths: Dictionary = {}
	var all_hb_ok: bool = true
	for emo: String in ["normal", "confiada", "nerviosa", "sonrojada", "hollin", "sorprendida"]:
		var hb_tex: Texture2D = CharacterArt.get_trixie_halfbody(emo)
		if hb_tex == null:
			all_hb_ok = false
		else:
			hb_paths[hb_tex.resource_path] = true
	var all_halfbodies_distinct_ok: bool = all_hb_ok and hb_paths.size() == 6

	var sylvi_paths: Dictionary = {}
	var all_sylvi_ok: bool = true
	for s_emo: String in ["normal", "sonrojada_picante", "impaciente"]:
		var s_tex: Texture2D = CharacterArt.get_customer_halfbody(&"sylvi", s_emo)
		if s_tex == null:
			all_sylvi_ok = false
		else:
			sylvi_paths[s_tex.resource_path] = true
	var sylvi_halfbodies_distinct_ok: bool = all_sylvi_ok and sylvi_paths.size() == 3

	var velvet_paths: Dictionary = {}
	var all_velvet_ok: bool = true
	for v_emo: String in ["normal", "sonrojada_picante", "impaciente"]:
		var v_tex: Texture2D = CharacterArt.get_customer_halfbody(&"velvet", v_emo)
		if v_tex == null:
			all_velvet_ok = false
		else:
			velvet_paths[v_tex.resource_path] = true
	var velvet_halfbodies_distinct_ok: bool = all_velvet_ok and velvet_paths.size() == 3

	var seraphina_paths: Dictionary = {}
	var all_seraphina_ok: bool = true
	for sp_emo: String in ["normal", "sonrojada_picante", "impaciente"]:
		var sp_tex: Texture2D = CharacterArt.get_customer_halfbody(&"seraphina", sp_emo)
		if sp_tex == null:
			all_seraphina_ok = false
		else:
			seraphina_paths[sp_tex.resource_path] = true
	var seraphina_halfbodies_distinct_ok: bool = all_seraphina_ok and seraphina_paths.size() == 3

	var mona_paths: Dictionary = {}
	var all_mona_ok: bool = true
	for mn_emo: String in ["normal", "sonrojada_picante", "impaciente"]:
		var mn_tex: Texture2D = CharacterArt.get_customer_halfbody(&"mona", mn_emo)
		if mn_tex == null:
			all_mona_ok = false
		else:
			mona_paths[mn_tex.resource_path] = true
	var mona_halfbodies_distinct_ok: bool = all_mona_ok and mona_paths.size() == 3

	var roxy_paths: Dictionary = {}
	var all_roxy_ok: bool = true
	for rx_emo: String in ["normal", "sonrojada_picante", "impaciente"]:
		var rx_tex: Texture2D = CharacterArt.get_customer_halfbody(&"roxy", rx_emo)
		if rx_tex == null:
			all_roxy_ok = false
		else:
			roxy_paths[rx_tex.resource_path] = true
	var roxy_halfbodies_distinct_ok: bool = all_roxy_ok and roxy_paths.size() == 3

	var st: Node = m._state()
	var tut_step_1_ok: bool = (
		m._tutorial.active
		and m._tutorial.step == TutorialDirector.Step.BASIC_BREAK_LIKED
		and m._hud != null
		and m._hud.trixie_bubble != null
		and m._hud.trixie_bubble.visible
		and not st.mix_tutorial_done
	)
	var banner_above_cauldron_ok: bool = (
		m._hud != null
		and m._hud.trixie_bubble != null
		and (m._hud.trixie_bubble.base_position.y + SpeechBubble.BODY_HEIGHT) < (MainGame.CAULDRON_CENTER.y - MainGame.CAULDRON_ELLIPSE_RY)
	)

	# 1) Verify idle frame causes zero passive extraction AND tutorial pauses patience!
	var tube_before: float = m._potion_tube_pct
	var ess_before: int = m.essence_gold
	var pat_before: float = m.customer_patience_left
	m._process_cauldron_gameplay(5.0)
	var no_autoclicker_ok: bool = (m._potion_tube_pct == tube_before and m.essence_gold == ess_before)
	var tutorial_pauses_patience_ok: bool = (m.customer_patience_left == pat_before)

	# 2) Verify 3 hits break a tier-1 orb initially (advances basic tutorial 1 -> 2)
	var chem: Dictionary = m.get_customer_chemistry()
	var liked_k: int = int(chem["liked"])
	var disliked_k: int = int(chem["disliked"])

	m._orbs.clear()
	var red_orb: Dictionary = m._make_orb_dict(liked_k, MainGame.CAULDRON_CENTER, 1)
	var red_id: int = int(red_orb["id"])
	m._orbs.append(red_orb)
	var h1_broke: bool = m._hit_orb_by_id(red_id, m.click_damage, true)
	var h2_broke: bool = m._hit_orb_by_id(red_id, m.click_damage, true)
	var hp_before_3: int = int(m._orbs[0]["hp"]) if m._orbs.size() == 1 else -1
	var h3_broke: bool = m._hit_orb_by_id(red_id, m.click_damage, true)
	var three_clicks_to_break_ok: bool = (not h1_broke and not h2_broke and hp_before_3 == 1 and h3_broke and m._potion_tube_pct > 15.0 and m._combo == 1)
	var tut_step_2_ok: bool = (m._tutorial.step == TutorialDirector.Step.BASIC_PURGE_DISLIKED)

	# 3) Verify lift-and-drop color combining & concentration mechanics
	m._orbs.clear()
	var mix_a: Dictionary = m._make_orb_dict(ChemistryRules.BubbleKind.RED, MainGame.CAULDRON_CENTER + Vector2(-60, 0), 1)
	var mix_b: Dictionary = m._make_orb_dict(ChemistryRules.BubbleKind.GREEN, MainGame.CAULDRON_CENTER + Vector2(60, 0), 1)
	m._orbs.append(mix_a)
	m._orbs.append(mix_b)
	var combined_color: bool = m._combine_orbs_by_id(int(mix_a["id"]), int(mix_b["id"]))
	var lift_combine_color_ok: bool = (combined_color and m._orbs.size() >= 1 and int(m._orbs[0]["kind"]) == ChemistryRules.BubbleKind.YELLOW and int(m._orbs[0]["hp"]) == MainGame.BASE_ORB_HP)

	m._orbs.clear()
	var conc_a: Dictionary = m._make_orb_dict(ChemistryRules.BubbleKind.RED, MainGame.CAULDRON_CENTER + Vector2(-60, 0), 1)
	var conc_b: Dictionary = m._make_orb_dict(ChemistryRules.BubbleKind.RED, MainGame.CAULDRON_CENTER + Vector2(60, 0), 1)
	m._orbs.append(conc_a)
	m._orbs.append(conc_b)
	var combined_same: bool = m._combine_orbs_by_id(int(conc_a["id"]), int(conc_b["id"]))
	var lift_concentrate_ok: bool = (combined_same and m._orbs.size() == 1 and int(m._orbs[0]["kind"]) == ChemistryRules.BubbleKind.RED and int(m._orbs[0]["tier"]) == 2)

	# 4) Purge a Disliked orb with Right-click -> preserves combo & advances basic tutorial 2 -> 3 (summary)
	m._orbs.clear()
	var bad_p: Dictionary = m._make_orb_dict(disliked_k, MainGame.CAULDRON_CENTER + Vector2(90, 0), 1)
	m._orbs.append(bad_p)
	m._purge_orb_by_id(int(bad_p["id"]))
	var purge_kept_combo: bool = (m._combo == 1 and m._potion_tube_pct > 15.0)
	var tut_step_3_ok: bool = (m._tutorial.step == TutorialDirector.Step.BASIC_READY_SUMMARY and m._hud != null and m._hud.trixie_bubble != null and m._hud.trixie_bubble.is_ack_visible())

	# Acknowledge summary -> basic tutorial done and patience starts counting down
	m._acknowledge_basic_tutorial_summary()
	var pat_pre_tick: float = m.customer_patience_left
	m._process_cauldron_gameplay(2.0)
	var patience_ticks_after_tut_ok: bool = (not m._tutorial.active and st.cauldron_basics_tutorial_done and m.customer_patience_left < pat_pre_tick)

	# 5) Break Disliked orb -> lowers tube, resets combo to 0, triggers nerviosa & customer impaciente
	m._orbs.clear()
	var bad_1: Dictionary = m._make_orb_dict(disliked_k, MainGame.CAULDRON_CENTER, 1)
	bad_1["hp"] = 1
	m._orbs.append(bad_1)
	var tube_pre_bad: float = m._potion_tube_pct
	m._hit_orb_by_id(int(bad_1["id"]), 1, true)
	var disliked_lowered_tube: bool = m._potion_tube_pct < tube_pre_bad
	var disliked_reset_combo: bool = (m._combo == 0)
	var nerviosa_ok: bool = (m._trixie_emotion == "nerviosa")
	var cust_impaciente_ok: bool = (m._customer_emotion == "impaciente")

	# Second consecutive Disliked backfire -> triggers hollin
	m._orbs.clear()
	var bad_2: Dictionary = m._make_orb_dict(disliked_k, MainGame.CAULDRON_CENTER, 1)
	bad_2["hp"] = 1
	m._orbs.append(bad_2)
	m._hit_orb_by_id(int(bad_2["id"]), 1, true)
	var hollin_triggered: bool = (m._trixie_emotion == "hollin")

	# 6) Break GOLD Star orb -> triggers sorprendida
	m._orbs.clear()
	var gold_o: Dictionary = m._make_orb_dict(ChemistryRules.BubbleKind.GOLD, MainGame.CAULDRON_CENTER, 1)
	gold_o["hp"] = 1
	m._orbs.append(gold_o)
	m._hit_orb_by_id(int(gold_o["id"]), 1, true)
	var sorprendida_triggered: bool = (m._trixie_emotion == "sorprendida")

	# 7) Complete Sylvi's order -> Velvet arrives with mixed color order & JUST-IN-TIME MIX TUTORIAL pops and pauses time!
	m._orbs.clear()
	var finisher: Dictionary = m._make_orb_dict(liked_k, MainGame.CAULDRON_CENTER, 3)
	finisher["hp"] = 1
	m._orbs.append(finisher)
	m._hit_orb_by_id(int(finisher["id"]), 1, true)
	var mixed_order_velvet_ok: bool = (m.orders_completed >= 1 and m._active_customer != null and m._active_customer.customer_id == &"velvet" and ChemistryRules.is_mixed_kind(int(m.get_customer_chemistry()["liked"])))
	var mix_tut_started_ok: bool = (m._tutorial.active and m._tutorial.step == TutorialDirector.Step.MIX_DRAG_COMBINE)
	var v_pat_before: float = m.customer_patience_left
	m._process_cauldron_gameplay(4.0)
	var mix_tut_paused_ok: bool = (m.customer_patience_left == v_pat_before)

	# Complete the contextual mix tutorial by combining RED + BLUE -> PURPLE and breaking it
	var v_comps: Array[int] = ChemistryRules.get_recipe_components(int(m.get_customer_chemistry()["liked"]))
	m._orbs.clear()
	var vm_a: Dictionary = m._make_orb_dict(v_comps[0], MainGame.CAULDRON_CENTER + Vector2(-50, 0), 1)
	var vm_b: Dictionary = m._make_orb_dict(v_comps[1], MainGame.CAULDRON_CENTER + Vector2(50, 0), 1)
	m._orbs.append(vm_a)
	m._orbs.append(vm_b)
	m._combine_orbs_by_id(int(vm_a["id"]), int(vm_b["id"]))
	var mix_tut_step2_ok: bool = (m._tutorial.step == TutorialDirector.Step.MIX_BREAK_RESULT)
	m._orbs[0]["hp"] = 1
	m._hit_orb_by_id(int(m._orbs[0]["id"]), 1, true)
	var mix_tut_done_ok: bool = (not m._tutorial.active and st.mix_tutorial_done)

	# 8) Append temporary 3rd customer (&"seraphina") to test Frenzy + Velvet serve + Seraphina patience timeout
	m._wave_customers.append(&"seraphina")

	# Trigger Frenzy on Velvet -> sonrojada on both girls
	m._orbs.clear()
	var v_bad: Dictionary = m._make_orb_dict(int(m.get_customer_chemistry()["disliked"]), MainGame.CAULDRON_CENTER, 1)
	m._orbs.append(v_bad)
	if m._frenzy_charge < 100.0:
		m._frenzy_charge = 100.0
	var frenzy_triggered: bool = m.try_activate_frenzy()
	var sonrojada_triggered: bool = (m._trixie_emotion == "sonrojada")
	var cust_sonrojada_ok: bool = (m._customer_emotion == "sonrojada")

	# Serve Velvet -> Seraphina arrives
	var v_liked: int = int(m.get_customer_chemistry()["liked"])
	m._orbs.clear()
	var v_fin: Dictionary = m._make_orb_dict(v_liked, MainGame.CAULDRON_CENTER, 3)
	v_fin["hp"] = 1
	m._orbs.append(v_fin)
	m._hit_orb_by_id(int(v_fin["id"]), 1, true)
	var seraphina_arrived_ok: bool = (m._active_customer != null and m._active_customer.customer_id == &"seraphina" and m._wave_served_count == 2)

	# Drain Seraphina's patience -> customer leaves, missed count=1, combo=0, 2/3 served -> wave victory & closing dialogue!
	m._combo = 3
	m.customer_patience_left = 0.05
	m._process_cauldron_gameplay(0.2)
	var customer_timeout_advances_ok: bool = (seraphina_arrived_ok and m._wave_missed_count == 1 and m._combo == 0)

	var end_triggered_gracefully: bool = m.round_ending and m._wave_victory and not m._closing_active
	m._round_end_timer = 0.0
	m._process_cauldron_gameplay(0.05)
	var closing_opened_ok: bool = m._closing_active and m._hud != null and m._hud.is_closing_visible() and m._closing_lines.size() == 1 and String(m._closing_lines[0].get("speaker", "")) == "trixie"

	for _step: int in range(10):
		if not m._closing_active or m._fading_out:
			break
		if m._hud != null:
			m._hud.complete_closing_typing()
		m._handle_closing_advance_input()

	var wave_closing_dialogue_ok: bool = (
		end_triggered_gracefully
		and closing_opened_ok
		and st.is_map_node_completed(&"castillo")
		and st.is_map_node_unlocked(&"pueblo")
		and st.cauldron_tutorial_done
	)

	# 9) Verify dynamic varied customer orders & Mona Elfa Noble archetype
	var rolled_kinds: Dictionary = {}
	var roll_valid: bool = true
	for _r: int in range(10):
		var c_chem: Dictionary = m._roll_order_chemistry_for_customer(&"sylvi", false)
		var lk: int = int(c_chem["liked"])
		var dk: int = int(c_chem["disliked"])
		m._last_order_liked_kind = lk
		rolled_kinds[lk] = true
		if ChemistryRules.is_mixed_kind(lk) and ChemistryRules.get_recipe_components(lk).has(dk):
			roll_valid = false
	var varied_customer_orders_ok: bool = (rolled_kinds.size() >= 2 and roll_valid)

	var mona_c: CustomerArchetypeData = m._find_customer_by_id(&"mona")
	var mona_elf_archetype_ok: bool = (
		mona_c != null
		and mona_c.species_archetype.contains("Elfa")
		and not mona_c.species_archetype.contains("Bruja")
	)

	m._flask_view.reset_mix_pigment(true)
	var reset_clean_ok: bool = (m._flask_view.mix_weight == 0.0 and m._flask_view.broth_target_color == PotionFlaskView.BROTH_NEUTRAL_COLOR)
	m._flask_view.inject_mix_pigment(ChemistryRules.BubbleKind.BLUE, 1)
	var h_blue: float = m._flask_view.flask_target_color.h
	m._flask_view.inject_mix_pigment(ChemistryRules.BubbleKind.RED, 1)
	var h_purple: float = m._flask_view.flask_target_color.h
	m._flask_view.inject_mix_pigment(ChemistryRules.BubbleKind.BLUE, 1)
	var h_bluish: float = m._flask_view.flask_target_color.h
	m._flask_view.reset_mix_pigment(false)
	var mix_pigment_blending_ok: bool = (
		reset_clean_ok
		and h_blue >= 0.50 and h_blue <= 0.66
		and h_purple >= 0.72 and h_purple <= 0.90
		and h_bluish >= 0.58 and h_bluish < h_purple - 0.05
		and m._flask_view.mix_weight == 0.0
		and m._flask_view.broth_target_color == PotionFlaskView.BROTH_NEUTRAL_COLOR
	)

	return {
		"initial_cap_ok": initial_cap_ok,
		"cauldron_tex_ok": cauldron_tex_ok,
		"stop_bg_tex_ok": stop_bg_tex_ok,
		"flask_assets_ok": flask_assets_ok,
		"orb_sprites_ok": orb_sprites_ok,
		"dialog_bg_tex_ok": dialog_bg_tex_ok,
		"pueblo_bg_exists_ok": pueblo_bg_exists_ok,
		"mix_pigment_blending_ok": mix_pigment_blending_ok,
		"no_duplicate_meta_buttons_in_main": no_duplicate_meta_buttons_in_main,
		"all_halfbodies_distinct_ok": all_halfbodies_distinct_ok,
		"sylvi_halfbodies_distinct_ok": sylvi_halfbodies_distinct_ok,
		"velvet_halfbodies_distinct_ok": velvet_halfbodies_distinct_ok,
		"seraphina_halfbodies_distinct_ok": seraphina_halfbodies_distinct_ok,
		"mona_halfbodies_distinct_ok": mona_halfbodies_distinct_ok,
		"roxy_halfbodies_distinct_ok": roxy_halfbodies_distinct_ok,
		"cauldron_tutorial_flow_ok": tut_step_1_ok and banner_above_cauldron_ok and tut_step_2_ok and tut_step_3_ok and patience_ticks_after_tut_ok,
		"tutorial_pauses_patience_ok": tutorial_pauses_patience_ok,
		"mix_tutorial_contextual_ok": mix_tut_started_ok and mix_tut_paused_ok and mix_tut_step2_ok and mix_tut_done_ok,
		"customer_timeout_advances_ok": customer_timeout_advances_ok,
		"varied_customer_orders_ok": varied_customer_orders_ok,
		"mona_elf_archetype_ok": mona_elf_archetype_ok,
		"no_autoclicker_ok": no_autoclicker_ok,
		"three_clicks_to_break_ok": three_clicks_to_break_ok,
		"lift_combine_color_ok": lift_combine_color_ok,
		"lift_concentrate_ok": lift_concentrate_ok,
		"purge_kept_combo": purge_kept_combo,
		"disliked_lowered_tube": disliked_lowered_tube,
		"disliked_reset_combo": disliked_reset_combo,
		"nerviosa_ok": nerviosa_ok,
		"cust_impaciente_ok": cust_impaciente_ok,
		"hollin_triggered": hollin_triggered,
		"sorprendida_triggered": sorprendida_triggered,
		"orders_completed": m.orders_completed,
		"mixed_order_velvet_ok": mixed_order_velvet_ok,
		"frenzy_triggered": frenzy_triggered,
		"sonrojada_triggered": sonrojada_triggered,
		"cust_sonrojada_ok": cust_sonrojada_ok,
		"wave_closing_dialogue_ok": wave_closing_dialogue_ok,
		"nodes_count": m.tree_nodes.size(),
	}
