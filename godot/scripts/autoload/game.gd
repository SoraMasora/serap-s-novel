extends Node
## Глобальные данные: конфиг, сценарий, ассеты, настройки игрока, открытые концовки.

signal settings_changed

const CONFIG_PATH := "res://data/game_config.tres"
const MANIFEST_PATH := "res://data/assets_manifest.json"
const SETTINGS_PATH := "user://settings.cfg"
const SEEN_PATH := "user://seen.json"

var config: GameConfig
var db: StoryDB
var memory: LoopMemory
## group → {key → res-путь}
var manifest: Dictionary = {}
var settings := {
	"speed": 28.0, "music": 0.6, "auto_delay": 1800.0, "fullscreen": 1.0, "soft": 0.0, "cw": 0.0
}
## Прочитанные реплики («сцена:индекс») — «Пропуск» листает только их
var seen: Dictionary = {}
var _tex_cache: Dictionary = {}
var _seen_dirty := 0


func _ready() -> void:
	config = load(CONFIG_PATH)
	db = StoryDB.load_from()
	memory = LoopMemory.new(db.loop)
	memory.data.merge(SaveSystem.read_json(LoopMemory.PATH), true)
	refresh_loop_access()
	if ensure_loop_entry():
		save_memory()
	settings = {
		"speed": config.default_text_speed,
		"music": config.default_music_volume,
		"auto_delay": config.default_auto_delay_ms,
		"fullscreen": 1.0,
		"soft": 0.0,
		"cw": 0.0,
	}
	_load_manifest()
	_load_settings()
	_load_seen()
	apply_window()


func _load_manifest() -> void:
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if f == null:
		push_error("Нет %s — запустите node tools/godot/export_data.cjs --assets" % MANIFEST_PATH)
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		manifest = d
	else:
		push_error("Битый " + MANIFEST_PATH)


## Текстура по группе и ключу (bg/sprites/title/ui); null, если нет.
## Новый арт из res://art/<group>/ (в git) перекрывает сгенерированные ассеты.
func tex(group: String, key: String) -> Texture2D:
	var path := _art_path(group, key)
	if path == "":
		path = manifest.get(group, {}).get(key, "")
	if path == "":
		return null
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


func has_tex(group: String, key: String) -> bool:
	return _art_path(group, key) != "" or manifest.get(group, {}).has(key)


func _art_path(group: String, key: String) -> String:
	for ext: String in [".webp", ".png", ".jpg"]:
		var p := "res://art/%s/%s%s" % [group, key, ext]
		if ResourceLoader.exists(p):
			return p
	return ""


## Полный экран без чёрных полос (stretch aspect = expand) или окно
func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var fs := float(settings.get("fullscreen", 1.0)) > 0.5
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func toggle_fullscreen() -> void:
	set_setting("fullscreen", 0.0 if float(settings.get("fullscreen", 1.0)) > 0.5 else 1.0)
	apply_window()


func is_seen(key: String) -> bool:
	return seen.has(key)


func mark_seen(key: String) -> void:
	if seen.has(key):
		return
	seen[key] = 1
	_seen_dirty += 1
	if _seen_dirty >= 8:
		save_seen()


func save_seen() -> void:
	if _seen_dirty == 0:
		return
	_seen_dirty = 0
	var f := FileAccess.open(SEEN_PATH + ".tmp", FileAccess.WRITE)
	if f == null:
		push_error("Не удалось записать прочитанное: " + error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(seen.keys()))
	f.close()
	DirAccess.rename_absolute(SEEN_PATH + ".tmp", SEEN_PATH)


func _load_seen() -> void:
	if not FileAccess.file_exists(SEEN_PATH):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SEEN_PATH))
	if d is Array:
		for k: Variant in d:
			seen[str(k)] = 1


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:  # Android «назад» = Esc
		var ev := InputEventAction.new()
		ev.action = "vn_menu"
		ev.pressed = true
		Input.parse_input_event(ev)
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		save_seen()


func _load_settings() -> void:
	var cf := ConfigFile.new()
	var err := cf.load(SETTINGS_PATH)
	if err == ERR_FILE_NOT_FOUND:
		return
	if err != OK:
		push_warning(
			"Настройки не прочитаны (%s) — используются значения по умолчанию" % error_string(err)
		)
		return
	for k: String in settings:
		settings[k] = float(cf.get_value("player", k, settings[k]))


func set_setting(k: String, v: float) -> void:
	settings[k] = v
	var cf := ConfigFile.new()
	for key: String in settings:
		cf.set_value("player", key, settings[key])
	var err := cf.save(SETTINGS_PATH)
	if err != OK:
		push_error("Не удалось сохранить настройки: " + error_string(err))
	settings_changed.emit()


func save_memory() -> Error:
	return SaveSystem.write_atomic(LoopMemory.PATH, JSON.stringify(memory.data))


func refresh_loop_access() -> void:
	var before := JSON.stringify(memory.data)
	memory.unlock_from_endings(SaveSystem.endings())
	if JSON.stringify(memory.data) != before:
		save_memory()


func ensure_loop_entry() -> bool:
	if not memory.enabled() or memory.data.pending != null or not memory.data.deaths.is_empty():
		return false
	var got := SaveSystem.endings()
	var kind: String = memory.data.get("last_ending", "")
	if not memory.rules.BASE_ENDINGS.has(kind) or not got.get(kind, false):
		kind = ""
		for candidate: String in got:
			if memory.rules.BASE_ENDINGS.has(candidate) and got[candidate]:
				kind = candidate
	if kind == "":
		return false
	memory.finish(kind, memory.data.name if memory.data.name != "" else config.default_name)
	return true


func forget_memory() -> void:
	# Forgetting deaths must never undo the completed good ending or its peaceful replays.
	var freed: bool = memory.data.freed or SaveSystem.endings().get("truth", false)
	var unlocked: bool = memory.data.get("unlocked", false)
	var last: String = memory.data.get("last_ending", "")
	memory.data = {
		"deaths": [],
		"name": "",
		"freed": freed,
		"pending": null,
		"unlocked": unlocked,
		"last_ending": last
	}
	save_memory()
	SaveSystem.delete_slot("auto")
