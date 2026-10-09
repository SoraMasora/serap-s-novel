extends Control
## Главная сцена: подача новеллы — порт begin/run/say/choose/finish/openMap… из js/engine.js.
## Логика сценария — StoryRunner (чистые данные), здесь только показ, ввод и тайминги.

const CHARACTER := preload("res://scenes/ui/character_view.tscn")
const CHOICE := preload("res://scenes/ui/choice_button.tscn")
const HEART := preload("res://scenes/ui/heart.tscn")
const PAT_FRAMES := ["sera_pat2", "sera_pat3", "sera_pat4", "sera_pat3"]

@export var bg_fade_sec := 1.2
@export var cam_default_ms := 1400.0
@export var cam_default_scale := 1.6
@export var zoom_scale := 1.35
@export var zoom_origin := Vector2(0.67, 0.68)
@export var zoom_sec := 1.4
@export var toast_sec := 1.8
@export var auto_ms_per_char := 25.0
@export var save_log_tail := 200
@export var ending_delay_sec := 0.9

var runner: StoryRunner
var cfg: GameConfig
var auto := false
var skip := false
var in_choice := false
var waiting := false
var breath_on := false
var playing := false
var _chars: Dictionary = {}
var _lean_on := false
var _gen := 0
var _options: Array = []
var _bg_front: TextureRect
var _bg_back: TextureRect
var _toast_tw: Tween

@onready var stage: Control = $Stage
@onready var gloom: ColorRect = $Stage/Gloom
@onready var rain_fx: RainFx = $Stage/Rain
@onready var chars_layer: Control = $Stage/Chars
@onready var fx_layer: Control = $Stage/FxLayer
@onready var flash: ColorRect = $Stage/Flash
@onready var hud: Control = $Hud
@onready var chapter_label: Label = $Hud/Chapter
@onready var toast: Label = $Toast
@onready var side: TextureRect = $Side
@onready var textbox: TextBox = $TextBox
@onready var choices: Control = $Choices
@onready var choice_list: VBoxContainer = $Choices/List
@onready var pixel_map: PixelMap = $PixelMap
@onready var cut: Cutscene = $Cutscene
@onready var card: ChapterCard = $ChapterCard
@onready var breath: BreathGame = $BreathGame
@onready var title: TitleScreen = $TitleScreen
@onready var name_screen: NameScreen = $NameScreen
@onready var modal: Modal = $Modal
@onready var ending: EndingScreen = $EndingScreen


func _ready() -> void:
	cfg = Game.config
	runner = StoryRunner.new(Game.db, cfg)
	_bg_front = $Stage/BgA
	_bg_back = $Stage/BgB
	textbox.speed = Game.settings.speed
	breath.inhale_ms = cfg.breath_inhale_ms
	breath.exhale_ms = cfg.breath_exhale_ms
	breath.ok_ratio = cfg.breath_ok_ratio
	_connect_signals()
	if _cli_autoplay():
		return
	to_title()


func _connect_signals() -> void:
	textbox.clicked.connect(_on_textbox_click)
	textbox.typing_done.connect(_on_typing_done)
	textbox.control_pressed.connect(_on_control)
	$Stage/ClickCatcher.gui_input.connect(_on_stage_input)
	cut.caption_shown.connect(
		func(t: String) -> void: runner.log_push({"n": "", "t": t, "s": runner.snap_lite(-1)})
	)
	cut.sfx_requested.connect(func(k: String) -> void: Audio.sfx(k))
	cut.finished.connect(_resume_after_overlay)
	card.finished.connect(_resume_after_overlay)
	breath.heartbeat.connect(func() -> void: Audio.sfx("heart"))
	breath.finished.connect(_on_breath_done)
	pixel_map.entered.connect(_on_map_entered)
	pixel_map.item_picked.connect(func() -> void: autosave())
	pixel_map.button_pressed.connect(_on_control)
	title.action.connect(_on_title_action)
	name_screen.confirmed.connect(_on_name)
	modal.slot_chosen.connect(_on_slot)
	modal.setting_changed.connect(_on_setting)
	modal.menu_action.connect(_on_menu)
	modal.rollback_confirmed.connect(rollback)
	ending.back.connect(to_title)


## Безголовый автоплей для CI/отладки: godot --headless --path godot -- --autoplay=SEED
func _cli_autoplay() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autoplay="):
			var r := AutoPlayer.new(StoryRunner.new(Game.db, cfg)).play(int(a.get_slice("=", 1)))
			print("AUTOPLAY ", JSON.stringify(r))
			get_tree().quit(0 if r.ending != "" else 1)
			return true
	return false


