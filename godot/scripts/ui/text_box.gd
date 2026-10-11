class_name TextBox
extends Control
## Окно реплик в стиле Серы: сливовая плашка с двойной бордовой рамкой и крестиками,
## имя на ленте с белым бантом, печать текста (Comfortaa), сердечко «дальше»,
## кнопки-иконки (Авто · Пропуск · Заметки · Журнал · Сохр. · Загр. · Кадр · Меню).

signal clicked
signal typing_done
signal control_pressed(action: String)

## Цвет имени по типу говорящего (sera — по умолчанию)
@export var name_colors := {
	"sera": Color("#ffd3e2"),
	"gg": Color("#d6e8ff"),
	"father": Color("#e6e6ec"),
	"unk": Color("#e8c9d6"),
	"npc": Color("#ffe6c4"),
}
## Цвет ленты под именем
@export var ribbon_colors := {
	"sera": Color("#8e1a3d"),
	"gg": Color("#2c3f6e"),
	"father": Color("#4a4652"),
	"unk": Color("#5a2a44"),
	"npc": Color("#7a4a2a"),
}
@export var narr_color := Color("#d9cfdc")
@export var thought_color := Color("#c3d2f2")
@export var text_color := Color("#f6eef2")
## Сдвиг текста вправо, когда слева виден портрет героя (карточка-полароид)
@export var side_shift := 168.0

var speed := 28.0
var typing := false
var _acc := 0.0
var _body_left := 52.0
var _name_left := 26.0
var _bar_left := 52.0

@onready var name_box: Label = $NameBox
@onready var ribbon: Deco = $NameBox/Ribbon
@onready var thought_tag: Label = $Body/ThoughtTag
@onready var text: RichTextLabel = $Body/Text
@onready var next_mark: Control = $Next
@onready var thought_bar: ColorRect = $ThoughtBar
@onready var underline: TextureRect = $NameBox/Underline
@onready var controls: HBoxContainer = $Controls
@onready var panel: Deco = $Panel


func _ready() -> void:
	_body_left = $Body.offset_left
	_name_left = name_box.offset_left
	_bar_left = thought_bar.offset_left
	for c: Node in controls.get_children():
		var b := c as Button
		if b:
			b.pressed.connect(func() -> void: control_pressed.emit(String(b.name).to_lower()))
	# сердечко «дальше»: мягкая пульсация и покачивание
	var mark: Control = $Next/Mark
	mark.pivot_offset = Vector2(8, 8)
	var tw := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(mark, "scale", Vector2(1.18, 1.18), 0.5)
	tw.parallel().tween_property(mark, "position:y", 3.0, 0.5)
	tw.tween_property(mark, "scale", Vector2.ONE, 0.7)
	tw.parallel().tween_property(mark, "position:y", 0.0, 0.7)
	next_mark.visible = false


## kind: sera/gg/father/unk/npc; thought — мысли героя; narr — без имени
func show_line(
	display_name: String, kind: String, line: String, thought: bool, instant: bool
) -> void:
	var was := name_box.text
	name_box.visible = display_name != ""
	name_box.text = display_name
	var col: Color = name_colors.get(kind, name_colors.sera)
	name_box.add_theme_color_override("font_color", col)
	name_box.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	ribbon.fill = ribbon_colors.get(kind, ribbon_colors.sera)
	underline.self_modulate = col
	name_box.offset_right = name_box.offset_left
	if display_name != "" and display_name != was:
		name_box.pivot_offset = Vector2(0, 17)
		name_box.scale = Vector2(0.92, 0.92)
		name_box.modulate.a = 0.0
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(name_box, "scale", Vector2.ONE, 0.28)
		tw.tween_property(name_box, "modulate:a", 1.0, 0.2)
	thought_tag.visible = thought
	thought_bar.visible = thought
	$Body.offset_left = thought_bar.offset_left + (16.0 if thought else 0.0)
	if thought:
		_fit_thought_bar.call_deferred()
	var narr := display_name == "" and not thought
	text.add_theme_color_override(
		"default_color", thought_color if thought else (narr_color if narr else text_color)
	)
	var esc := line.replace("[", "[lb]")
	text.text = "[i]%s[/i]" % esc if (thought or narr) else esc
	text.visible_characters = 0
	_acc = 0.0
	typing = true
	next_mark.visible = false
	if instant or speed <= 0.0:
		finish_typing()


func finish_typing() -> void:
	typing = false
	text.visible_characters = -1
	next_mark.visible = true
	typing_done.emit()


func _process(delta: float) -> void:
	if not typing:
		return
	_acc += delta * maxf(5.0, speed)
	text.visible_characters = int(_acc)
	if text.visible_characters >= text.get_total_character_count():
		finish_typing()


func set_side_padding(on: bool) -> void:
	var m := side_shift if on else 0.0
	thought_bar.offset_left = _bar_left + m
	thought_bar.offset_right = thought_bar.offset_left + 2.0
	$Body.offset_left = _body_left + m + (16.0 if thought_bar.visible else 0.0)
	var nw := name_box.offset_right - name_box.offset_left
	name_box.offset_left = _name_left + m
	name_box.offset_right = name_box.offset_left + nw


func set_toggle(action: String, on: bool) -> void:
	var b := controls.get_node_or_null(NodePath(action.capitalize())) as Button
	if b:
		b.set_pressed_no_signal(on)
		b.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit()


## Полоса у мыслей — только на высоту блока (метка + текст)
func _fit_thought_bar() -> void:
	var h := thought_tag.size.y + 2.0 + float(text.get_content_height())
	thought_bar.offset_bottom = thought_bar.offset_top + h
