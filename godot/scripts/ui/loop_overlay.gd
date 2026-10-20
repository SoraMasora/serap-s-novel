class_name LoopOverlay
extends Control
## Additive presentation layer. Generation cancels timers on restore/title.
## 0.7.4: screamer variants (LOOP.SCARE.order by death count), glitch shader, decaying shake,
## zoom punch, cut to silence and a fake title. Soft mode: one calm frame, no strobe/shake/negative.

signal finished
signal death_finished
signal warning_accepted
signal ambush_finished

const FACE := "x_face"
const SMILE := "x_smile"
const SERAPH := "x_scream"
const BLACK_ALPHA := 0.96
const FX_KEYS: Array[String] = ["split", "slices", "noise", "invert", "redden"]

## Dev/test: force a screamer variant (burst, lull, title, whisper, false); "" — by death count.
@export var scare_override := ""
@export var shake_px := 28.0
@export var lull_wait_sec := Vector2(2.6, 4.2)
@export var ambush_wait_sec := Vector2(2.2, 4.4)
@export var dead_air_sec := Vector2(1.7, 2.6)

var _generation := 0
var _next: Callable
var _locked := false
var _ambush := false
var _shake := 0.0
var _rng := RandomNumberGenerator.new()
var _zoom: Tween
var _hit_tw: Tween
var _fade: Tween

@onready var black: ColorRect = $Black
@onready var image: TextureRect = $Image
@onready var hit: ColorRect = $Hit
@onready var caption: Label = $Caption
@onready var next_button: Button = $Next
@onready var glitch: ShaderMaterial = image.material


func _ready() -> void:
	next_button.pressed.connect(_advance)
	image.resized.connect(_center_pivot)
	_rng.randomize()
	visible = false


func kill() -> void:
	_generation += 1
	_next = Callable()
	_locked = false
	_ambush = false
	visible = false
	_calm_fx()


func _reset() -> int:
	kill()
	visible = true
	black.color = Color(0, 0, 0, BLACK_ALPHA)
	image.texture = null
	image.visible = true
	image.flip_h = false
	image.flip_v = false
	image.modulate = Color.WHITE
	caption.text = ""
	caption.visible = true
	caption.modulate = Color.WHITE
	next_button.visible = true
	next_button.text = "Продолжить"
	return _generation


func warning() -> void:
	_reset()
	caption.text = (
		"Предупреждение\n\nСюжет содержит смерть, самоубийство, религиозное насилие, "
		+ "резкий громкий скример и мерцание.\nВ настройках можно смягчить вспышки.\n\n"
		+ "Если тебе тяжело, сделай паузу и поговори с кем-то рядом."
	)
	next_button.text = "Понимаю. Продолжить"
	_next = func() -> void:
		kill()
		warning_accepted.emit()


func sms(data: Dictionary, fmt: Callable) -> void:
	_reset()
	caption.text = (
		"%s\n\n%s\n\n%s"
		% [data.get("time", "23:47"), data.get("from", ""), fmt.call(data.get("text", ""))]
	)
	_next = _done


func omen(lines: Array, fmt: Callable, fast: bool) -> void:
	var g := _reset()
	var index := [0]
	var page := [0]
	_next = func() -> void:
		if index[0] >= lines.size():
			_done()
			return
		caption.text = fmt.call(str(lines[index[0]]))
		index[0] += 1
		page[0] += 1
		var p: int = page[0]
		Audio.sfx("toll")
		get_tree().create_timer(0.3 if fast else 3.0).timeout.connect(
			func() -> void:
				if g == _generation and p == page[0]:
					_advance()
		)
	_advance()


func montage(ids: Array, fast: bool) -> void:
	var g := _reset()
	_next = Callable()
	next_button.visible = false
	var soft := bool(Game.settings.soft)
	for id: String in ids:
		var death: Dictionary = Game.db.loop.DEATHS[id]
		# 0.7.4: the last moment (Sera in frame) flickers before the aftermath — not in soft mode
		var keys: Array = (
			[death.img] if soft or fast or not death.has("cg") else [death.cg, death.img]
		)
		for key: String in keys:
			if g != _generation:
				return
			image.texture = Game.tex("bg", key)
			Audio.sfx("glitch")
			var sec := 0.08 if fast else (1.1 if soft else (0.24 if key != death.img else 0.36))
			await get_tree().create_timer(sec).timeout
	if g == _generation:
		_done()


func subliminal(id: String) -> void:
	if Game.settings.soft or visible:
		return
	if id == "last":
		var ids: Array = Game.memory.data.deaths
		id = ids[-1] if not ids.is_empty() else ""
	var death: Dictionary = Game.db.loop.DEATHS.get(id, {})
	var texture := Game.tex("bg", str(death.get("cg", death.get("img", id))))
	if texture == null:
		texture = Game.tex("bg", str(death.get("img", id)))
	if texture == null:
		return
	var g := _reset()
	_locked = true
	next_button.visible = false
	image.texture = texture
	glitch.set_shader_parameter("split", 0.012)
	glitch.set_shader_parameter("seed", _rng.randf() * 100.0)
	await get_tree().create_timer(0.11).timeout
	if g == _generation:
		kill()


