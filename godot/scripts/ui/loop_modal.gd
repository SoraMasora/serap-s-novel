extends "res://scripts/ui/modal.gd"
## Extends the author's FancyPanel/fullscreen settings, without replacing them.


func _ready() -> void:
	super._ready()
	$Center/Panel/Panels/Settings/Soft.toggled.connect(
		func(on: bool) -> void: setting_changed.emit("soft", 1.0 if on else 0.0)
	)
	$Center/Panel/Panels/Settings/Forget.pressed.connect(func() -> void: menu_action.emit("forget"))
	$Center/Panel/Panels/ForgetMemory/Yes.pressed.connect(
		func() -> void: menu_action.emit("forget_confirm")
	)


func open_settings(s: Dictionary) -> void:
	super.open_settings(s)
	$Center/Panel/Panels/Settings/Soft.set_pressed_no_signal(bool(s.get("soft", 0.0)))


func open_notes(notes: Array, total: int) -> void:
	super.open_notes(notes, total)
	if Game.memory.level() == 0:
		return
	var heading: Label = NOTE_ITEM.instantiate()
	heading.text = "Что я видел · %d из 7" % Game.memory.level()
	notes_list.add_child(heading)
	for id: String in Game.memory.data.deaths:
		var it: Label = NOTE_ITEM.instantiate()
		it.text = "✝︎ " + str(Game.db.loop.DEATHS[id].m)
		notes_list.add_child(it)


func open_endings(got: Dictionary, endings: Dictionary) -> void:
	super.open_endings(got, endings)
	var progress: Label = NOTE_ITEM.instantiate()
	if Game.memory.data.freed:
		progress.text = "Истинный хороший финал пройден · игра без смертей Серы"
	elif not Game.memory.enabled():
		progress.text = (
			"Новая история · %d из 7 разных концовок" % Game.memory.base_ending_count(got)
		)
	else:
		progress.text = "Первый снег · %d из 7" % Game.memory.data.deaths.size()
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	endings_list.add_child(progress)


func open_forget() -> void:
	_show($Center/Panel/Panels/ForgetMemory)
