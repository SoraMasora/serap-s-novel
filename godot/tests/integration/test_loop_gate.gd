extends GutTest
## Gate counts distinct ORIGINAL endings, never loop deaths or the new truth ending.

const MAIN := preload("res://scenes/main/main.tscn")

var main: Control
var _saved_memory: Dictionary
var _saved_settings: Dictionary
var _saved_endings: Dictionary


func before_each() -> void:
	_saved_memory = Game.memory.data.duplicate(true)
	_saved_settings = Game.settings.duplicate(true)
	_saved_endings = SaveSystem.endings()
	SaveSystem.write_atomic(SaveSystem.ENDINGS_PATH, "{}")
	Game.memory = LoopMemory.new(Game.db.loop)
	Game.settings.cw = 1.0
	Game.settings.speed = 0.0
	SaveSystem.delete_slot("auto")
	Engine.time_scale = 16.0
	main = MAIN.instantiate()
	add_child_autofree(main)
	await wait_process_frames(3)


func after_each() -> void:
	main.loop_overlay.kill()
	Game.memory.data = _saved_memory
	Game.settings = _saved_settings
	SaveSystem.write_atomic(SaveSystem.ENDINGS_PATH, JSON.stringify(_saved_endings))
	Game.save_memory()
	SaveSystem.delete_slot("auto")
	Engine.time_scale = 1.0


func _open_first(total: int) -> void:
	for i in total:
		SaveSystem.unlock_ending(Game.db.loop.BASE_ENDINGS[i])
	Game.refresh_loop_access()


func test_first_six_different_endings_never_start_deaths() -> void:
	for i in 6:
		main.playing = true
		main.runner.new_game("Тест")
		main.finish(Game.db.loop.BASE_ENDINGS[i])
		assert_eq(Game.memory.base_ending_count(SaveSystem.endings()), i + 1)
		assert_false(Game.memory.enabled())
		assert_null(Game.memory.data.pending)
		main.to_title()
		assert_false(main.title.get_node("Bar/New").disabled)
		assert_eq(main.title.btn_continue.text, "Продолжить")


func test_repeated_ending_does_not_count_seven_times() -> void:
	for _i in 10:
		SaveSystem.unlock_ending("good")
	Game.refresh_loop_access()
	assert_eq(Game.memory.base_ending_count(SaveSystem.endings()), 1)
	assert_false(Game.memory.enabled())
	assert_null(Game.memory.data.pending)


func test_unknown_and_new_truth_are_not_original_endings() -> void:
	var m := LoopMemory.new(Game.db.loop)
	var got := {"truth": true, "invented": true}
	assert_eq(m.base_ending_count(got), 0)
	assert_eq(Game.db.loop.BASE_ENDINGS.size(), 11)
	assert_has(Game.db.loop.BASE_ENDINGS, "closed")


func test_seventh_current_ending_opens_branch_immediately() -> void:
	_open_first(6)
	var seventh: String = Game.db.loop.BASE_ENDINGS[6]
	main.runner.new_game("Май")
	main.playing = true
	main.finish(seventh)
	assert_true(Game.memory.enabled())
	assert_eq(Game.memory.base_ending_count(SaveSystem.endings()), 7)
	assert_eq(Game.memory.data.pending.kind, seventh)
	main._start_death(false)
	assert_eq(main.runner.st.scene, "L_after_" + seventh)


func test_existing_seven_original_endings_offer_new_branch_on_title() -> void:
	_open_first(7)
	main.to_title()
	assert_true(Game.memory.haunted())
	assert_not_null(Game.memory.data.pending)
	assert_false(main.title.btn_continue.disabled)
	assert_eq(main.title.btn_continue.text, "ПРОДОЛЖИТЬ!")
	main._on_title_action("continue")
	assert_true(str(main.runner.st.scene).begins_with("L_after_"))


func test_locked_old_loop_save_cannot_bypass_gate() -> void:
	var saved: Dictionary = main.runner.save_snapshot()
	saved.scene = "L_d_room"
	saved.i = 0
	saved.bg = "d_room"
	main._restore(saved)
	assert_eq(main.runner.st.scene, "start")
	assert_false(main.loop_overlay.visible)
	assert_false(Game.memory.haunted())


func test_true_ending_saves_before_automatic_exit_and_stays_peaceful() -> void:
	_open_first(7)
	Game.memory.data.deaths = Game.db.loop.ORDER.duplicate()
	main.runner.new_game("Май")
	main.playing = true
	main.ending_delay_sec = 0.01
	main.truth_exit_delay_sec = 0.1
	var exits := [0]
	main.truth_exit_requested.disconnect(main._exit_application)
	main.truth_exit_requested.connect(func() -> void: exits[0] += 1)
	main.finish("truth")
	assert_true(Game.memory.data.freed)
	assert_false(Game.memory.haunted())
	assert_null(Game.memory.data.pending)
	var saved := SaveSystem.read_json(LoopMemory.PATH)
	assert_true(saved.freed, "completion is on disk before exit is requested")
	assert_true(SaveSystem.endings().get("truth", false))
	await wait_seconds(0.5)
	assert_eq(exits[0], 1, "automatic exit requested once")
	var reopened := LoopMemory.new(Game.db.loop)
	reopened.data.merge(SaveSystem.read_json(LoopMemory.PATH), true)
	reopened.unlock_from_endings(SaveSystem.endings())
	assert_false(reopened.enabled())
	for kind: String in reopened.rules.BASE_ENDINGS:
		reopened.finish(kind, "Май")
		assert_null(reopened.data.pending, "no more Sera deaths: " + kind)


func test_completed_gallery_recovers_peaceful_mode_after_meta_reset() -> void:
	_open_first(7)
	SaveSystem.unlock_ending("truth")
	Game.memory = LoopMemory.new(Game.db.loop)
	Game.refresh_loop_access()
	assert_true(Game.memory.data.freed)
	Game.forget_memory()
	assert_true(Game.memory.data.freed)
	assert_false(Game.memory.enabled())
	assert_null(Game.memory.data.pending)


func test_old_death_save_after_completion_starts_clean_without_death_images() -> void:
	_open_first(7)
	Game.memory.data.deaths = Game.db.loop.ORDER.duplicate()
	Game.memory.finish("truth", "Май")
	var saved: Dictionary = main.runner.save_snapshot()
	saved.scene = "L_d_cross"
	saved.bg = "d_cross"
	saved.name = "Май"
	main._restore(saved)
	assert_eq(main.runner.st.scene, "start")
	assert_eq(main.runner.st.name, "Май")
	assert_eq(main.runner.st.flags.loop, 0)
	assert_false(main.loop_overlay.visible)
	assert_false(Game.memory.haunted())
