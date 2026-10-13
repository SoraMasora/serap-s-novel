extends GutTest
## Логика сценария: tier/TV, условия, концовки, выбор, карта, откат.

var db: StoryDB
var cfg: GameConfig
var r: StoryRunner


func before_each() -> void:
	db = StoryDB.load_from()
	cfg = load("res://data/game_config.tres")
	r = StoryRunner.new(db, cfg)


func test_story_loaded() -> void:
	assert_eq(db.load_error, "")
	assert_eq(db.scenes.size(), 351, "число сцен как в веб-версии")
	assert_eq(db.notes_total, 61)


func test_all_targets_exist() -> void:
	var missing: Array = []
	for t in db.collect_targets():
		if not db.has_scene(t):
			missing.append(t)
	assert_eq(missing, [], "все переходы ведут в существующие сцены")


func test_all_conditions_parse_and_run() -> void:
	var n := 0
	for key: String in db.scenes:
		for c: Dictionary in db.scenes[key]:
			if c.has("when"):
				var e := Expression.new()
				assert_eq(e.parse(c.when, PackedStringArray(["feel", "press"])), OK, c.when)
				e.execute([50.0, 0.0], r, true)
				assert_false(e.has_execute_failed(), c.when)
				n += 1
	assert_eq(n, 88)


func test_tier_thresholds() -> void:
	r.st.feel = 39
	r.st.press = 0
	assert_eq(r.tier(), "cold")
	r.st.feel = 65
	assert_eq(r.tier(), "warm")
	r.st.press = 2
	assert_eq(r.tier(), "mid")
	r.st.press = 3
	assert_eq(r.tier(), "cold")
	r.st.feel = 50
	r.st.press = 0
	assert_eq(r.tv({"warm": "a", "mid": "b", "cold": "c"}), "b")
	assert_eq(r.tv({"warm": "a"}), null, "нет ключа тона и mid → null (строка пропускается)")


func test_pick_ending_matches_js_rules() -> void:
	var cases := [
		[90, 0, {"defended": true, "therapy": true, "expoYes": true, "sang": true}, "end_expo"],
		[85, 0, {"defended": true, "therapy": true, "expoYes": true}, "end_good"],
		[80, 0, {"defended": true, "therapy": true}, "end_good"],
		[60, 4, {}, "end_home"],
		[20, 0, {}, "end_home"],
		[35, 0, {}, "end_bad"],
		[60, 3, {}, "end_bad"],
		[60, 3, {"defended": true, "c3fled": true}, "end_letters"],
		[60, 0, {}, "end_neutral"],
	]
	for c: Array in cases:
		r.st.feel = c[0]
		r.st.press = c[1]
		r.st.flags = c[2]
		assert_eq(r.pick_ending(), c[3], str(c))


func test_first_line_and_card() -> void:
	var ev := r.step()
	assert_eq(ev[-1].type, "card")
	ev = r.step()
	assert_eq(ev[-1].type, "say")
	var types := ev.map(func(e: Dictionary) -> String: return e.type)
	assert_has(types, "bg")
	assert_has(types, "rain")
	assert_has(types, "music")
	assert_eq(r.st.bg, "street_rain")


func test_name_substitution() -> void:
	r.new_game("Аня")
	assert_eq(r.fmt("Привет, {P}!"), "Привет, Аня!")
	r.new_game("   ")
	assert_eq(r.st.name, "Кирилл")


func test_choice_applies_effects_and_react() -> void:
	var opts := [{"t": "a", "feel": 10, "set": {"x": true}, "go": "c1_store"}]
	r.mark_choice_shown()
	assert_eq(r.choose(opts, 0), "clap")
	assert_eq(r.st.feel, 60.0)
	assert_true(r.flag("x"))
	assert_eq(r.st.scene, "c1_store")
	assert_eq(r.choose([{"t": "b", "feel": -12, "go": "start"}], 0), "angry")
	assert_eq(r.choose([{"t": "c", "feel": 1, "go": "start"}], 0), "")


func test_map_visits_counter() -> void:
	r.jump("d1")
	var ev := r.step()
	assert_eq(ev[-1].type, "map")
	r.map_enter("store")
	assert_eq(r.st.flags.v_store, 1)
	assert_eq(r.st.scene, "store_1")
	assert_eq(r.st.map.done, ["store"])


func test_rollback_restores_notes_and_position() -> void:
	for _k in 12:
		r.step()
	var k := r.log.size() - 3
	var scene_at: String = r.log[k].s.scene
	assert_true(r.rollback(k))
	assert_eq(r.log.size(), k)
	assert_eq(r.st.scene, scene_at)


func test_breath_result() -> void:
	var b := {"flag": "plBreath", "feel": 4, "go": "start", "fail": "c1_store"}
	r.breath_result(b, 0.7)
	assert_true(r.flag("plBreath"))
	assert_eq(r.st.scene, "start")
	r.breath_result(b, 0.2)
	assert_false(r.flag("plBreath"))
	assert_eq(r.st.scene, "c1_store")


