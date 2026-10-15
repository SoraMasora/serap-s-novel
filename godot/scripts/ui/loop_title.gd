extends "res://scripts/ui/title_screen.gd"
## All 0.7.1 button nodes, theme and effects remain untouched.

var _haunted := false


func refresh(can_continue: bool) -> void:
	super.refresh(can_continue)
	_haunted = Game.memory.haunted()
	$Bar/New.disabled = _haunted
	$Bar/New.tooltip_text = "Начать заново нельзя. Я всё помню." if _haunted else ""
	btn_continue.text = "ПРОДОЛЖИТЬ!" if _haunted else "Продолжить"
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		if _haunted:
			btn_continue.add_theme_color_override(key, Color(1.0, 0.12, 0.16))
		else:
			btn_continue.remove_theme_color_override(key)
	btn_continue.disabled = not (can_continue or _haunted)
	$Frames/te.texture = Game.tex("title", "te")
	$Frames/te.visible = _haunted
	$Frames/te.modulate.a = 1.0 if _haunted else 0.0
	$Dust.visible = not _haunted
	$LoopSnow.visible = _haunted


func _process(delta: float) -> void:
	if not _haunted:
		super._process(delta)
		return
	if not visible:
		return
	_timer -= delta * 1000.0
	if _timer <= 0.0:
		_timer = randf_range(3.5, 10.0) * 1000.0
		$Frames/te.modulate.a = 0.0
		get_tree().create_timer(0.09).timeout.connect(
			func() -> void: $Frames/te.modulate.a = 1.0 if _haunted else 0.0
		)
