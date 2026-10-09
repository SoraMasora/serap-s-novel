extends Node
## Мобильная платформа: определение сенсорного режима, безопасная зона (вырез/«чёлка»),
## кнопка «Назад» Android, уход приложения в фон, полноэкранный режим веб-сборки.
## Узлы в группе "safe_area" автоматически отодвигаются от вырезов экрана.

signal touch_mode_changed(on: bool)
signal safe_area_changed(insets: Vector4)
signal back_requested
signal app_paused
signal app_resumed

const CONFIG_PATH := "res://data/mobile_config.tres"
const SAFE_GROUP := &"safe_area"
## settings["touch"]: 0 — авто, 1 — всегда сенсорный режим, 2 — никогда
const TOUCH_AUTO := 0
const TOUCH_ON := 1
const TOUCH_OFF := 2

var cfg: MobileConfig
var touch := false
## left, top, right, bottom — в единицах холста (после растяжения canvas_items)
var insets := Vector4.ZERO


func _ready() -> void:
	cfg = load(CONFIG_PATH)
	process_mode = Node.PROCESS_MODE_ALWAYS
	touch = detect_touch(int(Game.settings.get("touch", TOUCH_AUTO)), _platform_flags())
	get_tree().root.size_changed.connect(update_safe_area)
	get_tree().node_added.connect(_on_node_added)
	if touch and cfg.keep_screen_on:
		DisplayServer.screen_set_keep_on(true)
	update_safe_area.call_deferred()


## Чистая функция: сенсорный режим по настройке и признакам платформы (для тестов).
## flags: {mobile: телефон/планшет или мобильный браузер, touchscreen: есть сенсорный экран,
## cli: "--touch" | "--no-touch" | ""}
static func detect_touch(setting: int, flags: Dictionary) -> bool:
	match str(flags.get("cli", "")):
		"--touch":
			return true
		"--no-touch":
			return false
	if setting == TOUCH_ON:
		return true
	if setting == TOUCH_OFF:
		return false
	return bool(flags.get("mobile", false))


func _platform_flags() -> Dictionary:
	var cli := ""
	for a in OS.get_cmdline_user_args():
		if a == "--touch" or a == "--no-touch":
			cli = a
	var mobile := OS.has_feature("mobile")
	if not mobile and OS.has_feature("web"):
		mobile = OS.has_feature("web_android") or OS.has_feature("web_ios")
		if not mobile:
			# Браузер без явного тега: сенсорный экран и «грубый» указатель — телефон/планшет
			var coarse: Variant = JavaScriptBridge.eval(
				"navigator.maxTouchPoints > 0 && matchMedia('(pointer: coarse)').matches", true
			)
			mobile = coarse == true
	return {"mobile": mobile, "touchscreen": DisplayServer.is_touchscreen_available(), "cli": cli}


func set_touch(on: bool) -> void:
	if on == touch:
		return
	touch = on
	touch_mode_changed.emit(on)


## Чистая функция: отступы безопасной зоны в единицах холста.
## window — размер окна в пикселях, safe — безопасная область в пикселях окна,
## canvas — видимый размер холста.
static func compute_insets(window: Vector2i, safe: Rect2i, canvas: Vector2) -> Vector4:
	if window.x <= 0 or window.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	var k := canvas / Vector2(window)
	var l := clampf(safe.position.x, 0, window.x) * k.x
	var t := clampf(safe.position.y, 0, window.y) * k.y
	var r := clampf(window.x - safe.end.x, 0, window.x) * k.x
	var b := clampf(window.y - safe.end.y, 0, window.y) * k.y
	return Vector4(l, t, r, b)


func update_safe_area() -> void:
	var ins := Vector4.ZERO
	if OS.has_feature("mobile"):
		var win := get_tree().root.size
		var safe := DisplayServer.get_display_safe_area()
		# На Android/iOS в полноэкранном режиме окно = экран, безопасная зона — в тех же координатах
		ins = compute_insets(win, safe, get_tree().root.get_visible_rect().size)
	if ins != insets:
		insets = ins
		safe_area_changed.emit(insets)
	for n: Node in get_tree().get_nodes_in_group(SAFE_GROUP):
		apply_insets(n as Control, insets)


## Отодвигает Control от краёв, к которым он привязан (якорь 0 или 1), на величину отступов.
## Исходные отступы запоминаются в meta, поэтому вызов идемпотентен.
static func apply_insets(c: Control, ins: Vector4) -> void:
	if c == null:
		return
	if not c.has_meta("safe_base"):
		c.set_meta(
			"safe_base", Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom)
		)
	var o: Vector4 = c.get_meta("safe_base")
	c.offset_left = o.x + (ins.x if is_zero_approx(c.anchor_left) else 0.0)
	c.offset_top = o.y + (ins.y if is_zero_approx(c.anchor_top) else 0.0)
	c.offset_right = o.z - (ins.z if is_equal_approx(c.anchor_right, 1.0) else 0.0)
	c.offset_bottom = o.w - (ins.w if is_equal_approx(c.anchor_bottom, 1.0) else 0.0)


func _on_node_added(n: Node) -> void:
	if n.is_in_group(SAFE_GROUP) and insets != Vector4.ZERO:
		(func() -> void: apply_insets(n as Control, insets)).call_deferred()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			back_requested.emit()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			app_paused.emit()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			app_resumed.emit()
			update_safe_area.call_deferred()


## Веб-сборка на телефоне: можно ли развернуть на весь экран (вызывать из обработчика нажатия)
func can_web_fullscreen() -> bool:
	return OS.has_feature("web") and touch and cfg.web_fullscreen_button


func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


## Полный экран: браузер разрешает его только из обработчика касания — вызывать из pressed()
func toggle_fullscreen() -> void:
	if is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if OS.has_feature("web"):
		# Альбомная ориентация доступна только в полноэкранном режиме (Android Chrome); iOS — игнорирует
		JavaScriptBridge.eval(
			(
				"try{screen.orientation&&screen.orientation.lock&&"
				+ "screen.orientation.lock('landscape').catch(function(){})}catch(e){}"
			),
			true
		)
