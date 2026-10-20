class_name PixelWorld
extends Node2D
## Пиксельная прогулка 320×180 (мир 560 px): герой, Сера-спутница, NPC, точки входа, листовки,
## таймер, дождь, машины, вороны, дым ТЭЦ, электрички. Порт update()/render() из js/pixel.js.
## Статичные слои (фон, передний план, свет) запечены tools/godot/bake_web.cjs из того же кода.

signal entered(id: String)
signal said(text: String)
signal item_picked(count: int, total: int)
signal ticked(seconds_left: int)
signal sfx_requested(key: String)
## Звук с громкостью/высотой (скрип качелей тише при слабом размахе).
signal sfx_tuned(key: String, volume_db: float, pitch: float)
## Пиксельный крупный план (godot/art/pixel/closeup_<key>_N.webp) с репликой
signal closeup(key: String, text: String)

const BAKE_PATH := "res://data/pixel_bake.json"
const PIX := "res://assets/pixel/"
const DIRS := ["down", "up", "left", "right"]
const CAR_COLORS := [Color("#8a2a2a"), Color("#d8d2c0"), Color("#3a4a6a"), Color("#5a6a4a")]

var pc: PixelConfig
var cfg: Dictionary = {}
var world := "yard"
var time := "day"
var running := false
var cam_x := 0.0
var t_ms := 0.0
var hero := {}
var msg_t := 0.0
var bake: Dictionary = {}
## Качели без Серы: герой садится сам (W — вперёд, A — назад).
## 1:11 качания — концовка «Ленивый идиот»
var sitting := false
var swing_time := 0.0
var _tex: Dictionary = {}
var _drops: Array = []
var _splashes: Array = []
var _cars: Array = []
var _crows: Array = []
var _smoke: Array = []
var _trains: Array = []
var _trail: Array[Vector2] = []
var _fol_t := 6.0
var _fol_i := 0
var _tick_t := 0.0
var _pending_items_done := -1.0
var _pending_exit := -1.0
var _say_text := ""
## Дорога во дворе: можно выйти на проезжую часть — и попасть под машину (концовка «Обочина»)
var _road_t := 0.0
var _road_warned := false
var _hit_t := -1.0
var _sw_ang := 0.0
var _sw_vel := 0.0
var _sw_sign := 0
var _sw_line := 0

@onready var light: Sprite2D = $"../Light"
@onready var halo: Sprite2D = $"../Halo"


func _ready() -> void:
	var f := FileAccess.open(BAKE_PATH, FileAccess.READ)
	if f == null:
		push_error("Нет %s — запустите tools/godot/bake_web.cjs" % BAKE_PATH)
	else:
		bake = JSON.parse_string(f.get_as_text())


func _t(name: String) -> Texture2D:
	if not _tex.has(name):
		var p := PIX + name + ".png"
		_tex[name] = load(p) if ResourceLoader.exists(p) else null
	return _tex[name]


func open(p_cfg: Dictionary, p_pc: PixelConfig) -> void:
	cfg = p_cfg
	pc = p_pc
	world = cfg.get("world", "yard")
	time = cfg.get("time", "day")
	_trains.clear()
	_tick_t = 0.0
	_pending_items_done = -1.0
	_pending_exit = -1.0
	_road_t = 0.0
	_road_warned = false
	_hit_t = -1.0
	sitting = false
	swing_time = 0.0
	_sw_ang = 0.0
	_sw_vel = 0.0
	if cfg.has("items"):
		var got: Array = []
		for g: Variant in cfg.get("got", []):
			got.append(int(g))
		cfg.got = got
	hero = {
		"x": 97.0,
		"y": 116.0,
		"dir": "down",
		"t": 0.0,
		"moving": false,
		"target": null,
		"auto": "",
		"step_t": 0.0,
		"idle_t": 0.0
	}
	if cfg.get("pos") is Dictionary:
		hero.x = float(cfg.pos.x)
		hero.y = float(cfg.pos.y)
	elif cfg.get("start") is Dictionary:
		hero.x = float(cfg.start.x)
		hero.y = float(cfg.start.y)
		hero.dir = cfg.start.get("dir", "right")
	_trail.clear()
	_fol_t = 4.0
	for i in 20:
		_trail.append(Vector2(hero.x - 14 + i * 0.7, hero.y))
	cam_x = clampf(hero.x - pc.screen.x / 2.0, 0, pc.world_width - pc.screen.x)
	_init_fx()
	var dark := time != "day"
	light.texture = _t("%s_%s_light" % [world, time]) if dark else null
	halo.texture = _t("%s_%s_halo" % [world, time]) if dark else null
	light.visible = dark
	halo.visible = dark
	running = true