# ── Экраны ──
func to_title() -> void:
	playing = false
	auto = false
	skip = false
	_sync_btns()
	_gen += 1
	for n: Control in [ending, modal, textbox, hud, choices, card, side, name_screen]:
		n.visible = false
	cut.kill()
	breath.kill()
	pixel_map.close()
	_clear_chars()
	Audio.set_loc("title")
	Audio.music("calm")
	Audio.rain(false)
	_set_rain(false)
	title.visible = true
	title.refresh(SaveSystem.has_slot("auto"))


func begin() -> void:
	playing = true
	title.visible = false
	hud.visible = true
	if runner.st.mode == "map":
		open_map()
		return
	textbox.visible = true
	run()


func _on_title_action(a: String) -> void:
	match a:
		"new":
			title.visible = false
			name_screen.open(cfg.max_name_length, cfg.default_name)
		"continue":
			load_slot("auto")
		"load":
			modal.open_slots("load", _slot_infos())
		"endings":
			modal.open_endings(SaveSystem.endings(), Game.db.endings)
		"settings":
			modal.open_settings(Game.settings)


func _on_name(n: String) -> void:
	runner.new_game(n)
	begin()


# ── Исполнение ──
func run() -> void:
	if not playing:
		return
	for e: Dictionary in runner.step():
		_apply(e)


func _apply(e: Dictionary) -> void:
	match e.type:
		"say":
			_say(e)
		"card":
			textbox.visible = false
			side.visible = false
			card.show_card(e.big, e.small, 300.0 if skip else cfg.card_ms)
		"note":
			if not skip:
				show_toast("✎ Новая заметка о Сере")
		"chapter":
			chapter_label.text = e.text
		"bg":
			set_bg(e.key, false)
		"zoom":
			_zoom()
		"cam":
			cam_to(e.cam)
		"cut":
			textbox.visible = false
			side.visible = false
			cut.play(e.frames, skip, runner.fmt)
		"music":
			Audio.music(e.mode)
		"rain":
			_set_rain(e.on)
		"show":
			_show_view(e.who, e.expr, e.pos)
		"hide":
			for w: String in e.who:
				_hide_view(w)
		"fx":
			if not skip:
				_fx(e.kind)
		"sfx":
			if not skip:
				Audio.sfx(e.key)
		"react":
			if not skip:
				react(e.kind)
		"breath":
			_breath(e.cfg)
		"choice":
			_choose(e.options)
		"map":
			open_map()
		"final":
			finish(e.kind)
		"stall":
			push_error("Сцена %s закончилась без перехода" % e.scene)


func _resume_after_overlay() -> void:
	textbox.visible = true
	run()


# ── Реплики ──
func _say(e: Dictionary) -> void:
	for ch: Dictionary in e.changes:
		_show_view(ch.who, ch.expr, ch.pos)
	var speaker: String = e.name
	var thought: bool = e.thought
	var who := runner.char_for(speaker)
	var kind := "sera"
	if speaker == "P":
		kind = "gg"
	elif speaker == "Пастор":
		kind = "father"
	elif speaker == "???":
		kind = "unk"
	elif who != "" and speaker != "Сера":
		kind = "npc"
	var hero_on: bool = runner.st.chars.has("hero")
	_set_speaker("" if (speaker == "P" and not hero_on) or thought else speaker)
	if speaker == "P" and not hero_on:
		var t := Game.tex("sprites", "hero_" + str(e.expr if e.expr else "neutral"))
		if t and (not side.visible or side.texture != t):
			side.texture = t
			side.modulate.a = 0.0
			create_tween().tween_property(side, "modulate:a", 1.0, 0.35)
		side.visible = true
	else:
		side.visible = false
	textbox.set_side_padding(side.visible)
	textbox.visible = true
	waiting = false
	textbox.show_line(e.display, kind, e.text, thought, skip or Game.settings.speed <= 0)


func _on_typing_done() -> void:
	waiting = true
	autosave()
	var g := _gen
	if skip:
		_after(cfg.skip_line_delay_ms, func() -> void: if g == _gen: advance())
	elif auto:
		var n := textbox.text.get_total_character_count()
		_after(Game.settings.auto_delay + n * auto_ms_per_char, func() -> void: if g == _gen and auto: advance())


