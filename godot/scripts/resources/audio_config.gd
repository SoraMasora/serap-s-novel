class_name AudioConfig
extends Resource
## Звук (порт js/audio.js). Экземпляр: res://data/audio_config.tres

## Фон → трек (LOC). Неизвестный фон → default_track
@export var loc_tracks := {}
@export var default_track := "sudno"
@export var track_paths := {
	"roofs": "res://assets/music/roofs.mp3",
	"sudno": "res://assets/music/sudno.mp3",
	"elektro": "res://assets/music/elektro.mp3",
}
## Трек играет на 30% от ползунка музыки и через master 0.8 (TRK·master)
@export var track_gain_db := -12.4
@export var fade_out_sec := 1.6
@export var fade_in_sec := 2.2
@export var fade_in_first_sec := 1.2
## Процедурный «tense» запечён с громкостью музыки 0.6 → компенсация +4.4 дБ
@export var tense_path := "res://assets/sfx_baked/music_tense.ogg"
@export var tense_gain_db := 4.4
@export var rain_path := "res://assets/sfx_baked/rain_loop.ogg"
@export var rain_gain_db := 0.0
@export var rain_fade_in_sec := 2.0
@export var rain_fade_out_sec := 1.5
## Локации-магазины: у двери звенит колокольчик
@export var shop_locs := PackedStringArray(["store", "cafe", "cg_shift"])
@export var sfx_dir := "res://assets/sfx_baked/"
@export var sfx_keys := PackedStringArray(
	[
		"door", "enter", "bell", "train", "horn", "slam", "heart", "tear", "phone", "keys",
		"steps", "step", "bump", "drop", "knock", "creak", "cloth", "paper", "latch", "unlock"
	]
)
