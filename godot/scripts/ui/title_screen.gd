class_name TitleScreen
extends Control
## Титульный экран: Сера перебирает пальцами и моргает (кадры t0/t1/t2/tb), пылинки, логотип, меню.

signal action(name: String)

@export var frame_sequence := PackedStringArray(["t0", "t1", "t0", "t2", "t1", "t0", "t2", "t0"])
@export var frame_min_ms := 520.0
@export var frame_jitter_ms := 380.0
@export var blink_chance := 0.35
@export var blink_ms := 140.0
@export var crossfade_sec := 0.35

var _haunted := false
var _step := 0
var _timer := 0.0
var _cur := "t0"

@onready var frames: Control = $Frames
@onready var blink: TextureRect = $Frames/tb
@onready var logo: TextureRect = $Logo/Img
@onready var btn_continue: Button = $Bar/Continue


func _ready() -> void:
	for f: TextureRect in frames.get_children():
		f.texture = Game.tex("title", String(f.name))
		f.modulate.a = 1.0 if String(f.name) == "t0" else 0.0
	logo.texture = Game.tex("ui", "logo")
	for b: Button in $Bar.get_children():
		b.pressed.connect(func() -> void: action.emit(String(b.name).to_lower()))
	var tw := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tw.tween_property(frames, "scale", Vector2(1.06, 1.06), 28.0)
	tw.tween_property(frames, "scale", Vector2.ONE, 28.0)
	var pulse := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	pulse.tween_property(logo, "modulate", Color(1.25, 0.9, 1.0), 2.5)
	pulse.tween_property(logo, "modulate", Color.WHITE, 2.5)


func refresh(can_continue: bool) -> void:
	_haunted = Game.memory.haunted()
	$Bar/New.disabled = _haunted
	$Bar/New.tooltip_text = "Начать заново нельзя. Я всё помню." if _haunted else ""
	btn_continue.text = "ПРОДОЛЖИТЬ!" if _haunted else "Продолжить"
	# Keep the original VineButton background/border/hover; only the loop label is red.
	for color_key: String in [
		"font_color", "font_hover_color", "font_pressed_color", "font_focus_color"
	]:
		if _haunted:
			btn_continue.add_theme_color_override(color_key, Color(1.0, 0.12, 0.16))
		else:
			btn_continue.remove_theme_color_override(color_key)
	btn_continue.disabled = not (can_continue or _haunted)
	$Frames/te.texture = Game.tex("title", "te")
	$Frames/te.visible = _haunted
	$Frames/te.modulate.a = 1.0 if _haunted else 0.0
	$Dust.set("snowing", _haunted)
	frames.pivot_offset = Vector2(size.x * 0.5, size.y * 0.6)


func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta * 1000.0
	if _haunted:
		if _timer <= 0.0:
			_timer = randf_range(3.5, 10.0) * 1000.0
			$Frames/te.modulate.a = 0.0
			get_tree().create_timer(0.09).timeout.connect(
				func() -> void: $Frames/te.modulate.a = 1.0 if _haunted else 0.0
			)
		return
	if _timer > 0.0:
		return
	var k := frame_sequence[_step % frame_sequence.size()]
	_step += 1
	_timer = frame_min_ms + randf() * frame_jitter_ms
	if k == "t0" and randf() < blink_chance:
		blink.modulate.a = 1.0
		get_tree().create_timer(blink_ms / 1000.0).timeout.connect(
			func() -> void: blink.modulate.a = 0.0
		)
	if k != _cur:
		var nf := frames.get_node(NodePath(k)) as TextureRect
		var old := frames.get_node(NodePath(_cur)) as TextureRect
		_cur = k
		frames.move_child(nf, frames.get_child_count() - 2)
		var tw := create_tween()
		tw.tween_property(nf, "modulate:a", 1.0, crossfade_sec)
		tw.tween_callback(
			func() -> void:
				if old != frames.get_node(NodePath(_cur)):
					old.modulate.a = 0.0
		)
