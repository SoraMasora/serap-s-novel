extends Node
## Курсоры «банка энергетика»: свой набор на каждое состояние мыши (стрелка, рука при наведении,
## нажатие, фон/ожидание, текст, запрет, перетаскивание) с покадровой анимацией.
## Кадры — лист art/ui/cursor_sheet.webp (tools/art/cursor.py), 64×64 на кадр; при старте
## режутся и уменьшаются под DPI экрана. Курсор аппаратный (системный) — не отстаёт от мыши;
## анимация — подмена картинки текущей формы, только когда меняется кадр.

const SHEET := "res://art/ui/cursor_sheet.webp"
const CELL := 64
const BASE_SIZE := 32
## Строка листа: кадров, fps, точка клика (в пикселях кадра 64×64), зациклено.
const ROWS := {
	&"arrow": [8, 14.0, Vector2(3, 3), false],
	&"point": [8, 10.0, Vector2(3, 3), true],
	&"click": [6, 20.0, Vector2(3, 3), false],
	&"busy": [8, 12.0, Vector2(3, 3), true],
	&"wait": [8, 12.0, Vector2(32, 32), true],
	&"ibeam": [2, 1.8, Vector2(32, 32), true],
	&"forbid": [1, 1.0, Vector2(3, 3), false],
	&"drag": [4, 8.0, Vector2(3, 3), true],
}
const ORDER := [&"arrow", &"point", &"click", &"busy", &"wait", &"ibeam", &"forbid", &"drag"]
const IDLE_SHINE_EVERY := 6.0

var size_px := BASE_SIZE
var _frames := {}  # row -> Array[Image]
var _shape := -1
var _row: StringName = &"arrow"
var _t := 0.0
var _frame := -1
var _idle := 0.0
var _clicking := false
var _enabled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless" or not ResourceLoader.exists(SHEET):
		return
	_enabled = true
	size_px = _pick_size()
	_cut()
	for shape in Input.CURSOR_HSPLIT + 2:
		_apply(shape, _row_for(shape), 0)
	get_tree().node_added.connect(_on_node_added)
	for n in get_tree().root.find_children("*", "Control", true, false):
		_on_node_added(n)


## Размер курсора: 32 px на обычном экране, больше на HiDPI/4K (как системный).
func _pick_size() -> int:
	var scr := DisplayServer.window_get_current_screen()
	var k := maxf(DisplayServer.screen_get_scale(scr), DisplayServer.screen_get_dpi(scr) / 96.0)
	k = maxf(k, DisplayServer.screen_get_size(scr).y / 1440.0)
	return clampi(int(roundf(BASE_SIZE * clampf(k, 1.0, 2.0) / 8.0)) * 8, BASE_SIZE, CELL)


func _cut() -> void:
	var sheet: Image = (load(SHEET) as Texture2D).get_image()
	if sheet.is_compressed():
		sheet.decompress()
	sheet.convert(Image.FORMAT_RGBA8)
	for y in ORDER.size():
		var row: StringName = ORDER[y]
		var list: Array[Image] = []
		for x in int(ROWS[row][0]):
			var im := sheet.get_region(Rect2i(x * CELL, y * CELL, CELL, CELL))
			if size_px != CELL:
				im.resize(size_px, size_px, Image.INTERPOLATE_LANCZOS)
			list.append(im)
		_frames[row] = list


func _row_for(shape: int) -> StringName:
	match shape:
		Input.CURSOR_POINTING_HAND:
			return &"point"
		Input.CURSOR_IBEAM:
			return &"ibeam"
		Input.CURSOR_BUSY:
			return &"busy"
		Input.CURSOR_WAIT:
			return &"wait"
		Input.CURSOR_FORBIDDEN:
			return &"forbid"
		Input.CURSOR_DRAG, Input.CURSOR_CAN_DROP, Input.CURSOR_MOVE:
			return &"drag"
	return &"arrow"


func _apply(shape: int, row: StringName, frame: int) -> void:
	var list: Array = _frames[row]
	var hot: Vector2 = ROWS[row][2] * (float(size_px) / CELL)
	Input.set_custom_mouse_cursor(list[clampi(frame, 0, list.size() - 1)], shape, hot.round())


## Кнопки, ползунки и переключатели — «рука» (как ссылки в системе).
func _on_node_added(n: Node) -> void:
	if n is BaseButton or n is Slider or n is TabBar:
		var c := n as Control
		if c.mouse_default_cursor_shape == Control.CURSOR_ARROW:
			c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			c.set_meta(&"cursor_auto", true)


func _input(e: InputEvent) -> void:
	if not _enabled:
		return
	var mb := e as InputEventMouseButton
	if mb and mb.pressed and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if _row in [&"arrow", &"point", &"click"]:
			_clicking = true
			_set_row(&"click")


func _process(delta: float) -> void:
	if not _enabled:
		return
	_fix_disabled()
	var shape := _current_shape()
	if shape != _shape:
		if _shape >= 0:
			_apply(_shape, _row_for(_shape), 0)
		_shape = shape
		_clicking = false
		_set_row(_row_for(shape))
	_t += delta
	var spec: Array = ROWS[_row]
	var n: int = spec[0]
	var f := int(_t * float(spec[1]))
	if _row == &"arrow":
		_idle += delta
		f = 0 if _idle < IDLE_SHINE_EVERY else 1 + int((_idle - IDLE_SHINE_EVERY) * float(spec[1]))
		if f >= n:
			_idle = 0.0
			f = 0
	elif spec[3]:
		f %= n
	elif f >= n:
		if _clicking:
			_clicking = false
			_set_row(_row_for(_shape))
			return
		f = n - 1
	if f != _frame:
		_frame = f
		_apply(_shape, _row, f)


func _set_row(row: StringName) -> void:
	_row = row
	_t = 0.0
	_idle = 0.0
	_frame = -1


## Форма под мышью: системная, а если она «стрелка» — та, что просит контрол под курсором
## (на некоторых системах/без фокуса окна Godot не успевает переключить форму сам).
func _current_shape() -> int:
	var shape: int = Input.get_current_cursor_shape()
	if shape == Input.CURSOR_ARROW:
		var h := get_viewport().gui_get_hovered_control()
		if h:
			shape = h.get_cursor_shape(h.get_local_mouse_position())
	return shape


## Неактивная кнопка — обычная стрелка, а не «рука».
func _fix_disabled() -> void:
	var h := get_viewport().gui_get_hovered_control()
	if h is BaseButton and h.has_meta(&"cursor_auto"):
		var want := (
			Control.CURSOR_ARROW if (h as BaseButton).disabled else Control.CURSOR_POINTING_HAND
		)
		if h.mouse_default_cursor_shape != want:
			h.mouse_default_cursor_shape = want
