class_name RainFx
extends Control
## Дождь поверх сцены: три слоя капель по глубине + дымка снизу (порт canvas-дождя engine.js).
## Виден только на открытых локациях (решает main.gd).

@export var drop_count := 650
@export var slant := 0.12
@export var speed_per_sec := 1.32
@export var band_alpha := PackedFloat32Array([0.38, 0.58, 0.85])
@export var band_width := PackedFloat32Array([1.0, 1.3, 1.9])
@export var color := Color(215 / 255.0, 222 / 255.0, 245 / 255.0, 1)
@export var mist := Color(150 / 255.0, 160 / 255.0, 200 / 255.0, 0.10)

var raining := false:
	set(v):
		raining = v
		visible = v
		if v and _drops.is_empty():
			_drops.resize(drop_count)
			for i in drop_count:
				_drops[i] = _new_drop(true)
var _drops: Array = []


func _new_drop(any: bool) -> Dictionary:
	var z := randf()
	return {
		"x": randf() * 1.15 - 0.05,
		"y": randf() if any else -0.1 - randf() * 0.2,
		"z": z,
		"l": 18.0 + z * 46.0,
		"v": 0.55 + z * 0.9,
	}


func _process(delta: float) -> void:
	if not raining:
		return
	var k := delta * speed_per_sec
	var hw := size.y / maxf(1.0, size.x)
	for i in _drops.size():
		var d: Dictionary = _drops[i]
		d.y += k * d.v
		d.x -= k * d.v * slant * hw
		if d.y > 1.05:
			_drops[i] = _new_drop(false)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var kk := h / 720.0
	for y in range(int(h * 0.45), int(h), 6):
		var a := mist.a * (y - h * 0.45) / (h * 0.55)
		draw_rect(Rect2(0, y, w, 6), Color(mist, a))
	for d: Dictionary in _drops:
		var band := mini(2, int(d.z * 3))
		var p := Vector2(d.x * w, d.y * h)
		var l: float = d.l * kk
		draw_line(
			p, p + Vector2(-l * slant, l), Color(color, band_alpha[band]), band_width[band] * kk
		)
