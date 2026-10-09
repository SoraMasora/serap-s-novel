class_name PixelMap
extends Control
## Обёртка пиксельной прогулки: HUD (день, задача, кнопки), подписи, подсказка, мини-карта, ввод.

signal entered(id: String, pos: Dictionary)
signal item_picked
signal button_pressed(action: String)

const SIGN := preload("res://scenes/pixel/pixel_sign.tscn")
const CONFIG_PATH := "res://data/pixel_config.tres"

var pc: PixelConfig
var _base_task := ""
var _msg := ""
var _prefix := "E · "

@onready var view: SubViewportContainer = $Frame/View
@onready var pworld: PixelWorld = $Frame/View/Viewport/World
@onready var signs: Control = $Frame/Signs
@onready var day_label: Label = $Hud/Info/Day
@onready var task_label: Label = $Hud/Info/Task
@onready var prompt: Label = $Prompt
@onready var help: Label = $Help
@onready var mini: MiniMap = $Mini
@onready var touch: PixelTouchControls = $Touch


func _ready() -> void:
	pc = load(CONFIG_PATH)
	visible = false
	_sync_touch(Mobile.touch)
	Mobile.touch_mode_changed.connect(_sync_touch)
	pworld.entered.connect(_on_entered)
	pworld.said.connect(func(t: String) -> void: _msg = t)
	pworld.sfx_requested.connect(func(k: String) -> void: Audio.sfx(k))
	pworld.item_picked.connect(
		func(n: int, total: int) -> void:
			task_label.text = "%s · %d/%d" % [_base_task, n, total]
			item_picked.emit()
	)
	pworld.ticked.connect(_on_tick)
	view.gui_input.connect(_on_view_input)
	for b: Button in $Hud/Buttons.get_children():
		b.pressed.connect(func() -> void: button_pressed.emit(String(b.name).to_lower()))


func open(m: Dictionary) -> void:
	visible = true
	_base_task = m.get("task", "")
	_msg = ""
	day_label.text = m.get("title", "")
	var left: int = int(m.visits) - m.done.size()
	if m.has("items"):
		task_label.text = "%s · %d/%d" % [_base_task, m.get("got", []).size(), m.items.size()]
	elif m.get("timer") != null:
		task_label.text = _base_task
	else:
		task_label.text = (
			"%s · осталось: %d" % [_base_task if _base_task != "" else "Куда пойти?", left]
		)
	task_label.remove_theme_color_override("font_color")
	pworld.open(m, pc)
	for c: Node in signs.get_children():
		c.queue_free()
	for s: Array in pc.signs.get(pworld.world, []):
		var l: Label = SIGN.instantiate()
		l.text = s[0]
		l.set_meta("wx", float(s[1]))
		l.set_meta("wy", float(s[2]))
		signs.add_child(l)
	mini.setup(pworld)


func _sync_touch(on: bool) -> void:
	help.text = Mobile.cfg.map_help_touch if on else pc.help_text
	if on:
		help.add_theme_font_size_override("font_size", Mobile.cfg.map_help_font_size)
		prompt.add_theme_font_size_override("font_size", Mobile.cfg.map_prompt_font_size)
	else:
		help.remove_theme_font_size_override("font_size")
		prompt.remove_theme_font_size_override("font_size")
	_prefix = Mobile.cfg.map_prompt_prefix_touch if on else "E · "


func close() -> void:
	touch.release_all()
	pworld.stop()
	visible = false


func is_open() -> bool:
	return visible and pworld.running


func current_pos() -> Dictionary:
	return {"x": pworld.hero.x, "y": pworld.hero.y}


func _on_entered(id: String) -> void:
	var pos := current_pos()
	visible = false
	entered.emit(id, pos)


func _on_tick(s: int) -> void:
	task_label.text = "%s · %d:%02d" % [_base_task, s / 60, s % 60]
	if s <= 15:
		task_label.add_theme_color_override("font_color", Color("#ff6b6b"))


func _process(_delta: float) -> void:
	if not visible:
		return
	var k := view.size.x / pc.screen.x
	for l: Label in signs.get_children():
		var x: float = l.get_meta("wx") - pworld.cam_x
		l.position.x = x * k - l.size.x / 2.0
		l.position.y = float(l.get_meta("wy")) / pc.screen.y * view.size.y
		l.visible = x > -30 and x < pc.screen.x + 30
	if pworld.msg_t > 0:
		prompt.text = _msg
		prompt.visible = true
	else:
		var n := pworld.near()
		if n != "":
			if n.begins_with("it"):
				prompt.text = _prefix + str(pworld.cfg.get("itemLabel", "Сорвать листовку"))
			else:
				var done: bool = n != "home" and pworld.cfg.done.has(n)
				prompt.text = (
					"%s%s%s" % [_prefix, pworld.spots()[n].label, " (уже был)" if done else ""]
				)
			prompt.visible = true
		else:
			prompt.visible = false
	mini.queue_redraw()


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pworld.click(event.position / (view.size / Vector2(pc.screen)))


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("map_interact"):
		get_viewport().set_input_as_handled()
		pworld.act(pworld.near())
