class_name EndingScreen
extends Control
## Экран концовки: название, текст, число собранных заметок.

signal back

@onready var title: Label = $Center/Panel/Box/Title
@onready var body: Label = $Center/Panel/Box/Text


func _ready() -> void:
	$Center/Panel/Box/Back.pressed.connect(func() -> void: back.emit())


func open(t: String, text: String) -> void:
	title.text = t
	body.text = text
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.8)
