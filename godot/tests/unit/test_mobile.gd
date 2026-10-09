extends GutTest
## Мобильная платформа: выбор сенсорного режима, отступы безопасной зоны, привязка к краям.

const M := preload("res://scripts/autoload/mobile.gd")


func test_detect_touch_auto_follows_platform() -> void:
	assert_true(M.detect_touch(M.TOUCH_AUTO, {"mobile": true}))
	assert_false(M.detect_touch(M.TOUCH_AUTO, {"mobile": false, "touchscreen": true}))


func test_detect_touch_setting_and_cli_override() -> void:
	assert_true(M.detect_touch(M.TOUCH_ON, {"mobile": false}))
	assert_false(M.detect_touch(M.TOUCH_OFF, {"mobile": true}))
	assert_true(M.detect_touch(M.TOUCH_OFF, {"mobile": false, "cli": "--touch"}))
	assert_false(M.detect_touch(M.TOUCH_ON, {"mobile": true, "cli": "--no-touch"}))


func test_insets_scale_to_canvas() -> void:
	# 2400×1080 (20:9), вырез 100 px слева и справа, холст 1600×720 (expand от 1280×720)
	var ins := M.compute_insets(
		Vector2i(2400, 1080), Rect2i(100, 0, 2200, 1080), Vector2(1600, 720)
	)
	assert_almost_eq(ins.x, 66.67, 0.01)
	assert_almost_eq(ins.y, 0.0, 0.01)
	assert_almost_eq(ins.z, 66.67, 0.01)
	assert_almost_eq(ins.w, 0.0, 0.01)


func test_insets_degenerate_inputs_are_zero() -> void:
	assert_eq(M.compute_insets(Vector2i.ZERO, Rect2i(0, 0, 10, 10), Vector2(10, 10)), Vector4.ZERO)
	assert_eq(M.compute_insets(Vector2i(10, 10), Rect2i(), Vector2(10, 10)), Vector4.ZERO)


func test_apply_insets_respects_anchors_and_is_idempotent() -> void:
	var full := Control.new()
	full.set_anchors_preset(Control.PRESET_FULL_RECT)
	var right := Control.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -300
	right.offset_right = -20
	autofree(full)
	autofree(right)
	var ins := Vector4(40, 10, 30, 0)
	for _i in 2:
		M.apply_insets(full, ins)
		M.apply_insets(right, ins)
	assert_eq(full.offset_left, 40.0)
	assert_eq(full.offset_top, 10.0)
	assert_eq(full.offset_right, -30.0)
	assert_eq(full.offset_bottom, 0.0)
	assert_eq(right.offset_left, -300.0, "левый край привязан к правому якорю — не двигаем")
	assert_eq(right.offset_right, -50.0)
	M.apply_insets(right, Vector4.ZERO)
	assert_eq(right.offset_right, -20.0, "возврат к исходным отступам")
