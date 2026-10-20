class_name UiFx
extends RefCounted
## Живые кнопки меню и окон: при наведении карточка чуть «приподнимается» и слева появляется
## белый бант — как у вариантов выбора. Навешивается на готовые кнопки, без отдельных сцен.

const SKIP := [&"ControlButton", &"ChoiceVine"]


static func decorate(root: Node) -> void:
	for n: Node in root.find_children("*", "Button", true, false):
		var b := n as Button
		if b.has_meta("ui_fx") or SKIP.has(b.theme_type_variation) or b is CheckButton:
			continue
		b.set_meta("ui_fx", true)
		var bow := Deco.new()
		bow.kind = Deco.Kind.BOW
		bow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bow.size = Vector2(18, 18)
		bow.modulate.a = 0.0
		b.add_child(bow)
		var place := func() -> void:
			b.pivot_offset = b.size / 2.0
			bow.position = Vector2(8, b.size.y / 2.0 - 9)
		b.resized.connect(place)
		place.call()
		b.mouse_entered.connect(_hover.bind(b, bow, true))
		b.mouse_exited.connect(_hover.bind(b, bow, false))
		b.focus_entered.connect(_hover.bind(b, bow, true))
		b.focus_exited.connect(_hover.bind(b, bow, false))


static func _hover(b: Button, bow: Control, on: bool) -> void:
	if b.disabled and on:
		return
	var tw := b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2.ONE * (1.045 if on else 1.0), 0.18)
	tw.parallel().tween_property(bow, "modulate:a", 1.0 if on else 0.0, 0.15)
	tw.parallel().tween_property(bow, "rotation", -0.2 if on else 0.0, 0.2)
