extends GutTest
## Дымовой тест главной сцены: титул → имя → прохождение в режиме пропуска с выборами,
## картой и дыханием до экрана концовки; затем «Продолжить» из автосейва.

const MAIN := preload("res://scenes/main/main.tscn")

var main: Control


func before_each() -> void:
	Engine.time_scale = 8.0
	SaveSystem.delete_slot("auto")
	main = MAIN.instantiate()
	add_child_autofree(main)
	await wait_process_frames(3)


func after_each() -> void:
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
