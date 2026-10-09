class_name TouchActionButton
extends Control
## Сенсорная кнопка действия InputMap с поддержкой мультитача (можно держать вместе с джойстиком).
## hold = true — действие зажато, пока палец на кнопке (бег);
## false — одно нажатие через InputEventAction, поэтому срабатывают и _unhandled_input-обработчики
## (например, «войти» на карте).

signal triggered

@export var action := &"map_interact"
@export var hold := false
@export var text := "E":
	set(v):
		text = v
		if is_node_ready():
			$Face/Label.text = v

var _index := -1
var _tw: Tween

@onready var face: Control = $Face


func _ready() -> void:
	$Face/Label.text = text
	visibility_changed.connect(_on_visibility)


func _on_visibility() -> void:
	if not is_visible_in_tree():
		_up()


func is_down() -> bool:
	return _index != -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _index == -1:
			_index = t.index
			_down()
		elif not t.pressed and t.index == _index:
			_up()
		accept_event()
	elif event is InputEventScreenDrag or event is InputEventMouse:
		accept_event()


func _down() -> void:
	_anim(0.9, Color(1.35, 0.85, 1.0))
	if hold:
		Input.action_press(action)
	else:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = true
		Input.parse_input_event(e)
		var r := InputEventAction.new()
		r.action = action
		r.pressed = false
		Input.parse_input_event(r)
	triggered.emit()


func _up() -> void:
	if _index == -1:
		return
	_index = -1
	_anim(1.0, Color.WHITE)
	if hold and Input.is_action_pressed(action):
		Input.action_release(action)


func _anim(s: float, c: Color) -> void:
	if not is_inside_tree():
		return
	if _tw:
		_tw.kill()
	face.pivot_offset = face.size / 2.0
	_tw = create_tween().set_parallel()
	_tw.tween_property(face, "scale", Vector2(s, s), 0.08)
	_tw.tween_property(face, "modulate", c, 0.08)
