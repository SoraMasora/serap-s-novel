class_name TouchStick
extends Control
## Виртуальный джойстик (телефон): тянешь — сила в map_left/right/up/down, у края — бег.

const R := 95.0
const KNOB := 40.0
const DEAD := 0.18

var _down := false
var _vec := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(R * 2.0 + 40.0, R * 2.0 + 40.0)
	size = custom_minimum_size


func _center() -> Vector2:
	return size / 2.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_down = event.pressed
		_move(event.position if _down else _center())
		accept_event()
	elif event is InputEventMouseMotion and _down:
		_move(event.position)
		accept_event()


func _move(p: Vector2) -> void:
	_vec = (p - _center()) / R
	if _vec.length() > 1.0:
		_vec = _vec.normalized()
	_apply()
	queue_redraw()


func release() -> void:
	_down = false
	_vec = Vector2.ZERO
	_apply()
	queue_redraw()


func _apply() -> void:
	var v := _vec if _vec.length() > DEAD else Vector2.ZERO
	_axis("map_left", maxf(0.0, -v.x))
	_axis("map_right", maxf(0.0, v.x))
	_axis("map_up", maxf(0.0, -v.y))
	_axis("map_down", maxf(0.0, v.y))
	_axis("map_run", 1.0 if v.length() > 0.92 else 0.0)


func _axis(action: String, s: float) -> void:
	if s > 0.0:
		Input.action_press(action, s)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		release()


func _draw() -> void:
	var c := _center()
	var k := c + _vec * R
	draw_circle(c, R, Color(0.05, 0.04, 0.08, 0.38))
	draw_arc(c, R, 0.0, TAU, 64, Color(0.95, 0.55, 0.7, 0.55), 3.0, true)
	draw_circle(k, KNOB, Color(0.95, 0.6, 0.75, 0.6 if _down else 0.4))
	draw_arc(k, KNOB, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 2.0, true)
