extends GutTest


func test_snowy_street_used_in_all_three_snow_scenes() -> void:
	for id: String in ["L_d_store", "L_d_cross", "L_clue_4"]:
		assert_eq(Game.db.scene(id)[0].bg, "street_snow")
	assert_true(FileAccess.file_exists("res://art/bg/street_snow.webp"))
	var script := load("res://scripts/ui/loop_main.gd") as GDScript
	var main = script.new()
	assert_has(main.loop_outdoor_bgs, "street_snow")
	main.free()


func test_liza_remains_crying_on_every_liza_line() -> void:
	var lines := 0
	for cmd: Dictionary in Game.db.scene("L_clue_3"):
		if cmd.get("who", "") == "liza":
			assert_eq(cmd.show, "cry")
		if cmd.has("say") and cmd.say[0] == "Лиза":
			assert_eq(cmd.say[2], "cry")
			lines += 1
	assert_eq(lines, 4)
	assert_not_null(Game.tex("sprites", "liza_cry"))


func test_redrawn_backgrounds_resolve_to_art_overrides() -> void:
	for key: String in [
		"m2_shift",
		"cg_m2_shift_a",
		"cg_m2_snow_joke",
		"cg_m2_snow_words",
		"street_snow",
		"dm_train",
		"dm_cliff",
		"dm_room",
		"dm_store",
		"dm_road",
		"dm_cross",
		"dm_neck"
	]:
		var texture := Game.tex("bg", key)
		assert_not_null(texture, key)
		if texture != null:
			assert_true(texture.resource_path.begins_with("res://art/bg/"), key)
