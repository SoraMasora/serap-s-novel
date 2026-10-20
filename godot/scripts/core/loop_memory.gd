class_name LoopMemory
extends RefCounted
## Persistent memory is deliberately outside saves and rollback.

const PATH := "user://serap_meta.json"

var data := {
	"deaths": [], "name": "", "freed": false, "pending": null, "unlocked": false, "last_ending": ""
}
var rules: Dictionary


func _init(p_rules: Dictionary) -> void:
	rules = p_rules


func enabled() -> bool:
	return bool(data.get("unlocked", false)) and not data.freed


func base_ending_count(got: Dictionary) -> int:
	var total := 0
	for kind: String in rules.BASE_ENDINGS:
		if got.get(kind, false):
			total += 1
	return total


func unlock_from_endings(got: Dictionary) -> void:
	# Completion is also recovered from the ending gallery if meta was reset/lost.
	if got.get("truth", false):
		data.freed = true
	if base_ending_count(got) >= int(rules.get("REQUIRED_ENDINGS", 7)):
		data.unlocked = true
	if not enabled():
		data.pending = null


func level() -> int:
	return mini(7, data.deaths.size()) if enabled() else 0


func truth() -> bool:
	return level() >= 7


func haunted() -> bool:
	return enabled() and (level() > 0 or data.pending != null)


func band() -> String:
	var n := level()
	return "T" if n >= 7 else ("C" if n >= 5 else ("B" if n >= 3 else "A"))


func sync(st: Dictionary) -> void:
	st.flags.loop = level()
	st.flags.truth = truth()
	st.flags.dord = data.deaths.duplicate() if enabled() else []
	for id: String in rules.ORDER:
		st.flags["d_" + id] = enabled() and data.deaths.has(id)


func finish(kind: String, player_name: String) -> void:
	data.name = player_name
	if kind != "truth":
		data.last_ending = kind
	if not enabled():
		data.pending = null
	if kind == "truth" and truth():
		data.freed = true
		data.pending = null
	elif kind != "truth" and enabled():
		var death: String = rules.PREF.get(kind, "room")
		if data.deaths.has(death):
			for id: String in rules.ORDER:
				if not data.deaths.has(id):
					death = id
					break
		data.pending = {"kind": kind, "death": death}


func commit_death(player_name: String) -> void:
	if enabled() and data.pending != null and not data.deaths.has(data.pending.death):
		data.deaths.append(data.pending.death)
	data.pending = null
	data.name = player_name


static func hash_text(text: String) -> float:
	var h: int = 2166136261
	for i in text.length():
		h = ((h ^ text.unicode_at(i)) * 16777619) & 0xffffffff
	return float(h) / 4294967296.0


func flash_text(st: Dictionary, salt: String) -> String:
	var ids: Array = st.flags.get("dord", [])
	if ids.is_empty():
		return "…"
	var id: String = ids[int(hash_text(salt + "d") * ids.size())]
	var lines: Array = rules.FLASH[id]
	return lines[int(hash_text(salt + "t") * lines.size())]


func places(st: Dictionary, current: bool = false) -> String:
	var ids: Array = st.flags.get("dord", []).duplicate()
	var id: String = st.flags.get("dth", "")
	if current and id != "" and not ids.has(id):
		ids.append(id)
	var words: PackedStringArray = []
	for d: String in ids:
		var w: String = rules.DEATHS[d].w
		words.append(w.left(1).to_upper() + w.substr(1) + ".")
	return " ".join(words) if not words.is_empty() else "…"


func text(v: Variant, st: Dictionary) -> Variant:
	if not (v is Dictionary) or not v.has("loop_text"):
		return v
	var flags: Dictionary = st.flags
	var key := clampi(int(flags.get("loop", 0)), 0, 7) * 8
	key += 4 if flags.get("d_cross", false) else 0
	key += 2 if flags.get("d_train", false) else 0
	key += 1 if flags.get("lend", "") == "good" else 0
	var out: String = v.loop_text[int(v.lookup[key])]
	var ids: Array = flags.get("dord", [])
	for i in 7:
		var memory: String = rules.DEATHS[ids[i]].s if i < ids.size() else "снег"
		out = out.replace("{{mem:%d}}" % i, memory)
	out = out.replace("{{list}}", places(st)).replace("{{list:current}}", places(st, true))
	for pair: Array in [
		["first", ids[0] if not ids.is_empty() else ""], ["current", flags.get("dth", "")]
	]:
		out = out.replace("{{word:%s}}" % pair[0], rules.DEATHS.get(pair[1], {}).get("w", "…"))
	while out.contains("{{flash:"):
		var a := out.find("{{flash:")
		var b := out.find("}}", a)
		var salt := out.substr(a + 8, b - a - 8)
		out = out.substr(0, a) + flash_text(st, salt) + out.substr(b + 2)
	return out


func best(options: Array, scene: String) -> int:
	if rules.BEST.has(scene) and int(rules.BEST[scene]) < options.size():
		return int(rules.BEST[scene])
	var bi := 0
	var bv := -INF
	for i in options.size():
		var o: Dictionary = options[i]
		var score := float(o.get("feel", 0)) - 10.0 * float(o.get("add", {}).get("press", 0))
		if score > bv:
			bv = score
			bi = i
	return bi
