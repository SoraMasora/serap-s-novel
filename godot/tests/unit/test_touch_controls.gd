extends GutTest
## Сенсорное управление прогулкой: джойстик (встроенный VirtualJoystick) и кнопки действий.

const CONTROLS := preload("res://scenes/mobile/pixel_touch_controls.tscn")

var tc: PixelTouchControls
var vp: SubViewport
var _was_touch := false


func before_each() -> void:
	_was_touch = Mobile.touch
	Mobile.set_touch(true)
	# Отдельный SubViewport: касания идут через его GUI, как на телефоне, без оверлеев раннера GUT
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	add_child_autofree(vp)
	tc = CONTROLS.instantiate()
	vp.add_child(tc)
	tc.position = Vector2.ZERO
	tc.size = Vector2(1280, 720)
	await wait_process_frames(2)


func after_each() -> void:
	tc.release_all()
	Mobile.set_touch(_was_touch)


func _touch(pos: Vector2, pressed: bool, index := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	vp.push_input(e)


func _drag(pos: Vector2, rel: Vector2, index := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = rel
	vp.push_input(e)


func test_visible_only_in_touch_mode() -> void:
	assert_true(tc.visible)
	Mobile.set_touch(false)
	assert_false(tc.visible)
	Mobile.set_touch(true)
	assert_true(tc.visible)


func test_joystick_drag_right_walks_right_and_release_stops() -> void:
	var j := tc.joystick.get_global_rect()
	var p := j.position + j.size * Vector2(0.4, 0.6)
	_touch(p, true)
	_drag(p + Vector2(90, 0), Vector2(90, 0))
	await wait_process_frames(1)
	assert_gt(Input.get_axis("map_left", "map_right"), 0.5, "вправо")
	assert_almost_eq(Input.get_axis("map_up", "map_down"), 0.0, 0.05)
	_touch(p + Vector2(90, 0), false)
	await wait_process_frames(1)
	assert_eq(Input.get_axis("map_left", "map_right"), 0.0, "палец убран — стоим")


func test_run_button_holds_while_second_finger_moves_joystick() -> void:
	var r := tc.run.get_global_rect().get_center()
	var j := tc.joystick.get_global_rect()
	var p := j.position + j.size * Vector2(0.4, 0.6)
	_touch(r, true, 1)
	_touch(p, true, 0)
	_drag(p + Vector2(0, -90), Vector2(0, -90), 0)
	await wait_process_frames(1)
	assert_true(Input.is_action_pressed("map_run"), "бег зажат вторым пальцем")
	assert_lt(Input.get_axis("map_up", "map_down"), -0.5, "вверх")
	_touch(r, false, 1)
	await wait_process_frames(1)
	assert_false(Input.is_action_pressed("map_run"))
	_touch(p, false, 0)


func test_act_button_fires_interact_event() -> void:
	watch_signals(tc.act)
	var seen := [false]
	var probe := _Probe.new()
	probe.hit.connect(func() -> void: seen[0] = true)
	add_child_autofree(probe)  # в основном дереве: Input.parse_input_event идёт в корневой вьюпорт
	_touch(tc.act.get_global_rect().get_center(), true)
	await wait_process_frames(2)
	_touch(tc.act.get_global_rect().get_center(), false)
	assert_signal_emitted(tc.act, "triggered")
	assert_true(seen[0], "InputEventAction map_interact дошёл до _unhandled_input")


func test_release_all_unsticks_hidden_joystick() -> void:
	var j := tc.joystick.get_global_rect()
	var p := j.position + j.size * Vector2(0.4, 0.6)
	_touch(p, true)
	_drag(p + Vector2(-90, 0), Vector2(-90, 0))
	await wait_process_frames(1)
	assert_lt(Input.get_axis("map_left", "map_right"), -0.5)
	tc.visible = false
	await wait_process_frames(1)
	assert_eq(Input.get_axis("map_left", "map_right"), 0.0, "скрыли — отпустили")
	tc.visible = true
	_touch(p, true)
	_drag(p + Vector2(90, 0), Vector2(90, 0))
	await wait_process_frames(1)
	assert_gt(Input.get_axis("map_left", "map_right"), 0.5, "джойстик снова принимает касание")
	_touch(p + Vector2(90, 0), false)


class _Probe:
	extends Node
	signal hit

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("map_interact"):
			hit.emit()
