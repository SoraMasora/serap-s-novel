class_name StoryRunner
extends RefCounted
## Чистая логика сценария — порт run()/choose()/breath()/openMap() из js/engine.js.
## Ничего не рисует: step() возвращает список событий, последнее — блокирующее
## (say, card, cut, breath, choice, map, final, stall). Подачу делает main.gd.

const BLOCKING := ["say", "card", "cut", "breath", "choice", "map", "final", "stall"]
const MAX_STEPS := 100000

var db: StoryDB
var config: GameConfig
var memory: LoopMemory
## Состояние игры (сохраняется целиком) — аналог st из engine.js
var st: Dictionary = {}
## Журнал: {n, t, th, ch, s(снимок для отката)}
var log: Array[Dictionary] = []
var _hooks: Dictionary = {}
var _expr_cache: Dictionary = {}
var _choice_snap: Dictionary = {}


func _init(p_db: StoryDB, p_config: GameConfig) -> void:
	db = p_db
	config = p_config
	memory = LoopMemory.new(db.loop)
	for hook: Dictionary in db.loop.get("HOOKS", []):
		var sc := db.scene(hook.scene)
		for i in sc.size():
			if sc[i].has("say") and JSON.stringify(sc[i].say[1]).contains(hook.after):
				_hooks["%s:%d" % [hook.scene, i + 1]] = hook.echo
				break
	new_game(config.default_name)


func new_game(player_name: String) -> void:
	var n := player_name.strip_edges()
	st = {
		"scene": config.start_scene,
		"i": 0,
		"feel": config.start_feel,
		"press": 0,
		"flags": {},
		"notes": [],
		"name": n if n != "" else config.default_name,
		"bg": "",
		"chars": {},
		"music": "",
		"rain": false,
		"chapter": "",
		"mode": "",
		"map": null,
		"snow": false,
		"stack": [],
		"hk": {},
		"flk": "",
	}
	log.clear()
	memory.sync(st)


# ── Тон маршрута ──
func tier(s: Dictionary = st) -> String:
	if s.feel < config.cold_feel_below or s.press >= config.cold_press_min:
		return "cold"
	if s.feel >= config.warm_feel_min and s.press < config.warm_press_below:
		return "warm"
	return "mid"


## Значение может быть {warm, mid, cold} — выбираем по тону (TV)
func tv(v: Variant) -> Variant:
	if v is Dictionary and (v.has("mid") or v.has("warm") or v.has("cold")):
		var t := tier()
		return v[t] if v.has(t) else v.get("mid")
	return v


func fmt(t: String) -> String:
	return t.replace("{P}", str(st.name))


# ── Функции для выражений условий (база Expression) ──
func flag(k: String) -> bool:
	return truthy(st.flags.get(k))


func num(k: String) -> float:
	var v: Variant = st.flags.get(k, 0)
	return float(v) if (v is int or v is float) else (1.0 if truthy(v) else 0.0)


func notes_count() -> int:
	return st.notes.size()


static func truthy(v: Variant) -> bool:
	match typeof(v):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return v != 0
		TYPE_STRING, TYPE_STRING_NAME:
			return not str(v).is_empty()
	return true


func eval_cond(src: String) -> bool:
	var e: Expression = _expr_cache.get(src)
	if e == null:
		e = Expression.new()
		var err := e.parse(src, PackedStringArray(["feel", "press"]))
		if err != OK:
			push_error("Условие не разобрано: %s — %s" % [src, e.get_error_text()])
			return false
		_expr_cache[src] = e
	var r: Variant = e.execute([float(st.feel), float(st.press)], self, true)
	if e.has_execute_failed():
		push_error("Условие не выполнено: %s — %s" % [src, e.get_error_text()])
		return false
	return truthy(r)


func pick_ending() -> String:
	for r: Dictionary in db.ending_rules:
		if eval_cond(r.when):
			return "L_truth" if memory.truth() else r.go
	push_error("Ни одно правило концовки не сработало")
	return db.ending_rules[-1].go if db.ending_rules.size() else db.start


# ── Состояние ──
func change_feel(d: float) -> void:
	st.feel = clampf(st.feel + d, 0, 100)


## true — заметка новая
func add_note(t: String) -> bool:
	if st.notes.has(t):
		return false
	st.notes.append(t)
	return true


func jump(label: String) -> void:
	if not db.has_scene(label):
		push_error("Переход в несуществующую сцену: " + label)
	st.scene = label
	st.i = 0


