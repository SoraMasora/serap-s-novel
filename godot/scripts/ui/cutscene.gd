class_name Cutscene
extends Control
## Катсцена: кадры сменяют друг друга сами (клик — следующий), новый проявляется поверх старого,
## один медленный зум на всю катсцену (playCut).

signal caption_shown(text: String)
signal sfx_requested(key: String)
signal finished

@export var default_frame_ms := 2600.0
@export var crossfade_sec := 0.9
@export var zoom_from := 1.07

var _frames: Array = []
var _k := 0
var _cur := 0
var _skip := false
var _timer: SceneTreeTimer
var _active := false

@onready var stage: Control = $Stage
@onready var imgs: Array[TextureRect] = [$Stage/A, $Stage/B]
@onready var caption: Label = $Caption


func play(frames: Array, skip: bool, fmt: Callable) -> void:
	_frames = frames
	_k = 0
	_skip = skip
	_active = true
	visible = true
	modulate.a = 1.0
	for i in imgs:
		i.modulate.a = 0.0
	caption.text = ""
	var total := 1.2
	for f: Dictionary in frames:
		total += float(f.get("ms", default_frame_ms)) / 1000.0
	stage.pivot_offset = stage.size / 2.0
	stage.scale = Vector2.ONE * (1.0 if skip else zoom_from)
	if not skip:
		create_tween().tween_property(stage, "scale", Vector2.ONE, total)
	set_meta("fmt", fmt)
	_next()


func _next() -> void:
	if not _active:
		return
	if _k >= _frames.size():
		_active = false
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.05 if _skip else 0.7)
		tw.tween_callback(_done)
		return
	var f: Dictionary = _frames[_k]
	_k += 1
	var prev := imgs[_cur]
	_cur ^= 1
	var el := imgs[_cur]
	el.texture = Game.tex("bg", f.img)
	stage.move_child(el, -1)
	el.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(el, "modulate:a", 1.0, 0.0 if _skip else crossfade_sec)
	tw.tween_callback(func() -> void: prev.modulate.a = 0.0)
	var fmt: Callable = get_meta("fmt")
	var t: String = fmt.call(f.text) if f.get("text") else ""
	caption.text = t
	caption.modulate.a = 0.0
	if t != "":
		create_tween().tween_property(caption, "modulate:a", 1.0, 0.6)
		caption_shown.emit(t)
	if f.get("sfx") and not _skip:
		sfx_requested.emit(f.sfx)
	var ms := 200.0 if _skip else float(f.get("ms", default_frame_ms))
	var my_k := _k
	get_tree().create_timer(ms / 1000.0).timeout.connect(
		func() -> void:
			if _active and _k == my_k:
				_next()
	)


func _done() -> void:
	visible = false
	stage.scale = Vector2.ONE
	finished.emit()


## Прервать (загрузка/откат)
func kill() -> void:
	_active = false
	visible = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_next()
