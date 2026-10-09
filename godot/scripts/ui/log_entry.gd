class_name LogEntry
extends Button
## Строка журнала: «Имя: текст ↺». С точкой отката — кликабельна.

signal chosen(index: int)

@export var thought_color := Color("#b9c8ec")
@export var choice_color := Color("#ff9fc0")

var index := -1


func setup(l: Dictionary, k: int) -> void:
	index = k
	var n := str(l.get("n", ""))
	text = ("%s: " % n if n != "" else "") + str(l.get("t", "")) + ("  ↺" if l.has("s") else "")
	disabled = not l.has("s")
	tooltip_text = "Вернуться к этому моменту" if l.has("s") else ""
	if l.get("th"):
		add_theme_color_override("font_color", thought_color)
	if l.get("ch"):
		add_theme_color_override("font_color", choice_color)
	pressed.connect(func() -> void: chosen.emit(index))
