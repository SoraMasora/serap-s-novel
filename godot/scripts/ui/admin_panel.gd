class_name AdminPanel
extends CanvasLayer
## F9 opens a paused overlay. Closing restores the prior pause state.

const ROW := preload("res://scenes/ui/admin_ending_row.tscn")

var _was_paused := false
var _rows: Dictionary = {}

@onready var box: VBoxContainer = $Root/Center/Panel/Margin/Box
@onready var list: VBoxContainer = $Root/Center/Panel/Margin/Box/Scroll/List
@onready var status: Label = $Root/Center/Panel/Margin/Box/Status


func _ready() -> void:
	for kind: String in Game.db.endings:
		if kind == "truth":
			continue
		var row := ROW.instantiate() as CheckButton
		row.text = Game.db.endings[kind].title
		row.toggled.connect(func(on: bool) -> void: _set_ending(kind, on))
		list.add_child(row)
		_rows[kind] = row
	box.get_node("Truth").toggled.connect(func(on: bool) -> void: _set_ending("truth", on))
	box.get_node("Deaths/Minus").pressed.connect(func() -> void: _change_deaths(-1))
	box.get_node("Deaths/Plus").pressed.connect(func() -> void: _change_deaths(1))
	box.get_node("Buttons/All").pressed.connect(func() -> void: _all(true))
	box.get_node("Buttons/None").pressed.connect(func() -> void: _all(false))
	box.get_node("Buttons/Close").pressed.connect(close)
	Game.progress_changed.connect(refresh)
	refresh()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("admin_panel") and not event.is_echo():
		if Game.config.admin_panel_enabled:
			if visible:
				close()
			else:
				open()
			get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("vn_menu"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	refresh()
	show()
	box.get_node("Buttons/Close").grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = _was_paused


func refresh() -> void:
	var got := SaveSystem.endings()
	for kind: String in _rows:
		_rows[kind].set_pressed_no_signal(bool(got.get(kind, false)))
	box.get_node("Truth").set_pressed_no_signal(bool(got.get("truth", false)))
	box.get_node("Deaths/Count").text = "Память смертей: %d / 7" % Game.memory.data.deaths.size()
	status.text = (
		"Открыто: %d / 11 · цикл: %s"
		% [Game.memory.base_ending_count(got), "включён" if Game.memory.enabled() else "выключен"]
	)


func _result(err: Error) -> void:
	refresh()
	if err != OK:
		status.text = "Ошибка сохранения: " + error_string(err)
		push_error(status.text)


func _set_ending(kind: String, on: bool) -> void:
	_result(Game.admin_set_ending(kind, on))


func _change_deaths(delta: int) -> void:
	_result(Game.admin_set_deaths(Game.memory.data.deaths.size() + delta))


func _all(on: bool) -> void:
	for kind: String in Game.db.loop.BASE_ENDINGS:
		var err := Game.admin_set_ending(kind, on)
		if err != OK:
			_result(err)
			return
	_result(OK)
