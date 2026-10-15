extends GutTest
## Дымовой тест главной сцены: титул → имя → прохождение в режиме пропуска с выборами,
## картой и дыханием до экрана концовки; затем «Продолжить» из автосейва.

const MAIN := preload("res://scenes/main/main.tscn")

var main: Control
var _memory_backup: Dictionary
var _settings_backup: Dictionary
var _endings_backup: Dictionary


func before_each() -> void:
	_memory_backup = Game.memory.data.duplicate(true)
	_settings_backup = Game.settings.duplicate(true)
	_endings_backup = SaveSystem.endings()
	SaveSystem.write_atomic(SaveSystem.ENDINGS_PATH, "{}")
	Game.settings.cw = 1.0
	Game.settings.speed = 0.0
	Game.memory.data = {
		"deaths": [], "name": "", "freed": false, "pending": null, "unlocked": false
	}
	Engine.time_scale = 8.0
	SaveSystem.delete_slot("auto")
	main = MAIN.instantiate()
	add_child_autofree(main)
	await wait_process_frames(3)


func after_each() -> void:
	Game.memory.data = _memory_backup
	Game.settings = _settings_backup
	SaveSystem.write_atomic(SaveSystem.ENDINGS_PATH, JSON.stringify(_endings_backup))
	Game.save_memory()
	Engine.time_scale = 1.0


func _drive(max_iters: int) -> Dictionary:
	var stats := {"lines": 0, "choices": 0, "maps": 0, "breaths": 0, "ending": false}
	for _n in max_iters:
		if main.ending.visible:
			stats.ending = true
			break
		if main.choices.visible:
			var btns: Array = main.choice_list.get_children().filter(
				func(b: Node) -> bool: return not b.is_queued_for_deletion()
			)
			(btns[0] as Button).pressed.emit()
			stats.choices += 1
		elif main.pixel_map.visible and main.pixel_map.is_open():
			var w: PixelWorld = main.pixel_map.pworld
			if w.cfg.has("items"):
				w.stop()
				w.entered.emit("__items")
			else:
				for s: String in w.cfg.spots:
					if not w.cfg.done.has(s):
						w.act(s)
						break
			stats.maps += 1
		elif main.breath.visible:
			stats.breaths += 1
		elif main.textbox.visible:
			if not main.textbox.typing and main.waiting:
				stats.lines += 1
			main.advance()
		await wait_seconds(0.02)
	return stats


func test_title_shown_first() -> void:
	assert_true(main.title.visible)
	assert_false(main.textbox.visible)


func test_new_game_shows_card_then_text() -> void:
	main._on_title_action("new")
	assert_true(main.name_screen.visible)
	main.name_screen.input.text = "Тест"
	main.name_screen._ok()
	assert_true(main.card.visible, "карточка главы")
	main.card._close()
	await wait_until(func() -> bool: return main.textbox.visible, 5.0)
	assert_true(main.textbox.visible)
	assert_ne(main.textbox.text.text, "")
	assert_eq(main.runner.st.name, "Тест")


func test_playthrough_reaches_an_ending() -> void:
	main._on_title_action("new")
	main._on_name("Тест")
	main.skip = true
	var stats := await _drive(6000)
	gut.p("Прогон: " + str(stats))
	assert_true(stats.ending, "дошли до концовки")
	assert_gt(stats.choices, 5)
	assert_gt(stats.maps, 0)
	assert_false(SaveSystem.has_slot("auto"), "автосейв удалён после финала")


func test_continue_from_autosave() -> void:
	main._on_title_action("new")
	main._on_name("Тест")
	await _drive(40)
	var at: String = main.runner.st.scene
	assert_true(SaveSystem.has_slot("auto"))
	main.to_title()
	main._on_title_action("continue")
	await wait_process_frames(2)
	assert_eq(main.runner.st.scene, at)
	assert_false(main.title.visible)


func test_reply_frame_never_changes_original_story_state() -> void:
	var cg := ChoiceCGState.new()
	var failures: Array = []
	main.skip = true
	for scene_id: String in cg.catalog:
		main.runner.new_game("Кир")
		main.runner.st.scene = scene_id
		main.runner.st.bg = "room"
		main.runner.st.chars = {"sera": {"expr": "neutral", "pos": "center"}}
		main.runner.st.feel = 0.0 if scene_id in ["c1_hand", "c1_hug"] else 60.0
		if scene_id == "m2_roof_b_ns":
			main.runner.st.flags.c3nosmoke = true
		var baseline := StoryRunner.new(Game.db, Game.config)
		baseline.st = main.runner.st.duplicate(true)
		baseline.step()
		main._choice_cg.arm()
		main.begin()
		if not main.choice_cg_frame.visible or main.runner.st != baseline.st:
			failures.append(scene_id)
	assert_eq(
		failures, [], "Active frames do not change bg, camera commands, characters or story state"
	)


func test_reply_frame_advances_to_original_and_restores_from_save() -> void:
	main.runner.new_game("Кир")
	main.runner.st.bg = "room"
	main.runner.st.chars = {"sera": {"expr": "cold", "pos": "center"}}
	main._options = [{"t": "Ответ", "go": "c1_room_good"}]
	main.in_choice = true
	main.skip = true
	main.playing = true
	main._on_choice(0)
	assert_true(main.choice_cg_frame.visible, "actual dialogue-choice handler shows a frame")
	assert_eq(main.runner.st.bg, "room")
	var saved: Dictionary = main.runner.save_snapshot()
	saved["presentation_cg"] = main._choice_cg.key
	main.run()
	assert_false(main.choice_cg_frame.visible, "next response uses original scene")
	assert_true(main.runner.st.chars.has("sera"))
	main._restore(saved)
	assert_true(main.choice_cg_frame.visible, "save restores the reply overlay")
	assert_false(
		main.runner.st.has("presentation_cg"), "presentation data stays outside story state"
	)
	main.run()
	assert_false(main.choice_cg_frame.visible, "overlay remains one line after load")