func show_char(who: String, expr: Variant, pos: Variant = null) -> Dictionary:
	var prev: Dictionary = st.chars.get(who, {})
	var p: String = pos if pos is String and pos != "" else prev.get("pos", "center")
	st.chars[who] = {"expr": expr, "pos": p}
	return {"type": "show", "who": who, "expr": expr, "pos": p}


func hide_char(who: String) -> Array:
	var list: Array = st.chars.keys() if who == "all" else [who]
	for w: String in list:
		st.chars.erase(w)
	return list


func char_for(speaker: String) -> String:
	return config.speaker_to_char.get(speaker, "")


## Снимок для журнала/отката (snapLite): без заметок, i со сдвигом
func snap_lite(off: int = -1) -> Dictionary:
	var o: Dictionary = st.duplicate(true)
	o.erase("notes")
	o.i = maxi(0, int(st.i) + off)
	o.nc = st.notes.size()
	return o


func log_push(e: Dictionary) -> void:
	log.append(e)
	while log.size() > config.log_max:
		log.pop_front()


# ── Исполнение ──
func step() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for _guard in MAX_STEPS:
		memory.sync(st)
		var hk := "%s:%d" % [st.scene, int(st.i)]
		if memory.level() > 0 and _hooks.has(hk) and not st.hk.has(hk):
			st.hk[hk] = true
			st.stack.append([st.scene, st.i])
			jump(_hooks[hk] + "_" + memory.band())
		var scene := db.scene(st.scene)
		if st.i >= scene.size():
			out.append({"type": "stall", "scene": st.scene})
			return out
		var c: Dictionary = scene[st.i]
		st.i += 1
		if c.has("say"):
			var t: Variant = memory.text(tv(c.say[1]), st)
			if t == null:
				continue
			var expr: Variant = tv(c.say[2]) if c.say.size() > 2 else null
			if _memory_flash_due():
				st.i -= 1
				out.append({"type": "subl", "id": "last"})
				out.append(_say("!", memory.flash_text(st, str(st.scene) + ":" + str(st.i)), null))
			else:
				out.append(_say(c.say[0], fmt(_tilt(c.say[0], t)), expr))
			return out
		if c.get("ret", false):
			if not st.stack.is_empty():
				var back: Array = st.stack.pop_back()
				st.scene = back[0]
				st.i = int(back[1])
			continue
		if c.has("lgo"):
			jump(c.lgo + str(mini(6, memory.level())))
			continue
		if c.has("dgo"):
			jump(c.dgo + str(st.flags.get("dth", "room")))
			continue
		if c.has("tier"):
			var g: Variant = tv(c.tier)
			if g:
				jump(g)
				continue
		if c.has("card"):
			out.append(
				{"type": "card", "big": c.card[0], "small": c.card[1] if c.card.size() > 1 else ""}
			)
			return out
		if c.has("note"):
			var n: Variant = tv(c.note)
			if n and add_note(n):
				out.append({"type": "note", "text": n})
		if c.has("chapter"):
			st.chapter = c.chapter
			out.append({"type": "chapter", "text": c.chapter})
		if c.has("bg"):
			st.bg = c.bg
			out.append({"type": "bg", "key": c.bg})
		if c.get("zoom"):
			out.append({"type": "zoom"})
		if c.has("cam"):
			out.append({"type": "cam", "cam": c.cam})
		if c.has("cut"):
			out.append({"type": "cut", "frames": c.cut})
			return out
		if c.has("music"):
			st.music = c.music
			out.append({"type": "music", "mode": c.music})
		if c.has("snow"):
			st.snow = bool(c.snow)
			out.append({"type": "snow", "on": st.snow})
		if c.has("subl"):
			out.append({"type": "subl", "id": c.subl})
		if c.has("rain"):
			st.rain = bool(c.rain)
			out.append({"type": "rain", "on": st.rain})
		if c.has("show"):
			var who: String = c.get("who", "father" if c.show == "father" else "sera")
			out.append(show_char(who, c.show, c.get("pos")))
		if c.has("hide"):
			out.append({"type": "hide", "who": hide_char(c.hide)})
		if c.has("fx"):
			out.append({"type": "fx", "kind": c.fx})
		if c.has("sfx"):
			out.append({"type": "sfx", "key": c.sfx})
		if c.has("react"):
			out.append({"type": "react", "kind": c.react})
		var is_choice := c.has("choice")
		if (c.get("feel") is float or c.get("feel") is int) and not is_choice:
			change_feel(c.feel)
		if c.has("set") and not is_choice:
			st.flags.merge(c.set, true)
		if c.has("add") and not is_choice:
			st.press += int(c.add.get("press", 0))
		if c.has("when"):
			if eval_cond(c.when):
				jump(c.go)
			continue
		if c.has("go"):
			jump(c.go)
			continue
		if c.has("breath"):
			out.append({"type": "breath", "cfg": c.breath})
			return out
		if is_choice:
			out.append({"type": "choice", "options": c.choice})
			return out
		var overlay := false
		for kind: String in ["sms", "omen", "montage", "scream"]:
			if c.has(kind):
				out.append({"type": kind, "data": c[kind]})
				overlay = true
				break
		if overlay:
			return out
		if c.get("ending"):
			jump(pick_ending())
			continue
		if c.has("map"):
			var m: Dictionary = {"done": [], "pos": null}
			m.merge(c.map.duplicate(true), true)
			if memory.truth():
				m.erase("timer")
			st.map = m
			st.mode = "map"
			out.append({"type": "map"})
			return out
		if c.get("tomap"):
			if st.map == null:
				push_error("tomap без активной карты в " + st.scene)
				continue
			if st.map.done.size() >= int(st.map.visits):
				var a: String = st.map.after
				st.map = null
				st.mode = ""
				jump(a)
				continue
			st.mode = "map"
			out.append({"type": "map"})
			return out
		if c.has("final"):
			out.append({"type": "final", "kind": c.final})
			return out
	push_error("StoryRunner: превышен лимит шагов (зацикливание?) в " + str(st.scene))
	out.append({"type": "stall", "scene": st.scene})
	return out


