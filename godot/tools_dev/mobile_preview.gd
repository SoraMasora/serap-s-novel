extends SceneTree
## Mobile layout and real viewport-touch smoke. SERA_TOUCH=1, X11/OpenGL (not headless).

var _out := "/data/mobile/preview"
var _settings: Dictionary


func _init() -> void:
	call_deferred("_go")


func _shot(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out + "/" + label + ".png")


func _touch(id: int, pos: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = pos
	event.pressed = down
	root.push_input(event, true)


func _go() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	var game: Node = root.get_node("Game")
	_settings = game.settings.duplicate(true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	game.settings.cw = 1.0
	game.settings.speed = 0.0
	var main: Control = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	root.mode = Window.MODE_WINDOWED
	root.size = (
		Vector2i(1600, 720) if OS.get_environment("SERA_WIDE") == "1" else Vector2i(1280, 720)
	)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	await create_timer(0.8).timeout
	await _shot("01-title")
	main.title.hide()
	main.set_bg("dm_train", true)
	main.textbox.show()
	(
		main
		. textbox
		. show_line(
			"Сера",
			"sera",
			"Она стояла у самого края, за жёлтой линией. Обернулась ко мне — и улыбнулась. Я сделал шаг, но поезд уже заглушил её голос.",
			false,
			true
		)
	)
	await create_timer(0.3).timeout
	await _shot("02-dialogue")
	main.modal.open_settings(game.settings)
	await create_timer(0.3).timeout
	await _shot("03-settings")
	var close: Control = main.modal.settings_panel.get_node("Close")
	print(
		"MOBILE_LAYOUT settings_close=",
		close.get_global_rect(),
		" viewport=",
		root.get_visible_rect()
	)
	main.modal.close()
	main.textbox.hide()
	var runner := StoryRunner.new(game.db, game.config)
	runner.new_game("Кир")
	for i in 2000:
		var event: Dictionary = runner.step()[-1]
		if event.type == "map":
			break
		if event.type == "choice":
			runner.mark_choice_shown()
			runner.choose(event.options, 0)
		elif event.type == "breath":
			runner.breath_result(event.cfg, 1.0)
	main.pixel_map.open(runner.st.map)
	await create_timer(0.3).timeout
	var stick: TouchStick = main.pixel_map._stick
	var run: TouchAction = main.pixel_map._touch_run
	var start: float = main.pixel_map.pworld.hero.x
	_touch(0, stick.global_position + Vector2(170, 115), true)
	_touch(1, run.global_position + run.size / 2.0, true)
	await create_timer(0.25).timeout
	await _shot("04-map-touch")
	print(
		"TOUCH stick=", stick.get_global_rect(), " run=", run.get_global_rect(), " held=", run._held
	)
	assert(Input.is_action_pressed("map_right"), "real viewport joystick touch")
	assert(Input.is_action_pressed("mobile_run"), "second real finger holds run")
	assert(main.pixel_map.pworld.hero.x > start, "hero actually walks")
	await _shot("04-map-touch")
	_touch(1, run.global_position + run.size / 2.0, false)
	_touch(0, stick.global_position + Vector2(170, 115), false)
	await create_timer(0.1).timeout
	assert(not Input.is_action_pressed("map_right"))
	print(
		"RELEASE RUN own=",
		run._finger,
		" held=",
		run._held,
		" action=",
		Input.is_action_pressed("mobile_run")
	)
	assert(not Input.is_action_pressed("mobile_run"))
	main.modal.open_menu()
	await create_timer(0.2).timeout
	assert(not stick.visible)
	await _shot("05-menu")
	print("MOBILE_SMOKE PASS: viewport two-finger input, hero movement, release, menu blocking")
	game.settings = _settings
	main.queue_free()
	runner = null
	await process_frame
	await process_frame
	quit(0)
