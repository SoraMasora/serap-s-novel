extends GutTest
## The original 234 scenes remain intact; the 88 new scenes form an additive loop.

var db: StoryDB
var r: StoryRunner


func before_each() -> void:
	db = StoryDB.load_from()
	r = StoryRunner.new(db, load("res://data/game_config.tres"))


func test_all_dynamic_dialogue_matches_original_js() -> void:
	var f := FileAccess.open("res://tests/fixtures/loop_text.json", FileAccess.READ)
	var cases: Array = JSON.parse_string(f.get_as_text())
	for c: Dictionary in cases:
		r.st.flags = c.flags
		var value: Variant = db.scene(c.scene)[int(c.index)].say[1]
		assert_eq(r.memory.text(value, r.st), c.expected, "%s:%d" % [c.scene, int(c.index)])


func test_seven_unique_deaths_for_every_ending() -> void:
	for kind: String in db.loop.PREF:
		var m := LoopMemory.new(db.loop)
		for n in 7:
			m.finish(kind, "Май")
			assert_not_null(m.data.pending)
			assert_false(m.data.deaths.has(m.data.pending.death))
			m.commit_death("Май")
			assert_eq(m.level(), n + 1)
		assert_true(m.truth())
		assert_eq(m.data.name, "Май")


func test_each_bridge_and_death_reaches_screamer() -> void:
	for kind: String in db.loop.PREF:
		for n in 7:
			r.new_game("Тест")
			r.memory.data.deaths = db.loop.ORDER.slice(0, n)
			r.memory.finish(kind, "Тест")
			r.memory.sync(r.st)
			r.st.flags.lend = kind
			r.st.flags.dth = r.memory.data.pending.death
			r.jump("L_after_" + kind)
			var seen_death := false
			var ending := ""
			for _i in 150:
				var e: Dictionary = r.step()[-1]
				if str(r.st.scene).begins_with("L_d_"):
					seen_death = true
				if e.type in ["scream", "stall", "final"]:
					ending = e.type
					break
			assert_true(seen_death, kind + ":" + str(n))
			assert_eq(ending, "scream", kind + ":" + str(n))
			r.memory.commit_death("Тест")
			assert_eq(r.memory.level(), n + 1)


func test_memory_survives_restore_and_rollback() -> void:
	var saved := r.save_snapshot()
	r.memory.data.deaths = ["room", "train", "cross"]
	r.restore(saved)
	assert_eq(r.st.flags.loop, 3)
	assert_true(r.st.flags.d_cross)
	r.log_push({"n": "", "t": "", "s": saved})
	assert_true(r.rollback(0))
	assert_eq(r.st.flags.loop, 3)
	assert_eq(r.memory.data.deaths.size(), 3)


func test_truth_forces_good_choices_and_removes_map_timer() -> void:
	r.memory.data.deaths = db.loop.ORDER.duplicate()
	r.new_game("Тест")
	for scene: String in db.scenes:
		for c: Dictionary in db.scenes[scene]:
			if not c.has("choice"):
				continue
			for i in c.choice.size():
				r.jump(scene)
				var best := r.memory.best(c.choice, scene)
				r.choose(c.choice, i)
				assert_eq(r.st.scene, c.choice[best].go, scene)
	# Find map commands from the real scenario rather than guessing a label.
	for scene: String in db.scenes:
		var commands: Array = db.scenes[scene]
		for i in commands.size():
			if commands[i].has("map") and commands[i].map.has("timer"):
				r.jump(scene)
				r.st.i = i
				var event: Dictionary = r.step()[-1]
				assert_eq(event.type, "map")
				assert_false(r.st.map.has("timer"))
	var play := AutoPlayer.new(r).play(42)
	assert_eq(play.ending, "truth", "full eighth loop reaches true ending")
	assert_eq(r.st.name, "Кирилл")


func test_truth_ending_frees_menu() -> void:
	r.memory.data.deaths = db.loop.ORDER.duplicate()
	r.memory.finish("truth", "Тест")
	assert_false(r.memory.haunted())
	assert_eq(r.memory.level(), 0)
	assert_null(r.memory.data.pending)


func test_truth_cannot_fail_breathing_or_end_badly() -> void:
	r.memory.data.deaths = db.loop.ORDER.duplicate()
	r.new_game("Тест")
	r.breath_result({"flag": "plBreath"}, 0.0)
	assert_true(r.st.flags.plBreath)
	for seed in 200:
		var play := AutoPlayer.new(r).play(seed + 1)
		assert_eq(play.ending, "truth", "eighth loop seed %d" % seed)
