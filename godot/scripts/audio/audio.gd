extends Node
## Звук: трек по локации с кроссфейдом, процедурный «tense», дождь, SFX (порт js/audio.js).

const CONFIG_PATH := "res://data/audio_config.tres"

var config: AudioConfig
## null — тишина; "tense" — процедурная петля; иначе — трек по локации
var mode: Variant = "calm"
var loc := "title"
var cur_track := ""
var _streams: Dictionary = {}
var _active: AudioStreamPlayer
var _rain_on := false
var _sfx_i := 0

@onready var track_a: AudioStreamPlayer = $TrackA
@onready var track_b: AudioStreamPlayer = $TrackB
@onready var tense: AudioStreamPlayer = $Tense
@onready var rain_player: AudioStreamPlayer = $Rain
@onready var sfx_pool: Node = $SfxPool


func _ready() -> void:
	config = load(CONFIG_PATH)
	_active = track_a
	tense.stream = _stream(config.tense_path, true)
	tense.volume_db = config.tense_gain_db
	rain_player.stream = _stream(config.rain_path, true)
	rain_player.volume_db = -80.0
	apply_volume()
	Game.settings_changed.connect(apply_volume)


func apply_volume() -> void:
	var v: float = Game.settings.music
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(v, 0.0001)))


func _stream(path: String, looped: bool) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	if not ResourceLoader.exists(path):
		push_error("Нет звука: " + path)
		return null
	var s: AudioStream = load(path)
	if looped:
		if s is AudioStreamMP3:
			(s as AudioStreamMP3).loop = true
		elif s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
	_streams[path] = s
	return s


func music(m: Variant) -> void:
	if m == null or m == "" or m == "none":
		m = null
	mode = m
	_update()


func set_loc(k: String) -> void:
	if k == "":
		return
	loc = k
	_update()


func _update() -> void:
	if mode == "tense":
		_play_track("")
		if not tense.playing:
			tense.play()
		return
	tense.stop()
	_play_track(config.loc_tracks.get(loc, config.default_track) if mode != null else "")


func _play_track(k: String) -> void:
	if k == cur_track:
		if k != "" and not _active.playing:
			_active.play()
		return
	var had_old := cur_track != ""
	var old := _active
	cur_track = k
	if had_old:
		_fade(old, -80.0, config.fade_out_sec, true)
	if k == "":
		return
	var path: String = config.track_paths.get(k, "")
	var s := _stream(path, true)
	if s == null:
		return
	_active = track_b if old == track_a else track_a
	_active.stream = s
	_active.volume_db = -80.0
	_active.play()
	_fade(
		_active, config.track_gain_db, config.fade_in_sec if had_old else config.fade_in_first_sec, false
	)


func _fade(p: AudioStreamPlayer, to_db: float, sec: float, stop_after: bool) -> void:
	var tw := create_tween()
	tw.tween_property(p, "volume_db", to_db, sec)
	if stop_after:
		tw.tween_callback(p.stop)


func rain(on: bool) -> void:
	if on == _rain_on:
		return
	_rain_on = on
	if on:
		rain_player.play()
		_fade(rain_player, config.rain_gain_db, config.rain_fade_in_sec, false)
	else:
		_fade(rain_player, -80.0, config.rain_fade_out_sec, true)


func sfx(k: String) -> void:
	if not config.sfx_keys.has(k):
		push_warning("Неизвестный SFX: " + k)
		return
	var key := "door_shop" if k == "door" and config.shop_locs.has(loc) else k
	var s := _stream(config.sfx_dir + key + ".ogg", false)
	if s == null:
		return
	var p: AudioStreamPlayer = sfx_pool.get_child(_sfx_i % sfx_pool.get_child_count())
	_sfx_i += 1
	p.stream = s
	p.play()