func _after(ms: float, f: Callable) -> void:
	get_tree().create_timer(ms / 1000.0).timeout.connect(f)


func advance() -> void:
	if in_choice or modal.is_open() or not playing:
		return
	if textbox.typing:
		textbox.finish_typing()
		return
	if waiting:
		waiting = false
		_gen += 1
		run()


func _on_textbox_click() -> void:
	if skip:
		skip = false
		_sync_btns()
	advance()


func _on_stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if textbox.visible:
			advance()


# ── Выбор ──
func _choose(options: Array) -> void:
	in_choice = true
	skip = false
	_sync_btns()
	autosave()
	runner.mark_choice_shown()
	_options = options
	for c: Node in choice_list.get_children():
		c.queue_free()
	for i in options.size():
		var o: Dictionary = options[i]
		var b: ChoiceButton = CHOICE.instantiate()
		choice_list.add_child(b)
		b.setup(runner.fmt(o.t), o.get("hint", ""))
		b.pressed.connect(_on_choice.bind(i))
		b.hovered.connect(hover_lean)
	choices.visible = true


func _on_choice(i: int) -> void:
	choices.visible = false
	in_choice = false
	hover_lean(false)
	var rk := runner.choose(_options, i)
	if rk != "":
		react(rk)
	run()


# ── Мини-игра дыхания ──
func _breath(bcfg: Dictionary) -> void:
	textbox.visible = false
	side.visible = false
	breath_on = true
	breath.start(bcfg, skip)
	set_meta("breath_cfg", bcfg)


func _on_breath_done(score: float) -> void:
	breath_on = false
	runner.breath_result(get_meta("breath_cfg"), score)
	textbox.visible = true
	run()


# ── Карта ──
func open_map() -> void:
	_clear_chars()
	runner.hide_char("all")
	textbox.visible = false
	side.visible = false
	choices.visible = false
	var m: Dictionary = runner.st.map
	if m.has("bg"):
		set_bg(m.bg, false)
	Audio.set_loc("map")
	if m.has("music"):
		runner.st.music = m.music
		Audio.music(m.music)
	_set_rain(false)
	Audio.rain(true)
	chapter_label.text = runner.st.chapter
	pixel_map.open(m)
	autosave()


func _on_map_entered(id: String, pos: Dictionary) -> void:
	runner.map_enter(id, pos)
	textbox.visible = true
	run()


# ── Фон, камера, погода ──
func set_bg(k: String, instant: bool) -> void:
	cam_to(null)
	Audio.set_loc(k)
	_apply_rain()
	var t := Game.tex("bg", k)
	if t == null:
		push_warning("Нет фона: " + k)
	if instant:
		_bg_front.texture = t
		_bg_front.modulate.a = 1.0
		_bg_back.modulate.a = 0.0
		return
	_bg_back.texture = t
	var tw := create_tween().set_parallel()
	tw.tween_property(_bg_back, "modulate:a", 1.0, bg_fade_sec)
	tw.tween_property(_bg_front, "modulate:a", 0.0, bg_fade_sec)
	var tmp := _bg_front
	_bg_front = _bg_back
	_bg_back = tmp


func cam_to(c: Variant) -> void:
	for b: TextureRect in [_bg_front, _bg_back]:
		b.scale = Vector2.ONE
	if not (c is Dictionary):
		return
	var ms: float = 1.0 if skip else float(c.get("ms", cam_default_ms))
	_bg_front.pivot_offset = _bg_front.size * Vector2(c.x / 100.0, c.y / 100.0)
	var s: float = c.get("s", cam_default_scale)
	create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT).tween_property(
		_bg_front, "scale", Vector2(s, s), ms / 1000.0
	)


func _zoom() -> void:
	_bg_front.pivot_offset = _bg_front.size * zoom_origin
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(
		_bg_front, "scale", Vector2(zoom_scale, zoom_scale), zoom_sec
	)


func _set_rain(on: bool) -> void:
	runner.st.rain = on
	_apply_rain()


func _apply_rain() -> void:
	var outdoor := bool(runner.st.rain) and cfg.outdoor_bgs.has(str(runner.st.bg))
	rain_fx.raining = outdoor
	gloom.visible = bool(runner.st.rain)
	for b: TextureRect in [_bg_front, _bg_back]:
		b.self_modulate = Color(0.8, 0.8, 0.84) if runner.st.rain else Color.WHITE
	if not pixel_map.visible:
		Audio.rain(outdoor)