func stop() -> void:
	running = false
	if not cfg.is_empty():
		cfg.pos = {"x": hero.x, "y": hero.y}


func spots() -> Dictionary:
	var s: Dictionary = pc.spots.get(world, {}).duplicate()
	s.merge(cfg.get("extra", {}), true)
	return s


func avail(id: String) -> bool:
	if id == "home":
		return true
	if id == "swing":
		return world == "yard" and time != "day" and not cfg.has("follow") and not cfg.has("items")
	return cfg.spots.has(id) or (cfg.has("info") and cfg.info.has(id))


func _item_near() -> String:
	if not cfg.has("items"):
		return ""
	var best := ""
	var bd := pc.item_radius
	for i in cfg.items.size():
		if cfg.got.has(i):
			continue
		var d := Vector2(cfg.items[i][0] - hero.x, (112 - hero.y) * 1.2).length()
		if d < bd:
			bd = d
			best = "it%d" % i
	return best


func near() -> String:
	if sitting:
		return "swing"
	var it := _item_near()
	if it != "":
		return it
	var best := ""
	var bd := pc.near_radius
	var sp := spots()
	for id: String in sp:
		if not avail(id):
			continue
		var d := Vector2(sp[id].x - hero.x, (sp[id].y - hero.y) * 1.4).length()
		if d < bd:
			bd = d
			best = id
	return best


func say(t: String) -> void:
	msg_t = pc.say_seconds
	_say_text = t
	said.emit(t)


func act(id: String) -> void:
	if id == "" or not running:
		return
	if id.begins_with("it") and cfg.has("items"):
		_pick_item(int(id.substr(2)))
		return
	if cfg.has("info") and cfg.info.has(id) and not cfg.spots.has(id):
		var v: Variant = cfg.info[id]
		if not cfg.has("infoN"):
			cfg.infoN = {}
		var k := int(cfg.infoN.get(id, 0)) + 1
		cfg.infoN[id] = k
		say(v[(k - 1) % v.size()] if v is Array else str(v))
		if id == "kiosk" and world == "station":
			closeup.emit("kiosk_sera" if cfg.has("follow") else "kiosk", _say_text)
		return
	if id == "home":
		var def := (
			"Сначала — листовки. Все до одной."
			if cfg.has("items")
			else "Рано возвращаться. Хочется ещё куда-нибудь заглянуть."
		)
		say(cfg.get("home", def))
		return
	if id == "swing":
		if cfg.get("noSera", false):
			_toggle_sit()
			return
		say(pc.swing_lines[str(cfg.get("title", "")).length() % 2])
		closeup.emit("swing", _say_text)
		return
	if cfg.done.has(id):
		say("Сегодня я тут уже был.")
		return
	sfx_requested.emit("enter")
	stop()
	entered.emit(id)


func spot_label(id: String) -> String:
	if id == "swing" and cfg.get("noSera", false):
		return "Встать" if sitting else "Сесть на качели"
	return str(spots()[id].label)


func _toggle_sit() -> void:
	sitting = not sitting
	swing_time = 0.0
	_sw_line = 0
	_sw_vel = 0.0
	_sw_ang = 0.0
	hero.target = null
	hero.moving = false
	if sitting:
		hero.x = 226.0
		hero.y = 124.0
		say(pc.sit_hint)
	else:
		say(pc.stand_line)


## Маятник: W — толкнуться вперёд, A — назад (в такт — раскачивает, невпопад — гасит)
func _upd_sit(dt: float) -> void:
	if Input.is_action_just_pressed("map_up"):
		_sw_vel += pc.swing_push if _sw_vel >= -0.15 else -pc.swing_push * 0.4
	if Input.is_action_just_pressed("map_left"):
		_sw_vel -= pc.swing_push if _sw_vel <= 0.15 else -pc.swing_push * 0.4
	_sw_vel += (-pc.swing_gl * sin(_sw_ang) - pc.swing_damp * _sw_vel) * dt
	_sw_ang = clampf(_sw_ang + _sw_vel * dt, -1.1, 1.1)
	var e := 0.5 * _sw_vel * _sw_vel + pc.swing_gl * (1.0 - cos(_sw_ang))
	var amp := acos(clampf(1.0 - e / pc.swing_gl, -1.0, 1.0))
	var sg := signi(int(signf(_sw_vel)))
	if sg != 0 and sg != _sw_sign:
		_sw_sign = sg
		if amp > 0.12:
			var k := "swing_%s%d" % ["fwd" if sg > 0 else "back", randi_range(1, 3)]
			var vol := lerpf(-16.0, -3.0, clampf((amp - 0.12) / 0.8, 0.0, 1.0))
			sfx_tuned.emit(k, vol, randf_range(0.94, 1.06))
	if amp > pc.swing_min_amp:
		swing_time += dt
	var lines: Array = pc.sit_lines
	if _sw_line < lines.size() and swing_time >= float(lines[_sw_line][0]):
		say(str(lines[_sw_line][1]))
		_sw_line += 1
	if swing_time >= pc.lazy_seconds:
		sitting = false
		stop()
		entered.emit("__lazy")


