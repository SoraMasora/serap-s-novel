extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if not ok:
		push_error("QA FAILED: " + label)
		quit(1)
		assert(ok, label)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)

func _run() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var game = root.get_node("Game")
	var admin = root.get_node("Admin")
	_key(KEY_F9)
	await process_frame
	_check(admin.visible and paused, "F9 opens and pauses")
	for i in 7:
		_check(game.admin_set_ending(game.db.loop.BASE_ENDINGS[i], true) == OK, "grant ending")
	_check(game.memory.haunted(), "seven endings open loop entry")
	_check(main.title.get_node("Bar/New").disabled, "title refreshes to haunted")
	_check(game.admin_set_ending("truth", true) == OK, "grant truth")
	_check(not main.title.get_node("Bar/New").disabled, "truth frees title immediately")
	_check(game.admin_set_ending("truth", false) == OK, "remove truth")
	_check(game.memory.enabled(), "truth removal re-enables unlocked loop")
	main.modal.open_endings(root.get_node("SaveSystem").endings(), game.db.endings)
	_check(game.admin_set_ending("good", false) == OK, "remove while gallery open")
	main.modal.close()
	admin._all(false)
	_key(KEY_ESCAPE)
	await process_frame
	_check(not admin.visible and not paused, "Escape closes and resumes")
	_key(KEY_F9)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://admin_panel_qa.png")
	admin.close()
	print("RUNTIME_QA_PASS: physical F9/Esc, seven-ending gate, truth toggle, title/gallery refresh")
	quit()