func _say(speaker: String, text: String, expr: Variant) -> Dictionary:
	var e := {"type": "say", "name": speaker, "text": text, "expr": expr, "changes": []}
	var thought := speaker == config.thought_marker
	if expr and (speaker == "Сера" or speaker == "???") and st.chars.has("sera"):
		e.changes.append(show_char("sera", expr))
	if expr and speaker == "P" and st.chars.has("hero"):
		e.changes.append(show_char("hero", expr))
	elif speaker != "P":
		var who := char_for(speaker)
		if who != "" and config.single_sprite_chars.has(who) and st.chars.has(who):
			e.changes.append(show_char(who, expr if expr else "neutral"))
	var disp := "" if thought else (str(st.name) if speaker == "P" else speaker)
	e.display = disp
	e.thought = thought
	log_push({"n": disp, "t": text, "th": thought, "s": snap_lite(-1)})
	return e


## Выбор варианта: возвращает ключ реакции Серы (или "")
func choose(options: Array, idx: int) -> String:
	if memory.truth():
		var best_idx := memory.best(options, str(st.scene))
		if idx != best_idx:
			log_push({"n": "→", "t": "Нет. Я знаю, чем это кончается.", "ch": true})
		idx = best_idx
	var o: Dictionary = options[idx]
	var f: float = float(o.get("feel", 0))
	var rk: String = o.get("react", "")
	if rk == "":
		if f >= 10:
			rk = "shy"
		elif f >= 5:
			rk = "hop"
		elif f <= -12:
			rk = "shake"
		elif f < 0:
			rk = "shiver"
	log_push({"n": "→", "t": fmt(o.t), "ch": true, "s": _choice_snap})
	if f != 0:
		change_feel(f)
	if o.has("set"):
		st.flags.merge(o.set, true)
	if o.has("add"):
		st.press += int(o.add.get("press", 0))
	jump(o.go)
	return rk


## Вызывается при показе выбора (снимок до выбора — для отката)
func mark_choice_shown() -> void:
	_choice_snap = snap_lite(-1)


## Итог мини-игры дыхания
func breath_result(cfg: Dictionary, score: float) -> void:
	if memory.truth():
		score = 1.0
	var ok := score >= config.breath_ok_ratio
	st.flags[cfg.get("flag", "breathOk")] = ok
	st.flags.breathScore = roundi(score * 100)
	if ok and cfg.has("feel"):
		change_feel(cfg.feel)
	if cfg.has("go"):
		jump(cfg.go if ok else cfg.get("fail", cfg.go))


# ── Пиксельная карта ──
func map_spot_available(id: String) -> bool:
	var m: Dictionary = st.map
	return m.spots.has(id)


