class_name BreathGame
extends Control
## Мини-игра «Дыши со мной»: держи (пробел/мышь), пока круг растёт, отпускай, пока сжимается.

signal heartbeat
signal finished(score: float)

@export var inhale_ms := 3000.0
@export var exhale_ms := 3400.0
@export var ok_ratio := 0.6
@export var result_hold_sec := 1.5
@export var heartbeat_every_ms := 2600.0
@export var heartbeat_below := 0.55

var _cfg: Dictionary = {}
var _running := false
var _t := 0.0
var _good := 0.0
var _all := 0.0
var _beat := 0.0
var _n := 3

@onready var title: Label = $Box/Title
@onready var ring: BreathRing = $Box/Ring
@onready var txt: Label = $Box/Txt
@onready var bar_fill: ColorRect = $Box/Bar/Fill
@onready var hint: Label = $Box/Hint
@onready var bar: Control = $Box/Bar


func start(cfg: Dictionary, skip: bool) -> void:
	_cfg = cfg
	_n = int(cfg.get("n", 3))
	title.text = cfg.get("title", "Дыши со мной")
	_t = 0.0
	_good = 0.0
	_all = 0.0
	_beat = 0.0
	visible = true
	hint.modulate.a = 1.0
	bar.modulate.a = 1.0
	heartbeat.emit()
	if skip:
		_finish(1.0)
		return
	_running = true


func _process(delta: float) -> void:
	if not _running:
		return
	_t += delta * 1000.0
	var cy := inhale_ms + exhale_ms
	var tot := _n * cy
	var ph := fmod(_t, cy)
	var inh := ph < inhale_ms
	var k := ph / inhale_ms if inh else 1.0 - (ph - inhale_ms) / exhale_ms
	var e := 0.5 - cos(PI * k) / 2.0
	ring.amount = 0.42 + 0.58 * e
	var held := Input.is_action_pressed("breath_hold")
	_all += delta
	if held == inh:
		_good += delta
	ring.sync = held == inh
	txt.text = "%s…  %d / %d" % ["Вдох" if inh else "Выдох", int(_t / cy) + 1, _n]
	bar_fill.anchor_right = clampf(_t / tot, 0.0, 1.0)
	var q := _good / maxf(0.001, _all)
	if _t - _beat > heartbeat_every_ms and q < heartbeat_below:
		_beat = _t
		heartbeat.emit()
	if _t >= tot:
		_running = false
		_finish(q)


func _finish(score: float) -> void:
	var ok := score >= ok_ratio
	txt.text = _cfg.get("ok", "Ровно. Вместе.") if ok else _cfg.get("bad", "Сбилось… но я всё равно рядом.")
	create_tween().tween_property(hint, "modulate:a", 0.0, 0.4)
	create_tween().tween_property(bar, "modulate:a", 0.0, 0.4)
	get_tree().create_timer(result_hold_sec).timeout.connect(
		func() -> void:
			visible = false
			finished.emit(score)
	)


func kill() -> void:
	_running = false
	visible = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()