func swing_amp() -> float:
	return absf(_sw_ang)


func _pick_item(i: int) -> void:
	if cfg.got.has(i):
		return
	cfg.got.append(i)
	sfx_requested.emit("tear")
	var lines: Array = cfg.get("itemLines", [])
	say(lines[i] if i < lines.size() else "Сорвал. Скомкал. В карман.")
	item_picked.emit(cfg.got.size(), cfg.items.size())
	if cfg.got.size() >= cfg.items.size():
		_pending_items_done = 1.5


func click(p: Vector2) -> void:
	var x := p.x + cam_x
	var y := p.y
	if cfg.has("items"):
		for i in cfg.items.size():
			var it: Array = cfg.items[i]
			if not cfg.got.has(i) and absf(x - it[0]) < 9 and y > it[1] - 12 and y < 124:
				hero.target = Vector2(it[0], 112)
				hero.auto = "it%d" % i
				return
	var hit := ""
	var sp := spots()
	for id: String in sp:
		if avail(id) and absf(x - sp[id].x) < 14 and y > sp[id].y - 44 and y < sp[id].y + 10:
			hit = id
	if hit != "":
		hero.target = Vector2(sp[hit].x, sp[hit].y + 2)
	else:
		hero.target = Vector2(x, clampf(y, pc.walk_y_min, pc.walk_y_max))
	hero.auto = hit


func _upd_road(dt: float) -> void:
	if _hit_t >= 0.0:
		_hit_t += dt
		if _hit_t > pc.hit_delay:
			_hit_t = -1.0
			stop()
			entered.emit("__car")
		return
	if world != "yard":
		return
	if hero.y <= pc.road_y:
		_road_t = 0.0
		return
	_road_t += dt
	if not _road_warned:
		_road_warned = true
		say(pc.road_warning)
	if (
		_road_t > pc.road_car_after
		and not _cars.any(func(c: Dictionary) -> bool: return c.get("hunt", false))
	):
		var lane := 170.0 if hero.y > 165.0 else 160.0
		var dir := 1 if hero.dir != "right" else -1
		_cars.append(
			{
				"x": cam_x - 50.0 if dir > 0 else cam_x + pc.screen.x + 20.0,
				"y": lane,
				"dir": dir,
				"v": pc.road_car_speed,
				"c": CAR_COLORS[randi() % 4],
				"hunt": true
			}
		)
	for c: Dictionary in _cars:
		var cx0: float = c.x + 15.0
		if absf(cx0 - hero.x) < 16.0 and hero.y > float(c.y) - 3.0 and hero.y < float(c.y) + 10.0:
			c.v = 0.0
			_hit_t = 0.0
			hero.moving = false
			sfx_requested.emit("brake")
			return


func _blocked(x: float, y: float) -> bool:
	for r: Array in pc.obstacles.get(world, []):
		if x > r[0] and x < r[2] and y > r[1] and y < r[3]:
			return true
	return false


func _process(delta: float) -> void:
	if not running:
		return
	var dt := minf(0.05, delta)
	t_ms += dt * 1000.0
	if not get_tree().paused:
		_update(dt)
	queue_redraw()
	light.position.x = -roundf(cam_x)
	halo.position.x = -roundf(cam_x)


