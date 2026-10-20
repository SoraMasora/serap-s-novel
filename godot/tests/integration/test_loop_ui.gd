extends GutTest
## Exercise the actual Godot presentation, not only the pure runner.

const MAIN := preload("res://scenes/main/main.tscn")

var main: Control
var _memory: Dictionary
var _settings: Dictionary
var _endings: Dictionary


func before_each() -> void:
	_memory = Game.memory.data.duplicate(true)
	_settings = Game.settings.duplicate(true)
	_endings = SaveSystem.endings()
	SaveSystem.write_atomic(SaveSystem.ENDINGS_PATH, "{}")
	Game.memory.data = {
		"deaths": [], "name": "Тест", "freed": false, "pending": null, "unlocked": true
	}
	Game.settings.cw = 1.0
	Game.settings.speed = 0.0
	SaveSystem.delete_slot("auto")
	Engine.time_scale = 16.0
	main = MAIN.instantiate()
	add_child_autofree(main)
	await wait_process_frames(3)


func after_each() -> void:
	main.loop_overlay.kill()
	Game.memory.data = _memory
	Game.settings = _settings
	SaveSystem.write_atomic(SaveSystem.ENDINGS_PATH, JSON.stringify(_endings))
	Game.save_memory()
	SaveSystem.delete_slot("auto")
	Engine.time_scale = 1.0


func test_warning_requires_acknowledgement() -> void:
	Game.settings.cw = 0.0
	main._on_title_action("new")
	assert_true(main.loop_overlay.visible)
	assert_false(main.name_screen.visible)
	main.loop_overlay._advance()
	assert_true(main.name_screen.visible)
	assert_eq(Game.settings.cw, 1.0)


func test_haunted_menu_and_continue_without_auto_save() -> void:
	Game.memory.data.deaths = ["room", "road"]
	main.to_title()
	assert_true(main.title.get_node("Bar/New").disabled)
	assert_eq(main.title.btn_continue.text, "ПРОДОЛЖИТЬ!")
	assert_false(main.title.btn_continue.disabled)
	assert_true(main.title.get_node("Frames/te").visible)
	main._on_title_action("continue")
	assert_eq(main.runner.st.name, "Тест")
	assert_eq(main.runner.st.flags.loop, 2)
	assert_false(main.title.visible)


func test_pending_ending_survives_restart() -> void:
	Game.memory.finish("letters", "Май")
	Game.save_memory()
	var loaded := LoopMemory.new(Game.db.loop)
	loaded.data.merge(SaveSystem.read_json(LoopMemory.PATH), true)
	assert_eq(loaded.data.pending.kind, "letters")
	assert_eq(loaded.data.pending.death, "room")
	Game.memory.data = loaded.data
	main.to_title()
	main._on_title_action("continue")
	assert_eq(main.runner.st.scene, "L_after_letters")
	assert_eq(main.runner.st.flags.dth, "room")
	assert_eq(main.runner.st.name, "Май")


func test_actual_death_screamer_returns_to_locked_title() -> void:
	Game.memory.finish("good", "Тест")
	main._start_death(true)
	for _i in 500:
		if main.title.visible:
			break
		if main.card.visible:
			main.card._close()
		elif main.loop_overlay.visible:
			main.loop_overlay._advance()
		elif main.textbox.visible:
			main.advance()
		await wait_seconds(0.02)
	assert_true(main.title.visible)
	assert_eq(Game.memory.data.deaths, ["train"])
	assert_null(Game.memory.data.pending)
	assert_false(SaveSystem.has_slot("auto"))
	assert_true(main.title.get_node("Bar/New").disabled)


func test_soft_mode_and_overlay_cancel_on_restore() -> void:
	Game.settings.soft = 1.0
	main.loop_overlay.subliminal("room")
	assert_false(main.loop_overlay.visible)
	main.loop_overlay.scream()
	await wait_seconds(0.7)
	assert_true(main.loop_overlay.image.visible)
	assert_false(main.loop_overlay.image.flip_h)
	assert_false(main.loop_overlay.image.flip_v)
	main.to_title()
	await wait_seconds(5.0)
	assert_false(main.loop_overlay.visible)
	assert_eq(Game.memory.data.deaths, [])


func test_existing_manual_save_survives_forgetting() -> void:
	main.runner.new_game("Май")
	SaveSystem.save_slot("loop_test", main.runner.save_snapshot(), [])
	Game.memory.data.deaths = ["neck"]
	Game.forget_memory()
	assert_true(SaveSystem.has_slot("loop_test"))
	assert_eq(Game.memory.level(), 0)
	SaveSystem.delete_slot("loop_test")


func test_original_title_button_design_is_preserved() -> void:
	for button: Button in main.title.get_node("Bar").get_children():
		assert_eq(button.theme_type_variation, &"VineButton")
		assert_eq(button.modulate, Color.WHITE)
		assert_false(button.has_theme_stylebox_override("normal"))
		assert_false(button.has_theme_stylebox_override("hover"))
	Game.memory.data.deaths = ["room"]
	main.to_title()
	assert_eq(main.title.btn_continue.modulate, Color.WHITE, "original frame is not tinted")
	Game.memory.data.deaths = []
	main.to_title()
	assert_eq(main.title.btn_continue.text, "Продолжить")
	assert_false(main.title.btn_continue.has_theme_color_override("font_color"))
