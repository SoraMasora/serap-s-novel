class_name ChoiceButton
extends Button
## Вариант выбора (#choices button.vbtn из css): чёрно-красный градиент, рамка; при наведении —
## подсветка и лозы, «прорастающие» снизу вверх (clip-path inset(100%→0), 1.9 с; правая +0.3 с).

signal hovered(on: bool)

## Высота лозы относительно кнопки (.vine.l/.r{height:165%}), пропорции текстуры 516/1192
@export var vine_height_ratio := 1.65
@export var vine_aspect := 516.0 / 1192.0
## Выступ наружу: translate(∓78%)
@export var vine_shift := 0.78
@export var grow_sec := 1.9
@export var fade_in_sec := 1.1
@export var retract_sec := 0.9
@export var fade_out_sec := 0.7
@export var right_delay_sec := 0.3
@export var glow_color := Color(1, 0.157, 0.353, 0.8)

var reveal: Array[float] = [0.0, 0.0]
var _tw: Tween

@onready var hint_label: Label = $Hint
@onready var vines: Array[Control] = [$VineL, $VineR]


func setup(label: String, hint: String) -> void:
	text = label
	hint_label.text = hint
	hint_label.visible = hint != ""
	if hint != "":
		custom_minimum_size.y = 72.0


func _ready() -> void:
	mouse_entered.connect(set_hover.bind(true))
	mouse_exited.connect(set_hover.bind(false))
	resized.connect(_layout_vines)
	_layout_vines()


## Лозы: центр по вертикали, высота 165 %, выступ наружу на 78 % ширины, видна доля reveal снизу
func _layout_vines() -> void:
	var h := size.y * vine_height_ratio
	var w := h * vine_aspect
	var bottom := size.y * 0.5 + h * 0.5
	for i in vines.size():
		var v := vines[i]
		v.position = Vector2(-w * vine_shift if i == 0 else size.x - w * (1.0 - vine_shift), 0)
		v.size = Vector2(w, h * reveal[i])
		v.position.y = bottom - h * reveal[i]
		var img: TextureRect = v.get_node("Img")
		img.offset_top = -h


func _set_reveal(f: float, i: int) -> void:
	reveal[i] = f
	_layout_vines()


func set_hover(on: bool) -> void:
	hovered.emit(on)
	if disabled:
		return
	if _tw:
		_tw.kill()
	var a := 1.0 if on else 0.0
	_tw = create_tween().set_parallel()
	_tw.tween_property($FrameHover, "modulate:a", a, 0.3)
	_tw.tween_property($BgHover, "modulate:a", a, 0.3)
	add_theme_color_override("font_shadow_color", glow_color if on else Color(0, 0, 0, 0))
	for i in vines.size():
		var delay := right_delay_sec * i if on else 0.0
		(
			_tw
			. tween_method(_set_reveal.bind(i), reveal[i], a, grow_sec if on else retract_sec)
			. set_delay(delay)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_OUT)
		)
		var fade := fade_in_sec if on else fade_out_sec
		_tw.tween_property(vines[i], "modulate:a", a, fade).set_delay(delay)