func _update(dt: float) -> void:
	if _hit_t >= 0.0:
		_upd_road(dt)
		_upd_fx(dt)
		return
	if sitting:
		_upd_sit(dt)
		if not running:
			return
		if msg_t > 0:
			msg_t -= dt
		var tg := clampf(hero.x - pc.screen.x / 2.0, 0, pc.world_width - pc.screen.x)
		cam_x += (tg - cam_x) * minf(1.0, dt * 5.0)
		_upd_fx(dt)
		_upd_trains(dt)
		return
	var dx := Input.get_axis("map_left", "map_right")
	var dy := Input.get_axis("map_up", "map_down")
	var run := Input.is_action_pressed("map_run")
	if dx != 0 or dy != 0:
		hero.target = null
		hero.auto = ""
	elif hero.target != null:
		var v: Vector2 = hero.target - Vector2(hero.x, hero.y)
		if v.length() < 1.5:
			hero.target = null
			if hero.auto != "":
				var a: String = hero.auto
				hero.auto = ""
				act(a)
				if not running:
					return
		else:
			dx = v.x / v.length()
			dy = v.y / v.length()
	hero.moving = dx != 0 or dy != 0
	if hero.moving:
		var l := Vector2(dx, dy).length()
		var sp := (pc.run_speed if run else pc.walk_speed) * dt
		var nx: float = hero.x + dx / l * sp
		var ny: float = hero.y + dy / l * sp * 0.8
		if not _blocked(nx, hero.y):
			hero.x = nx
		if not _blocked(hero.x, ny):
			hero.y = ny
		hero.t += dt * (1.4 if run else 1.0)
		if absf(dx) > absf(dy):
			hero.dir = "right" if dx > 0 else "left"
		else:
			hero.dir = "down" if dy > 0 else "up"
		hero.step_t -= dt
		if hero.step_t <= 0:
			hero.step_t = pc.run_step_interval if run else pc.step_interval
			sfx_requested.emit("step")
		hero.idle_t = 0.0
	else:
		hero.idle_t += dt
		hero.t = 0.0
	if cfg.has("follow"):
		var hp := Vector2(hero.x, hero.y)
		if _trail.is_empty() or _trail[-1].distance_to(hp) > 1.2:
			_trail.append(hp)
			if _trail.size() > 60:
				_trail.pop_front()
		_fol_t -= dt
		if _fol_t <= 0 and msg_t <= 0:
			_fol_t = 9.0 + randf() * 5.0
			var lines: Array = cfg.get("lines", Array(pc.follow_lines))
			say(lines[_fol_i % lines.size()])
			_fol_i += 1
	hero.x = clampf(hero.x, 6, pc.world_width - 6)
	var y_max := pc.walk_y_max + 4
	if world == "yard":
		y_max = pc.road_y_max
	hero.y = clampf(hero.y, pc.walk_y_min, y_max)
	_upd_road(dt)
	if not running:
		return
	var tgt := clampf(hero.x - pc.screen.x / 2.0, 0, pc.world_width - pc.screen.x)
	cam_x += (tgt - cam_x) * minf(1.0, dt * 5.0)
	if msg_t > 0:
		msg_t -= dt
	_upd_fx(dt)
	_upd_trains(dt)
	if cfg.get("timer") != null:
		var tl: float = cfg.get("tleft", cfg.timer) if cfg.get("tleft") != null else cfg.timer
		cfg.tleft = maxf(0.0, tl - dt)
		_tick_t -= dt
		if _tick_t <= 0:
			_tick_t = 0.25
			ticked.emit(int(ceil(cfg.tleft)))
		if cfg.tleft <= 0:
			stop()
			entered.emit("__late")
			return
	if _pending_items_done > 0:
		_pending_items_done -= dt
		if _pending_items_done <= 0:
			say(cfg.get("itemsDone", "Кажется, всё. Больше ни одной."))
			_pending_exit = 1.7
	if _pending_exit > 0:
		_pending_exit -= dt
		if _pending_exit <= 0:
			stop()
			entered.emit("__items")


func follower() -> Vector2:
	var k := maxi(0, _trail.size() - 18)
	return _trail[k] if k < _trail.size() else Vector2(hero.x - 14, hero.y)


# ── Живой мир ──
func _init_fx() -> void:
	_drops.clear()
	for i in 140:
		_drops.append(
			{
				"x": randf() * (pc.screen.x + 40),
				"y": randf() * pc.screen.y,
				"v": 140 + randf() * 90,
				"l": 3 + randi() % 4
			}
		)
	_splashes.clear()
	_cars.clear()
	_smoke.clear()
	_crows.clear()
	for i in 3:
		_crows.append(
			{
				"x": 60.0 + i * 170,
				"y": 41.0 + i,
				"fly": false,
				"vx": 0.0,
				"vy": 0.0,
				"t": randf() * 5
			}
		)


