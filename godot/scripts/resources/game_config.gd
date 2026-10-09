class_name GameConfig
extends Resource
## Настройки правил и подачи новеллы (порт констант js/engine.js).
## Экземпляр: res://data/game_config.tres

@export_group("Новая игра")
@export var start_scene := "start"
@export var start_feel := 50
@export var default_name := "Кирилл"
@export var max_name_length := 16

@export_group("Тон маршрута (tier)")
## feel < cold_feel_below или press >= cold_press_min → cold
@export var cold_feel_below := 40
@export var cold_press_min := 3
## feel >= warm_feel_min и press < warm_press_below → warm
@export var warm_feel_min := 65
@export var warm_press_below := 2

@export_group("Персонажи")
## Позиции на экране (доля ширины) — POS
@export var positions := {"left": 0.25, "center": 0.5, "right": 0.75, "fl": 0.16, "fr": 0.84}
## Персонажи с одним спрайтом (или who_expr, если такой есть) — SINGLE
@export var single_sprite_chars := PackedStringArray(
	["father", "valya", "timur", "liza", "margo", "matvey"]
)
## Имя говорящего → id персонажа — WHO
@export var speaker_to_char := {
	"???": "sera",
	"Сера": "sera",
	"Пастор": "father",
	"P": "hero",
	"Баба Валя": "valya",
	"Тимур": "timur",
	"Лиза": "liza",
	"Маргарита Павловна": "margo",
	"Матвей": "matvey",
	"Парень в пальто": "matvey",
}
## Эмоции Серы, для которых есть кадр моргания — BLINK
@export var blink_exprs := PackedStringArray(["neutral", "cold"])
## Маркер внутреннего голоса героя — THOUGHT
@export var thought_marker := "~"

@export_group("Реакции Серы")
## kind → {spr, ms, hearts, dark, frames}; покадровые — {seq: [[кадр, мс], ...]}
@export var reactions := {
	"pat": {"spr": "pat", "ms": 2700, "frames": true, "hearts": 6},
	"tongue": {"spr": "tongue", "ms": 1500, "hearts": 2, "dark": true},
	"hop": {"spr": "neutral", "ms": 1200, "hearts": 3},
	"shy": {"spr": "shy", "ms": 1600, "hearts": 2},
	"shake": {"spr": "cold", "ms": 1100},
	"shiver": {"spr": "sad", "ms": 900},
	"wipe": {"spr": "sadwipe", "ms": 2000},
	"frown": {"spr": "sadfrown", "ms": 1600},
	"down": {"spr": "saddown", "ms": 2000},
	"yawn": {"seq": [["yawn1", 380], ["yawn2", 950], ["yawn3", 650]]},
	"cover": {"seq": [["cover1", 350], ["cover2", 1300]], "hearts": 2},
	"giggle":
	{
		"seq":
		[["giggle1", 260], ["giggle2", 260], ["giggle1", 260], ["giggle2", 260], ["giggle1", 300]]
	},
	"huff": {"seq": [["huff1", 700], ["huff2", 1000]]},
	"chain": {"seq": [["chain1", 520], ["chain2", 760], ["chain1", 520], ["chain2", 900]]},
	"shout": {"seq": [["shout1", 420], ["shout2", 700], ["shout1", 520], ["shout2", 800]]},
	"vsign": {"seq": [["vsign1", 650], ["vsign2", 1000]]},
}
## Когда Сера плачет — CRY_MAP
@export var cry_map := {
	"pat": "wipe",
	"hop": "wipe",
	"shy": "wipe",
	"tongue": "frown",
	"shake": "frown",
	"shiver": "down"
}

@export_group("Мир")
## Фоны под открытым небом: дождь виден/слышен только здесь — OUTDOOR
@export
var outdoor_bgs := PackedStringArray(["street", "roof", "court", "platform", "yard", "street_rain"])

@export_group("Подача текста и режимы")
@export var default_text_speed := 28.0
@export var default_music_volume := 0.6
@export var default_auto_delay_ms := 1800.0
@export var skip_line_delay_ms := 60.0
@export var card_ms := 3000.0
@export var cut_frame_default_ms := 2600.0
@export var save_slots := 6
@export var log_max := 2000

@export_group("Мини-игра «Дыши со мной»")
@export var breath_inhale_ms := 3000.0
@export var breath_exhale_ms := 3400.0
@export var breath_ok_ratio := 0.6