func _fx(kind: String) -> void:
	if kind == "flash":
		flash.modulate.a = 0.85
		create_tween().tween_property(flash, "modulate:a", 0.0, 0.7)
	elif kind == "shake":
		var tw := create_tween()
		for x: float in [-8.0, 8.0, -5.0, 5.0, 0.0]:
			tw.tween_property(stage, "position:x", x, 0.14)


# ── Персонажи ──
func _sprite_key(who: String, expr: Variant) -> String:
	if cfg.single_sprite_chars.has(who):
		var k := "%s_%s" % [who, expr]
		return k if expr and Game.has_tex("sprites", k) else who
	return "%s_%s" % [who, expr]


func _show_view(who: String, expr: Variant, pos: String) -> void:
	var key := _sprite_key(who, expr)
	var v: CharacterView = _chars.get(who)
	var x: float = cfg.positions.get(pos, 0.5)
	if v == null or v.dying:
		v = CHARACTER.instantiate()
		chars_layer.add_child(v)
		v.who = who
		_chars[who] = v
		v.set_base_key(key)
		v.place(x, true)
		v.appear()
	else:
		v.set_base_key(key)
		v.place(x, false)
		v.appear()
	v.expr = expr
	var bk := "blink_" + str(expr)
	v.set_blink_texture(
		Game.tex("sprites", bk) if who == "sera" and cfg.blink_exprs.has(str(expr)) else null
	)


func _hide_view(who: String) -> void:
	var v: CharacterView = _chars.get(who)
	if v:
		v.vanish()
		_chars.erase(who)


func _clear_chars() -> void:
	for v: CharacterView in _chars.values():
		v.queue_free()
	_chars.clear()


func _set_speaker(speaker: String) -> void:
	var active_who := runner.char_for(speaker) if speaker != "" else ""
	for who: String in _chars:
		var active := speaker == "" or active_who == who
		(_chars[who] as CharacterView).set_dim(not (active or _chars.size() < 2))


func react(kind: String) -> void:
	var sera: Dictionary = runner.st.chars.get("sera", {})
	if str(sera.get("expr", "")).begins_with("sad") and cfg.cry_map.has(kind):
		kind = cfg.cry_map[kind]
	var v: CharacterView = _chars.get("sera")
	var r: Dictionary = cfg.reactions.get(kind, {})
	if v == null or r.is_empty() or sera.is_empty():
		return
	_lean_on = false
	var seq: Array = r.get("seq", [])
	var ms: float = r.get("ms", 0.0)
	if ms <= 0.0:
		for f: Array in seq:
			ms += float(f[1])
	v.react("sera_" + str(r.get("spr", "neutral")), seq, ms, kind, PAT_FRAMES if r.get("frames") else [])
	if r.has("hearts"):
		_hearts(int(r.hearts), bool(r.get("dark", false)))


func hover_lean(on: bool) -> void:
	var v: CharacterView = _chars.get("sera")
	if v == null or v.reacting:
		return
	var crying := str(runner.st.chars.get("sera", {}).get("expr", "")).begins_with("sad")
	if on and not _lean_on:
		_lean_on = true
		v.lean(true, "sera_sadwipe" if crying else "sera_lean")
	elif not on and _lean_on:
		_lean_on = false
		v.lean(false, "")


func _hearts(n: int, dark: bool) -> void:
	for k in n:
		_after(
			k * 160.0,
			func() -> void:
				var h: Label = HEART.instantiate()
				h.position = fx_layer.size * Vector2(0.38 + randf() * 0.24, 0.25 + randf() * 0.25)
				fx_layer.add_child(h)
				h.set_dark(dark)
		)


# ── Финал ──
func finish(kind: String) -> void:
	auto = false
	skip = false
	_sync_btns()
	SaveSystem.unlock_ending(kind)
	SaveSystem.delete_slot("auto")
	var e: Dictionary = Game.db.endings.get(kind, {"title": kind, "text": ""})
	var text := "%s\n\nЗаметок о Сере собрано: %d из %d" % [e.text, runner.st.notes.size(), Game.db.notes_total]
	_after(ending_delay_sec * 1000.0, func() -> void: ending.open(e.title, text))


# ── Сохранения ──
func autosave() -> void:
	if not playing:
		return
	save_to("auto")


func save_to(slot: String) -> void:
	var s := runner.save_snapshot()
	if runner.st.mode == "map" and pixel_map.is_open():
		s.map.pos = pixel_map.current_pos()
	SaveSystem.save_slot(slot, s, runner.log.slice(-save_log_tail))