func _upd_fx(dt: float) -> void:
	for d: Dictionary in _drops:
		d.y += d.v * dt
		d.x -= d.v * dt * 0.12
		if d.y > 108 + randf() * 70 or d.x < -10:
			if d.y > 108 and randf() < 0.35:
				_splashes.append({"x": d.x + cam_x, "y": d.y, "t": 0.0})
			d.y = -5 - randf() * 20
			d.x = randf() * (pc.screen.x + 40)
	for s: Dictionary in _splashes:
		s.t += dt
	_splashes = _splashes.filter(func(s: Dictionary) -> bool: return s.t < 0.25)
	if world == "yard" and randf() < dt * 0.18 and _cars.size() < 2:
		var dir := 1 if randf() < 0.5 else -1
		_cars.append(
			{
				"x": -40.0 if dir > 0 else pc.world_width + 40.0,
				"y": 170 if dir > 0 else 160,
				"dir": dir,
				"v": 70 + randf() * 40,
				"c": CAR_COLORS[randi() % 4]
			}
		)
	for c: Dictionary in _cars:
		c.x += c.dir * c.v * dt
	_cars = _cars.filter(
		func(c: Dictionary) -> bool: return c.x > -60 and c.x < pc.world_width + 60
	)
	for c: Dictionary in _crows:
		c.t += dt
		if not c.fly and absf(c.x - hero.x) < 22 and absf(hero.y - 108) < 60 and c.y > 90:
			c.fly = true
			c.vx = (1 if c.x > hero.x else -1) * 50.0
			c.vy = -40.0
		if c.fly:
			c.x += c.vx * dt
			c.y += c.vy * dt
			c.vy += 6 * dt
			if c.y < 20 or c.x < -20 or c.x > pc.world_width + 20:
				c.fly = false
				c.x = 40 + randf() * (pc.world_width - 80)
				c.y = 41.0
	if randf() < dt * 3:
		for p: Array in [[214, 10], [228, 14], [470, 18]]:
			_smoke.append({"x": p[0] + 3.0, "y": float(p[1]), "t": 0.0})
	for s: Dictionary in _smoke:
		s.t += dt
		s.x += 5 * dt
		s.y -= 4 * dt
	_smoke = _smoke.filter(func(s: Dictionary) -> bool: return s.t < 4)


func _upd_trains(dt: float) -> void:
	if world != "station":
		return
	if randf() < dt * 0.06 and _trains.is_empty():
		var dir := -1 if randf() < 0.5 else 1
		_trains.append(
			{
				"x": pc.world_width + 20.0 if dir < 0 else 150.0,
				"dir": dir,
				"v": 110 + randf() * 40,
				"n": 3 + randi() % 2
			}
		)
		sfx_requested.emit("train")
	for t: Dictionary in _trains:
		t.x += t.dir * t.v * dt
	_trains = _trains.filter(
		func(t: Dictionary) -> bool:
			return t.x + t.n * 64 > 300 if t.dir < 0 else t.x < pc.world_width + 40
	)


# ── Отрисовка ──
func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(floorf(x), floorf(y), w, h), c)


func _draw() -> void:
	if not running and cfg.is_empty():
		return
	var cx := roundf(cam_x)
	var dark := time != "day"
	var bg := _t("%s_%s_bg" % [world, time])
	if bg:
		draw_texture(bg, Vector2(-cx, 0))
	_draw_trains(dark, cx)
	for s: Dictionary in _smoke:
		var a: float = (0.25 if dark else 0.35) * (1 - s.t / 4)
		var col := (
			Color(120 / 255.0, 110 / 255.0, 140 / 255.0, a)
			if dark
			else Color(220 / 255.0, 220 / 255.0, 225 / 255.0, a)
		)
		var r: float = 2 + s.t * 2
		_r(s.x - cx - r / 2, s.y - r / 2, floorf(r), floorf(r * 0.7), col)
	var n := near()
	var actors: Array = []
	var quiet: bool = cfg.has("scenes") and not cfg.get("npcsOn", false)
	if world == "yard" and not quiet:
		for npc: Array in pc.yard_npcs:
			var need: String = npc[4]
			if (
				(cfg.spots.has(need) or (cfg.has("info") and cfg.info.has(need)))
				and (not npc[5] or time == "day")
			):
				actors.append([float(npc[3]), "npc", npc[0], float(npc[1]) - cx, float(npc[2])])
	if cfg.has("follow"):
		var f := follower()
		var mv: bool = hero.moving and _trail.size() > 18
		var bob := -1.0 if mv and sin(t_ms / 90.0) > 0 else 0.0
		actors.append([f.y, "npc", "sera", roundf(f.x - 5 - cx), roundf(f.y - 16 + bob)])
	var on_swing: bool = (
		world == "yard"
		and dark
		and not cfg.has("items")
		and not cfg.get("noSera", false)
		and not cfg.has("follow")
	)
	if world == "yard":
		actors.append([121.0, "swing_sera" if on_swing else "swing", cx])
	if cfg.get("seraBench", false):
		actors.append(
			[106.0, "npc", "sera_sit", 494 - cx, 93.0 + (1.0 if sin(t_ms / 700.0) > 0.3 else 0.0)]
		)
	for e: Dictionary in cfg.get("npcs", []):
		actors.append([float(e.y) + 14, "npc", e.id, roundf(e.x - cx), float(e.y)])
	if not sitting:
		actors.append([float(hero.y), "hero"])
	actors.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for a: Array in actors:
		if a[1] == "hero":
			_draw_hero(roundf(hero.x - cx), roundf(hero.y))
		elif a[1] == "swing" or a[1] == "swing_sera":
			_draw_swing(cx, a[1] == "swing_sera", dark)
		else:
			_draw_npc(a[2], a[3], a[4])
	_draw_world_fx(dark, cx)
	_draw_items(cx)
	_draw_markers(n, cx)
	var fg := _t("%s_%s_fg" % [world, time])
	if fg:
		draw_texture(fg, Vector2(-cx, 0))
	var rc := Color(200 / 255.0, 210 / 255.0, 235 / 255.0, 0.42)
	for d: Dictionary in _drops:
		for k in int(d.l):
			_r(d.x - k * 0.12, d.y + k, 1, 1, rc)
	if not dark:
		draw_rect(
			Rect2(0, 0, pc.screen.x, pc.screen.y), Color(40 / 255.0, 50 / 255.0, 70 / 255.0, 0.12)
		)
	if _hit_t >= 0.0:
		var a := clampf(1.0 - _hit_t / pc.hit_delay, 0.0, 1.0)
		draw_rect(Rect2(0, 0, pc.screen.x, pc.screen.y), Color(1, 0.97, 0.9, a * 0.85))


