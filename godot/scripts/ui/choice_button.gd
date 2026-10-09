class_name ChoiceButton
extends Button
## Вариант выбора: текст + подсказка мелким курсивом.

signal hovered(on: bool)

@onready var hint_label: Label = $Hint


func setup(label: String, hint: String) -> void:
	text = label
	hint_label.text = hint
	hint_label.visible = hint != ""
	if hint != "":
		custom_minimum_size.y = 64.0


func _ready() -> void:
	mouse_entered.connect(func() -> void: hovered.emit(true))
	mouse_exited.connect(func() -> void: hovered.emit(false))
