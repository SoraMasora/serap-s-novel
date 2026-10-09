class_name TouchQuickMenu
extends HBoxContainer
## Быстрое меню для пальцев (вместо мелкой строки «Авто · Пропуск · …» в окне реплик).
## Кнопки — инстансы quick_button.tscn, список действий — MobileConfig.quick_menu.

signal action(name: String)

const BUTTON := preload("res://scenes/mobile/quick_button.tscn")

var _btns: Dictionary = {}


func _ready() -> void:
	for c: Node in get_children():
		c.queue_free()
	for it: Array in Mobile.cfg.quick_menu:
		var b: Button = BUTTON.instantiate()
		var a := String(it[0])
		b.name = a.capitalize()
		b.text = String(it[1])
		b.toggle_mode = a == "auto" or a == "skip"
		b.pressed.connect(func() -> void: action.emit(a))
		add_child(b)
		_btns[a] = b


func set_toggle(a: String, on: bool) -> void:
	var b: Button = _btns.get(a)
	if b:
		b.set_pressed_no_signal(on)


func button(a: String) -> Button:
	return _btns.get(a)
