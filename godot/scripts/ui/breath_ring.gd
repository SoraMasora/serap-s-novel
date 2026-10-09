class_name BreathRing
extends Control
## Круг дыхания: пунктирное кольцо, пульсирующий диск, светлое ядро.

@export var color_idle := Color(0.76, 0.227, 0.345, 0.55)
@export var color_sync := Color(1, 0.667, 0.784, 0.7)
@export var ring_color := Color(0.94, 0.78, 0.86, 0.35)

var amount := 0.42:
	set(v):
		amount = v
		queue_redraw()
var sync := false:
	set(v):
		if v != sync:
			sync = v
			queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0
	var segs := 48
	for i in segs:
		if i % 2 == 0:
			var a0 := TAU * i / segs
			draw_arc(c, r - 1.0, a0, a0 + TAU / segs, 4, ring_color, 2.0, true)
	var col := color_sync if sync else color_idle
	var rr := r * amount
	for k in 6:
		var f := 1.0 - k / 6.0
		draw_circle(c, rr * (0.72 + 0.28 * f), Color(col, col.a * (0.25 + 0.75 * (1.0 - f))))
	draw_circle(c, rr * 0.72, Color(col, col.a))
	draw_circle(c, r * 0.08, Color("#f1e6ee"))
