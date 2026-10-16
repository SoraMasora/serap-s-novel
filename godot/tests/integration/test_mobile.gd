extends GutTest
## Real InputEventScreenTouch/Drag, independently owned fingers and lifecycle cleanup.

const STICK := preload("res://scenes/mobile/touch_stick.tscn")
const ACTION := preload("res://scenes/mobile/touch_action.tscn")
const MAP := preload("res://scenes/pixel/pixel_map.tscn")
const TEXTBOX := preload("res://scenes/ui/text_box.tscn")
var _old_touch := ""


func before_each() -> void:
	_old_touch = OS.get_environment("SERA_TOUCH")
	OS.set_environment("SERA_TOUCH", "1")


func after_each() -> void:
	OS.set_environment("SERA_TOUCH", _old_touch)
	for action: String in [
		"map_left", "map_right", "map_up", "map_down", "map_run", "mobile_run", "map_interact"
	]:
		Input.action_release(action)


func _touch(index: int, pos: Vector2, down: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = down
	return event


func _stick() -> TouchStick:
	var stick: TouchStick = STICK.instantiate()
	add_child_autofree(stick)
	return stick


func test_safe_area_scales_notch_and_navigation_insets() -> void:
	var margins := MobileProfile.safe_margins(
		Vector2(2400, 1080), Rect2(90, 0, 2260, 1050), Vector2(1600, 720)
	)
	assert_true(margins.is_equal_approx(Vector4(60, 0, 100.0 / 3.0, 20)))
	assert_eq(MobileProfile.safe_margins(Vector2.ZERO, Rect2(), Vector2(1280, 720)), Vector4.ZERO)


func test_stick_tracks_only_its_finger_and_clamps() -> void:
	var stick := _stick()
	stick._input(_touch(2, Vector2(210, 115), true))
	assert_true(Input.is_action_pressed("map_right"))
	assert_true(Input.is_action_pressed("map_run"))
	stick._input(_touch(3, Vector2(210, 115), false))
	assert_true(Input.is_action_pressed("map_right"), "other finger cannot release joystick")
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = Vector2(-400, 115)
	stick._input(drag)
	assert_almost_eq(stick._vec.length(), 1.0, 0.001)
	assert_true(Input.is_action_pressed("map_left"))
	stick._input(_touch(2, Vector2(-400, 115), false))
	assert_false(Input.is_action_pressed("map_left"))
	assert_false(Input.is_action_pressed("map_run"))


func test_dead_zone_does_not_move() -> void:
	var stick := _stick()
	stick._input(_touch(0, Vector2(118, 115), true))
	assert_false(Input.is_action_pressed("map_right"))
	assert_false(Input.is_action_pressed("map_run"))


func test_stick_releases_on_focus_loss_and_hide() -> void:
	var stick := _stick()
	for reason in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		stick._input(_touch(0, Vector2(210, 115), true))
		stick.notification(reason)
		assert_false(Input.is_action_pressed("map_right"))
	stick._input(_touch(0, Vector2(210, 115), true))
	stick.hide()
	assert_false(Input.is_action_pressed("map_right"))


func test_two_fingers_can_run_and_steer_independently() -> void:
	var stick := _stick()
	var button: TouchAction = ACTION.instantiate()
	button.action = "mobile_run"
	button.position = Vector2(400, 300)
	add_child_autofree(button)
	stick._input(_touch(0, Vector2(170, 115), true))
	button._input(_touch(1, Vector2(430, 330), true))
	await wait_process_frames(2)
	assert_true(Input.is_action_pressed("map_right"))
	assert_true(Input.is_action_pressed("mobile_run"))
	stick.release()
	assert_true(Input.is_action_pressed("mobile_run"), "stick cannot clear run button")
	button._input(_touch(1, Vector2(900, 600), false))
	await wait_process_frames(2)
	assert_false(Input.is_action_pressed("mobile_run"), "release outside button still works")


func test_action_releases_on_hide() -> void:
	var button: TouchAction = ACTION.instantiate()
	add_child_autofree(button)
	button._input(_touch(0, Vector2(20, 20), true))
	await wait_process_frames(2)
	assert_true(Input.is_action_pressed("map_interact"))
	button.hide()
	await wait_process_frames(2)
	assert_false(Input.is_action_pressed("map_interact"))


func test_map_menu_blocks_and_releases_controls() -> void:
	var map: PixelMap = MAP.instantiate()
	add_child_autofree(map)
	map.open(
		{
			"world": "yard",
			"time": "day",
			"title": "Тест",
			"task": "Идти",
			"visits": 2,
			"done": [],
			"spots": {"shop": "shop"}
		}
	)
	map._upd_touch()
	map._stick._input(_touch(0, map._stick.position + Vector2(210, 115), true))
	assert_true(Input.is_action_pressed("map_right"))
	map.set_touch_blocked(true)
	assert_false(Input.is_action_pressed("map_right"))
	assert_false(map._touch.visible)
	assert_false(map._stick.visible)
	map.set_touch_blocked(false)
	assert_true(map._touch.visible)
	map.close()
	assert_false(Input.is_action_pressed("map_run"))


func test_mobile_textbox_and_weather_budget() -> void:
	var box: TextBox = TEXTBOX.instantiate()
	add_child_autofree(box)
	assert_almost_eq(box.anchor_top, 0.6, 0.0001)
	assert_eq(box.text.get_theme_font_size("normal_font_size"), 26)
	var rain := RainFx.new()
	add_child_autofree(rain)
	assert_eq(rain.drop_count, MobileProfile.RAIN_DROPS)
	rain.raining = true
	assert_eq(rain._drops.size(), MobileProfile.RAIN_DROPS)


func test_mobile_texture_cache_is_bounded() -> void:
	Game._tex_cache.clear()
	for key: String in Game.manifest.bg:
		Game.tex("bg", key)
		if Game._tex_cache.size() == MobileProfile.TEXTURE_CACHE_LIMIT:
			break
	Game.tex("bg", "dm_room")
	Game.tex("bg", "dm_train")
	assert_lte(Game._tex_cache.size(), MobileProfile.TEXTURE_CACHE_LIMIT)
	assert_not_null(Game.tex("bg", "dm_room"))


func test_viewport_multitouch_has_no_emulated_mouse_sticking() -> void:
	var stick := _stick()
	var button: TouchAction = ACTION.instantiate()
	button.position = Vector2(400, 300)
	button.action = "mobile_run"
	add_child_autofree(button)
	get_viewport().push_input(_touch(0, Vector2(170, 115), true), true)
	get_viewport().push_input(_touch(1, Vector2(430, 330), true), true)
	await wait_process_frames(3)
	assert_true(Input.is_action_pressed("map_right"))
	assert_true(Input.is_action_pressed("mobile_run"))
	get_viewport().push_input(_touch(1, Vector2(430, 330), false), true)
	get_viewport().push_input(_touch(0, Vector2(170, 115), false), true)
	await wait_process_frames(3)
	assert_false(Input.is_action_pressed("map_right"))
	assert_false(Input.is_action_pressed("mobile_run"))
	stick.release()


func test_touch_action_enters_nearby_map_spot() -> void:
	var map: PixelMap = MAP.instantiate()
	add_child_autofree(map)
	map.open(
		{
			"world": "yard",
			"time": "day",
			"title": "Тест",
			"visits": 1,
			"done": [],
			"spots": {"store": "test_store"}
		}
	)
	var spot: Dictionary = map.pc.spots.yard.store
	map.pworld.hero.x = float(spot.x)
	map.pworld.hero.y = float(spot.y)
	map._upd_touch()
	watch_signals(map)
	var button: TouchAction = map._touch_act
	button._input(_touch(0, button.global_position + button.size / 2.0, true))
	assert_signal_emitted(map, "entered")
	assert_false(map.visible)
	assert_false(Input.is_action_pressed("map_interact"), "scene transition releases the finger")
