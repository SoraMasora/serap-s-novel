class_name ChoiceCGState
extends RefCounted
## Presentation only: one reply after a dialogue choice; never mutates story state.

var catalog: Dictionary = JSON.parse_string(
	FileAccess.get_file_as_string("res://data/choice_cg.json")
)
var pending := false
var key := ""
var restore_next := ""


func arm() -> void:
	pending = true


func clear() -> void:
	key = ""


func reset() -> void:
	clear()
	pending = false
	restore_next = ""


func response(scene_id: String) -> String:
	# Removed reply art must not reappear when loading an older save.
	var restored := restore_next if restore_next in catalog.values() else ""
	key = restored if restored != "" else str(catalog.get(scene_id, "")) if pending else ""
	pending = false
	restore_next = ""
	return key
