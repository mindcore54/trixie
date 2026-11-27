class_name MainGameSmokeRunner
extends RefCounted
## Headless verification harness for MainGame cauldron mechanics, tutorials,
## pigment mixing, wave closing dialogue, and character expression assets.


static func run(m: MainGame) -> Dictionary:
	var b: CauldronBoard = m._board
	var w: WaveDirector = m._wave
	var c_center: Vector2 = b.get_center() if b != null else MainGame.CAULDRON_CENTER

	var initial_cap_ok: bool = (b != null and b.spawn_cap == 6 and b.orbs.size() == 6 and b.click_damage == 1 and not b.hold_auto_hit_unlocked)
	var cauldron_tex_ok: bool = (b != null and b.cauldron_tex != null and b.cauldron_tex.resource_path == CauldronBoard.CAULDRON_TEX_PATH)
	var stop_bg_tex_ok: bool = (m._stop_bg_tex != null and m._stop_bg_tex.resource_path == "res://assets/backgrounds/bg_01_castillo.jpg" and m._bg_sprite != null and m._bg_sprite.visible)
	var flask_assets_ok: bool = (m._flask_view != null and m._flask_view.has_assets())
	var orb_sprites_ok: bool = (b != null and b.orb_textures.size() == 8 and b.crack_textures.size() == 2 and b.crack_glow_textures.size() == 2)
	var dialog_bg_tex_ok: bool = (m._hud != null and m._hud.has_dialog_and_bubble_textures())
	var pueblo_bg_exists_ok: bool = ResourceLoader.exists("res://assets/backgrounds/bg_02_pueblo.jpg")
	var no_duplicate_meta_buttons_in_main: bool = (
		m.get("_tab_tree_btn") == null
		and m.get("_tab_gallery_btn") == null
		and m.get("_end_round_btn") == null
	)
	var customer_hud_ok: bool = (
		m._hud != null
		and m._hud.has_customer_hud_textures()
		and m._hud.get_node_or_null("TopBar/Margin/HBox/TimerLabel") == null
		and m._hud.get_node_or_null("CauldronHudRoot/ChemistryCard") == null
		and not ResourceLoader.exists("res://scenes/ui/ChemistryStrip.tscn")
	)
	m._refresh_hud_labels()
	var wave_dock: WaveProgressDock = m._hud.get_wave_dock() if m._hud != null else null
	var top_hud_base_ok: bool = (
		m._hud != null
		and m._hud.has_floating_top_hud()
		and m._hud.has_top_hud_textures()
		and m._hud.is_stop_intro_visible()
		and m._hud.has_stop_intro_backdrop()
		and m._hud.get_stop_intro_text() == "Afueras del Castillo"
		and (not m._hud.trixie_bubble.visible)
		and (not m._hud.customer_bubble.visible)
		and m.is_patience_paused()
		and wave_dock != null
		and wave_dock.get_visible_slot_count() == 2
		and wave_dock.get_slot_states() == [WaveDirector.SlotState.ACTIVE, WaveDirector.SlotState.PENDING]
	)
	if m._hud != null:
		m._hud.finish_stop_intro_now()
	var stop_intro_release_ok: bool = (
		m._hud != null
		and (not m._hud.is_stop_intro_visible())
		and m._hud.trixie_bubble.visible
		and m._hud.customer_bubble.visible
	)
	var ptxt: String = m._hud.customer_hud.get_patience_prefix_text() if (m._hud != null and m._hud.customer_hud != null) else ""
	var customer_hud_clean_copy_ok: bool = (
		m._hud != null
		and m._hud.customer_hud != null
		and m._hud.customer_hud.get_displayed_name() == "Sylvi"
		and m._hud.customer_hud.has_custom_name_font()
		and ptxt != ""
		and not ptxt.contains("Pausado")
		and not ptxt.contains("s")
		and m._hud.customer_hud.get_fill_ratio() > 0.95
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
	var witch_name_initial_ok: bool = (
		m._hud != null
		and m._hud.has_styled_witch_name()
		and m._hud.get_witch_name_text() == "Trixie"
	)
	st.active_witch_id = &"lyra"
	m._refresh_hud_labels()
	var witch_name_dynamic_ok: bool = (m._hud != null and m._hud.get_witch_name_text() == "Lyra")
	st.active_witch_id = &"trixie"
	m._refresh_hud_labels()
	var witch_name_hud_ok: bool = witch_name_initial_ok and witch_name_dynamic_ok and (m._hud != null and m._hud.get_witch_name_text() == "Trixie")

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
		and (m._hud.trixie_bubble.base_position.y + SpeechBubble.BODY_HEIGHT) < (c_center.y - CauldronBoard.ELLIPSE_RY)
	)

	# 1) Verify idle frame causes zero passive extraction AND tutorial pauses patience!
	var tube_before: float = w.potion_tube_pct
	var ess_before: int = m.essence_gold
	var pat_before: float = w.customer_patience_left
	m._process_cauldron_gameplay(5.0)
	var no_autoclicker_ok: bool = (w.potion_tube_pct == tube_before and m.essence_gold == ess_before)
	var tutorial_pauses_patience_ok: bool = (w.customer_patience_left == pat_before)

	# 2) Verify 3 hits break a tier-1 orb initially (advances basic tutorial 1 -> 2)
	var chem: Dictionary = m.get_customer_chemistry()
	var liked_k: int = int(chem["liked"])
	var disliked_k: int = int(chem["disliked"])

	b.orbs.clear()
	var red_orb: Dictionary = b.make_orb_dict(liked_k, c_center, 1)
	var red_id: int = int(red_orb["id"])
	b.orbs.append(red_orb)
	var h1_broke: bool = b.hit_orb_by_id(red_id, b.click_damage, true)
	var h2_broke: bool = b.hit_orb_by_id(red_id, b.click_damage, true)
	var hp_before_3: int = int(b.orbs[0]["hp"]) if b.orbs.size() == 1 else -1
	var h3_broke: bool = b.hit_orb_by_id(red_id, b.click_damage, true)
	var three_clicks_to_break_ok: bool = (not h1_broke and not h2_broke and hp_before_3 == 1 and h3_broke and w.potion_tube_pct > 15.0 and b.combo == 1)
	var tut_step_2_ok: bool = (m._tutorial.step == TutorialDirector.Step.BASIC_PURGE_DISLIKED)

	# 3) Verify lift-and-drop color combining & concentration mechanics
	b.orbs.clear()
	var mix_a: Dictionary = b.make_orb_dict(ChemistryRules.BubbleKind.RED, c_center + Vector2(-60, 0), 1)
	var mix_b: Dictionary = b.make_orb_dict(ChemistryRules.BubbleKind.GREEN, c_center + Vector2(60, 0), 1)
	b.orbs.append(mix_a)
	b.orbs.append(mix_b)
	var combined_color: bool = b.combine_orbs_by_id(int(mix_a["id"]), int(mix_b["id"]))
	var lift_combine_color_ok: bool = (combined_color and b.orbs.size() >= 1 and int(b.orbs[0]["kind"]) == ChemistryRules.BubbleKind.YELLOW and int(b.orbs[0]["hp"]) == CauldronBoard.BASE_ORB_HP)

	b.orbs.clear()
	var conc_a: Dictionary = b.make_orb_dict(ChemistryRules.BubbleKind.RED, c_center + Vector2(-60, 0), 1)
	var conc_b: Dictionary = b.make_orb_dict(ChemistryRules.BubbleKind.RED, c_center + Vector2(60, 0), 1)
	b.orbs.append(conc_a)
	b.orbs.append(conc_b)
	var combined_same: bool = b.combine_orbs_by_id(int(conc_a["id"]), int(conc_b["id"]))
	var lift_concentrate_ok: bool = (combined_same and b.orbs.size() == 1 and int(b.orbs[0]["kind"]) == ChemistryRules.BubbleKind.RED and int(b.orbs[0]["tier"]) == 2)

	# 4) Purge a Disliked orb with Right-click -> preserves combo & finishes basic tutorial immediately
	b.orbs.clear()
	var bad_p: Dictionary = b.make_orb_dict(disliked_k, c_center + Vector2(90, 0), 1)
	b.orbs.append(bad_p)
	b.purge_orb_by_id(int(bad_p["id"]))
	var purge_kept_combo: bool = (b.combo == 1 and w.potion_tube_pct > 15.0)
	var pat_pre_tick: float = w.customer_patience_left
	m.push_patience_pause(&"test_dialog")
	var lock_active_ok: bool = m.is_patience_paused()
	m._process_cauldron_gameplay(3.0)
	var lock_froze_patience_ok: bool = (w.customer_patience_left == pat_pre_tick)
	m.pop_patience_pause(&"test_dialog")
	var lock_released_ok: bool = not m.is_patience_paused()
	m._process_cauldron_gameplay(2.0)
	var patience_ticks_after_tut_ok: bool = (not m._tutorial.active and st.cauldron_basics_tutorial_done and w.customer_patience_left < pat_pre_tick)
	var patience_pause_lock_ok: bool = lock_active_ok and lock_froze_patience_ok and lock_released_ok and patience_ticks_after_tut_ok

	# 5) Break Disliked orb -> lowers tube, resets combo to 0, triggers nerviosa & customer impaciente
	b.orbs.clear()
	var bad_1: Dictionary = b.make_orb_dict(disliked_k, c_center, 1)
	bad_1["hp"] = 1
	b.orbs.append(bad_1)
	var tube_pre_bad: float = w.potion_tube_pct
	b.hit_orb_by_id(int(bad_1["id"]), 1, true)
	var disliked_lowered_tube: bool = w.potion_tube_pct < tube_pre_bad
	var disliked_reset_combo: bool = (b.combo == 0)
	var nerviosa_ok: bool = (m._trixie_emotion == "nerviosa")
	var cust_impaciente_ok: bool = (w.customer_emotion == "impaciente")

	# Second consecutive Disliked backfire -> triggers hollin
	b.orbs.clear()
	var bad_2: Dictionary = b.make_orb_dict(disliked_k, c_center, 1)
	bad_2["hp"] = 1
	b.orbs.append(bad_2)
	b.hit_orb_by_id(int(bad_2["id"]), 1, true)
	var hollin_triggered: bool = (m._trixie_emotion == "hollin")

	# 6) Break GOLD Star orb -> triggers sorprendida
	b.orbs.clear()
	var gold_o: Dictionary = b.make_orb_dict(ChemistryRules.BubbleKind.GOLD, c_center, 1)
	gold_o["hp"] = 1
	b.orbs.append(gold_o)
	b.hit_orb_by_id(int(gold_o["id"]), 1, true)
	var sorprendida_triggered: bool = (m._trixie_emotion == "sorprendida")

	# 7) Complete Sylvi's order -> Velvet arrives with mixed color order & JUST-IN-TIME MIX TUTORIAL pops and pauses time!
	b.orbs.clear()
	var finisher: Dictionary = b.make_orb_dict(liked_k, c_center, 3)
	finisher["hp"] = 1
	b.orbs.append(finisher)
	b.hit_orb_by_id(int(finisher["id"]), 1, true)
	m._refresh_hud_labels()
	var wave_mid_slots_ok: bool = (
		wave_dock != null
		and wave_dock.get_visible_slot_count() == 2
		and wave_dock.get_slot_states() == [WaveDirector.SlotState.SERVED, WaveDirector.SlotState.ACTIVE]
	)
	var mixed_order_velvet_ok: bool = (m.orders_completed >= 1 and w.active_customer != null and w.active_customer.customer_id == &"velvet" and ChemistryRules.is_mixed_kind(int(m.get_customer_chemistry()["liked"])))
	var mix_tut_started_ok: bool = (m._tutorial.active and m._tutorial.step == TutorialDirector.Step.MIX_DRAG_COMBINE)
	var v_pat_before: float = w.customer_patience_left
	m._process_cauldron_gameplay(4.0)
	var mix_tut_paused_ok: bool = (w.customer_patience_left == v_pat_before)

	# Complete the contextual mix tutorial by combining RED + BLUE -> PURPLE and breaking it
	var v_comps: Array[int] = ChemistryRules.get_recipe_components(int(m.get_customer_chemistry()["liked"]))
	b.orbs.clear()
	var vm_a: Dictionary = b.make_orb_dict(v_comps[0], c_center + Vector2(-50, 0), 1)
	var vm_b: Dictionary = b.make_orb_dict(v_comps[1], c_center + Vector2(50, 0), 1)
	b.orbs.append(vm_a)
	b.orbs.append(vm_b)
	b.combine_orbs_by_id(int(vm_a["id"]), int(vm_b["id"]))
	var mix_tut_step2_ok: bool = (m._tutorial.step == TutorialDirector.Step.MIX_BREAK_RESULT)
	b.orbs[0]["hp"] = 1
	b.hit_orb_by_id(int(b.orbs[0]["id"]), 1, true)
	var mix_tut_done_ok: bool = (not m._tutorial.active and st.mix_tutorial_done)

	# 8) Append temporary 3rd customer (&"seraphina") to test Frenzy + Velvet serve + Seraphina patience timeout
	w.wave_customers.append(&"seraphina")

	# Trigger Frenzy on Velvet -> sonrojada on both girls
	b.orbs.clear()
	var v_bad: Dictionary = b.make_orb_dict(int(m.get_customer_chemistry()["disliked"]), c_center, 1)
	b.orbs.append(v_bad)
	if b.frenzy_charge < 100.0:
		b.frenzy_charge = 100.0
	var frenzy_triggered: bool = m.try_activate_frenzy()
	var sonrojada_triggered: bool = (m._trixie_emotion == "sonrojada")
	var cust_sonrojada_ok: bool = (w.customer_emotion == "sonrojada")

	# Serve Velvet -> Seraphina arrives
	var v_liked: int = int(m.get_customer_chemistry()["liked"])
	b.orbs.clear()
	var v_fin: Dictionary = b.make_orb_dict(v_liked, c_center, 3)
	v_fin["hp"] = 1
	b.orbs.append(v_fin)
	b.hit_orb_by_id(int(v_fin["id"]), 1, true)
	var seraphina_arrived_ok: bool = (w.active_customer != null and w.active_customer.customer_id == &"seraphina" and w.wave_served_count == 2)

	# Drain Seraphina's patience -> customer leaves, missed count=1, combo=0, 2/3 served -> wave victory & closing dialogue!
	b.combo = 3
	w.customer_patience_left = 0.05
	m._process_cauldron_gameplay(0.2)
	var customer_timeout_advances_ok: bool = (seraphina_arrived_ok and w.wave_missed_count == 1 and b.combo == 0)
	m._refresh_hud_labels()
	var wave_end_slots_ok: bool = (
		wave_dock != null
		and wave_dock.get_visible_slot_count() == 3
		and wave_dock.get_slot_states() == [WaveDirector.SlotState.SERVED, WaveDirector.SlotState.SERVED, WaveDirector.SlotState.FAILED]
	)

	var end_triggered_gracefully: bool = w.round_ending and w.wave_victory and not w.closing_active
	w.round_end_timer = 0.0
	m._process_cauldron_gameplay(0.05)
	var closing_opened_ok: bool = w.closing_active and m._hud != null and m._hud.is_closing_visible() and (not m._hud.is_stop_intro_visible()) and (wave_dock != null and not wave_dock.visible) and w.closing_lines.size() == 1 and String(w.closing_lines[0].get("speaker", "")) == "trixie"

	for _step: int in range(10):
		if not w.closing_active or m._fading_out:
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
		var c_chem: Dictionary = ChemistryRules.roll_order_chemistry(&"sylvi", false, false, false, w.last_order_liked_kind)
		var lk: int = int(c_chem["liked"])
		var dk: int = int(c_chem["disliked"])
		w.last_order_liked_kind = lk
		rolled_kinds[lk] = true
		if ChemistryRules.is_mixed_kind(lk) and ChemistryRules.get_recipe_components(lk).has(dk):
			roll_valid = false
	var varied_customer_orders_ok: bool = (rolled_kinds.size() >= 2 and roll_valid)

	var mona_c: CustomerArchetypeData = w.find_customer_by_id(m.customers_catalog, &"mona")
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
		"top_hud_floating_ok": top_hud_base_ok and stop_intro_release_ok and wave_mid_slots_ok and wave_end_slots_ok,
		"customer_hud_ok": customer_hud_ok,
		"customer_hud_clean_copy_ok": customer_hud_clean_copy_ok,
		"witch_name_hud_ok": witch_name_hud_ok,
		"patience_pause_lock_ok": patience_pause_lock_ok,
		"all_halfbodies_distinct_ok": all_halfbodies_distinct_ok,
		"sylvi_halfbodies_distinct_ok": sylvi_halfbodies_distinct_ok,
		"velvet_halfbodies_distinct_ok": velvet_halfbodies_distinct_ok,
		"seraphina_halfbodies_distinct_ok": seraphina_halfbodies_distinct_ok,
		"mona_halfbodies_distinct_ok": mona_halfbodies_distinct_ok,
		"roxy_halfbodies_distinct_ok": roxy_halfbodies_distinct_ok,
		"cauldron_tutorial_flow_ok": tut_step_1_ok and banner_above_cauldron_ok and tut_step_2_ok and patience_ticks_after_tut_ok,
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
