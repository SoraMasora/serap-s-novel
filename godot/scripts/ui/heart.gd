extends Label
## Сердечко/крестик, всплывающее над Серой (hearts()).

@export var rise_px := 90.0
@export var life_sec := 1.8


func _ready() -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position:y", position.y - rise_px, life_sec).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, life_sec).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2(1.3, 1.3), life_sec)
	tw.chain().tween_callback(queue_free)


func set_dark(dark: bool) -> void:
	text = "✝" if dark else "♡"
	add_theme_color_override("font_color", Color("#b8a0ff") if dark else Color("#ff5c8a"))
