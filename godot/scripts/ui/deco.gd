@tool
class_name Deco
extends Control
## Рисованные элементы интерфейса в стиле Серы: тёмно-сливовая плашка с двойной бордовой
## рамкой и крестиками по углам, лента-табличка с белым бантом, сердечко «дальше»,
## карточка-полароид со скотчем. Рисуется кодом — без растровых текстур, чётко на любом экране.

enum Kind { PANEL, RIBBON, HEART, CAMEO, BOW }

@export var kind: Kind = Kind.PANEL:
	set(v):
		kind = v
		queue_redraw()
@export var fill := Color(0.075, 0.035, 0.065, 0.84):
	set(v):
		fill = v
		queue_redraw()
@export var accent := Color(0.784, 0.15, 0.31, 0.6):
	set(v):
		accent = v
		queue_redraw()
@export var radius := 16.0
@export var glow := 0.0:
	set(v):
		glow = v
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	match kind:
		Kind.PANEL:
			_panel()
		Kind.RIBBON:
			_ribbon()
		Kind.HEART:
			heart(self, size / 2.0, minf(size.x, size.y) * 0.5, accent)
		Kind.CAMEO:
			_cameo()
		Kind.BOW:
			bow(self, size / 2.0, minf(size.x, size.y) * 0.5, Color(0.97, 0.95, 0.96))


func _panel() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(radius))
	sb.set_border_width_all(1)
	sb.border_color = accent
	sb.shadow_color = Color(accent.r, accent.g * 0.5, accent.b * 0.7, 0.16 + glow * 0.2)
	sb.shadow_size = 18
	sb.anti_aliasing = true
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	# мягкий градиент сверху вниз
	var top := Color(1, 0.55, 0.7, 0.06)
	var bot := Color(0, 0, 0, 0.0)
	draw_polygon(
		PackedVector2Array(
			[
				Vector2(radius, 1),
				Vector2(size.x - radius, 1),
				Vector2(size.x - radius, size.y * 0.55),
				Vector2(radius, size.y * 0.55)
			]
		),
		PackedColorArray([top, top, bot, bot])
	)
	var inner := StyleBoxFlat.new()
	inner.draw_center = false
	inner.set_corner_radius_all(int(maxf(2.0, radius - 6.0)))
	inner.set_border_width_all(1)
	inner.border_color = Color(1, 0.62, 0.76, 0.16)
	inner.anti_aliasing = true
	draw_style_box(inner, Rect2(Vector2(6, 6), size - Vector2(12, 12)))
	var c := Color(accent.r, accent.g, accent.b, minf(1.0, accent.a + 0.25))
	for p: Vector2 in [
		Vector2(18, 18),
		Vector2(size.x - 18, 18),
		Vector2(18, size.y - 18),
		Vector2(size.x - 18, size.y - 18)
	]:
		cross(self, p, 5.0, c)


func _ribbon() -> void:
	var w := size.x
	var h := size.y
	var n := h * 0.42
	var pts := PackedVector2Array(
		[Vector2(0, 0), Vector2(w, 0), Vector2(w - n, h * 0.5), Vector2(w, h), Vector2(0, h)]
	)
	var light := (
		Color(fill.r, fill.g, fill.b, 0.96) if fill.a > 0.9 else Color(0.55, 0.1, 0.24, 0.96)
	)
	var dark := light.darkened(0.5)
	draw_polygon(pts, PackedColorArray([light, light.lerp(dark, 0.3), dark, dark, dark]))
	var line := pts.duplicate()
	line.append(pts[0])
	draw_polyline(line, Color(1, 0.62, 0.76, 0.55 + glow * 0.3), 1.0, true)
	draw_line(Vector2(4, 3), Vector2(w - 6, 3), Color(1, 0.8, 0.88, 0.18), 1.0)
	bow(self, Vector2(h * 0.6, h * 0.46), h * 0.32, Color(0.98, 0.96, 0.97))


func _cameo() -> void:
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(0.93, 0.9, 0.91)
	paper.set_corner_radius_all(4)
	paper.shadow_color = Color(0, 0, 0, 0.55)
	paper.shadow_size = 12
	paper.shadow_offset = Vector2(2, 4)
	paper.anti_aliasing = true
	draw_style_box(paper, Rect2(Vector2.ZERO, size))
	var ink := StyleBoxFlat.new()
	ink.bg_color = Color(0.09, 0.05, 0.08)
	ink.set_corner_radius_all(2)
	draw_style_box(ink, Rect2(Vector2(7, 7), size - Vector2(14, 30)))
	# скотч наискосок
	var t := Transform2D(-0.12, Vector2(size.x * 0.5, 0))
	var tape := PackedVector2Array(
		[Vector2(-30, -9), Vector2(30, -9), Vector2(30, 9), Vector2(-30, 9)]
	)
	draw_set_transform_matrix(t)
	draw_polygon(tape, PackedColorArray([Color(0.98, 0.85, 0.9, 0.62)]))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	cross(self, Vector2(size.x - 16, size.y - 12), 4.0, Color(0.6, 0.1, 0.24, 0.9))


static func cross(ci: CanvasItem, p: Vector2, r: float, c: Color) -> void:
	ci.draw_line(p + Vector2(0, -r * 1.2), p + Vector2(0, r * 1.6), c, 1.6, true)
	ci.draw_line(p + Vector2(-r * 0.8, -r * 0.3), p + Vector2(r * 0.8, -r * 0.3), c, 1.6, true)


static func heart(ci: CanvasItem, p: Vector2, r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		var x := 16.0 * pow(sin(a), 3)
		var y := -(13.0 * cos(a) - 5.0 * cos(2 * a) - 2.0 * cos(3 * a) - cos(4 * a))
		pts.append(p + Vector2(x, y) * (r / 17.0))
	ci.draw_polygon(pts, PackedColorArray([c]))


## Белый бант (как у Серы): две петли, хвостики и узелок
static func bow(ci: CanvasItem, p: Vector2, r: float, c: Color) -> void:
	var edge := Color(0.55, 0.12, 0.25, 0.9)
	for s: float in [-1.0, 1.0]:
		var loop := PackedVector2Array(
			[
				p,
				p + Vector2(s * r * 1.05, -r * 0.75),
				p + Vector2(s * r * 1.25, -r * 0.1),
				p + Vector2(s * r * 1.0, r * 0.55),
			]
		)
		ci.draw_polygon(loop, PackedColorArray([c]))
		var o := loop.duplicate()
		o.append(p)
		ci.draw_polyline(o, edge, 1.0, true)
		var tail := PackedVector2Array(
			[
				p + Vector2(s * r * 0.1, r * 0.1),
				p + Vector2(s * r * 0.55, r * 1.15),
				p + Vector2(s * r * 0.3, r * 1.05),
				p + Vector2(s * r * 0.05, r * 0.25)
			]
		)
		ci.draw_polygon(tail, PackedColorArray([c.darkened(0.06)]))
	ci.draw_circle(p, r * 0.24, c.darkened(0.12))
	ci.draw_arc(p, r * 0.24, 0, TAU, 12, edge, 1.0, true)
