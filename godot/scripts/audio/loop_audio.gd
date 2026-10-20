extends "res://scripts/audio/audio.gd"
## Extends 0.7.3 audio; all original samples, volume/pitch and art overrides remain.

const LOOP_SFX := [
	"scream", "glitch", "whisper", "toll", "thud", "wings", "gust", "shriek", "ring", "breath"
]

@onready var drone: AudioStreamPlayer = $LoopDrone
@onready var wind_player: AudioStreamPlayer = $LoopWind


func _ready() -> void:
	super._ready()
	drone.stream = _stream("res://assets/sfx_baked/loop_music_drone.ogg", true)
	wind_player.stream = _stream("res://assets/sfx_baked/loop_wind_loop.ogg", true)


func _update() -> void:
	if mode == "drone":
		_play_track("")
		tense.stop()
		if not drone.playing:
			drone.play()
		return
	drone.stop()
	super._update()


func sfx(key: String, volume_db := 0.0, pitch := 1.0) -> void:
	if key in LOOP_SFX:
		_play_sfx(_stream("res://assets/sfx_baked/loop_%s.ogg" % key, false), volume_db, pitch)
	else:
		super.sfx(key, volume_db, pitch)


func wind(on: bool) -> void:
	if on and not wind_player.playing:
		wind_player.play()
	elif not on:
		wind_player.stop()


func hush() -> void:
	mode = null
	cur_track = ""
	_rain_on = false
	for p: AudioStreamPlayer in [track_a, track_b, tense, rain_player, drone, wind_player]:
		p.stop()
	for p: AudioStreamPlayer in sfx_pool.get_children():
		p.stop()


func _exit_tree() -> void:
	for p: AudioStreamPlayer in [drone, wind_player]:
		p.stop()
		p.stream = null
	super._exit_tree()
