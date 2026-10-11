class_name FancyPanel
extends PanelContainer
## Окно в стиле окна реплик: тёмно-сливовая плашка с двойной бордовой рамкой, крестики по углам,
## белый бант на верхней кромке. Рисуется под содержимым (контейнер рисует себя раньше детей).

@export var fill := Color(0.075, 0.035, 0.065, 0.94)
@export var accent := Color(0.784, 0.15, 0.31, 0.6)
@export var radius := 16.0
@export var bow := true


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	Deco.panel(self, Rect2(Vector2.ZERO, size), fill, accent, radius, 0.4)
	if not bow:
		return
	var cx := size.x / 2.0
	var line := Color(1, 0.55, 0.72, 0.55)
	draw_line(Vector2(cx - 120, 0), Vector2(cx - 26, 0), line, 1.0, true)
	draw_line(Vector2(cx + 26, 0), Vector2(cx + 120, 0), line, 1.0, true)
	Deco.cross(self, Vector2(cx - 132, 0), 3.5, line)
	Deco.cross(self, Vector2(cx + 132, 0), 3.5, line)
	Deco.bow(self, Vector2(cx, 1), 15.0, Color(0.98, 0.96, 0.97))
