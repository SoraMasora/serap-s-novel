class_name PixelTouchControls
extends Control
## Сенсорное управление прогулкой: встроенный VirtualJoystick (Godot 4.7) слева, «E» и «Бег» справа.
## Видно только в сенсорном режиме. Джойстик пишет силу в действия map_* — PixelWorld читает их
## тем же Input.get_axis, что и клавиатуру.

const MAP_ACTIONS: Array[StringName] = [
	&"map_left", &"map_right", &"map_up", &"map_down", &"map_run"
]

@onready var joystick: VirtualJoystick = $Joystick
@onready var act: TouchActionButton = $Act
@onready var run: TouchActionButton = $Run


func _ready() -> void:
	joystick.joystick_size = Mobile.cfg.joystick_radius * 2.0
	joystick.deadzone_ratio = Mobile.cfg.joystick_deadzone
	_sync(Mobile.touch)
	Mobile.touch_mode_changed.connect(_sync)
	visibility_changed.connect(_on_visibility)


func _on_visibility() -> void:
	if not is_visible_in_tree():
		release_all()


func _sync(on: bool) -> void:
	visible = on
	if not on:
		release_all()


## Отпустить всё: скрытый VirtualJoystick не получает отпускания пальца, поэтому сбрасываем
## его так же, как он сам сбрасывается при изменении размера (NOTIFICATION_RESIZED → _reset).
func release_all() -> void:
	joystick.notification(NOTIFICATION_RESIZED)
	for a: StringName in MAP_ACTIONS:
		if Input.is_action_pressed(a):
			Input.action_release(a)
