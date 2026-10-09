extends Node
## Замер CPU-времени кадра пиксельной карты (логика + сборка канваса, без GPU).
## godot --headless --audio-driver Dummy --path godot \
##   res://tests/perf/perf_pixel_map.tscn -- --frames=600
## Вывод: PERF {...} — Performance.TIME_PROCESS, мс (все _process за кадр: логика карты,
## частицы, HUD). GPU не участвует (headless dummy-рендер); интервал кадров headless
## упирается в ~6.9 мс (144 Гц) и как метрика не годится.

const WARMUP := 60
var frames := 600
var samples: PackedFloat64Array = []
var n := 0
var dirs := ["map_right", "map_down", "map_left", "map_up"]
var pm: PixelMap


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			frames = int(a.get_slice("=", 1))
	var runner := StoryRunner.new(StoryDB.load_from(), load("res://data/game_config.tres"))
	runner.new_game("Кирилл")
	for _i in 2000:
		var e: Dictionary = runner.step()[-1]
		if e.type == "map":
			break
		if e.type == "choice":
			runner.mark_choice_shown()
			runner.choose(e.options, 0)
		elif e.type == "breath":
			runner.breath_result(e.cfg, 1.0)
		elif e.type == "final":
			push_error("perf: карта не встретилась")
			get_tree().quit(1)
			return
	pm = load("res://scenes/pixel/pixel_map.tscn").instantiate()
	add_child(pm)
	pm.open(runner.st.map)
	print("perf: map=", runner.st.scene, " ", runner.st.map.get("title", ""))


func _process(_delta: float) -> void:
	n += 1
	if n % 90 == 1:
		for d in dirs:
			Input.action_release(d)
		Input.action_press(dirs[(n / 90) % dirs.size()])
	if n > WARMUP:
		samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	if samples.size() >= frames:
		set_process(false)
		_report()
		get_tree().quit(0)


func _report() -> void:
	var s := samples.duplicate()
	s.sort()
	var q := func(r: float) -> float: return s[mini(s.size() - 1, int(r * s.size()))]
	var avg := 0.0
	for v in s:
		avg += v
	avg /= s.size()
	print(
		"PERF ",
		(
			JSON
			. stringify(
				{
					"n": s.size(),
					"avg": snappedf(avg, 0.001),
					"p50": snappedf(q.call(0.5), 0.001),
					"p95": snappedf(q.call(0.95), 0.001),
					"p99": snappedf(q.call(0.99), 0.001),
					"max": snappedf(s[-1], 0.001),
				}
			)
		)
	)
