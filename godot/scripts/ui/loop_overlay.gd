class_name LoopOverlay
extends Control
## Additive presentation layer. Generation cancels timers on restore/title.

signal finished
signal death_finished
signal warning_accepted

var _generation := 0
var _next: Callable
var _locked := false

@onready var image: TextureRect = $Image
@onready var caption: Label = $Caption
@onready var next_button: Button = $Next


func _ready() -> void:
	next_button.pressed.connect(_advance)
	visible = false


func kill() -> void:
	_generation += 1
	_next = Callable()
	_locked = false
	visible = false


func _reset() -> int:
	kill()
	visible = true
	image.texture = null
	image.visible = true
	image.flip_h = false
	image.flip_v = false
	image.modulate = Color.WHITE
	caption.text = ""
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
	for id: String in ids:
		if g != _generation:
			return
		image.texture = Game.tex("bg", Game.db.loop.DEATHS[id].img)
		Audio.sfx("glitch")
		await (
			get_tree().create_timer(0.08 if fast else (1.1 if Game.settings.soft else 0.42)).timeout
		)
	if g == _generation:
		_done()


func subliminal(id: String) -> void:
	if Game.settings.soft or visible:
		return
	if id == "last":
		var ids: Array = Game.memory.data.deaths
		id = ids[-1] if not ids.is_empty() else ""
	var key: String = Game.db.loop.DEATHS.get(id, {}).get("img", id)
	var texture := Game.tex("bg", key)
	if texture == null:
		return
	var g := _reset()
	_locked = true
	next_button.visible = false
	image.texture = texture
	await get_tree().create_timer(0.11).timeout
	if g == _generation:
		kill()


func scream() -> void:
	var g := _reset()
	_locked = true
	next_button.visible = false
	image.visible = false
	Audio.hush()
	await get_tree().create_timer(0.6).timeout
	if g != _generation:
		return
	image.texture = Game.tex("bg", "x_scream")
	image.visible = true
	caption.text = "!ЦЕНОК ЕН ОТЭ"
	caption.modulate = Color(1.0, 0.12, 0.15)
	Audio.sfx("scream")
	for i in 32:
		if g != _generation:
			return
		if not Game.settings.soft:
			image.flip_v = i % 10 in [1, 6]
			image.flip_h = i % 10 in [3, 9]
			image.modulate = Color(0.3, 1.4, 1.5) if i % 10 == 4 else Color.WHITE
			image.visible = i % 10 != 7
		await get_tree().create_timer(0.085).timeout
	if g != _generation:
		return
	image.visible = false
	caption.text = ""
	await get_tree().create_timer(1.3).timeout
	if g == _generation:
		kill()
		death_finished.emit()


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