## Вход в точку карты (id) или служебные '__items'/'__late'
func map_enter(id: String, pos: Variant = null) -> void:
	var m: Dictionary = st.map
	if pos != null:
		m.pos = pos
	if id == "__items" or id == "__late":
		var a: String = m.get("late", m.after) if id == "__late" else m.after
		st.map = null
		st.mode = ""
		jump(a)
		return
	m.done.append(id)
	st.mode = ""
	if m.has("scenes") and m.scenes.has(id):
		jump(m.scenes[id])
		return
	var n := int(st.flags.get("v_" + id, 0)) + 1
	st.flags["v_" + id] = n
	var key := "%s_%d" % [id, n]
	jump(key if db.has_scene(key) else id + "_3")


## Снимок для сохранения: i-1, чтобы реплика повторилась при загрузке
func save_snapshot() -> Dictionary:
	var s: Dictionary = st.duplicate(true)
	if st.mode != "map":
		s.i = maxi(0, int(st.i) - 1)
	return s


func restore(s: Dictionary) -> void:
	var base := {
		"notes": [], "mode": "", "map": null, "snow": false, "stack": [], "hk": {}, "flk": ""
	}
	base.merge(s.duplicate(true), true)
	base.erase("nc")
	# числа из JSON — float; индексы и счётчики приводим к int
	base.i = int(base.get("i", 0))
	base.press = int(base.get("press", 0))
	base.feel = float(base.get("feel", config.start_feel))
	st = base
	memory.sync(st)
	if not db.has_scene(str(st.get("scene", ""))):
		push_error("Сохранение ссылается на неизвестную сцену: " + str(st.get("scene")))
		st.scene = config.start_scene
		st.i = 0


## Откат к записи журнала k
func rollback(k: int) -> bool:
	if k < 0 or k >= log.size() or not log[k].has("s"):
		return false
	var snap: Dictionary = log[k].s
	var notes: Array = st.notes.slice(0, int(snap.get("nc", 0)))
	log.resize(k)
	var s := snap.duplicate(true)
	s.notes = notes
	restore(s)
	return true


func _base_scene() -> bool:
	return not str(st.scene).begins_with("L_") and not str(st.scene).begins_with("e_")


func _memory_flash_due() -> bool:
	var n := memory.level()
	if n < 2 or memory.truth() or not _base_scene():
		return false
	var key := "%s:%d" % [st.scene, int(st.i) - 1]
	var chance := [0.0, 0.0, 0.025, 0.035, 0.045, 0.06, 0.075]
	if st.flk == key or LoopMemory.hash_text(key + "f" + str(n)) >= chance[n]:
		return false
	st.flk = key
	return true


func _tilt(speaker: String, text: String) -> String:
	var n := memory.level()
	if n == 0 or memory.truth() or not _base_scene() or text.length() < 8:
		return text
	if speaker != "P" and speaker != config.thought_marker:
		return text
	var key := "%s:%d" % [st.scene, int(st.i) - 1]
	var chance := [0.0, 0.1, 0.15, 0.22, 0.3, 0.4, 0.5]
	var out := text
	if LoopMemory.hash_text(key + "g" + str(n)) < chance[n]:
		var count := 1 + int(n >= 2) + int(n >= 3) + int(n >= 4)
		out = _tilt_op(out, int(LoopMemory.hash_text(key + "m") * count))
		if n >= 5 and LoopMemory.hash_text(key + "x") < 0.4:
			out = _tilt_op(out, int(LoopMemory.hash_text(key + "y") * count))
	var tails := [0.0, 0.08, 0.1, 0.14, 0.18, 0.25, 0.32]
	if speaker == config.thought_marker and LoopMemory.hash_text(key + "t" + str(n)) < tails[n]:
		var lines: Array = db.loop.TAILS[memory.band()]
		out += " " + str(lines[int(LoopMemory.hash_text(key + "u") * lines.size())])
	return out


func _tilt_op(text: String, op: int) -> String:
	if op == 0:
		return text if text.left(1) in ["…", "«", '"', "("] else "…" + text
	if op == 1:
		var pos := text.find(", ")
		return text.substr(0, pos) + "… " + text.substr(pos + 2) if pos >= 0 else "…" + text
	var re := RegEx.new()
	if op == 2:
		re.compile('^([«"(…]?)([А-ЯЁа-яё])([а-яё]*)')
	else:
		re.compile("(?i)(^|\\s)(не|я|она|мне|это|ты)(\\s)")
	var hit := re.search(text)
	if hit == null:
		return text if op == 2 else "…" + text
	var word := hit.get_string(2)
	var change := word + "… " + word.to_lower() if op == 3 else word + "-" + word.to_lower()
	return (
		text.substr(0, hit.get_start())
		+ hit.get_string(1)
		+ change
		+ hit.get_string(3)
		+ text.substr(hit.get_end())
	)
