class_name PixelConfig
extends Resource
## Пиксельная прогулка (порт констант js/pixel.js). Экземпляр: res://data/pixel_config.tres

@export var screen := Vector2i(320, 180)
@export var world_width := 560
@export var walk_y_min := 108.0
@export var walk_y_max := 146.0
## Проезжая часть во дворе: ниже road_y — дорога; можно дойти до road_y_max
@export var road_y := 153.0
@export var road_y_max := 174.0
@export var road_car_after := 0.9
@export var road_car_speed := 170.0
@export var hit_delay := 0.7
@export var road_warning := "Дорога. Машины тут не тормозят — даже ночью, даже под дождём."
@export var walk_speed := 64.0
@export var run_speed := 92.0
@export var step_interval := 0.27
@export var run_step_interval := 0.2
@export var near_radius := 18.0
@export var item_radius := 15.0
@export var say_seconds := 3.2
## world → {id: {x, y, label, decor?}}
@export var spots := {
	"yard":
	{
		"home": {"x": 97, "y": 110, "label": "Подъезд №3 · домой"},
		"valya": {"x": 67, "y": 118, "label": "Лавочка у подъезда"},
		"cafe": {"x": 329, "y": 110, "label": "Кафе «Луна»"},
		"store": {"x": 424, "y": 110, "label": "Магазин «24 часа»"},
		"college": {"x": 515, "y": 110, "label": "Художественный колледж"},
		"swing": {"x": 226, "y": 124, "label": "Качели", "decor": true},
	},
	"station":
	{
		"home": {"x": 22, "y": 116, "label": "Обратно во двор"},
		"kiosk": {"x": 205, "y": 112, "label": "Ларёк «Табак · Шаурма»"},
		"underpass": {"x": 300, "y": 112, "label": "Подземный переход"},
		"platform": {"x": 499, "y": 114, "label": "Платформа 47 км"},
	},
}
## world → [[текст, x, y]]
@export var signs := {
	"yard":
	[
		["Подъезд №3", 97, 63],
		["Кафе «Луна»", 329, 58],
		["24 часа", 424, 52],
		["Колледж искусств", 515, 66]
	],
	"station":
	[["Гаражи", 80, 62], ["Табак · Шаурма", 207, 52], ["Переход", 300, 54], ["47 км", 470, 50]],
}
## Препятствия двора [x1, y1, x2, y2]: лавочка, баки, песочница, качели
@export var obstacles := {
	"yard":
	[
		[52, 104, 82, 113],
		[234, 134, 270, 150],
		[170, 98, 196, 111],
		[196, 119, 212, 127],
		[211, 116, 241, 121]
	],
	"station": [],
}
## NPC двора: [id, x, y, depth_y, нужна_точка, только_днём]
@export var yard_npcs := [
	["valya", 60, 100, 113, "valya", false],
	["timur", 446, 97, 112, "store", false],
	["margo", 534, 97, 112, "college", true],
]
@export var follow_lines := PackedStringArray(
	[
		"Сера: «Не беги так. У меня ноги короче, чем твоя совесть».",
		"Сера: «Смотри, лужа в форме таракана. Это знак».",
		"Сера: «Я тут каждую ночь хожу. С тобой почему-то не так страшно. Только не зазнавайся».",
		"Сера: «Ты всегда так сутулишься? Выпрямись, затворник».",
		"Сера: «Магазин там, если что. Направо. Вечно направо».",
	]
)
@export var swing_lines := PackedStringArray(
	[
		(
			"Сера качается под дождём — промокла до нитки и уходить не собирается. "
			+ "Увидела меня — показала язык."
		),
		(
			"Сера раскачивается, подставив лицо дождю. "
			+ "«Не мешай, я ловлю вдохновение», — и показывает мне язык."
		),
	]
)
@export var help_text := "WASD / стрелки — идти · Shift — бегом · E или клик — войти · N — заметки"
