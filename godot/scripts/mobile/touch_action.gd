class_name TouchAction
extends Button
## Captures one real touch independently of the joystick's finger.

signal activated(action_name: String)

@export var action := "map_interact"
var _finger := -1
var _held := false
var _mouse_down := false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	# Raw touch is handled in _input. Native Button mouse emulation must not
	# generate a second press/release for a different finger.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or disabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _finger == -1:
			var local: Vector2 = (
				get_global_transform_with_canvas().affine_inverse() * event.position
			)
			if not Rect2(Vector2.ZERO, size).has_point(local):
				return
			_finger = event.index
			_set_held(true)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _finger:
			_finger = -1
			_set_held(false)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var inside := Rect2(Vector2.ZERO, size).has_point(local)
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			if inside:
				get_viewport().set_input_as_handled()
			return
		if _finger != -1:
			return
		if event.pressed and inside:
			_mouse_down = true
			_set_held(true)
			get_viewport().set_input_as_handled()
		elif not event.pressed and _mouse_down:
			_mouse_down = false
			_set_held(false)
			get_viewport().set_input_as_handled()


func _set_held(down: bool) -> void:
	if down == _held:
		return
	_held = down
	set_pressed_no_signal(down)
	if down:
		Input.action_press(action)
		activated.emit(action)
	else:
		Input.action_release(action)


func release() -> void:
	_mouse_down = false
	_finger = -1
	_set_held(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		release()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		release()
	elif what == NOTIFICATION_EXIT_TREE:
		release()
