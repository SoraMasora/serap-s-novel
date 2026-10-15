extends "res://scripts/ui/main.gd"
## Additive controller. Original 0.7.1 main.gd/CG cards/maps/input stay unchanged.

@onready var loop_overlay: LoopOverlay = $LoopOverlay


func _connect_signals() -> void:
	super._connect_signals()
	ending.back.disconnect(to_title)
	ending.back.connect(_ending_back)
	loop_overlay.finished.connect(_resume_after_overlay)
	loop_overlay.death_finished.connect(_death_done)
	loop_overlay.warning_accepted.connect(_warning_accepted)


func to_title() -> void:
	loop_overlay.kill()
	$LoopSnow.visible = false
	in_choice = false
	runner.memory = Game.memory
	super.to_title()
	Audio.music("drone" if Game.memory.haunted() else "calm")
	Audio.wind(false)


func begin() -> void:
	runner.memory = Game.memory
	runner.memory.sync(runner.st)
	super.begin()


func _on_title_action(action: String) -> void:
	if action == "new":
		if Game.memory.haunted():
			show_toast("Начать заново нельзя. Я всё помню.")
		else:
			_guard_warning(action)
	elif action == "continue":
		_guard_warning(action)
	else:
		super._on_title_action(action)


func _apply(event: Dictionary) -> void:
	match event.type:
		"snow":
			_update_snow()
		"subl":
			if not skip:
				loop_overlay.subliminal(event.id)
		"sms":
			_hide_loop_text()
			var data: Dictionary = event.data.duplicate(true)
			data.text = Game.memory.text(data.text, runner.st)
			runner.log_push(
				{
					"n": "✉ " + str(data.get("from", "")),
					"t": str(data.text),
					"s": runner.snap_lite(-1)
				}
			)
			autosave()
			loop_overlay.sms(data, runner.fmt)
		"omen":
			_hide_loop_text()
			loop_overlay.omen(event.data, runner.fmt, skip)
		"montage":
			_hide_loop_text()
			loop_overlay.montage(Game.memory.data.deaths, skip)
		"scream":
			_hide_loop_text()
			auto = false
			skip = false
			_sync_btns()
			loop_overlay.scream()
		_:
			super._apply(event)


func _say(event: Dictionary) -> void:
	super._say(event)
	if event.name == "!":
		textbox.name_box.visible = false
		textbox.text.add_theme_color_override("default_color", Color(1.0, 0.16, 0.2))
		textbox.finish_typing()


func advance() -> void:
	if not loop_overlay.visible:
		super.advance()


func _on_choice(index: int) -> void:
	if not in_choice:
		return
	if Game.memory.truth() and index != Game.memory.best(_options, runner.st.scene):
		in_choice = false
		var button := choice_list.get_child(index) as ChoiceButton
		var refusals: Array = Game.db.loop.REFUSE
		var key := str(runner.st.scene) + ":" + str(index)
		var refusal: String = refusals[int(LoopMemory.hash_text(key) * refusals.size())]
		button.text = "× " + runner.fmt(_options[index].t) + "\n— " + refusal
		Audio.sfx("glitch")
		var generation := _gen
		await get_tree().create_timer(2.1).timeout
		if generation != _gen or not playing:
			return
		in_choice = true
	# The original selection/dismiss animations and one-response CG run unchanged.
	super._on_choice(index)


func _on_map_entered(id: String, pos: Dictionary) -> void:
	if Game.memory.truth() and id in ["__car", "__lazy", "__late"]:
		show_toast("Нет. Я обещал быть рядом. Я знаю дорогу.")
		runner.st.map.pos = pos
		open_map()
		return
	super._on_map_entered(id, pos)


func set_bg(key: String, instant: bool) -> void:
	super.set_bg(key, instant)
	_update_snow()


func finish(kind: String) -> void:
	if Game.memory.truth() and kind != "truth":
		runner.jump("L_truth")
		run()
		return
	Game.memory.finish(kind, runner.st.name)
	Game.save_memory()
	super.finish(kind)


func _reset_presentation() -> void:
	loop_overlay.kill()
	super._reset_presentation()


func _present_state() -> void:
	runner.memory = Game.memory
	runner.memory.sync(runner.st)
	_update_snow()
	super._present_state()


func _on_menu(action: String) -> void:
	match action:
		"forget":
			modal.open_forget()
		"forget_confirm":
			Game.forget_memory()
			runner.new_game(cfg.default_name)
			to_title()
		_:
			super._on_menu(action)


func _unhandled_input(event: InputEvent) -> void:
	if not loop_overlay.visible:
		super._unhandled_input(event)


func _hide_loop_text() -> void:
	waiting = false
	_gen += 1
	textbox.visible = false
	side.visible = false
	choices.visible = false


func _guard_warning(action: String) -> void:
	if Game.settings.cw:
		_continue_action(action)
	else:
		set_meta("warning_action", action)
		loop_overlay.warning()


func _warning_accepted() -> void:
	Game.set_setting("cw", 1.0)
	_continue_action(get_meta("warning_action", "continue"))


func _continue_action(action: String) -> void:
	if action == "new":
		super._on_title_action("new")
	elif SaveSystem.has_slot("auto"):
		load_slot("auto")
	elif Game.memory.data.pending != null:
		_start_death(true)
	elif Game.memory.haunted():
		runner.new_game(Game.memory.data.name if Game.memory.data.name != "" else cfg.default_name)
		_reset_presentation()
		begin()


func _ending_back() -> void:
	if Game.memory.data.pending == null or Game.memory.data.freed:
		to_title()
		return
	var generation := _gen
	ending.open("Нет.", "Это ещё не всё.")
	Audio.sfx("glitch")
	await get_tree().create_timer(2.3).timeout
	if generation == _gen:
		_start_death(false)


func _start_death(fresh: bool) -> void:
	var pending: Variant = Game.memory.data.pending
	if pending == null:
		return
	_reset_presentation()
	if fresh:
		runner.new_game(Game.memory.data.name if Game.memory.data.name != "" else cfg.default_name)
	runner.st.mode = ""
	runner.st.map = null
	runner.st.stack = []
	runner.st.flags.lend = pending.kind
	runner.st.flags.dth = pending.death
	runner.jump("L_after_" + str(pending.kind))
	begin()


func _death_done() -> void:
	Game.memory.commit_death(runner.st.name)
	Game.save_memory()
	SaveSystem.delete_slot("auto")
	runner.st.snow = false
	to_title()


func _update_snow() -> void:
	var snowy := cfg.outdoor_bgs.has(str(runner.st.bg))
	snowy = (
		snowy
		or (
			runner.st.bg
			in ["d_road", "d_train", "d_cliff", "t_roof", "t_sky", "t_sky2", "t_hand", "t_angel"]
		)
	)
	$LoopSnow.visible = bool(runner.st.get("snow", false)) and snowy
	Audio.wind($LoopSnow.visible)
