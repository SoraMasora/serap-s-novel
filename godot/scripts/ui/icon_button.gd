class_name IconButton
extends Button
## Кнопка панели реплик: маленькая рисованная иконка + подпись. Наведение — розовое свечение
## и лёгкий подъём; включённый режим (Авто/Пропуск) подсвечен лентой снизу.

@export_enum("auto", "skip", "notes", "log", "save", "load", "menu", "hide") var icon_kind := "auto"
@export var ink := Color(0.88, 0.78, 0.84, 0.72)
@export var hot := Color(1, 0.6, 0.76, 1)

var _hover := 0.0
var _tw: Tween


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_constant_override("h_separation", 0)
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	toggled.connect(func(_on: bool) -> void: queue_redraw())
	_refresh_padding()


func _refresh_padding() -> void:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 22
	sb.content_margin_right = 7
	sb.content_margin_top = 3
	sb.content_margin_bottom = 4
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(st, sb)


func _set_hover(on: bool) -> void:
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_method(
		func(v: float) -> void:
			_hover = v
			queue_redraw(),
		_hover,
		1.0 if on else 0.0,
		0.18
	)


func _draw() -> void:
	var on := button_pressed and toggle_mode
	var c := ink.lerp(hot, maxf(_hover, 1.0 if on else 0.0))
	if _hover > 0.0 or on:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.55, 0.08, 0.22, 0.22 * maxf(_hover, 0.6 if on else 0.0))
		sb.set_corner_radius_all(9)
		draw_style_box(sb, Rect2(Vector2(1, 1), size - Vector2(2, 2)))
	if on:
		draw_line(
			Vector2(10, size.y - 1.5),
			Vector2(size.x - 8, size.y - 1.5),
			Color(1, 0.4, 0.6, 0.8),
			1.5
		)
	var o := Vector2(12, size.y * 0.5 - _hover * 1.0)
	_icon(o, c)


func _icon(o: Vector2, c: Color) -> void:
	var w := 1.4
	match icon_kind:
		"auto":
			draw_colored_polygon(
				PackedVector2Array([o + Vector2(-3, -5), o + Vector2(4, 0), o + Vector2(-3, 5)]), c
			)
		"skip":
			for dx: float in [-5.0, 1.0]:
				draw_colored_polygon(
					PackedVector2Array(
						[o + Vector2(dx, -4.5), o + Vector2(dx + 5, 0), o + Vector2(dx, 4.5)]
					),
					c
				)
		"notes":
			draw_rect(Rect2(o + Vector2(-4, -5.5), Vector2(8, 11)), c, false, w)
			for k in 3:
				draw_line(o + Vector2(-2, -2.5 + k * 2.8), o + Vector2(2.5, -2.5 + k * 2.8), c, 1.0)
		"log":
			draw_line(o + Vector2(0, -4), o + Vector2(0, 5), c, w)
			draw_polyline(
				PackedVector2Array(
					[o + Vector2(0, -4), o + Vector2(-5, -5), o + Vector2(-5, 4), o + Vector2(0, 5)]
				),
				c,
				w,
				true
			)
			draw_polyline(
				PackedVector2Array(
					[o + Vector2(0, -4), o + Vector2(5, -5), o + Vector2(5, 4), o + Vector2(0, 5)]
				),
				c,
				w,
				true
			)
		"save":
			Deco.heart(self, o + Vector2(0, 0.5), 5.0, c)
		"load":
			draw_arc(o, 4.5, -PI * 0.15, PI * 1.55, 16, c, w, true)
			draw_colored_polygon(
				PackedVector2Array(
					[o + Vector2(3.5, -6), o + Vector2(6.5, -1.5), o + Vector2(1.5, -1.5)]
				),
				c
			)
		"menu":
			Deco.cross(self, o + Vector2(0, -0.5), 4.5, c)
		"hide":
			var pts := PackedVector2Array()
			for i in 13:
				var a := PI * i / 12.0
				pts.append(o + Vector2(-cos(a) * 6.0, -sin(a) * 3.6))
			for i in range(1, 12):
				var a := PI * i / 12.0
				pts.append(o + Vector2(cos(a) * 6.0, sin(a) * 3.6))
			pts.append(pts[0])
			draw_polyline(pts, c, w, true)
			draw_circle(o, 1.8, c)
