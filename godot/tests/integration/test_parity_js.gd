extends GutTest
## Паритет с веб-версией: те же сиды → тот же путь (digest) и та же концовка, что в js/engine.js.
## Эталон: tests/fixtures/js_reference.json (node tools/godot/js_reference.cjs 200).

const CFG := preload("res://data/game_config.tres")


func test_deterministic_playthroughs_match_js() -> void:
	var f := FileAccess.open("res://tests/fixtures/js_reference.json", FileAccess.READ)
	assert_not_null(f, "нет эталона")
	var ref: Dictionary = JSON.parse_string(f.get_as_text())
	var db := StoryDB.load_from()
	var ap := AutoPlayer.new(StoryRunner.new(db, CFG))
	var endings := {}
	var mismatches := 0
	for want: Dictionary in ref.runs:
		var got := ap.play(int(want.seed))
		endings[got.ending] = endings.get(got.ending, 0) + 1
		for k: String in ["ending", "steps", "feel", "press", "notes", "digest"]:
			if str(got[k]) != str(want[k]).trim_suffix(".0"):
				mismatches += 1
				fail_test("seed %d: %s = %s, в JS %s" % [want.seed, k, got[k], want[k]])
				break
	gut.p("Концовки по сидам: " + str(endings))
	assert_eq(mismatches, 0, "все %d прогонов совпали с JS" % ref.runs.size())


func test_same_seed_same_digest() -> void:
	var db := StoryDB.load_from()
	var cfg: GameConfig = CFG
	var a := AutoPlayer.new(StoryRunner.new(db, cfg)).play(42)
	var b := AutoPlayer.new(StoryRunner.new(db, cfg)).play(42)
	assert_eq(a.digest, b.digest)
	assert_ne(a.ending, "")
