extends Node
## Глобальные данные: конфиг, сценарий, ассеты, настройки игрока, открытые концовки.

signal settings_changed

const CONFIG_PATH := "res://data/game_config.tres"
const MANIFEST_PATH := "res://data/assets_manifest.json"
const SETTINGS_PATH := "user://settings.cfg"

var config: GameConfig
var db: StoryDB
## group → {key → res-путь}
var manifest: Dictionary = {}
var settings := {"speed": 28.0, "music": 0.6, "auto_delay": 1800.0}
var _tex_cache: Dictionary = {}


func _ready() -> void:
	config = load(CONFIG_PATH)
	db = StoryDB.load_from()
	settings = {
		"speed": config.default_text_speed,
		"music": config.default_music_volume,
		"auto_delay": config.default_auto_delay_ms,
	}
	_load_manifest()
	_load_settings()


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


## Текстура по группе и ключу (bg/sprites/title/ui); null, если нет
func tex(group: String, key: String) -> Texture2D:
	var path: String = manifest.get(group, {}).get(key, "")
	if path == "":
		return null
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


func has_tex(group: String, key: String) -> bool:
	return manifest.get(group, {}).has(key)


func _load_settings() -> void:
	var cf := ConfigFile.new()
	var err := cf.load(SETTINGS_PATH)
	if err == ERR_FILE_NOT_FOUND:
		return
	if err != OK:
		push_warning("Настройки не прочитаны (%s) — используются значения по умолчанию" % error_string(err))
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