func _draw_hero(x: float, y: float) -> void:
	var tex := _t("hero")
	if tex == null:
		return
	var hb: Dictionary = bake.get("hero", {"fw": 16, "fh": 32, "anchor": [8, 28]})
	var fw: float = hb.fw
	var fh: float = hb.fh
	var col := 4
	if hero.moving:
		col = int(hero.t * 8) % 4
	elif hero.dir == "down" and fmod(hero.idle_t, 4.0) > 3.85:
		col = 6
	elif fmod(hero.idle_t, 3.0) > 2.6:
		col = 5
	var row := DIRS.find(hero.dir)
	draw_texture_rect_region(
		tex, Rect2(x - hb.anchor[0], y - hb.anchor[1], fw, fh), Rect2(col * fw, row * fh, fw, fh)
	)


## Качели во дворе: сиденье на цепях качается; вечером/ночью на них мокрая Сера (капли, язык)
func _draw_swing(cx: float, with_sera: bool, dark: bool) -> void:
	var sw := sin(t_ms / 650.0) * (2.0 if with_sera else 0.6)
	var dx := roundf(sw)
	var seat_y := 116.0 - absf(sw) * 0.3
	if sitting:
		dx = roundf(sin(_sw_ang) * 12.0)
		seat_y = 104.0 + cos(_sw_ang) * 12.0
	var chain := Color("#8a8a96") if not dark else Color("#6a6a78")
	for x0: float in [216.0, 234.0]:
		for k in 12:
			var f := k / 12.0
			if k % 3 != 2:
				_r(x0 + dx * f - cx, 104 + (seat_y - 104) * f, 1, 1, chain)
	_r(217 + dx - cx, seat_y, 18, 1, Color("#6a4426"))
	_r(217 + dx - cx, seat_y + 1, 18, 1, Color("#3a2414"))
	if sitting:
		_draw_sitting_hero(220.0 + dx - cx, seat_y, dark)
	if with_sera:
		var sx := 219.0 + dx - cx
		var sy := seat_y - 13.0
		_draw_npc("sera_sit", sx, sy)
		# мокрая: капли срываются с волос и падают
		var drip := Color(0.81, 0.88, 1.0, 0.9)
		for i in 3:
			var ph := fmod(t_ms / 1000.0 + i * 0.37, 1.1)
			_r(sx + [0.0, 10.0, 5.0][i], sy + 9 + ph * 14.0, 1, 1, drip)
		# показывает язык
		if fmod(t_ms / 1000.0, 3.0) < 1.2:
			_r(sx + 4, sy + 5, 2, 1, Color("#e8607e"))
			_r(sx + 4, sy + 6, 1, 1, Color("#e8607e"))


