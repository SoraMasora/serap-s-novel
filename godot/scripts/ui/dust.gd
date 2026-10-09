extends Control
## Пылинки на титульном экране (45 частиц, мерцают и всплывают).

@export var count := 45

var _motes: Array = []
var _t := 0.0


func _ready() -> void:
	for i in count:
		_motes.append(
			{
				"x": randf(),
				"y": randf(),
				"r": 0.5 + randf() * 1.8,
				"v": 0.0002 + randf() * 0.0005,
				"p": randf() * 6.0,
			}
		)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta * 1000.0
	var k := delta * 60.0
	for m: Dictionary in _motes:
		m.y -= m.v * k
		m.x += sin(_t / 2000.0 + m.p) * 0.0003 * k
		if m.y < 0.0:
			m.y = 1.0
	queue_redraw()


func _draw() -> void:
	for m: Dictionary in _motes:
		var c := Color(1.0, (170.0 + 60.0 * sin(m.p)) / 255.0, 200.0 / 255.0, 0.25 + 0.25 * sin(_t / 700.0 + m.p))
		draw_circle(Vector2(m.x * size.x, m.y * size.y), m.r * 1.5, c)
