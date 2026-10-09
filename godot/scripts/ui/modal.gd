class_name Modal
extends Control
## Модальные окна: заметки, журнал (+откат), слоты, настройки, концовки, меню.
## Вся разметка — в modal.tscn; списки — инстансы маленьких сцен.

signal closed
signal rollback_confirmed(index: int)
signal slot_chosen(mode: String, slot: String)
signal setting_changed(key: String, value: float)
signal menu_action(action: String)

const NOTE_ITEM := preload("res://scenes/ui/note_item.tscn")
const LOG_ENTRY := preload("res://scenes/ui/log_entry.tscn")
const LOG_CHAPTER := preload("res://scenes/ui/log_chapter.tscn")

var _slots_mode := "save"
var _log_entries: Array = []
var _rb_index := -1

@onready var panels: Control = $Center/Panel/Panels
@onready var notes_panel: Control = $Center/Panel/Panels/Notes
@onready var notes_list: VBoxContainer = $Center/Panel/Panels/Notes/Scroll/List
@onready var notes_sub: Label = $Center/Panel/Panels/Notes/Sub
@onready var log_panel: Control = $Center/Panel/Panels/Log
@onready var log_scroll: ScrollContainer = $Center/Panel/Panels/Log/Scroll
@onready var log_list: VBoxContainer = $Center/Panel/Panels/Log/Scroll/List
@onready var confirm_panel: Control = $Center/Panel/Panels/Confirm
@onready var confirm_quote: Label = $Center/Panel/Panels/Confirm/Quote
@onready var slots_panel: Control = $Center/Panel/Panels/Slots
@onready var slots_title: Label = $Center/Panel/Panels/Slots/Title
@onready var slots_grid: GridContainer = $Center/Panel/Panels/Slots/Grid
@onready var settings_panel: Control = $Center/Panel/Panels/Settings
@onready var s_speed: HSlider = $Center/Panel/Panels/Settings/Speed/Slider
@onready var s_music: HSlider = $Center/Panel/Panels/Settings/Music/Slider
@onready var s_auto: HSlider = $Center/Panel/Panels/Settings/Auto/Slider
@onready var endings_panel: Control = $Center/Panel/Panels/Endings
@onready var endings_list: VBoxContainer = $Center/Panel/Panels/Endings/List
@onready var menu_panel: Control = $Center/Panel/Panels/Menu


func _ready() -> void:
	visible = false
	for p: Node in panels.get_children():
		var c := p.get_node_or_null("Close") as Button
		if c:
			c.pressed.connect(close)
	for b: Button in slots_grid.get_children():
		b.pressed.connect(
			func() -> void: slot_chosen.emit(_slots_mode, String(b.name).trim_prefix("Slot"))
		)
	s_speed.value_changed.connect(func(v: float) -> void: setting_changed.emit("speed", v))
	s_music.value_changed.connect(func(v: float) -> void: setting_changed.emit("music", v))
	s_auto.value_changed.connect(func(v: float) -> void: setting_changed.emit("auto_delay", v))
	$Center/Panel/Panels/Confirm/Buttons/Yes.pressed.connect(
		func() -> void: rollback_confirmed.emit(_rb_index)
	)
	$Center/Panel/Panels/Confirm/Buttons/No.pressed.connect(func() -> void: open_log(_log_entries))
	for b: Button in $Center/Panel/Panels/Menu/Buttons.get_children():
		b.pressed.connect(func() -> void: menu_action.emit(String(b.name).to_lower()))


func is_open() -> bool:
	return visible


func _show(panel: Control) -> void:
	for p: Control in panels.get_children():
		p.visible = p == panel
	visible = true


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func _clear(list: Node) -> void:
	for c: Node in list.get_children():
		c.queue_free()


func open_notes(notes: Array, total: int) -> void:
	_clear(notes_list)
	notes_sub.text = "%d из %d" % [notes.size(), total]
	if notes.is_empty():
		var it: Label = NOTE_ITEM.instantiate()
		it.text = "Пока я почти ничего о ней не знаю."
		it.modulate.a = 0.6
		notes_list.add_child(it)
	for n: String in notes:
		var it: Label = NOTE_ITEM.instantiate()
		it.text = "✝ " + n
		notes_list.add_child(it)
	_show(notes_panel)


func open_log(entries: Array) -> void:
	_log_entries = entries
	_clear(log_list)
	var ch := ""
	for k in entries.size():
		var l: Dictionary = entries[k]
		var c: String = l.get("s", {}).get("chapter", "")
		if c != "" and c != ch:
			ch = c
			var h: Label = LOG_CHAPTER.instantiate()
			h.text = c
			log_list.add_child(h)
		var b: LogEntry = LOG_ENTRY.instantiate()
		log_list.add_child(b)
		b.setup(l, k)
		b.chosen.connect(_confirm_rollback)
	if entries.is_empty():
		var it: Label = NOTE_ITEM.instantiate()
		it.text = "Пока пусто."
		log_list.add_child(it)
	_show(log_panel)
	await get_tree().process_frame
	log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)


func _confirm_rollback(k: int) -> void:
	var l: Dictionary = _log_entries[k]
	_rb_index = k
	confirm_quote.text = ("%s: " % l.n if str(l.get("n", "")) != "" else "") + str(l.t)
	_show(confirm_panel)


## infos: slot → {date, chapter} или {}
func open_slots(mode: String, infos: Dictionary) -> void:
	_slots_mode = mode
	slots_title.text = "Сохранить" if mode == "save" else "Загрузить"
	for b: Button in slots_grid.get_children():
		var k := String(b.name).trim_prefix("Slot")
		var d: Dictionary = infos.get(k, {})
		b.text = "Слот %s\n%s" % [k, ("%s\n%s" % [d.date, d.chapter]) if d else "— пусто —"]
		b.disabled = mode == "load" and d.is_empty()
	_show(slots_panel)


func open_settings(s: Dictionary) -> void:
	s_speed.set_value_no_signal(s.speed)
	s_music.set_value_no_signal(s.music)
	s_auto.set_value_no_signal(s.auto_delay)
	_show(settings_panel)


func open_endings(got: Dictionary, endings: Dictionary) -> void:
	_clear(endings_list)
	for k: String in endings:
		var it: Label = NOTE_ITEM.instantiate()
		it.text = ("✝ " + str(endings[k].title)) if got.get(k) else "??? — не открыта"
		it.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		endings_list.add_child(it)
	_show(endings_panel)


func open_menu() -> void:
	_show(menu_panel)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()