## Герой на сиденье (тот же масштаб, что и спрайт героя): лохматая чёлка, чёрная футболка, кеды
func _draw_sitting_hero(sx: float, seat_y: float, dark: bool) -> void:
	var hair := Color("#121018")
	var skin := Color("#f3e3db") if not dark else Color("#d8c4bc")
	var tee := Color("#19181f")
	var pants := Color("#6a6a78")
	var y := seat_y - 15.0
	var lean := roundf(clampf(_sw_vel * 0.6, -1.0, 1.0))
	_r(sx + 2 + lean, y, 7, 2, hair)
	_r(sx + 1 + lean, y + 1, 9, 4, hair)
	_r(sx + 2 + lean, y + 3, 7, 4, skin)
	_r(sx + 2 + lean, y + 3, 7, 1, hair)
	_r(sx + 2 + lean, y + 4, 1, 1, hair)
	_r(sx + 6 + lean, y + 4, 1, 1, hair)
	_r(sx + 3 + lean, y + 5, 1, 1, Color("#2a2436"))
	_r(sx + 6 + lean, y + 5, 1, 1, Color("#2a2436"))
	_r(sx + 1, y + 7, 9, 7, tee)
	_r(sx - 2, y + 4, 2, 4, tee)
	_r(sx + 11, y + 4, 2, 4, tee)
	_r(sx - 2, y + 3, 1, 1, skin)
	_r(sx + 12, y + 3, 1, 1, skin)
	var kick := roundf(clampf(_sw_vel * 1.5, -2.0, 2.0))
	for lx: float in [sx + 2, sx + 6]:
		_r(lx, seat_y + 1, 3, 2, pants)
		_r(lx + kick * 0.5, seat_y + 3, 2, 3, pants)
		_r(lx + kick - 0.0, seat_y + 6, 3, 1, Color("#0c0c10"))


func _draw_npc(id: String, x: float, y: float) -> void:
	var tex := _t("npc_" + id)
	if tex == null:
		return
	var nb: Dictionary = bake.npcs[id]
	var fw: float = nb.fw
	var fh: float = nb.fh
	var fr := 1 if sin(t_ms / 600.0 + x) > 0.7 else 0
	draw_texture_rect_region(tex, Rect2(x - 1, y - 1, fw, fh), Rect2(fr * fw, 0, fw, fh))


func _draw_trains(dark: bool, cx: float) -> void:
	if world != "station" or _trains.is_empty():
		return
	var clip_x := 344 - cx
	for t: Dictionary in _trains:
		for i in int(t.n):
			var x: float = roundf(t.x + (i if t.dir < 0 else -i) * 64 - cx)
			var y := 72.0
			if x + 62 < clip_x:
				continue
			var x0 := maxf(x, clip_x)
			var cut := x0 - x
			_r(x0, y, 62 - cut, 20, Color("#2c4436") if dark else Color("#3d6a52"))
			_r(x0, y - 2, maxf(0, 60 - cut), 2, Color("#6a6a72") if dark else Color("#9a9aa2"))
			_r(x0, y + 14, 62 - cut, 2, Color("#a82a2a"))
			for w in range(4, 58, 7):
				if x + w >= clip_x:
					var on := sin(w + i) > -0.6
					_r(
						x + w,
						y + 4,
						5,
						6,
						(Color("#ffd890") if on else Color("#3a3a40")) if dark else Color("#8fa6b0")
					)
			if i == 0:
				var fx: float = x if t.dir < 0 else x + 61
				if fx >= clip_x:
					_r(fx, y + 10, 1, 2, Color("#fff6c8"))
				if dark:
					var lx: float = fx - 60 if t.dir < 0 else fx + 1
					if lx + 60 > clip_x:
						_r(
							maxf(lx, clip_x),
							y + 4,
							60 - maxf(0, clip_x - lx),
							14,
							Color(1, 240 / 255.0, 190 / 255.0, 0.14)
						)


