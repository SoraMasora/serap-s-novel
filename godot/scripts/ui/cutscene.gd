class_name Cutscene
extends Control
## Катсцена: кадры сменяют друг друга сами (клик — следующий), новый проявляется поверх старого.
## Камера одна на всю катсцену и движется непрерывно: у кадра может быть ключ
## cam:[u, v, zoom] (точка интереса в долях кадра и зум) — камера плавно доезжает до него
## за время кадра, без скачков на стыках. Без ключей — медленный общий наезд.
## anim — оверлей-спрайт поверх кадра: {spr, path:[[x,y]…] в px исходного кадра, ms, delay,
## scale:[от, до], wings} (например, таракан, вылетающий в окно).
## flip — покадровая анимация внутри кадра: список картинок, fps, once (не зацикливать),
## sfxAt:{номер_кадра: звук} (например, зажигалка на 6-м кадре).

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
var _cam := Vector3(0.5, 0.5, 1.0)
var _cam_tw: Tween
var _keyed := false
var _over: Array[Control] = []
var _flip: Dictionary = {}

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
	_keyed = frames.any(func(f: Dictionary) -> bool: return f.has("cam"))
	if _cam_tw:
		_cam_tw.kill()
	if _keyed:
		var c0: Array = frames[0].get("from", frames[0].get("cam"))
		_set_cam(Vector3(c0[0], c0[1], c0[2]))
	else:
		_set_cam(Vector3(0.5, 0.5, 1.0 if skip else zoom_from))
		if not skip:
			_cam_tw = create_tween()
			_cam_tw.tween_method(_set_cam, _cam, Vector3(0.5, 0.5, 1.0), total)
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
	_clear_overlays()
	if f.has("cam") and not _skip:
		var c: Array = f.cam
		if _cam_tw:
			_cam_tw.kill()
		_cam_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_cam_tw.tween_method(_set_cam, _cam, Vector3(c[0], c[1], c[2]), ms / 1000.0 + 0.4)
	if f.has("anim") and not _skip:
		_overlay(el, f.anim)
	_flip = {}
	if f.has("flip") and not _skip:
		_flip = {
			"el": el,
			"keys": f.flip,
			"dt": 1.0 / maxf(0.5, float(f.get("fps", 4))),
			"once": f.get("once", false),
			"sfx": f.get("sfxAt", {}),
			"t": 0.0,
			"i": 0
		}
	var my_k := _k
	get_tree().create_timer(ms / 1000.0).timeout.connect(
		func() -> void:
			if _active and _k == my_k:
				_next()
	)


func _process(delta: float) -> void:
	if _flip.is_empty() or not _active:
		return
	_flip.t += delta
	if _flip.t < _flip.dt:
		return
	_flip.t -= _flip.dt
	var n: int = _flip.keys.size()
	var i: int = _flip.i + 1
	if i >= n:
		if _flip.once:
			return
		i = 0
	_flip.i = i
	var el: TextureRect = _flip.el
	el.texture = Game.tex("bg", str(_flip.keys[i]))
	var k := str(i)
	if _flip.sfx.has(k):
		sfx_requested.emit(str(_flip.sfx[k]))


## Камера: зум вокруг точки интереса; точка не выходит за кадр, края всегда закрыты
func _set_cam(c: Vector3) -> void:
	_cam = c
	var z := maxf(1.0, c.z)
	stage.scale = Vector2(z, z)
	var sz := stage.size
	# pivot в пределах кадра: при зуме z точка pivot остаётся на месте — это и есть пан
	stage.pivot_offset = Vector2(clampf(c.x, 0.0, 1.0) * sz.x, clampf(c.y, 0.0, 1.0) * sz.y)


## Пиксели исходного кадра → координаты TextureRect (stretch «cover»)
func _img_to_local(el: TextureRect, p: Vector2) -> Vector2:
	var ts := el.texture.get_size() if el.texture else Vector2(1376, 768)
	var k := maxf(el.size.x / ts.x, el.size.y / ts.y)
	var off := (el.size - ts * k) * 0.5
	return off + p * k


func _overlay(el: TextureRect, a: Dictionary) -> void:
	var t := Game.tex("sprites", str(a.get("spr", "")))
	if t == null:
		return
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	el.add_child(holder)
	_over.append(holder)
	var spr := TextureRect.new()
	spr.texture = t
	spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ts := el.texture.get_size() if el.texture else Vector2(1376, 768)
	var k := maxf(el.size.x / ts.x, el.size.y / ts.y)
	spr.size = t.get_size() * k
	spr.position = -spr.size / 2.0
	spr.pivot_offset = spr.size / 2.0
	if a.get("wings", false):
		var wing := Control.new()
		wing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wing.draw.connect(_draw_wings.bind(wing, spr.size))
		holder.add_child(wing)
		var wt := wing.create_tween().set_loops()
		wt.tween_property(wing, "modulate:a", 0.25, 0.04)
		wt.tween_property(wing, "modulate:a", 0.9, 0.04)
	holder.add_child(spr)
	var path: Array = a.get("path", [])
	if path.size() < 2:
		return
	var pts: Array[Vector2] = []
	for q: Array in path:
		pts.append(_img_to_local(el, Vector2(q[0], q[1])))
	holder.position = pts[0]
	var sc: Array = a.get("scale", [1.0, 1.0])
	holder.scale = Vector2.ONE * float(sc[0])
	var dur := float(a.get("ms", 1500)) / 1000.0
	var tw := holder.create_tween()
	tw.tween_interval(float(a.get("delay", 0)) / 1000.0)
	var seg := dur / (pts.size() - 1)
	for i in range(1, pts.size()):
		var d := pts[i] - pts[i - 1]
		var f := float(i) / (pts.size() - 1)
		tw.tween_property(holder, "rotation", d.angle() + PI / 2.0, seg * 0.25)
		tw.parallel().tween_property(holder, "position", pts[i], seg).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(
			holder, "scale", Vector2.ONE * lerpf(float(sc[0]), float(sc[1]), f), seg
		)
	tw.tween_property(holder, "modulate:a", 0.0, 0.35)


func _draw_wings(w: Control, s: Vector2) -> void:
	var c := Color(0.95, 0.85, 0.7, 0.35)
	for side: float in [-1.0, 1.0]:
		w.draw_set_transform(
			Vector2(side * s.x * 0.28, -s.y * 0.02), side * 0.5, Vector2(0.55, 1.0)
		)
		w.draw_circle(Vector2.ZERO, s.y * 0.42, c)
	w.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _clear_overlays() -> void:
	for o in _over:
		if is_instance_valid(o):
			var tw := o.create_tween()
			tw.tween_property(o, "modulate:a", 0.0, 0.3)
			tw.tween_callback(o.queue_free)
	_over.clear()


func _done() -> void:
	visible = false
	_flip = {}
	_clear_overlays()
	if _cam_tw:
		_cam_tw.kill()
	stage.scale = Vector2.ONE
	finished.emit()


## Прервать (загрузка/откат)
func kill() -> void:
	_active = false
	_flip = {}
	visible = false
	if _cam_tw:
		_cam_tw.kill()
	for o in _over:
		if is_instance_valid(o):
			o.queue_free()
	_over.clear()
	stage.scale = Vector2.ONE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_next()
