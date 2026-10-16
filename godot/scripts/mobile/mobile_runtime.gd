extends Node
## Mobile lifecycle, safe area and UI sizing. No story/state-machine changes.

var _suspended := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not MobileProfile.enabled():
		return
	Engine.max_fps = 60
	Input.emulate_mouse_from_touch = true
	get_tree().node_added.connect(_node_added)
	get_tree().root.size_changed.connect(_fit_safe_area)


func _node_added(node: Node) -> void:
	if node is Button or node is LineEdit or node is Slider:
		_size_control.call_deferred(node.get_instance_id())
	if node.name == &"Main":
		_fit_safe_area.call_deferred()


func _size_control(instance_id: int) -> void:
	var node := instance_from_id(instance_id)
	if not is_instance_valid(node):
		return
	var control := node as Control
	control.custom_minimum_size.y = maxf(
		control.custom_minimum_size.y, 48.0 if node is Slider else 64.0
	)
	if node is Button or node is LineEdit:
		control.add_theme_font_size_override("font_size", 22)


func _fit_safe_area() -> void:
	var main := get_tree().root.get_node_or_null("Main") as Control
	if main == null or not OS.has_feature("android"):
		return
	var margins := MobileProfile.safe_margins(
		Vector2(DisplayServer.screen_get_size()),
		Rect2(DisplayServer.get_display_safe_area()),
		get_tree().root.get_visible_rect().size
	)
	main.offset_left = margins.x
	main.offset_top = margins.y
	main.offset_right = -margins.z
	main.offset_bottom = -margins.w


func _notification(what: int) -> void:
	if not MobileProfile.enabled() or not is_inside_tree():
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		Game.save_seen()
		Game.save_memory()
		var main := get_tree().root.get_node_or_null("Main")
		if main and main.playing and not main.loop_overlay.visible and not main._whisper_armed:
			main.autosave()
		_suspended = not get_tree().paused
		get_tree().paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED and _suspended:
		_suspended = false
		get_tree().paused = false
