extends Control
## Главная сцена: подача новеллы — порт begin/run/say/choose/finish/openMap… из js/engine.js.
## Логика сценария — StoryRunner (чистые данные), здесь только показ, ввод и тайминги.

const CHARACTER := preload("res://scenes/ui/character_view.tscn")
const CHOICE := preload("res://scenes/ui/choice_button.tscn")
const HEART := preload("res://scenes/ui/heart.tscn")
const PAT_FRAMES := ["sera_pat2", "sera_pat3", "sera_pat4", "sera_pat3"]
## Анимированные фоны: ключ фона → кадры (godot/art/bg) и fps. Сюжет пишет {bg:'bal_talk'}.
const BG_ANIM := {
	"bal_s0": {"frames": ["bal_l0", "bal_l1", "bal_l2", "bal_l3"], "fps": 6.0},
	"bal_talk": {"frames": ["bal_t0", "bal_t1", "bal_t2", "bal_t3"], "fps": 2.5},
	"m2_rs": {"frames": ["m2_rs0", "m2_rs1", "m2_rs2", "m2_rs3"], "fps": 2.5},
	# 0.6: крыша заново — дым от кончиков сигарет (m2_rx) / некурящий вариант с чаем (m2_rt)
	"m2_rx": {"frames": ["m2_rx0", "m2_rx1", "m2_rx2", "m2_rx3"], "fps": 2.5},
	"m2_rt": {"frames": ["m2_rt0", "m2_rt1", "m2_rt2", "m2_rt3"], "fps": 2.0},
	"m2_sn":
	{
		"frames": ["m2_sn0", "m2_sn1", "m2_sn2", "m2_sn3", "m2_sn4", "m2_sn5"],
		"fps": 5.0,
	},
	"m2_hug":
	{
		"frames": ["m2_hug0", "m2_hug1", "m2_hug2", "m2_hug3", "m2_hug4", "m2_hug5"],
		"fps": 5.0,
	},
}

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
var _ui_hidden := false
var _bg_anim: Dictionary = {}
var _line_key := ""
var _choice_cg := ChoiceCGState.new()

@onready var choice_cg_frame: TextureRect = $ChoiceCGFrame
@onready var stage: Control = $Stage
@onready var gloom: ColorRect = $Stage/Gloom
@onready var rain_fx: RainFx = $Stage/Rain
@onready var chars_layer: Control = $Stage/Chars
@onready var fx_layer: Control = $Stage/FxLayer
@onready var flash: ColorRect = $Stage/Flash
@onready var hud: Control = $Hud
@onready var chapter_label: Label = $Hud/Chapter
@onready var toast: Label = $Toast
@onready var side: Control = $Side
@onready var side_img: TextureRect = $Side/Clip/Img
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
	for n: Node in [modal, title, ending, name_screen, pixel_map]:
		UiFx.decorate(n)
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
	_choice_cg.reset()
	choice_cg_frame.visible = false
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
	_choice_cg.clear()
	choice_cg_frame.visible = false
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
	var cg_key := _choice_cg.response(str(runner.st.scene))
	choice_cg_frame.texture = Game.tex("bg", cg_key) if cg_key != "" else null
	choice_cg_frame.visible = choice_cg_frame.texture != null
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
		var bird := str(e.expr) == "bird"
		var t := Game.tex(
			"sprites", "side_bird" if bird else "hero_" + str(e.expr if e.expr else "neutral")
		)
		_side_frame(bird)
		if t and (not side.visible or side_img.texture != t):
			side_img.texture = t
			side.modulate.a = 0.0
			create_tween().tween_property(side, "modulate:a", 1.0, 0.35)
			if bird:
				_bird_pop()
		side.visible = true
	else:
		side.visible = false
	textbox.set_side_padding(side.visible)
	textbox.visible = true
	waiting = false
	_line_key = "%s:%d" % [runner.st.scene, runner.st.i]
	if skip and not Game.is_seen(_line_key):
		skip = false
		_sync_btns()
		show_toast("Новый текст — пропуск остановлен")
	textbox.show_line(e.display, kind, e.text, thought, skip or Game.settings.speed <= 0)
	var sv: CharacterView = _chars.get(who)
	if sv and not skip and not thought and e.changes.is_empty():
		sv.talk()


## Отложенный переход: только если реплика не сменилась (и авто ещё включено)
## Портрет: герой (крупно лицо, кадрирование спрайта) или птичка «Вряд ли» (весь кадр)
func _side_frame(bird: bool) -> void:
	if bird:
		side_img.anchor_left = 0.0
		side_img.anchor_top = 0.0
		side_img.anchor_right = 1.0
		side_img.anchor_bottom = 1.0
		side_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		side_img.anchor_left = -0.62
		side_img.anchor_top = -0.03
		side_img.anchor_right = 1.62
		side_img.anchor_bottom = 2.45
		side_img.stretch_mode = TextureRect.STRETCH_SCALE
	side_img.offset_left = 0
	side_img.offset_top = 0
	side_img.offset_right = 0
	side_img.offset_bottom = 0


