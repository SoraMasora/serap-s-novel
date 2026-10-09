extends GutTest
## Регресс вёрстки окна реплик под css v4–v13 (субтитры на всю ширину, имя слева, мысли с полосой).

const SCENE := preload("res://scenes/ui/text_box.tscn")
var tb: TextBox


func before_each() -> void:
	tb = SCENE.instantiate()
	add_child_autofree(tb)
	await get_tree().process_frame


func test_full_width_subtitles() -> void:
	assert_eq(tb.anchor_left, 0.0)
	assert_eq(tb.anchor_right, 1.0)
	assert_almost_eq(tb.anchor_top, 0.71, 0.001, "высота 29% как #textbox{height:29%}")
	assert_almost_eq(tb.get_node("Body").offset_left, 256.0, 1.0, "padding 20%")


func test_thought_line_has_bar_and_indent() -> void:
	tb.show_line("", "gg", "Тест мыслей.", true, true)
	await get_tree().process_frame
	assert_true(tb.thought_bar.visible)
	assert_true(tb.thought_tag.visible)
	var body: Control = tb.get_node("Body")
	assert_almost_eq(body.offset_left, tb.thought_bar.offset_left + 23.0, 0.01)
	assert_gt(tb.thought_bar.offset_bottom, tb.thought_bar.offset_top)
	tb.show_line("Сера", "sera", "Обычная реплика.", false, true)
	assert_false(tb.thought_bar.visible)
	assert_almost_eq(body.offset_left, tb.thought_bar.offset_left, 0.01)


func test_side_portrait_shifts_name_and_text() -> void:
	tb.show_line("Кирилл", "gg", "!!!", false, true)
	tb.set_side_padding(true)
	var w := tb.get_viewport_rect().size.x
	assert_almost_eq(tb.name_box.offset_left, w * 0.22, 1.0, "#side ~ #namebox{left:22%}")
	tb.set_side_padding(false)
	assert_almost_eq(tb.name_box.offset_left, 256.0, 1.0)


func test_controls_emit_lowercase_actions() -> void:
	watch_signals(tb)
	var buttons := tb.controls.get_children().filter(func(c: Node) -> bool: return c is Button)
	assert_eq(buttons.size(), 7)
	(buttons[2] as Button).pressed.emit()
	assert_signal_emitted_with_parameters(tb, "control_pressed", ["notes"])


func test_name_color_and_underline_follow_kind() -> void:
	tb.show_line("Кирилл", "gg", "x", false, true)
	assert_eq(tb.underline.self_modulate, tb.name_colors.gg)
	assert_true(tb.next_mark.visible, "мгновенная реплика → маркер «дальше»")
