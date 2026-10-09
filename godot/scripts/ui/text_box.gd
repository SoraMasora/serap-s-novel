class_name TextBox
extends Control
## Окно реплик: имя, печать текста, индикатор «дальше», кнопки управления.

signal clicked
signal typing_done
signal control_pressed(action: String)

## Цвет имени по типу говорящего (sera — по умолчанию)
@export var name_colors := {
	"sera": Color("#ffb6cf"),
	"gg": Color("#a9d4ff"),
	"father": Color("#d9d9e0"),
	"unk": Color("#c9a6b6"),
	"npc": Color("#ffd59a"),
}
## Свечение имени (text-shadow 0 0 16px из css v4)
@export var name_glow := {
	"sera": Color(1, 0.235, 0.47, 0.65),
	"gg": Color(0.43, 0.667, 1, 0.55),
	"father": Color(1, 1, 1, 0.25),
	"unk": Color(1, 0.235, 0.47, 0.4),
	"npc": Color(1, 0.667, 0.314, 0.45),
}
@export var narr_color := Color("#cfc6d6")
@export var thought_color := Color("#b9c8ec")
@export var text_color := Color("#f4ecf0")
@export var side_padding_ratio := 0.22

var speed := 28.0
var typing := false
var _acc := 0.0
var _body_left := 38.0
var _name_left := 26.0

@onready var name_box: Label = $NameBox
@onready var thought_tag: Label = $Body/ThoughtTag
@onready var text: RichTextLabel = $Body/Text
@onready var next_mark: Control = $Next
@onready var thought_bar: ColorRect = $ThoughtBar
@onready var underline: TextureRect = $NameBox/Underline
@onready var controls: HBoxContainer = $Controls


func _ready() -> void:
	_body_left = $Body.offset_left
	_name_left = name_box.offset_left
	for c: Node in controls.get_children():
		var b := c as Button
		if b:
			b.pressed.connect(func() -> void: control_pressed.emit(String(b.name).to_lower()))
	# nextPulse 1.6 с: opacity .55↔1, сдвиг вниз на 4 px
	var mark: Control = $Next/Mark
	var tw := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(next_mark, "modulate:a", 1.0, 0.8)
	tw.parallel().tween_property(mark, "position:y", 4.0, 0.8)
	tw.tween_property(next_mark, "modulate:a", 0.55, 0.8)
	tw.parallel().tween_property(mark, "position:y", 0.0, 0.8)
	next_mark.visible = false


## kind: sera/gg/father/unk/npc; thought — мысли героя; narr — без имени
func show_line(
	display_name: String, kind: String, line: String, thought: bool, instant: bool
) -> void:
	name_box.visible = display_name != ""
	name_box.text = display_name
	var col: Color = name_colors.get(kind, name_colors.sera)
	name_box.add_theme_color_override("font_color", col)
	name_box.add_theme_color_override("font_shadow_color", name_glow.get(kind, name_glow.sera))
	underline.self_modulate = col
	name_box.offset_right = name_box.offset_left
	thought_tag.visible = thought
	thought_bar.visible = thought
	$Body.offset_left = thought_bar.offset_left + (23.0 if thought else 0.0)
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
	var w := get_viewport_rect().size.x
	var m := w * side_padding_ratio - position.x if on else 0.0
	var left := maxf(_body_left, m)
	thought_bar.offset_left = left
	thought_bar.offset_right = left + 2.0
	$Body.offset_left = left + (23.0 if thought_bar.visible else 0.0)
	var nw := name_box.offset_right - name_box.offset_left
	name_box.offset_left = maxf(_name_left, m)
	name_box.offset_right = name_box.offset_left + nw


## Сенсорный режим: мелкая строка кнопок скрыта, её заменяет TouchQuickMenu в Main
func set_touch_mode(on: bool) -> void:
	controls.visible = not on


func set_toggle(action: String, on: bool) -> void:
	var b := controls.get_node_or_null(NodePath(action.capitalize())) as Button
	if b:
		b.set_pressed_no_signal(on)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit()


## border-left у мыслей — только на высоту блока (метка + текст), как в css
func _fit_thought_bar() -> void:
	var h := thought_tag.size.y + 2.0 + float(text.get_content_height())
	thought_bar.offset_bottom = thought_bar.offset_top + h