func _draw_world_fx(dark: bool, cx: float) -> void:
	var k := Color("#121016")
	for c: Dictionary in _crows:
		var x := floorf(c.x - cx)
		var y := floorf(c.y)
		if c.fly:
			var f := int(c.t * 10) % 2
			_r(x - 2, y - f, 2, 1, k)
			_r(x + 1, y - f, 2, 1, k)
			_r(x, y, 1, 1, k)
		else:
			_r(x, y, 3, 2, k)
			_r(x + 2, y - 1, 1, 1, k)
			_r(x - 1, y + 1, 1, 1, k)
	for c: Dictionary in _cars:
		var x := floorf(c.x - cx)
		var y: float = c.y
		if x < -50 or x > pc.screen.x + 50:
			continue
		_r(x - 1, y + 6, 32, 2, Color(0, 0, 0, 0.35))
		_r(x, y, 30, 6, c.c)
		_r(x + 6, y - 4, 16, 4, c.c)
		var wc := Color("#ffd88a") if dark else Color("#9fb4c4")
		_r(x + 8, y - 3, 6, 3, wc)
		_r(x + 15, y - 3, 6, 3, wc)
		_r(x + 4, y + 5, 5, 3, Color("#111111"))
		_r(x + 21, y + 5, 5, 3, Color("#111111"))
		_r(x + 29 if c.dir > 0 else x, y + 1, 1, 2, Color("#fff2b0") if dark else Color("#e8e8e0"))
		_r(x if c.dir > 0 else x + 29, y + 1, 1, 2, Color("#d02a2a"))
		if dark:
			_r(
				x + 30 if c.dir > 0 else x - 30,
				y - 1,
				30,
				7,
				Color(1, 230 / 255.0, 160 / 255.0, 0.12)
			)
	var sc := Color(210 / 255.0, 220 / 255.0, 240 / 255.0, 0.55)
	for s: Dictionary in _splashes:
		var x := floorf(s.x - cx)
		var y := floorf(s.y)
		var kk := 1 if s.t < 0.12 else 2
		_r(x - kk, y, 1, 1, sc)
		_r(x + kk, y, 1, 1, sc)
		if kk == 1:
			_r(x, y - 1, 1, 1, sc)
	var pud: Array = bake.get("worlds", {}).get(world, {}).get("puddles", [])
	for i in pud.size():
		var p: Array = pud[i]
		var ph := fmod(t_ms / 900.0 + i * 0.37, 1.0)
		var rx: float = p[0] - cx + sin(i * 7) * p[2] / 4.0
		var r := int(1 + ph * 5)
		var col := Color(230 / 255.0, 235 / 255.0, 1, 0.4 * (1 - ph))
		_r(rx - r, p[1], 1, 1, col)
		_r(rx + r, p[1], 1, 1, col)


func _draw_items(cx: float) -> void:
	if not cfg.has("items"):
		return
	for i in cfg.items.size():
		if cfg.got.has(i):
			continue
		var x := roundf(cfg.items[i][0] - cx)
		var y: float = cfg.items[i][1]
		if x < -8 or x > pc.screen.x + 8:
			continue
		var fl := 1 if sin(t_ms / 260.0 + i) > 0.6 else 0
		_r(x - 2, y + 1, 6, 7, Color(0, 0, 0, 0.3))
		_r(x - 3, y, 6, 7 - fl, Color("#ecebe4"))
		_r(x - 2, y + 1, 4, 3, Color("#8a2236"))
		_r(x - 2, y + 5, 4, 1, Color("#3a3a40"))
		var by := y - 8 + roundf(sin(t_ms / 300.0 + i) * 1.2)
		_r(x, by, 1, 3, Color("#ffe36b"))
		_r(x, by + 4, 1, 1, Color("#ffe36b"))


func _draw_markers(n: String, cx: float) -> void:
	var sp := spots()
	for id: String in sp:
		if id == "home" or not avail(id):
			continue
		var s: Dictionary = sp[id]
		var done: bool = cfg.done.has(id)
		var x := roundf(s.x - cx)
		var info: bool = cfg.has("info") and cfg.info.has(id) and not cfg.spots.has(id)
		if x < -10 or x > pc.screen.x + 10:
			continue
		var by := roundf(s.y - 34 + sin(t_ms / 300.0 + s.x) * 1.5)
		if info:
			var c := Color("#ffe36b") if n == id else Color("#9fd0ff")
			_r(x - 1, by + 2, 3, 3, c)
			_r(x, by + 6, 1, 2, c)
			continue
		if s.get("decor", false):
			var c := Color("#ffe36b") if n == id else Color("#ff9fc0")
			_r(x - 1, by + 4, 3, 2, c)
			_r(x - 2, by + 3, 2, 1, c)
			_r(x + 1, by + 3, 2, 1, c)
			_r(x, by + 6, 1, 1, c)
			continue
		_r(x - 3, by - 1, 7, 10, Color(0, 0, 0, 0.5))
		var col := (
			Color(160 / 255.0, 160 / 255.0, 170 / 255.0, 0.9)
			if done
			else (Color("#ffe36b") if n == id else Color("#ff6b9a"))
		)
		if done:
			for p: Array in [[-2, 4], [-1, 5], [0, 4], [1, 3], [2, 2]]:
				_r(x + p[0], by + p[1], 1, 1, col)
		else:
			_r(x, by, 2, 5, col)
			_r(x, by + 6, 2, 2, col)
