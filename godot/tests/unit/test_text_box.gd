extends GutTest
## Регресс вёрстки окна реплик (плашка в стиле Серы на всю ширину, имя на ленте, мысли с полосой).

const SCENE := preload("res://scenes/ui/text_box.tscn")
var tb: TextBox


func before_each() -> void:
	tb = SCENE.instantiate()
	add_child_autofree(tb)
	await get_tree().process_frame


func test_full_width_subtitles() -> void:
	assert_eq(tb.anchor_left, 0.0)
	assert_eq(tb.anchor_right, 1.0)
	assert_almost_eq(tb.anchor_top, 0.70, 0.001, "панель — нижние 30% экрана")
	assert_almost_eq(tb.get_node("Body").offset_left, tb._body_left, 0.01)
	assert_true(tb.panel is Deco)


func test_thought_line_has_bar_and_indent() -> void:
	tb.show_line("", "gg", "Тест мыслей.", true, true)
	await get_tree().process_frame
	assert_true(tb.thought_bar.visible)
	assert_true(tb.thought_tag.visible)
	var body: Control = tb.get_node("Body")
	assert_almost_eq(body.offset_left, tb.thought_bar.offset_left + 16.0, 0.01)
	assert_gt(tb.thought_bar.offset_bottom, tb.thought_bar.offset_top)
	tb.show_line("Сера", "sera", "Обычная реплика.", false, true)
	assert_false(tb.thought_bar.visible)
	assert_almost_eq(body.offset_left, tb.thought_bar.offset_left, 0.01)


func test_side_portrait_shifts_name_and_text() -> void:
	tb.show_line("Кирилл", "gg", "!!!", false, true)
	tb.set_side_padding(true)
	assert_almost_eq(
		tb.name_box.offset_left, tb._name_left + tb.side_shift, 1.0, "место под полароид"
	)
	tb.set_side_padding(false)
	assert_almost_eq(tb.name_box.offset_left, tb._name_left, 1.0)


func test_controls_emit_lowercase_actions() -> void:
	watch_signals(tb)
	var buttons := tb.controls.get_children().filter(func(c: Node) -> bool: return c is Button)
	assert_eq(buttons.size(), 8)
	(buttons[2] as Button).pressed.emit()
	assert_signal_emitted_with_parameters(tb, "control_pressed", ["notes"])


func test_name_color_and_underline_follow_kind() -> void:
	tb.show_line("Кирилл", "gg", "x", false, true)
	assert_eq(tb.underline.self_modulate, tb.name_colors.gg)
	assert_eq(tb.ribbon.fill, tb.ribbon_colors.gg)
	assert_true(tb.next_mark.visible, "мгновенная реплика → маркер «дальше»")
