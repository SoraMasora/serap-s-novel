extends "res://scripts/ui/main.gd"
## Additive controller. Original 0.7.3 main.gd/CG cards/maps/input stay unchanged.

signal truth_exit_requested

@export var truth_exit_delay_sec := 6.0
## 0.7.4 · «whisper» screamer: silence before her line, and how long it waits for a click.
@export var whisper_pause_sec := 2.2
@export var whisper_timeout_sec := 9.0
## Outdoor loop CGs (snow + wind on top).
@export var loop_outdoor_bgs := PackedStringArray(
	[
		"d_road",
		"d_train",
		"d_cliff",
		"dm_road",
		"dm_train",
		"dm_cliff",
		"t_roof",
		"t_sky",
		"t_sky2",
		"t_hand",
		"t_angel"
	]
)

var _truth_closing := false
var _whisper_armed := false

@onready var loop_overlay: LoopOverlay = $LoopOverlay


func _connect_signals() -> void:
	super._connect_signals()
	truth_exit_requested.connect(_exit_application)
	ending.back.disconnect(to_title)
	ending.back.connect(_ending_back)
	loop_overlay.finished.connect(_resume_after_overlay)
	loop_overlay.death_finished.connect(_death_done)
	loop_overlay.ambush_finished.connect(_ambush_done)
	loop_overlay.warning_accepted.connect(_warning_accepted)


func to_title() -> void:
	if _truth_closing:
		return
	Game.refresh_loop_access()
	if Game.ensure_loop_entry():
		Game.save_memory()
	loop_overlay.kill()
	_disarm_whisper()
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
	if _truth_closing:
		return
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
			var kind := loop_overlay.pick_scare()
			if kind == "whisper":
				_whisper()
			else:
				loop_overlay.scream(kind)
		_:
			super._apply(event)


func _say(event: Dictionary) -> void:
	super._say(event)
	if event.name == "!":
		textbox.name_box.visible = false
		textbox.text.add_theme_color_override("default_color", Color(1.0, 0.16, 0.2))
		textbox.finish_typing()


func advance() -> void:
	if _whisper_armed:
		_whisper_hit()
	elif not loop_overlay.visible:
		super.advance()


## Her line in the ordinary dialogue box after the death — a line that is not in the log or saves.
func _whisper() -> void:
	var generation := _gen
	Audio.hush()
	await get_tree().create_timer(whisper_pause_sec).timeout
	if generation != _gen or not playing:
		return
	var scare: Dictionary = Game.db.loop.get("SCARE", {})
	_whisper_armed = true
	Audio.sfx("whisper")
	side.visible = false
	textbox.set_side_padding(false)
	textbox.controls.visible = false
	textbox.visible = true
	var line := runner.fmt(str(scare.get("whisper", "…Обернись.")))
	textbox.show_line("Сера", "sera", line, false, false)
	await get_tree().create_timer(whisper_timeout_sec).timeout
	if generation == _gen and _whisper_armed:
		_whisper_hit()


func _whisper_hit() -> void:
	_disarm_whisper()
	_hide_loop_text()
	loop_overlay.scream("whisper")


func _disarm_whisper() -> void:
	_whisper_armed = false
	textbox.controls.visible = true


func _on_typing_done() -> void:
	if _whisper_armed:
		return
	super._on_typing_done()


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
	if kind == "truth":
		if not Game.memory.truth():
			show_toast("Сначала открой 7 разных концовок и пройди ветку воспоминаний.")
			return
		var before := Game.memory.data.duplicate(true)
		Game.memory.finish(kind, runner.st.name)
		if Game.save_memory() != OK:
			Game.memory.data = before
			runner.st.i = maxi(0, int(runner.st.i) - 1)
			show_toast("Не удалось сохранить финал. Проверь доступ к папке сохранений.")
			return
		super.finish(kind)
		Game.save_seen()
		_truth_closing = true
		playing = false
		_gen += 1
		var text := "Прогресс сохранён. Следующий запуск — без смертей Серы."
		_after((ending_delay_sec + 0.1) * 1000.0, show_toast.bind(text))
		_after(
			maxf(truth_exit_delay_sec, ending_delay_sec + 0.2) * 1000.0,
			func() -> void: truth_exit_requested.emit()
		)
		return
	# Count distinct original endings AFTER the old game records the current ending.
	super.finish(kind)
	Game.refresh_loop_access()
	Game.memory.finish(kind, runner.st.name)
	Game.save_memory()


func _exit_application() -> void:
	get_tree().quit(0)


func _restore(snapshot: Dictionary) -> void:
	var scene: String = snapshot.get("scene", "")
	if not Game.memory.enabled() and (scene.begins_with("L_") or scene.begins_with("e_")):
		_reset_presentation()
		runner.new_game(snapshot.get("name", cfg.default_name))
		_present_state()
		show_toast(
			(
				"Ветка завершена. Можно играть дальше без смертей Серы."
				if Game.memory.data.freed
				else "Эта ветка откроется после 7 разных концовок основного сюжета."
			)
		)
		return
	super._restore(snapshot)


func _reset_presentation() -> void:
	loop_overlay.kill()
	_disarm_whisper()
	super._reset_presentation()


func _present_state() -> void:
	runner.memory = Game.memory
	runner.memory.sync(runner.st)
	_update_snow()
	super._present_state()


func _on_menu(action: String) -> void:
	if _truth_closing:
		return
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
	if loop_overlay.visible:
		return
	if _whisper_armed:
		# her line is not an ordinary line: no menu, notes or hidden UI — any advance lets her in
		if event.is_action_pressed("vn_advance") or event.is_action_pressed("vn_skip_hold"):
			get_viewport().set_input_as_handled()
			_whisper_hit()
		return
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
	if _truth_closing:
		return
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
	var ambush := loop_overlay.take_ambush()
	Game.memory.commit_death(runner.st.name)
	Game.save_memory()
	SaveSystem.delete_slot("auto")
	runner.st.snow = false
	to_title()
	if ambush:
		loop_overlay.ambush()


func _ambush_done() -> void:
	if title.visible:
		Audio.music("drone" if Game.memory.haunted() else "calm")


func _update_snow() -> void:
	var bg := str(runner.st.bg)
	var snowy := cfg.outdoor_bgs.has(bg) or loop_outdoor_bgs.has(bg)
	$LoopSnow.visible = bool(runner.st.get("snow", false)) and snowy
	Audio.wind($LoopSnow.visible)