func load_slot(slot: String) -> void:
	var d := SaveSystem.load_slot(slot)
	if d.is_empty():
		show_toast("Слот пуст или повреждён")
		return
	runner.log.assign(d.get("log", []))
	_restore(d.st)


func _restore(s: Dictionary) -> void:
	_reset_presentation()
	runner.restore(s)
	_present_state()


func _reset_presentation() -> void:
	auto = false
	skip = false
	_sync_btns()
	_gen += 1
	waiting = false
	cut.kill()
	card.kill()
	breath.kill()
	breath_on = false
	modal.close()
	pixel_map.close()
	side.visible = false
	_clear_chars()
	for n: Control in [ending, choices, title, name_screen]:
		n.visible = false
	in_choice = false


func _present_state() -> void:
	var st := runner.st
	if str(st.bg) != "":
		set_bg(st.bg, true)
	for w: String in st.chars:
		_show_view(w, st.chars[w].expr, st.chars[w].pos)
	_set_rain(bool(st.rain))
	if str(st.music) != "":
		Audio.music(st.music)
	chapter_label.text = st.chapter
	begin()


func rollback(k: int) -> void:
	if breath_on:
		show_toast("Сначала закончи дыхание")
		return
	_reset_presentation()
	if runner.rollback(k):
		_present_state()
		show_toast("↺ Возврат в прошлое")


func _slot_infos() -> Dictionary:
	var out := {}
	for k in range(1, cfg.save_slots + 1):
		var d := SaveSystem.load_slot(str(k))
		if not d.is_empty():
			out[str(k)] = {"date": d.get("date", ""), "chapter": d.st.get("chapter", "")}
	return out


func _on_slot(mode: String, k: String) -> void:
	if mode == "save":
		save_to(k)
		show_toast("Сохранено")
		modal.open_slots("save", _slot_infos())
	elif SaveSystem.has_slot(k):
		load_slot(k)


# ── Меню и настройки ──
func _on_control(a: String) -> void:
	match a:
		"auto":
			auto = not auto
			skip = false
			_sync_btns()
			if auto and waiting:
				advance()
		"skip":
			skip = not skip
			auto = false
			_sync_btns()
			if skip and (waiting or textbox.typing):
				advance()
		"notes":
			modal.open_notes(runner.st.notes, Game.db.notes_total)
		"log":
			modal.open_log(runner.log)
		"save":
			modal.open_slots("save", _slot_infos())
		"load":
			modal.open_slots("load", _slot_infos())
		"menu":
			modal.open_menu()


func _on_menu(a: String) -> void:
	match a:
		"resume":
			modal.close()
		"settings":
			modal.open_settings(Game.settings)
		"title":
			modal.close()
			to_title()


func _on_setting(k: String, v: float) -> void:
	Game.set_setting(k, v)
	textbox.speed = Game.settings.speed


func _sync_btns() -> void:
	textbox.set_toggle("auto", auto)
	textbox.set_toggle("skip", skip)


func show_toast(t: String) -> void:
	toast.text = t
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(toast, "modulate:a", 1.0, 0.3)
	_toast_tw.tween_interval(toast_sec)
	_toast_tw.tween_property(toast, "modulate:a", 0.0, 0.4)


# ── Клавиатура ──
func _unhandled_input(event: InputEvent) -> void:
	if modal.is_open():
		if event.is_action_pressed("vn_menu"):
			modal.close()
		return
	if pixel_map.is_open() and not title.visible:
		if event.is_action_pressed("vn_menu"):
			modal.open_menu()
		elif event.is_action_pressed("vn_notes"):
			modal.open_notes(runner.st.notes, Game.db.notes_total)
		return
	if not textbox.visible or title.visible or not playing:
		return
	if event.is_action_pressed("vn_advance"):
		get_viewport().set_input_as_handled()
		advance()
	elif event.is_action_pressed("vn_skip_hold"):
		skip = true
		_sync_btns()
		advance()
	elif event.is_action_released("vn_skip_hold"):
		skip = false
		_sync_btns()
	elif event.is_action_pressed("vn_menu"):
		modal.open_menu()
	elif event.is_action_pressed("vn_notes"):
		modal.open_notes(runner.st.notes, Game.db.notes_total)
	elif event.is_action_pressed("vn_auto"):
		_on_control("auto")
