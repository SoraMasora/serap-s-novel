class_name AutoPlayer
extends RefCounted
## Детерминированный автоплей (тот же ГПСЧ и политика, что tools/godot/js_reference.cjs).
## Используется тестами паритета и CLI: godot --headless --path godot -- --autoplay=SEED

var runner: StoryRunner
var trace: PackedStringArray = []
var ending := ""
var _rs := 1


func _init(p_runner: StoryRunner) -> void:
	runner = p_runner


func _pick(n: int) -> int:
	_rs = (_rs * 16807) % 2147483647
	return _rs % n


func play(seed: int, max_events: int = 5000) -> Dictionary:
	_rs = seed
	trace.clear()
	ending = ""
	runner.new_game(runner.config.default_name)
	for _n in max_events:
		var events := runner.step()
		var e: Dictionary = events[-1]
		var at := "%s:%d" % [runner.st.scene, runner.st.i]
		match e.type:
			"say", "card", "cut":
				trace.append("%s@%s" % [e.type, at])
			"choice":
				var k := _pick(e.options.size())
				trace.append("choice@%s=%d" % [at, k])
				runner.mark_choice_shown()
				runner.choose(e.options, k)
			"breath":
				var ok := _pick(2) == 0
				trace.append("breath@%s=%d" % [at, 1 if ok else 0])
				runner.breath_result(e.cfg, 1.0 if ok else 0.0)
			"map":
				var id := _map_choice(runner.st.map)
				trace.append("map@%s=%s" % [at, id])
				runner.map_enter(id)
			"final":
				ending = e.kind
				trace.append("final=" + ending)
				break
			_:
				push_error("AutoPlayer: застряли на %s (%s)" % [at, e.type])
				break
	var digest := "\n".join(trace).sha256_text()
	return {
		"seed": seed,
		"ending": ending,
		"steps": trace.size(),
		"feel": int(runner.st.feel),
		"press": int(runner.st.press),
		"notes": runner.st.notes.size(),
		"digest": digest,
	}


func _map_choice(m: Dictionary) -> String:
	if m.has("items"):
		return "__items"
	if m.get("timer") != null and m.has("late") and _pick(4) == 0:
		return "__late"
	var av: Array = []
	for s: String in m.spots:
		if not m.done.has(s):
			av.append(s)
	return av[_pick(av.size())]
