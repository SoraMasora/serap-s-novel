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
	assert_eq(db.scenes.size(), 234, "число сцен как в веб-версии")
	assert_eq(db.notes_total, 48)


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
	assert_eq(n, 50)


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
	assert_eq(r.choose(opts, 0), "shy")
	assert_eq(r.st.feel, 60.0)
	assert_true(r.flag("x"))
	assert_eq(r.st.scene, "c1_store")
	assert_eq(r.choose([{"t": "b", "feel": -12, "go": "start"}], 0), "shake")


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
