class_name ChapterCard
extends Control
## Карточка главы: проявляется, ждёт 3 с или клик, гаснет (showCard).

signal finished

@export var fade_sec := 0.6

var _open := false

@onready var big: Label = $Box/Big
@onready var small: Label = $Box/Small


func show_card(big_text: String, small_text: String, hold_ms: float) -> void:
	big.text = big_text
	small.text = small_text
	visible = true
	_open = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, fade_sec)
	get_tree().create_timer(hold_ms / 1000.0).timeout.connect(_close)


func _close() -> void:
	if not _open:
		return
	_open = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, fade_sec)
	tw.tween_callback(
		func() -> void:
			visible = false
			finished.emit()
	)


func kill() -> void:
	_open = false
	visible = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_close()
