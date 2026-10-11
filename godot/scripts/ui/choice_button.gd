class_name ChoiceButton
extends Button
## Вариант выбора в стиле Серы: тёмная «карточка-записка» с двойной бордовой рамкой и крестиками.
## Появляется каскадом (наклон, как наклейка), при наведении — карточка приподнимается,
## маркером прорисовывается неровное подчёркивание, слева качается белый бант-брелок,
## справа зажигается сердечко. При выборе карточка вспыхивает, остальные «сминаются» и падают.

signal hovered(on: bool)

@export var card_fill := Color(0.075, 0.03, 0.06, 0.93)
@export var card_fill_hover := Color(0.2, 0.04, 0.1, 0.96)
@export var border := Color(0.5, 0.08, 0.2, 1.0)
@export var border_hover := Color(1.0, 0.36, 0.55, 1.0)
@export var marker := Color(0.86, 0.12, 0.3, 0.9)
@export var appear_sec := 0.42
@export var cascade_sec := 0.09
@export var scribble_sec := 0.38

## 0..1 — доля наведения (рамка/заливка/подъём), прорисовка подчёркивания, качание банта
var hover := 0.0
var scribble := 0.0
var swing := 0.0
var flash := 0.0
var _t := 0.0
var _tilt := 0.0
var _seed := 0
var _tw: Tween

@onready var card: Control = $Card


func setup(label: String, index := 0) -> void:
	text = label
	_seed = hash(label)
	_tilt = (float(_seed % 7) - 3.0) * 0.0025
	_appear(index)


func _ready() -> void:
	mouse_entered.connect(set_hover.bind(true))
	mouse_exited.connect(set_hover.bind(false))
	focus_entered.connect(set_hover.bind(true))
	focus_exited.connect(set_hover.bind(false))
	card.draw.connect(_draw_card)
	resized.connect(func() -> void: pivot_offset = size / 2.0)


func _appear(index: int) -> void:
	modulate.a = 0.0
	card.position.x = -36.0
	rotation = _tilt * 4.0
	var d := index * cascade_sec
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, appear_sec * 0.7).set_delay(d)
	tw.tween_property(card, "position:x", 0.0, appear_sec).set_delay(d)
	tw.tween_property(self, "rotation", _tilt, appear_sec).set_delay(d)


func _process(delta: float) -> void:
	_t += delta
	if hover > 0.01 or swing > 0.01:
		card.queue_redraw()


func set_hover(on: bool) -> void:
	hovered.emit(on)
	if disabled:
		return
	if _tw:
		_tw.kill()
	var a := 1.0 if on else 0.0
	_tw = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_method(_set_hover, hover, a, 0.22)
	_tw.tween_method(_set_scribble, scribble, a, scribble_sec if on else 0.18)
	_tw.tween_property(self, "scale", Vector2.ONE * (1.025 if on else 1.0), 0.22)
	_tw.tween_property(self, "rotation", 0.0 if on else _tilt, 0.25)
	if on:
		swing = 1.0
		_tw.tween_method(_set_swing, 1.0, 0.0, 1.6).set_trans(Tween.TRANS_SINE)


func _set_hover(v: float) -> void:
	hover = v
	card.queue_redraw()


func _set_scribble(v: float) -> void:
	scribble = v
	card.queue_redraw()


func _set_swing(v: float) -> void:
	swing = v


func _set_flash(v: float) -> void:
	flash = v
	card.queue_redraw()


## Выбранная карточка: вспышка и «удар сердца»
func play_chosen() -> Tween:
	disabled = true
	var tw := create_tween().set_parallel()
	tw.tween_method(_set_flash, 1.0, 0.0, 0.5)
	tw.tween_property(self, "scale", Vector2.ONE * 1.07, 0.12).set_trans(Tween.TRANS_BACK)
	tw.chain().tween_property(self, "scale", Vector2.ONE, 0.18)
	tw.tween_property(self, "modulate:a", 0.0, 0.25).set_delay(0.12)
	return tw


## Невыбранные: сминаются и падают
func play_dismiss(index: int) -> Tween:
	disabled = true
	var dir := -1.0 if index % 2 == 0 else 1.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2(0.86, 0.6), 0.3)
	tw.tween_property(self, "rotation", dir * 0.09, 0.3)
	tw.tween_property(card, "position:y", 46.0, 0.32)
	tw.tween_property(self, "modulate:a", 0.0, 0.28)
	return tw


func _wob(i: int) -> float:
	return sin(float(_seed % 97) + i * 1.7) * 2.2


func _draw_card() -> void:
	var s := card.size
	var lift := -3.0 * hover
	var r := Rect2(Vector2(0, lift), s)
	var sb := StyleBoxFlat.new()
	sb.bg_color = card_fill.lerp(card_fill_hover, hover).lerp(Color(0.6, 0.12, 0.25, 0.96), flash)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.border_color = border.lerp(border_hover, hover)
	sb.shadow_color = Color(0, 0, 0, 0.55).lerp(Color(0.9, 0.12, 0.35, 0.45), hover)
	sb.shadow_size = int(10 + 12 * hover)
	sb.shadow_offset = Vector2(0, 4 + 3 * hover)
	sb.anti_aliasing = true
	card.draw_style_box(sb, r)
	var inner := StyleBoxFlat.new()
	inner.draw_center = false
	inner.set_corner_radius_all(3)
	inner.set_border_width_all(1)
	inner.border_color = Color(1, 0.62, 0.76, 0.1 + 0.18 * hover)
	inner.anti_aliasing = true
	card.draw_style_box(inner, r.grow(-5))
	# крестики по краям
	var cc := Color(0.78, 0.15, 0.31, 0.55 + 0.4 * hover)
	Deco.cross(card, Vector2(s.x - 22, s.y * 0.5 + lift), 5.0, cc)
	# бант-брелок слева качается
	var ang := sin(_t * 7.0) * 0.35 * swing
	var bp := Vector2(26, s.y * 0.5 + lift - 2)
	card.draw_set_transform(bp, ang, Vector2.ONE)
	var bc := Color(0.97, 0.95, 0.96, 0.55 + 0.45 * hover)
	Deco.bow(card, Vector2.ZERO, 9.0 + 1.5 * hover, bc)
	card.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# неровное подчёркивание маркером под текстом
	if scribble > 0.01:
		var font := get_theme_font("font")
		var fs := get_theme_font_size("font_size")
		var tw := minf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, s.x - 120)
		var x0 := (s.x - tw) * 0.5 - 6
		var y0 := s.y * 0.5 + fs * 0.62 + lift
		var pts := PackedVector2Array()
		var n := 18
		for i in n + 1:
			var f := float(i) / n
			if f > scribble:
				break
			pts.append(Vector2(x0 + (tw + 12) * f, y0 + _wob(i) * 0.6 + sin(f * PI) * 1.5))
		if pts.size() > 1:
			card.draw_polyline(pts, marker, 2.2, true)
	# сердечко справа загорается
	if hover > 0.01:
		var hp := Vector2(s.x - 48, s.y * 0.5 + lift)
		var hs := 6.0 + sin(_t * 5.0) * 0.6
		Deco.heart(card, hp, hs * hover, Color(1, 0.42, 0.62, hover))
