extends Node
## Сохранения: JSON-файлы в user://saves, атомарная запись (temp → rename).
## Пустой/битый файл не роняет игру: слот считается пустым, битый файл переименовывается в .bad.

const DIR := "user://saves"
const ENDINGS_PATH := "user://endings.json"
const FORMAT_VERSION := 1


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func slot_path(slot: String) -> String:
	return "%s/slot_%s.json" % [DIR, slot]


## Атомарная запись текста: пишем во временный файл, затем переименовываем поверх.
func write_atomic(path: String, text: String) -> Error:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		var e := FileAccess.get_open_error()
		push_error("Сохранение: не открыть %s: %s" % [tmp, error_string(e)])
		return e
	f.store_string(text)
	f.flush()
	var werr := f.get_error()
	f.close()
	if werr != OK:
		push_error("Сохранение: ошибка записи %s: %s" % [tmp, error_string(werr)])
		DirAccess.remove_absolute(tmp)
		return werr
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var rerr := DirAccess.rename_absolute(tmp, path)
	if rerr != OK:
		push_error("Сохранение: rename %s → %s: %s" % [tmp, path, error_string(rerr)])
	return rerr


## Чтение JSON-словаря; {} если файла нет; битый файл → .bad + предупреждение
func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("Не открыть %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if text.strip_edges() != "" and json.parse(text) == OK and json.data is Dictionary:
		return json.data
	push_warning("Файл повреждён или пуст, слот считается пустым: " + path)
	DirAccess.rename_absolute(path, path + ".bad")
	return {}


func save_slot(slot: String, st: Dictionary, log_tail: Array) -> Error:
	var data := {
		"version": FORMAT_VERSION,
		"date": Time.get_datetime_string_from_system(false, true),
		"st": st,
		"log": log_tail,
	}
	return write_atomic(slot_path(slot), JSON.stringify(data))


func load_slot(slot: String) -> Dictionary:
	var d := read_json(slot_path(slot))
	if d.is_empty():
		return {}
	if not (d.get("st") is Dictionary) or not (d.st.get("scene") is String):
		push_warning("Слот %s без состояния — пропущен" % slot)
		return {}
	return d


func has_slot(slot: String) -> bool:
	return not load_slot(slot).is_empty()


func delete_slot(slot: String) -> void:
	var p := slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)


func endings() -> Dictionary:
	return read_json(ENDINGS_PATH)


func unlock_ending(kind: String) -> void:
	var got := endings()
	got[kind] = true
	write_atomic(ENDINGS_PATH, JSON.stringify(got))