## Screamer variant for this death: LOOP.SCARE.order by the number of deaths already seen.
func pick_scare() -> String:
	if Game.settings.soft:
		return "burst"
	if scare_override != "":
		return scare_override
	var order: Array = Game.db.loop.get("SCARE", {}).get("order", ["burst"])
	if order.is_empty():
		return "burst"
	return str(order[Game.memory.data.deaths.size() % order.size()])


## True once after the "title" variant: loop_main shows the menu, then calls ambush().
func take_ambush() -> bool:
	var a := _ambush
	_ambush = false
	return a


func scream(kind := "") -> void:
	var g := _reset()
	_locked = true
	next_button.visible = false
	image.visible = false
	Audio.hush()
	_warm()
	if kind == "" or Game.settings.soft:
		kind = pick_scare()
	match kind:
		"lull":
			await _lull(g)
			if g == _generation:
				await _bang(g, FACE, 1.0)
		"whisper":
			await _reveal()
			if g == _generation:
				await _bang(g, FACE, 1.0)
		"false":
			await _hold(0.5)
			if g == _generation:
				await _bang(g, SERAPH, 0.22)
			if g == _generation:
				await _dead_air()
			if g == _generation:
				await _bang(g, FACE, 1.15)
		"title":
			await _fade_out()
			if g == _generation:
				kill()
				_ambush = true
				death_finished.emit()
			return
		_:
			# soft: no long black pause before the calm frame
			await _hold(0.15 if Game.settings.soft else 0.6)
			if g == _generation:
				await _bang(g, FACE, 1.0)
	if g != _generation:
		return
	await _cut()
	if g == _generation:
		kill()
		death_finished.emit()


## "The end" was the menu: the hit lands over the title screen — on the first click or by itself.
func ambush() -> void:
	var g := _reset()
	black.color = Color(0, 0, 0, 0)
	image.visible = false
	next_button.visible = false
	_warm()
	_next = func() -> void: _ambush_hit(g)
	await get_tree().create_timer(_rng.randf_range(ambush_wait_sec.x, ambush_wait_sec.y)).timeout
	if g == _generation and _next.is_valid():
		_ambush_hit(g)


func _ambush_hit(g: int) -> void:
	if g != _generation:
		return
	_next = Callable()
	_locked = true
	await _bang(g, FACE, 0.9)
	if g != _generation:
		return
	await _cut()
	if g == _generation:
		kill()
		ambush_finished.emit()


## Decode the screamer frames before the hit so the first strobe frame is not late.
func _warm() -> void:
	for key: String in [FACE, SMILE, SERAPH]:
		Game.tex("bg", key)


func _hold(sec: float) -> void:
	black.color = Color(0, 0, 0, BLACK_ALPHA)
	await get_tree().create_timer(sec).timeout


## Silence over the still scene (input swallowed), two frames of her smile, silence again.
func _lull(g: int) -> void:
	black.color = Color(0, 0, 0, 0)
	_fade_black(0.4, 3.5)
	await get_tree().create_timer(_rng.randf_range(lull_wait_sec.x, lull_wait_sec.y)).timeout
	if g != _generation:
		return
	image.texture = Game.tex("bg", SMILE)
	image.modulate.a = 0.6
	image.visible = true
	await get_tree().create_timer(0.07).timeout
	if g != _generation:
		return
	image.visible = false
	image.modulate.a = 1.0
	await get_tree().create_timer(_rng.randf_range(1.3, 2.4)).timeout


## After her whispered line: black, a breath right at the ear, her smile — silent — then the hit.
func _reveal() -> void:
	black.color = Color(0, 0, 0, 1)
	Audio.sfx("breath")
	image.texture = Game.tex("bg", SMILE)
	image.visible = true
	_zoom_to(Vector2(1.0, 1.0), Vector2(1.07, 1.07), 0.9)
	await get_tree().create_timer(_rng.randf_range(0.55, 0.85)).timeout


func _dead_air() -> void:
	Audio.hush()
	_calm_fx()
	image.visible = false
	caption.text = ""
	black.color = Color(0, 0, 0, 1)
	await get_tree().create_timer(_rng.randf_range(dead_air_sec.x, dead_air_sec.y)).timeout


func _fade_out() -> void:
	black.color = Color(0, 0, 0, 0)
	_fade_black(1.0, 1.6)
	await get_tree().create_timer(2.2).timeout


