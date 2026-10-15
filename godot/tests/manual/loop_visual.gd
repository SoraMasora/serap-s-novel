extends SceneTree
## Optional visual QA: xvfb-run godot --path godot -s res://tests/manual/loop_visual.gd
## Writes screenshots only, without changing persistent loop memory.

var main: Control


func _initialize() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	for _i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/data/godot-shots/" + name + ".png")


func _run() -> void:
	var game: Node = root.get_node("Game")
	var backup: Dictionary = game.memory.data.duplicate(true)
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	await _shot("normal-title")
	game.memory.data.deaths = ["room", "store", "train", "cross", "road", "cliff"]
	game.memory.data.freed = false
	main.to_title()
	await _shot("loop-title")
	main.modal.open_settings(game.settings)
	await _shot("settings")
	main.modal.close()
	main.loop_overlay.warning()
	await _shot("warning")
	main.loop_overlay.kill()
	main.loop_overlay.sms({"time": "23:47", "from": "Сера", "text": "Прости."}, main.runner.fmt)
	await _shot("sms")
	main.loop_overlay.kill()
	main.loop_overlay.scream()
	await create_timer(0.65).timeout
	await _shot("screamer")
	main.loop_overlay.kill()
	game.memory.data = backup
	main.queue_free()
	await process_frame
	print("VISUAL QA screenshots saved")
	quit()
