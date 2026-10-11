class_name PixelMap
extends Control
## Обёртка пиксельной прогулки: HUD (день, задача, кнопки), подписи, подсказка, мини-карта, ввод.

signal entered(id: String, pos: Dictionary)
signal item_picked
signal button_pressed(action: String)

const SIGN := preload("res://scenes/pixel/pixel_sign.tscn")
const CONFIG_PATH := "res://data/pixel_config.tres"

var pc: PixelConfig
var closeup_rect: TextureRect
var _base_task := ""
var _msg := ""
var _close_frames: Array[Texture2D] = []
var _close_t := 0.0
var _close_k := 0

@onready var view: SubViewportContainer = $View
@onready var pworld: PixelWorld = $View/Viewport/World
@onready var signs: Control = $Signs
@onready var day_label: Label = $Hud/Info/Day
@onready var task_label: Label = $Hud/Info/Task
@onready var prompt: Label = $Prompt
@onready var help: Label = $Help
@onready var mini: MiniMap = $Mini


func _ready() -> void:
	pc = load(CONFIG_PATH)
	visible = false
	help.text = pc.help_text
	pworld.entered.connect(_on_entered)
	pworld.said.connect(func(t: String) -> void: _msg = t)
	pworld.sfx_requested.connect(func(k: String) -> void: Audio.sfx(k))
	pworld.sfx_tuned.connect(func(k: String, v: float, p: float) -> void: Audio.sfx(k, v, p))
	pworld.item_picked.connect(
		func(n: int, total: int) -> void:
			task_label.text = "%s · %d/%d" % [_base_task, n, total]
			item_picked.emit()
	)
	pworld.ticked.connect(_on_tick)
	pworld.closeup.connect(show_closeup)
	closeup_rect = TextureRect.new()
	closeup_rect.name = "Closeup"
	closeup_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	closeup_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	closeup_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	closeup_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	closeup_rect.visible = false
	closeup_rect.gui_input.connect(
		func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed:
				hide_closeup()
	)
	add_child(closeup_rect)
	move_child(closeup_rect, view.get_index() + 1)
	view.gui_input.connect(_on_view_input)
	resized.connect(_fit)
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
	_fit()
	mini.setup(pworld)


## Пиксельный кадр 320×180 растягивается «с обрезкой», без чёрных полос на любом экране
func _fit() -> void:
	if pc == null:
		return
	var scr := Vector2(pc.screen)
	var k := maxf(size.x / scr.x, size.y / scr.y)
	view.size = scr
	view.scale = Vector2(k, k)
	view.position = ((size - scr * k) / 2.0).floor()


## Пиксельный крупный план: кадры closeup_<key>_0..N из godot/art/pixel, мир на паузе
func show_closeup(key: String, _text: String) -> void:
	_close_frames.clear()
	for i in 8:
		var t := Game.tex("pixel", "closeup_%s_%d" % [key, i])
		if t == null:
			break
		_close_frames.append(t)
	if _close_frames.is_empty():
		return
	_close_k = 0
	_close_t = 0.0
	closeup_rect.texture = _close_frames[0]
	closeup_rect.position = view.position
	closeup_rect.size = Vector2(pc.screen) * view.scale.x
	closeup_rect.visible = true
	closeup_rect.modulate.a = 0.0
	create_tween().tween_property(closeup_rect, "modulate:a", 1.0, 0.25)
	pworld.set_process(false)
	pworld.msg_t = maxf(pworld.msg_t, pc.say_seconds)
	signs.visible = false
	mini.visible = false
	help.visible = false


func hide_closeup() -> void:
	if not closeup_rect.visible:
		return
	var tw := create_tween()
	tw.tween_property(closeup_rect, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void: closeup_rect.visible = false)
	pworld.set_process(true)
	signs.visible = true
	mini.visible = true
	help.visible = true


func is_closeup() -> bool:
	return closeup_rect != null and closeup_rect.visible


func close() -> void:
	if closeup_rect:
		closeup_rect.visible = false
	signs.visible = true
	mini.visible = true
	help.visible = true
	pworld.set_process(true)
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


func _process(delta: float) -> void:
	if not visible:
		return
	if is_closeup():
		_close_t += delta
		if _close_t >= 0.22 and _close_frames.size() > 1:
			_close_t = 0.0
			_close_k = (_close_k + 1) % _close_frames.size()
			closeup_rect.texture = _close_frames[_close_k]
		prompt.text = _msg + "   ·   E — назад"
		prompt.visible = true
		return
	var k := view.scale.x
	for l: Label in signs.get_children():
		var x: float = l.get_meta("wx") - pworld.cam_x
		l.position.x = view.position.x + x * k - l.size.x / 2.0
		l.position.y = view.position.y + float(l.get_meta("wy")) * k
		l.visible = x > -30 and x < pc.screen.x + 30
	if pworld.msg_t > 0:
		prompt.text = _msg
		prompt.visible = true
	else:
		var n := pworld.near()
		if n != "":
			if n.begins_with("it"):
				prompt.text = "E · " + str(pworld.cfg.get("itemLabel", "Сорвать листовку"))
			else:
				var done: bool = n != "home" and pworld.cfg.done.has(n)
				prompt.text = "E · %s%s" % [pworld.spot_label(n), " (уже был)" if done else ""]
				if pworld.sitting:
					prompt.text = "W — вперёд · A — назад · E — встать"
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
	if is_closeup():
		if event.is_action_pressed("map_interact") or event.is_action_pressed("vn_menu"):
			get_viewport().set_input_as_handled()
			hide_closeup()
		return
	if event.is_action_pressed("map_interact"):
		get_viewport().set_input_as_handled()
		pworld.act(pworld.near())
