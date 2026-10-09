extends GutTest
## Сохранения: круговой путь, пустой/битый файл, атомарность (нет .tmp после записи).

const SLOT := "gut_test"


func after_each() -> void:
	SaveSystem.delete_slot(SLOT)
	var bad := SaveSystem.slot_path(SLOT) + ".bad"
	if FileAccess.file_exists(bad):
		DirAccess.remove_absolute(bad)


func test_roundtrip() -> void:
	var st := {
		"scene": "c1_store", "i": 3, "feel": 55.0, "press": 1, "flags": {"a": true}, "notes": ["x"]
	}
	assert_eq(SaveSystem.save_slot(SLOT, st, [{"n": "Сера", "t": "Привет"}]), OK)
	assert_false(
		FileAccess.file_exists(SaveSystem.slot_path(SLOT) + ".tmp"), "временный файл удалён"
	)
	var d := SaveSystem.load_slot(SLOT)
	assert_eq(d.st.scene, "c1_store")
	assert_eq(int(d.st.i), 3)
	assert_eq(d.log[0].t, "Привет")
	assert_eq(int(d.version), SaveSystem.FORMAT_VERSION)


func test_missing_slot_is_empty() -> void:
	assert_eq(SaveSystem.load_slot("nope_404"), {})
	assert_false(SaveSystem.has_slot("nope_404"))


func test_empty_file_survives() -> void:
	var f := FileAccess.open(SaveSystem.slot_path(SLOT), FileAccess.WRITE)
	f.close()
	assert_eq(SaveSystem.load_slot(SLOT), {})


func test_corrupt_file_survives_and_is_quarantined() -> void:
	var f := FileAccess.open(SaveSystem.slot_path(SLOT), FileAccess.WRITE)
	f.store_string('{"st": {"scene": "start", ')
	f.close()
	assert_eq(SaveSystem.load_slot(SLOT), {})
	assert_true(FileAccess.file_exists(SaveSystem.slot_path(SLOT) + ".bad"))
	assert_false(FileAccess.file_exists(SaveSystem.slot_path(SLOT)))


func test_wrong_shape_is_rejected() -> void:
	SaveSystem.write_atomic(SaveSystem.slot_path(SLOT), JSON.stringify({"st": {"i": 1}}))
	assert_eq(SaveSystem.load_slot(SLOT), {})


func test_restore_from_save_resumes_line() -> void:
	var r := StoryRunner.new(Game.db, Game.config)
	for _k in 5:
		r.step()
	var at: String = r.st.scene
	var snap := r.save_snapshot()
	SaveSystem.save_slot(SLOT, snap, [])
	var r2 := StoryRunner.new(Game.db, Game.config)
	r2.restore(SaveSystem.load_slot(SLOT).st)
	assert_eq(r2.st.scene, at)
	var ev := r2.step()
	assert_eq(ev[-1].type, "say", "после загрузки повторяется та же реплика")
