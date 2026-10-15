extends GutTest
## 0.7.4 screamer variants: each one ends, soft mode stays calm, the fake title and the whisper.

const MAIN := preload("res://scenes/main/main.tscn")
const OVERLAY := preload("res://scenes/ui/loop_overlay.tscn")

var _memory: Dictionary
var _settings: Dictionary
var _endings: Dictionary


func before_each() -> void:
	_memory = Game.memory.data.duplicate(true)
	_settings = Game.settings.duplicate(true)
	_endings = SaveSystem.endings()
	SaveSystem.write_atomic(SaveSystem.ENDINGS_PATH, "{}")
	Game.memory.data = {
		"deaths": [], "name": "Тест", "freed": false, "pending": null, "unlocked": true
	}
	Game.settings.cw = 1.0
	Game.settings.speed = 0.0
	Game.settings.soft = 0.0
	SaveSystem.delete_slot("auto")
	Engine.time_scale = 16.0


func after_each() -> void:
	Game.memory.data = _memory
	Game.settings = _settings
	SaveSystem.write_atomic(SaveSystem.ENDINGS_PATH, JSON.stringify(_endings))
	Game.save_memory()
	SaveSystem.delete_slot("auto")
	Engine.time_scale = 1.0


func _overlay() -> LoopOverlay:
	var o: LoopOverlay = OVERLAY.instantiate()
	add_child_autofree(o)
	return o


func _main() -> Control:
	var m: Control = MAIN.instantiate()
	add_child_autofree(m)
	await wait_process_frames(3)
	return m


## Plays the death until `stop` is true (cards, overlay pages and lines are clicked through).
func _play_death(m: Control, stop: Callable) -> void:
	Game.memory.finish("good", "Тест")
	m._start_death(true)
	for _i in 600:
		if stop.call():
			return
		if m.card.visible:
			m.card._close()
		elif m.loop_overlay.visible:
			m.loop_overlay._advance()
		elif m.textbox.visible:
			m.advance()
		await wait_seconds(0.02)


func test_variant_follows_death_count_and_soft_mode() -> void:
	var o := _overlay()
	var order: Array = Game.db.loop.SCARE.order
	for n in 14:
		Game.memory.data.deaths = []
		for i in n:
			Game.memory.data.deaths.append("d%d" % i)
		assert_eq(o.pick_scare(), order[n % order.size()], str(n))
	o.scare_override = "false"
	assert_eq(o.pick_scare(), "false")
	Game.settings.soft = 1.0
	assert_eq(o.pick_scare(), "burst", "soft mode never plays tricks")


func test_every_variant_finishes_and_hides() -> void:
	var o := _overlay()
	for kind: String in ["burst", "lull", "whisper", "false", "title"]:
		o.scream(kind)
		assert_true(o.visible, kind)
		assert_true(await wait_for_signal(o.death_finished, 30), kind)
		assert_false(o.visible, kind)
		assert_eq(o.take_ambush(), kind == "title", kind)
		assert_false(o.take_ambush(), "ambush is taken once")


func test_hit_uses_glitch_shake_and_seraph() -> void:
	Engine.time_scale = 1.0
	var o := _overlay()
	var seen := {}
	o.scream("burst")
	var done := [false]
	o.death_finished.connect(func() -> void: done[0] = true)
	var t0 := Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < 20000:
		var mat: ShaderMaterial = o.image.material
		if o.image.visible and o.image.texture:
			seen[o.image.texture.resource_path.get_file().get_basename()] = true
		if float(mat.get_shader_parameter("invert")) > 0.5:
			seen.invert = true
		if float(mat.get_shader_parameter("split")) > 0.0:
			seen.split = true
		if o.image.position != Vector2.ZERO:
			seen.shake = true
		if o.image.scale.x > 1.1:
			seen.zoom = true
		if o.hit.modulate.a > 0.0:
			seen.flash = true
		if o.caption.text in Game.db.loop.SCARE.flash:
			seen.caption = true
		await wait_process_frames(1)
	assert_true(done[0])
	for key: String in [
		"x_face", "x_scream", "invert", "split", "shake", "zoom", "flash", "caption"
	]:
		assert_true(seen.has(key), key)
	assert_eq(o.image.position, Vector2.ZERO)
	assert_eq(o.image.scale, Vector2.ONE)


func test_soft_mode_is_one_calm_frame() -> void:
	Game.settings.soft = 1.0
	var o := _overlay()
	o.scream("false")
	var done := [false]
	var textures := {}
	var loud := []
	o.death_finished.connect(func() -> void: done[0] = true)
	var t0 := Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < 20000:
		var mat: ShaderMaterial = o.image.material
		if float(mat.get_shader_parameter("invert")) != 0.0:
			loud.append("invert")
		if o.image.flip_h or o.image.flip_v:
			loud.append("flip")
		if o.image.position != Vector2.ZERO:
			loud.append("shake")
		if o.hit.modulate.a != 0.0:
			loud.append("flash")
		if o.image.visible and o.image.texture:
			textures[o.image.texture.resource_path] = true
		await wait_process_frames(1)
	assert_true(done[0])
	assert_eq(loud, [], "no strobe, negative, shake or flash")
	assert_eq(textures.size(), 1, "one static frame")


func test_fake_title_then_hit_over_menu() -> void:
	var m: Control = await _main()
	m.loop_overlay.scare_override = "title"
	await _play_death(m, func() -> bool: return m.title.visible)
	assert_true(m.title.visible)
	assert_eq(Game.memory.data.deaths, ["train"])
	assert_true(m.loop_overlay.visible, "the menu is a lie: the hit is still armed")
	assert_eq(m.loop_overlay.black.color.a, 0.0, "the menu is visible under it")
	assert_true(await wait_for_signal(m.loop_overlay.ambush_finished, 30))
	assert_false(m.loop_overlay.visible)
	assert_true(m.title.visible)
	assert_true(m.title.get_node("Bar/New").disabled)
	assert_false(SaveSystem.has_slot("auto"))


func test_fake_title_click_triggers_hit_early() -> void:
	var o := _overlay()
	o.ambush_wait_sec = Vector2(60.0, 60.0)
	o.ambush()
	await wait_process_frames(2)
	assert_true(o.visible)
	assert_false(o.image.visible)
	assert_eq(o.caption.text, "")
	o._advance()
	assert_gt(o.hit.modulate.a, 0.5, "the click is the trigger")
	assert_ne(o.caption.text, "")
	assert_true(await wait_for_signal(o.ambush_finished, 20))
	assert_false(o.visible)


func test_whisper_line_then_hit_returns_to_title() -> void:
	var m: Control = await _main()
	m.loop_overlay.scare_override = "whisper"
	await _play_death(m, func() -> bool: return m._whisper_armed or m.title.visible)
	assert_true(m._whisper_armed)
	assert_true(m.textbox.visible)
	assert_eq(m.textbox.name_box.text, "Сера")
	assert_string_contains(m.textbox.text.text, "Тест. Обернись.")
	for entry: Variant in m.runner.log:
		assert_false(str(entry).contains("Обернись"), "her whisper is not in the log")
	m.advance()
	assert_false(m._whisper_armed)
	assert_true(m.loop_overlay.visible)
	assert_true(await wait_until(func() -> bool: return m.title.visible, 30))
	assert_eq(Game.memory.data.deaths, ["train"])
	assert_false(SaveSystem.has_slot("auto"))
	assert_false(m.loop_overlay.visible)
