class_name NameScreen
extends Control
## «Как тебя зовут?» — имя героя ({P}).

signal confirmed(player_name: String)

@onready var input: LineEdit = $Center/Panel/Box/Input


func _ready() -> void:
	$Center/Panel/Box/Ok.pressed.connect(_ok)
	input.text_submitted.connect(func(_t: String) -> void: _ok())


func open(max_len: int, placeholder: String) -> void:
	input.max_length = max_len
	input.placeholder_text = placeholder
	input.text = ""
	visible = true
	input.grab_focus()


func _ok() -> void:
	visible = false
	confirmed.emit(input.text.strip_edges())
