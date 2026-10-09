class_name StoryDB
extends RefCounted
## Сценарий из res://data/story.json (генерируется tools/godot/export_data.cjs из js/story*.js).

const DEFAULT_PATH := "res://data/story.json"

var start := "start"
var notes_total := 0
var scenes: Dictionary = {}
var endings: Dictionary = {}
var ending_rules: Array = []
var load_error := ""


static func load_from(path: String = DEFAULT_PATH) -> StoryDB:
	var db := StoryDB.new()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		db.load_error = "не удалось открыть %s: %s" % [path, error_string(FileAccess.get_open_error())]
		push_error(db.load_error)
		return db
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		db.load_error = "битый JSON сценария: " + path
		push_error(db.load_error)
		return db
	db.start = data.get("start", "start")
	db.notes_total = int(data.get("notes_total", 0))
	db.scenes = data.get("scenes", {})
	db.endings = data.get("endings", {})
	db.ending_rules = data.get("ending_rules", [])
	return db


func has_scene(key: String) -> bool:
	return scenes.has(key)


func scene(key: String) -> Array:
	if not scenes.has(key):
		push_error("Нет сцены: " + key)
		return []
	return scenes[key]


## Все ссылки на сцены (go/fail/after/late/choice/tier/map) — для проверки целостности.
func collect_targets() -> Array[String]:
	var out: Array[String] = []
	for key: String in scenes:
		for c: Dictionary in scenes[key]:
			for g: String in ["go", "fail"]:
				if c.get(g) is String:
					out.append(c[g])
			if c.has("breath"):
				for g: String in ["go", "fail"]:
					if c.breath.get(g) is String:
						out.append(c.breath[g])
			if c.has("choice"):
				for o: Dictionary in c.choice:
					out.append(o.go)
			if c.has("tier"):
				for t: Variant in c.tier.values():
					if t is String:
						out.append(t)
			if c.has("map"):
				var m: Dictionary = c.map
				for g: String in ["after", "late"]:
					if m.get(g) is String:
						out.append(m[g])
				for v: Variant in m.get("scenes", {}).values():
					out.append(v)
	for r: Dictionary in ending_rules:
		out.append(r.go)
	return out