## The hit itself: her face lunges at the camera; strobe of face / seraph / negative / black.
func _bang(g: int, face: String, length: float) -> void:
	var soft := bool(Game.settings.soft)
	var scare: Dictionary = Game.db.loop.get("SCARE", {})
	var line := str(scare.get("caption", "!ЦЕНОК ЕН ОТЭ"))
	var flashes: Array = scare.get("flash", [])
	Audio.hush()
	if soft:
		Audio.sfx("scream")  # soft: the original scream only, no new shriek
	else:
		Audio.sfx("shriek")
		Audio.sfx("scream", -7.0)
	black.color = Color(0, 0, 0, 1)
	image.texture = Game.tex("bg", face)
	image.visible = true
	image.modulate = Color.WHITE
	caption.text = line
	caption.modulate = Color(1.0, 0.12, 0.15)
	caption.visible = true
	if soft:
		_zoom_to(Vector2.ONE, Vector2(1.04, 1.04), 2.4)
		await get_tree().create_timer(2.7 * length).timeout
		return
	_zoom_to(Vector2(0.84, 0.84), Vector2(1.18, 1.18), 0.09, 1.34, 2.2 * length)
	_flash(Color.WHITE, 0.95)
	_shake = 1.0
	var steps := maxi(3, int(round(30.0 * length)))
	for i in steps:
		if g != _generation:
			return
		var roll := _rng.randf()
		var key := face
		if i % 8 == 5:
			key = SERAPH
		elif i % 11 == 8:
			key = SMILE if face != SMILE else FACE
		image.texture = Game.tex("bg", key)
		image.visible = i % 9 != 7 and roll > 0.05
		image.flip_h = i % 13 == 6
		image.flip_v = i % 17 == 10
		glitch.set_shader_parameter("invert", 1.0 if i % 10 == 3 or roll > 0.95 else 0.0)
		glitch.set_shader_parameter("split", _rng.randf_range(0.002, 0.032))
		glitch.set_shader_parameter("slices", _rng.randf_range(0.25, 1.0) if roll > 0.45 else 0.0)
		glitch.set_shader_parameter("noise", _rng.randf_range(0.0, 0.45))
		glitch.set_shader_parameter("redden", 0.75 if i % 7 == 4 else 0.0)
		glitch.set_shader_parameter("seed", _rng.randf() * 100.0)
		caption.visible = i % 3 != 2
		caption.text = line
		if i % 9 == 4 and not flashes.is_empty():
			caption.text = str(flashes[int(i / 9.0) % flashes.size()])
		if i % 12 == 11:
			_flash(Color(0.85, 0.04, 0.07), 0.65)
			_shake = maxf(_shake, 0.75)
		await get_tree().create_timer(_rng.randf_range(0.045, 0.09)).timeout


## Hard cut: black, the scream stops mid-breath, only a ringing in the ears.
func _cut() -> void:
	Audio.hush()
	Audio.sfx("ring", -4.0)
	_calm_fx()
	image.visible = false
	caption.text = ""
	black.color = Color(0, 0, 0, 1)
	await get_tree().create_timer(1.5).timeout


func _zoom_to(from: Vector2, to: Vector2, sec: float, creep := 0.0, creep_sec := 0.0) -> void:
	if _zoom:
		_zoom.kill()
	_center_pivot()
	image.scale = from
	_zoom = create_tween()
	var punch := _zoom.tween_property(image, "scale", to, sec)
	punch.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if creep > 0.0:
		_zoom.tween_property(image, "scale", Vector2(creep, creep), creep_sec).set_trans(
			Tween.TRANS_SINE
		)


func _fade_black(alpha: float, sec: float) -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(black, "color:a", alpha, sec)


func _flash(color: Color, alpha: float) -> void:
	if _hit_tw:
		_hit_tw.kill()
	hit.color = color
	hit.modulate.a = alpha
	_hit_tw = create_tween()
	_hit_tw.tween_property(hit, "modulate:a", 0.0, 0.2)


func _calm_fx() -> void:
	_shake = 0.0
	for tw: Tween in [_zoom, _hit_tw, _fade]:
		if tw:
			tw.kill()
	image.scale = Vector2.ONE
	image.position = Vector2.ZERO
	hit.modulate.a = 0.0
	for k: String in FX_KEYS:
		glitch.set_shader_parameter(k, 0.0)


func _center_pivot() -> void:
	image.pivot_offset = image.size / 2.0


func _process(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(0.0, _shake - delta * 1.5)
	var a := shake_px * _shake * _shake
	image.position = Vector2(_rng.randf_range(-a, a), _rng.randf_range(-a, a))
	if _shake <= 0.0:
		image.position = Vector2.ZERO


func _done() -> void:
	kill()
	finished.emit()


func _advance() -> void:
	if not _locked and _next.is_valid():
		_next.call()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		_advance()


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("vn_advance") or _locked):
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("vn_advance"):
			_advance()
