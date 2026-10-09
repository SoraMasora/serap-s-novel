class_name CharacterView
extends Control
## Спрайт персонажа на сцене: появление/уход, позиция, «дыхание», моргание, реакции.

@export var height_ratio := 1.04
@export var fade_sec := 0.5
@export var move_sec := 0.6
@export var idle_period_sec := 6.0
@export var dim_color := Color(0.6, 0.6, 0.6, 1)

var who := ""
var expr: Variant = null
var reacting := false
var dying := false
var _blink_tex: Texture2D
var _blink_t := 0.0
var _react_tw: Tween
var _seq_timer := 0.0
var _seq: Array = []
var _seq_k := 0
var _base_key := ""

@onready var motion: Control = $Motion
@onready var idle: Control = $Motion/Idle
@onready var base: TextureRect = $Motion/Idle/Base
@onready var blink: TextureRect = $Motion/Idle/Blink


func _ready() -> void:
	modulate.a = 0.0
	blink.visible = false
	_blink_t = randf_range(2.0, 5.0)
	_start_idle()


func _start_idle() -> void:
	var tw := create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var q := idle_period_sec / 4.0
	tw.tween_property(idle, "rotation_degrees", 0.3, q)
	tw.parallel().tween_property(idle, "scale", Vector2(1.002, 1.006), q)
	tw.tween_property(idle, "rotation_degrees", 0.0, q)
	tw.parallel().tween_property(idle, "scale", Vector2(1.0, 1.011), q)
	tw.tween_property(idle, "rotation_degrees", -0.3, q)
	tw.parallel().tween_property(idle, "scale", Vector2(1.002, 1.006), q)
	tw.tween_property(idle, "rotation_degrees", 0.0, q)
	tw.parallel().tween_property(idle, "scale", Vector2.ONE, q)
	tw.custom_step(randf() * idle_period_sec)


## Основной спрайт (эмоция). Во время реакции применяется после её окончания.
func set_base_key(key: String) -> void:
	_base_key = key
	if not reacting:
		set_sprite(key)


func set_sprite(key: String) -> void:
	var t := Game.tex("sprites", key)
	if t == null:
		push_warning("Нет спрайта: " + key)
		return
	if base.texture != t:
		base.texture = t
	_layout()


func _layout() -> void:
	if base.texture == null:
		return
	var vp := get_viewport_rect().size
	var h := vp.y * height_ratio
	var w := h * base.texture.get_width() / base.texture.get_height()
	size = Vector2(w, h)
	pivot_offset = Vector2(w / 2.0, h)
	idle.pivot_offset = Vector2(w / 2.0, h)
	motion.pivot_offset = Vector2(w / 2.0, h)


## x_ratio — доля ширины экрана (центр персонажа)
func place(x_ratio: float, instant: bool) -> void:
	_layout()
	var vp := get_viewport_rect().size
	var target := Vector2(vp.x * x_ratio - size.x / 2.0, vp.y - size.y + vp.y * (height_ratio - 1.0))
	if instant:
		position = target
	else:
		create_tween().set_trans(Tween.TRANS_SINE).tween_property(self, "position", target, move_sec)


func appear() -> void:
	dying = false
	create_tween().tween_property(self, "modulate:a", 1.0, fade_sec)


func vanish() -> void:
	dying = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, fade_sec)
	tw.tween_callback(queue_free)


func set_dim(on: bool) -> void:
	base.modulate = dim_color if on else Color.WHITE
	blink.modulate = base.modulate


func set_blink_texture(t: Texture2D) -> void:
	_blink_tex = t
	blink.texture = t
	if t == null:
		blink.visible = false


func _process(delta: float) -> void:
	if _blink_tex != null and not reacting:
		_blink_t -= delta
		if _blink_t <= 0.0:
			blink.visible = not blink.visible
			_blink_t = 0.14 if blink.visible else randf_range(2.5, 5.5)
	elif blink.visible:
		blink.visible = false
	if reacting and not _seq.is_empty():
		_seq_timer -= delta
		if _seq_timer <= 0.0:
			_next_frame()


