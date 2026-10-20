extends GutTest
## Admin edits persist but never change ordinary save slots.

const PANEL := preload("res://scenes/ui/admin_panel.tscn")

var _saved_memory: Dictionary
var _saved_endings: Dictionary


func before_each() -> void:
	_saved_memory = Game.memory.data.duplicate(true)
	_saved_endings = SaveSystem.endings()
	SaveSystem.write_atomic(SaveSystem.ENDINGS_PATH, "{}")
	Game.memory.data = LoopMemory.new(Game.db.loop).data


func after_each() -> void:
	Admin.close()
	Game.memory.data = _saved_memory
	SaveSystem.write_atomic(SaveSystem.ENDINGS_PATH, JSON.stringify(_saved_endings))
	Game.save_memory()
	Game.progress_changed.emit()


func test_grant_and_remove_persist_in_gallery() -> void:
	assert_eq(Game.admin_set_ending("good", true), OK)
	assert_true(SaveSystem.endings().get("good", false))
	assert_eq(Game.admin_set_ending("good", false), OK)
	assert_false(SaveSystem.endings().has("good"))


func test_seventh_opens_and_removal_closes_gate() -> void:
	for i in 7:
		Game.admin_set_ending(Game.db.loop.BASE_ENDINGS[i], true)
	assert_true(Game.memory.enabled())
	assert_not_null(Game.memory.data.pending)
	Game.memory.data.pending = {"kind": "good", "death": "room"}
	Game.admin_set_ending(Game.db.loop.BASE_ENDINGS[0], false)
	assert_false(Game.memory.enabled())
	assert_null(Game.memory.data.pending)
	assert_false(SaveSystem.read_json(LoopMemory.PATH).unlocked)


func test_truth_toggles_peaceful_mode_and_persists() -> void:
	for i in 7:
		Game.admin_set_ending(Game.db.loop.BASE_ENDINGS[i], true)
	Game.admin_set_ending("truth", true)
	assert_true(Game.memory.data.freed)
	assert_false(Game.memory.enabled())
	assert_true(SaveSystem.read_json(LoopMemory.PATH).freed)
	Game.admin_set_ending("truth", false)
	assert_false(Game.memory.data.freed)
	assert_true(Game.memory.enabled())
	assert_false(SaveSystem.endings().has("truth"))


func test_invalid_ending_does_not_modify_progress() -> void:
	assert_eq(Game.admin_set_ending("invented", true), ERR_INVALID_PARAMETER)
	assert_true(SaveSystem.endings().is_empty())


func test_deaths_clamp_and_keep_existing_order() -> void:
	Game.memory.data.deaths = ["neck", "room"]
	assert_eq(Game.admin_set_deaths(99), OK)
	assert_eq(Game.memory.data.deaths.size(), 7)
	assert_eq(Game.memory.data.deaths[0], "neck")
	assert_eq(Game.memory.data.deaths[1], "room")
	assert_eq(SaveSystem.read_json(LoopMemory.PATH).deaths.size(), 7)
	Game.admin_set_deaths(-9)
	assert_true(Game.memory.data.deaths.is_empty())


func test_panel_has_all_ordinary_endings_and_truth() -> void:
	var panel := PANEL.instantiate() as AdminPanel
	add_child_autofree(panel)
	assert_eq(panel.list.get_child_count(), 11)
	assert_not_null(panel.box.get_node("Truth"))
	panel._all(true)
	assert_eq(Game.memory.base_ending_count(SaveSystem.endings()), 11)
	assert_false(SaveSystem.endings().get("truth", false))
	panel._all(false)
	assert_eq(Game.memory.base_ending_count(SaveSystem.endings()), 0)


func test_open_close_restores_pause_state() -> void:
	Admin.open()
	assert_true(get_tree().paused)
	assert_true(Admin.visible)
	Admin.close()
	assert_false(get_tree().paused)
	get_tree().paused = true
	Admin.open()
	Admin.close()
	assert_true(get_tree().paused)
	get_tree().paused = false


func test_f9_action_toggles_and_escape_closes() -> void:
	var event := InputEventAction.new()
	event.action = "admin_panel"
	event.pressed = true
	Admin._input(event)
	assert_true(Admin.visible)
	event.action = "vn_menu"
	Admin._input(event)
	assert_false(Admin.visible)
	assert_false(get_tree().paused)


func test_physical_f9_is_bound_to_action() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F9
	event.pressed = true
	assert_true(event.is_action_pressed("admin_panel"))
