extends SceneTree
## Dev (0.7.4): plays one loop death by itself, saves a PNG of every line and scream frame.
## Shows a death and a screamer variant without collecting 7 endings. From godot/:
##   godot --path . -s res://tools_dev/play_loop.gd -- --force=room --scare=title --dt=2.5
## --force=room|store|road|train|cross|cliff|neck  --scare=burst|lull|title|whisper|false
## --deaths=room,store (already seen; picks the variant when --scare is empty)  --soft=1
## --kind=good  --from=L_d_ (first scene to capture)  --dt=0.45  --sdt=0.07  --until=scream
## --out=user://loop_shots (or none). Loop memory, endings, seen lines and the auto slot are
## backed up first and restored on exit, so a real profile is not touched.

var _n := 0
var _out := "user://loop_shots"
var _backup := {}


func _init() -> void:
	call_deferred("_go")


func _arg(k: String, d: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--" + k + "="):
			return a.get_slice("=", 1)
	return d


func _shot(tag: String) -> void:
	if _out != "none":
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s/%03d_%s.png" % [_out, _n, tag])
	_n += 1


func _backup_user(paths: Array) -> void:
	for p: String in paths:
		_backup[p] = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else null


func _restore_user() -> void:
	for p: String in _backup:
		if _backup[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
			continue
		var f := FileAccess.open(p, FileAccess.WRITE)
		if f:
			f.store_buffer(_backup[p])
			f.close()


func _go() -> void:
	var save: Node = root.get_node("SaveSystem")
	_backup_user(
		[
			"user://serap_meta.json",
			"user://endings.json",
			"user://seen.json",
			save.slot_path("auto"),
		]
	)
	_out = _arg("out", "user://loop_shots")
	if _out != "none":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var game: Node = root.get_node("Game")
	game.settings.cw = 1.0
	game.settings.speed = 0.0
	game.settings.soft = float(_arg("soft", "0"))
	var deaths: Array = []
	for d: String in _arg("deaths", "").split(",", false):
		deaths.append(d)
	game.memory.data = {
		"deaths": deaths,
		"name": "Кир",
		"freed": false,
		"pending": null,
		"unlocked": true,
		"last_ending": ""
	}
	var main: Control = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await create_timer(0.5).timeout
	game.memory.finish(_arg("kind", "good"), "Кир")
	if _arg("force", "") != "":
		game.memory.data.pending.death = _arg("force", "")
	main.loop_overlay.scare_override = _arg("scare", "")
	print("PENDING ", game.memory.data.pending, " scare=", main.loop_overlay.pick_scare())
	main._start_death(true)
	await _play(main)
	print("DONE frames=", _n, " out=", ProjectSettings.globalize_path(_out))
	main.queue_free()
	_restore_user()
	quit(0)


func _play(main: Control) -> void:
	var dt := float(_arg("dt", "0.45"))
	var scream_dt := float(_arg("sdt", "0.07"))
	var start_scene := _arg("from", "")
	var started := start_scene == ""
	for _step in 1500:
		if main.title.visible and not main.loop_overlay.visible:
			await create_timer(0.6).timeout
			_shot("title")
			return
		if main.loop_overlay.visible and main.loop_overlay._locked:
			if _arg("until", "") == "scream":
				return
			await create_timer(scream_dt).timeout
			_shot("scream")
			continue
		if main.title.visible and main.loop_overlay.visible:
			await create_timer(dt).timeout
			_shot("ambush_wait")
			continue
		if main._whisper_armed:
			await create_timer(dt).timeout
			_shot("whisper")
			await create_timer(dt).timeout
			main.advance()
			continue
		await create_timer(dt).timeout
		var scene: String = str(main.runner.st.scene)
		if not started and scene.begins_with(start_scene):
			started = true
		if main.card.visible:
			if started:
				_shot("card_" + scene)
			main.card._close()
		elif main.loop_overlay.visible:
			if started:
				_shot("overlay_" + scene)
			main.loop_overlay._advance()
		elif main.textbox.visible:
			if main.textbox.typing:
				main.textbox.finish_typing()
				await create_timer(0.1).timeout
			if started:
				_shot(scene + "_" + str(main.runner.st.bg))
			main.advance()
