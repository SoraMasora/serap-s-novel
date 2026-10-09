extends GutTest
## Мобильная главная сцена: тема для пальцев, быстрое меню, «Назад», фон, карта на широком экране.

const MAIN := preload("res://scenes/main/main.tscn")

var main: Control
var _was_touch := false
var _win := Vector2i.ZERO
var _quits := true


func before_each() -> void:
	Engine.time_scale = 8.0
	_was_touch = Mobile.touch
	_win = get_tree().root.size
	Mobile.set_touch(true)
	_quits = Mobile.cfg.back_on_title_quits
	Mobile.cfg.back_on_title_quits = false  # «Назад» на титуле не должен закрыть прогон тестов
	SaveSystem.delete_slot("auto")
	main = MAIN.instantiate()
	add_child_autofree(main)
	await wait_process_frames(3)


func after_each() -> void:
	Engine.time_scale = 1.0
	Mobile.set_touch(_was_touch)
	Mobile.cfg.back_on_title_quits = _quits
	get_tree().root.size = _win


func _start() -> void:
	main._on_title_action("new")
	main.name_screen.input.text = "Тест"
	main.name_screen._ok()
	for _i in 100:
		if main.card.visible:
			main.card._close()
		if main.textbox.visible and main.waiting:
			break
		await wait_seconds(0.1)
	await wait_process_frames(2)


func test_touch_theme_and_quick_menu_replace_small_controls() -> void:
	assert_eq(main.theme, Mobile.cfg.touch_theme)
	assert_false(main.textbox.controls.visible, "мелкая строка кнопок скрыта")
	assert_false(main.quick.visible, "на титуле меню нет")
	await _start()
	assert_true(main.quick.visible, "быстрое меню во время реплик")
	assert_eq(main.quick.get_child_count(), Mobile.cfg.quick_menu.size())
	for b: Button in main.quick.get_children():
		assert_gte(b.get_combined_minimum_size().y, 80.0, "палец: высота кнопки ≥ 80 px холста")
	var dialogue: int = main.textbox.text.get_theme_font_size("normal_font_size")
	assert_gt(dialogue, 21, "шрифт реплик крупнее десктопного")


func test_quick_menu_toggles_auto_and_opens_log() -> void:
	await _start()
	main.quick.button("auto").pressed.emit()
	assert_true(main.auto)
	assert_true(main.quick.button("auto").button_pressed)
	main.quick.button("auto").pressed.emit()
	assert_false(main.auto)
	main.quick.button("log").pressed.emit()
	assert_true(main.modal.is_open())
	await wait_process_frames(1)
	assert_false(main.quick.visible, "под модальным окном меню скрыто")


func test_back_button_closes_modal_then_opens_menu() -> void:
	await _start()
	main.on_back()
	assert_true(main.modal.is_open(), "«Назад» в игре — меню")
	main.on_back()
	assert_false(main.modal.is_open(), "«Назад» в меню — закрыть")


func test_back_on_name_screen_returns_to_title() -> void:
	main._on_title_action("new")
	main.on_back()
	assert_true(main.title.visible)
	assert_false(main.name_screen.visible)


func test_app_pause_autosaves() -> void:
	await _start()
	SaveSystem.delete_slot("auto")
	Mobile.app_paused.emit()
	assert_true(SaveSystem.has_slot("auto"), "ушли в фон — автосейв")


func test_pixel_map_keeps_16_9_on_wide_phone() -> void:
	get_tree().root.size = Vector2i(2400, 1080)
	await wait_process_frames(3)
	var vis := get_viewport().get_visible_rect().size
	assert_almost_eq(vis.x / vis.y, 2400.0 / 1080.0, 0.01, "expand: холст на весь экран 20:9")
	main.runner.new_game("Тест")
	main.runner.jump("d1")
	main.begin()
	await wait_until(func() -> bool: return main.pixel_map.is_open(), 5.0)
	await wait_process_frames(3)
	var v: Vector2 = main.pixel_map.view.size
	assert_almost_eq(v.x / v.y, 16.0 / 9.0, 0.01, "карта 16:9 по центру")
	assert_eq(main.pixel_map.view.get_node("Viewport").size, Vector2i(320, 180))
	assert_true(main.pixel_map.touch.visible, "джойстик на карте")
	assert_false(main.quick.visible, "на карте свои кнопки")
