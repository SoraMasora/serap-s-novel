class_name CharacterView
extends Control
## Спрайт персонажа на сцене: появление/уход, позиция, «дыхание», моргание, реакции.
## Живость: мягкая смена эмоций (кроссфейд + движение по настроению), покачивание при репликах,
## случайные переносы веса в простое, поза головы для «задумчивых» эмоций.

@export var height_ratio := 1.04
@export var fade_sec := 0.5
@export var move_sec := 0.6
@export var idle_period_sec := 6.0
@export var dim_color := Color(0.6, 0.6, 0.6, 1)
@export var xfade_sec := 0.22
## Наклон (°) для эмоций, который держится, пока эмоция на экране
@export var poses := {"thinking": -1.3, "suspicious": 1.1, "tease": 0.9, "smirk": 0.7, "shy": -0.6}

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
var _emote_tw: Tween
var _shift_t := 0.0
var _shift_tw: Tween

@onready var motion: Control = $Motion
@onready var emote_node: Control = $Motion/Emote
@onready var idle: Control = $Motion/Emote/Idle
@onready var prev: TextureRect = $Motion/Emote/Idle/Prev
@onready var base: TextureRect = $Motion/Emote/Idle/Base
@onready var blink: TextureRect = $Motion/Emote/Idle/Blink


func _ready() -> void:
	modulate.a = 0.0
	blink.visible = false
	_blink_t = randf_range(2.0, 5.0)
	_shift_t = randf_range(6.0, 11.0)
	prev.visible = false
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
	var changed := _base_key != "" and _base_key != key
	_base_key = key
	if not reacting:
		if changed and base.texture != null and modulate.a > 0.5:
			_crossfade()
		set_sprite(key)
		if changed:
			emote(key.get_slice("_", 1))


## Старый спрайт плавно гаснет поверх нового — смена эмоции без «щелчка»
func _crossfade() -> void:
	prev.texture = base.texture
	prev.visible = true
	prev.modulate = Color(base.modulate, 1.0)
	prev.move_to_front()
	blink.move_to_front()
	var tw := create_tween()
	tw.tween_property(prev, "modulate:a", 0.0, xfade_sec)
	tw.tween_callback(func() -> void: prev.visible = false)


## Движение по настроению при смене эмоции (на отдельном слое — не мешает реакциям и наклону)
func emote(mood: String) -> void:
	if _emote_tw:
		_emote_tw.kill()
	var h := size.y
	var w := size.x
	emote_node.pivot_offset = Vector2(w / 2.0, h)
	var pose: float = poses.get(mood, 0.0)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_emote_tw = tw
	match mood:
		"happy", "laugh", "giggle", "vsign":
			for k in 2:
				tw.tween_property(emote_node, "position:y", -0.022 * h / (k + 1), 0.16)
				tw.tween_property(emote_node, "position:y", 0.0, 0.2).set_ease(Tween.EASE_IN)
		"surprised", "scared", "ouch":
			tw.tween_property(emote_node, "scale", Vector2(0.985, 1.025), 0.09)
			tw.parallel().tween_property(emote_node, "position:y", -0.03 * h, 0.12)
			tw.tween_property(emote_node, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
			tw.parallel().tween_property(emote_node, "position:y", 0.0, 0.3)
			if mood == "scared":
				for x: float in [0.004, -0.004, 0.003, -0.002, 0.0]:
					tw.tween_property(emote_node, "position:x", x * w, 0.05)
		"angry", "huff", "pout", "disgust", "shout":
			tw.tween_property(emote_node, "scale", Vector2(1.02, 0.982), 0.1)
			tw.tween_property(emote_node, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK)
			for x: float in [-0.006, 0.006, -0.003, 0.0]:
				tw.parallel().tween_property(emote_node, "position:x", x * w, 0.07)
		"sad", "saddown", "sadfrown", "sadwipe", "tired", "cold":
			tw.tween_property(emote_node, "position:y", 0.014 * h, 0.7)
			tw.parallel().tween_property(emote_node, "scale", Vector2(1.0, 0.992), 0.7)
			tw.tween_property(emote_node, "position:y", 0.006 * h, 1.2)
			tw.parallel().tween_property(emote_node, "scale", Vector2.ONE, 1.2)
		"shy", "soft":
			tw.tween_property(emote_node, "rotation_degrees", -1.4, 0.35)
			tw.tween_property(emote_node, "rotation_degrees", 0.6, 0.45)
			tw.tween_property(emote_node, "rotation_degrees", pose, 0.4)
		_:
			tw.tween_property(emote_node, "scale", Vector2(1.006, 1.006), 0.14)
			tw.tween_property(emote_node, "scale", Vector2.ONE, 0.22)
	if not mood.begins_with("sad") and mood != "tired" and mood != "cold":
		tw.parallel().tween_property(emote_node, "position:y", 0.0, 0.3).set_delay(0.4)
	if mood != "shy" and mood != "soft":
		tw.parallel().tween_property(emote_node, "rotation_degrees", pose, 0.45)


## Лёгкий «кивок» на реплике персонажа — будто говорит
func talk() -> void:
	if reacting or dying:
		return
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	var y := motion.position.y
	tw.tween_property(motion, "position:y", y - 0.006 * size.y, 0.12)
	tw.tween_property(motion, "position:y", y, 0.2)
	tw.tween_property(motion, "position:y", y - 0.003 * size.y, 0.12)
	tw.tween_property(motion, "position:y", y, 0.18)


## Перенос веса в простое: чуть в сторону и обратно
func _weight_shift() -> void:
	if _shift_tw and _shift_tw.is_running():
		return
	var dir := -1.0 if randf() < 0.5 else 1.0
	_shift_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shift_tw.tween_property(self, "rotation_degrees", dir * 0.5, 1.4)
	_shift_tw.tween_interval(randf_range(1.0, 2.5))
	_shift_tw.tween_property(self, "rotation_degrees", 0.0, 1.6)


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
	var target := Vector2(
		vp.x * x_ratio - size.x / 2.0, vp.y - size.y + vp.y * (height_ratio - 1.0)
	)
	if instant:
		position = target
	else:
		create_tween().set_trans(Tween.TRANS_SINE).tween_property(
			self, "position", target, move_sec
		)


func appear() -> void:
	dying = false
	if modulate.a < 0.05:
		motion.position.y = 0.025 * size.y
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC)
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(motion, "position:y", 0.0, fade_sec * 1.3)
		tw.tween_property(self, "modulate:a", 1.0, fade_sec)
	else:
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
	if not reacting and not dying:
		_shift_t -= delta
		if _shift_t <= 0.0:
			_shift_t = randf_range(8.0, 14.0)
			_weight_shift()
	if reacting and not _seq.is_empty():
		_seq_timer -= delta
		if _seq_timer <= 0.0:
			_next_frame()


## Реакция: seq — [[ключ_спрайта, мс], ...] (покадрово) или один спрайт на ms.
## loop_frames — для «погладить»: кадры зацикливаются до конца.
func react(
	sprite_key: String, seq: Array, ms: float, motion_kind: String, loop_frames: Array
) -> void:
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
		"clap":
			for _k in 3:
				_react_tw.tween_property(motion, "position:y", -0.012 * h, 0.13)
				_react_tw.tween_property(motion, "position:y", 0.0, 0.17)
		"angry":
			for x: float in [-0.006, 0.006, -0.006, 0.006, -0.004, 0.004, 0.0]:
				_react_tw.tween_property(motion, "position:x", x * w, 0.07)
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