## Птичка «выскакивает» вместо героя: пружинка и лёгкое покачивание
func _bird_pop() -> void:
	side.scale = Vector2(0.55, 0.55)
	var tw := create_tween()
	tw.tween_property(side, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tw.parallel().tween_property(side, "rotation", 0.06, 0.15)
	tw.tween_property(side, "rotation", -0.09, 0.18)
	tw.tween_property(side, "rotation", -0.05, 0.2)
	Audio.sfx("pop")


func _advance_if(g: int, need_auto: bool) -> void:
	if g == _gen and (auto or not need_auto):
		advance()


func _on_typing_done() -> void:
	waiting = true
	if _line_key != "":
		Game.mark_seen(_line_key)
	autosave()
	var g := _gen
	if skip:
		_after(cfg.skip_line_delay_ms, _advance_if.bind(g, false))
	elif auto:
		var n := textbox.text.get_total_character_count()
		_after(Game.settings.auto_delay + n * auto_ms_per_char, _advance_if.bind(g, true))


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
		b.setup(runner.fmt(o.t), i)
		b.pressed.connect(_on_choice.bind(i))
		b.hovered.connect(hover_lean)
	choices.visible = true


func _on_choice(i: int) -> void:
	if not in_choice:
		return
	in_choice = false
	hover_lean(false)
	var last: Tween
	var kids := choice_list.get_children()
	for k in kids.size():
		var b := kids[k] as ChoiceButton
		if b:
			last = b.play_chosen() if k == i else b.play_dismiss(k)
	if last and not skip and is_inside_tree():
		await get_tree().create_timer(0.36).timeout
	choices.visible = false
	_choice_cg.arm()
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
	_bg_anim = {}
	if BG_ANIM.has(k):
		_bg_anim = {
			"frames": BG_ANIM[k].frames, "dt": 1.0 / float(BG_ANIM[k].fps), "t": 0.0, "i": 0
		}
	var t := Game.tex("bg", _bg_anim.frames[0] if _bg_anim else k)
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


func _process(delta: float) -> void:
	if _bg_anim.is_empty():
		return
	_bg_anim.t += delta
	if _bg_anim.t < _bg_anim.dt:
		return
	_bg_anim.t -= _bg_anim.dt
	_bg_anim.i = (int(_bg_anim.i) + 1) % _bg_anim.frames.size()
	_bg_front.texture = Game.tex("bg", str(_bg_anim.frames[_bg_anim.i]))


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
	v.react(
		"sera_" + str(r.get("spr", "neutral")), seq, ms, kind, PAT_FRAMES if r.get("frames") else []
	)
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
	var text := (
		"%s\n\nЗаметок о Сере собрано: %d из %d"
		% [e.text, runner.st.notes.size(), Game.db.notes_total]
	)
	_after(ending_delay_sec * 1000.0, func() -> void: ending.open(e.title, text))


# ── Сохранения ──
func autosave() -> void:
	if not playing:
		return
	save_to("auto")


func save_to(slot: String) -> void:
	var s := runner.save_snapshot()
	s["presentation_cg"] = _choice_cg.key
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
	_choice_cg.restore_next = str(s.get("presentation_cg", ""))
	var story_state := s.duplicate(true)
	story_state.erase("presentation_cg")
	runner.restore(story_state)
	_present_state()


func _reset_presentation() -> void:
	_choice_cg.reset()
	choice_cg_frame.visible = false
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
			if skip and not waiting and not Game.is_seen(_line_key):
				skip = false
				show_toast("Пропуск — только по прочитанному")
			_sync_btns()
			if skip and (waiting or textbox.typing):
				advance()
		"hide":
			set_ui_hidden(true)
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
	if k == "fullscreen":
		Game.apply_window()
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


## Режим «Кадр»: прячет весь интерфейс, любой клик/клавиша возвращает
func set_ui_hidden(on: bool) -> void:
	_ui_hidden = on
	if on:
		auto = false
		skip = false
		_sync_btns()
	var a := 0.0 if on else 1.0
	for n: CanvasItem in [textbox, side, hud, choices]:
		create_tween().tween_property(n, "modulate:a", a, 0.25)
	textbox.mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_STOP
	choices.mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_PASS


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
			Game.toggle_fullscreen()
			get_viewport().set_input_as_handled()
			return
	if not _ui_hidden:
		return
	var press: bool = (
		(event is InputEventKey and event.pressed)
		or (event is InputEventMouseButton and event.pressed)
	)
	if press:
		set_ui_hidden(false)
		get_viewport().set_input_as_handled()


# ── Клавиатура ──
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_H and textbox.visible and playing:
			if not modal.is_open() and not pixel_map.is_open():
				set_ui_hidden(true)
				return
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
