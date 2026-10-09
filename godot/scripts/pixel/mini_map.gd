class_name MiniMap
extends Control
## Мини-карта: точки интереса и герой.

var _w: PixelWorld


func setup(w: PixelWorld) -> void:
	_w = w
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(0, size.y / 2.0 - 1, size.x, 2), Color(1, 1, 1, 0.15))
	if _w == null or _w.cfg.is_empty():
		return
	var ww := float(_w.pc.world_width)
	var sp := _w.spots()
	for id: String in sp:
		if sp[id].get("decor", false):
			continue
		var c := Color("#ff6b9a")
		if id == "home":
			c = Color("#9fd0ff")
		elif not _w.avail(id):
			c = Color(1, 1, 1, 0.2)
		elif _w.cfg.done.has(id):
			c = Color(0.63, 0.63, 0.67, 0.9)
		draw_rect(Rect2(sp[id].x / ww * size.x - 3, size.y / 2.0 - 3, 6, 6), c)
	draw_circle(Vector2(_w.hero.x / ww * size.x, size.y / 2.0), 4.0, Color("#ffe36b"))