## v20: главы → месяцы; во 2 месяце нет «ни разу не уронил», Сера в магазине злится, а не плачет.
func test_months_and_m2_dialogue() -> void:
	var bad: Array = []
	for key: String in db.scenes:
		for c: Dictionary in db.scenes[key]:
			if c.has("chapter"):
				var ch := str(c.chapter)
				if not (ch.begins_with("Месяц ") or ch.begins_with("Концовка")):
					bad.append(ch)
	assert_eq(bad, [], "все главы названы «Месяц N · …» или «Концовка · …»")
	for key: String in ["m2_roof_a", "m2_roof_b", "m2_roof_c"]:
		assert_false(str(db.scenes[key]).contains("не уронил"), key)
	assert_false(str(db.scenes["m2_door"]).contains("shout"), "без плачущего крика")
	assert_false(str(db.scenes["m2_door_quiet"]).contains("мышь"), "клички появляются позже")


## 0.6: «Не курю» в Месяце 1 → в Месяце 2 на крыше чай, а не сигареты
func test_m2_nosmoke_roof_is_tea() -> void:
	r.st.flags = {"c3nosmoke": true}
	r.jump("m2_roof")
	r.step()
	assert_eq(r.st.bg, "m2_rt")
	r.st.flags = {}
	r.jump("m2_roof")
	r.step()
	assert_eq(r.st.bg, "bal_s0", "сначала прикуривание")
	r.step()
	assert_eq(r.st.bg, "m2_rx")


## 0.6: купленный вишнёвый чай можно отдать Сере ночью — отдельный CG m2_tea
func test_m2_cherry_tea_can_be_given() -> void:
	r.st.flags = {"m2cherry": true}
	r.jump("m2_tea_q")
	var ev := r.step()
	ev = r.step()
	assert_eq(ev[-1].type, "choice")
	r.mark_choice_shown()
	var f: float = r.st.feel
	r.choose(ev[-1].options, 0)
	assert_true(r.flag("m2tea"))
	assert_eq(r.st.feel, f + 4.0)
	assert_eq(r.st.scene, "m2_tea")
	r.step()
	assert_eq(r.st.bg, "m2_tea")


func test_choice_cg_assets_and_scene_coverage() -> void:
	var cg := ChoiceCGState.new()
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/assets_manifest.json")
	)
	var missing: Array = []
	for scene_id: String in cg.catalog:
		var key: String = cg.catalog[scene_id]
		if not db.has_scene(scene_id) or not manifest.bg.has(key):
			missing.append(scene_id)
		elif not FileAccess.file_exists(manifest.bg[key]):
			missing.append(key)
	assert_eq(cg.catalog.size(), 73)
	assert_eq(missing, [], "reply frames are available; story presentation unchanged")


func test_choice_cg_only_one_reply_after_choice() -> void:
	var cg := ChoiceCGState.new()
	assert_eq(cg.response("c1_room_good"), "", "ordinary dialogue has no frame")
	cg.arm()
	assert_eq(cg.response("c1_room_good"), "cg_c1_room_good")
	cg.clear()
	assert_eq(cg.key, "", "advance removes the temporary overlay")
	assert_eq(cg.response("c1_room_good"), "", "second line uses original scene")
	cg.arm()
	assert_eq(cg.response("start"), "", "location/router choices do not replace scenes")
	cg.restore_next = "cg_c1_room_good"
	assert_eq(cg.response("c1_room_good"), "cg_c1_room_good", "save restores reply frame")


func test_choice_cg_keeps_original_guarded_routes_and_stage() -> void:
	var cg := ChoiceCGState.new()
	r.st.scene = "c1_hand"
	r.st.feel = 90.0
	r.st.bg = "roof"
	r.st.chars = {"sera": {"expr": "soft", "pos": "center"}}
	cg.arm()
	r.step()
	assert_eq(cg.response(r.st.scene), "cg_c1_hand_ok")
	assert_eq(r.st.bg, "roof", "CG does not overwrite original background")
	assert_true(r.st.chars.has("sera"), "CG does not remove the original sprite")
	r.new_game("Кир")
	r.st.scene = "m2_roof_b"
	r.st.flags.c3nosmoke = true
	cg.arm()
	r.step()
	assert_eq(cg.response(r.st.scene), "cg_m2_roof_b_ns", "no-smoking route unchanged")


func test_reviewed_choices_have_no_frame() -> void:
	var cg := ChoiceCGState.new()
	var removed := [
		"c1_gift_hang",
		"c1_gift_joke",
		"c1_gift_keep",
		"c1_shift_joke",
		"c1_shift_honest",
		"c1_guests_ignore",
		"c1_roof_under",
		"c1_roof_aggr",
		"c3_ms_def",
		"c3_ms_stand",
		"c3_ms_doubt",
		"c3_q_soft",
		"c3_q_silent",
		"c3_panic_leave",
		"ch3_force",
		"m2_cold_knock"
	]
	for scene_id: String in removed:
		cg.arm()
		assert_eq(cg.response(scene_id), "", scene_id)
	cg.arm()
	assert_eq(cg.response("c1_guests_push"), "cg_c1_guests_push")


func test_cold_knock_has_separate_ending() -> void:
	r.st.scene = "m2_cold_knock"
	r.st.i = 0
	r.st.feel = 10.0
	var final_kind := ""
	for i in range(40):
		var events := r.step()
		if events[-1].type == "final":
			final_kind = events[-1].kind
			break
	assert_true(r.flag("m2closed"))
	assert_eq(final_kind, "closed", "closed door does not jump to father ending")
	assert_eq(r.pick_ending(), "end_closed")