## Реакция: seq — [[ключ_спрайта, мс], ...] (покадрово) или один спрайт на ms.
## loop_frames — для «погладить»: кадры зацикливаются до конца.
func react(sprite_key: String, seq: Array, ms: float, motion_kind: String, loop_frames: Array) -> void:
	reacting = true
	blink.visible = false
	if _react_tw:
		_react_tw.kill()
	motion.position = Vector2.ZERO
	motion.rotation_degrees = 0.0
	motion.scale = Vector2.ONE
	_seq = []
	if not seq.is_empty():
		_seq = seq.duplicate()
		_seq_k = 0
		_next_frame()
	else:
		set_sprite(sprite_key)
		if not loop_frames.is_empty():
			_seq = []
			for k: int in range(int((ms - 720.0) / 170.0)):
				_seq.append([loop_frames[k % loop_frames.size()], 170])
			_seq.append([sprite_key, 400])
			_seq.insert(0, [sprite_key, 320])
			_seq_k = 0
			_next_frame()
	_play_motion(motion_kind, ms)
	get_tree().create_timer(ms / 1000.0).timeout.connect(_end_react, CONNECT_ONE_SHOT)


func _next_frame() -> void:
	if _seq_k >= _seq.size():
		_seq = []
		return
	var f: Array = _seq[_seq_k]
	_seq_k += 1
	set_sprite("sera_" + str(f[0]) if not str(f[0]).begins_with("sera_") else str(f[0]))
	_seq_timer = float(f[1]) / 1000.0


func _end_react() -> void:
	if not is_instance_valid(self) or dying:
		return
	reacting = false
	_seq = []
	motion.position = Vector2.ZERO
	motion.rotation_degrees = 0.0
	motion.scale = Vector2.ONE
	if _base_key != "":
		set_sprite(_base_key)


func _play_motion(kind: String, ms: float) -> void:
	var h := size.y
	var w := size.x
	_react_tw = create_tween().set_trans(Tween.TRANS_SINE)
	match kind:
		"hop", "shy":
			for _k in 2:
				_react_tw.tween_property(motion, "position:y", -0.04 * h, 0.22)
				_react_tw.tween_property(motion, "position:y", 0.0, 0.33)
		"shake":
			for x: float in [-0.02, 0.02, -0.02, 0.02, 0.0]:
				_react_tw.tween_property(motion, "position:x", x * w, 0.12)
		"shiver":
			for _k in 6:
				_react_tw.tween_property(motion, "position:x", 0.004 * w, 0.06)
				_react_tw.tween_property(motion, "position:x", 0.0, 0.06)
		"wipe", "frown":
			var n := maxi(1, int(ms / 500.0))
			for _k in n:
				_react_tw.tween_property(motion, "rotation_degrees", -0.9, 0.18)
				_react_tw.tween_property(motion, "rotation_degrees", 0.5, 0.17)
				_react_tw.tween_property(motion, "rotation_degrees", 0.0, 0.15)
		"down":
			_react_tw.tween_property(motion, "position:y", 0.02 * h, 0.8)
		"pat":
			_react_tw.tween_property(motion, "scale", Vector2(1.03, 1.03), 0.35)
			_react_tw.tween_interval(maxf(0.1, ms / 1000.0 - 0.7))
			_react_tw.tween_property(motion, "scale", Vector2.ONE, 0.35)
		"giggle", "shout":
			for _k in 4:
				_react_tw.tween_property(motion, "position:y", -0.008 * h, 0.12)
				_react_tw.tween_property(motion, "position:y", 0.0, 0.14)
		_:
			_react_tw.tween_property(motion, "scale", Vector2(1.01, 1.01), 0.25)
			_react_tw.tween_property(motion, "scale", Vector2.ONE, 0.35)


## Наклон к экрану при наведении на вариант выбора (hoverLean)
func lean(on: bool, lean_key: String) -> void:
	if reacting:
		return
	set_sprite(lean_key if on else _base_key)
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(motion, "scale", Vector2(1.06, 1.06) if on else Vector2.ONE, 0.35)
	tw.parallel().tween_property(motion, "position:y", -0.01 * size.y if on else 0.0, 0.35)
