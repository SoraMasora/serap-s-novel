class_name MobileConfig
extends Resource
## Мобильная версия: сенсорное управление, тема для пальцев, безопасная зона.
## Экземпляр: res://data/mobile_config.tres (меняется в инспекторе, не в коде).

## Тема поверх основной (крупные шрифты и кнопки) — подключается к Main в сенсорном режиме
@export var touch_theme: Theme
## Подсказка внизу карты в сенсорном режиме (вместо «WASD/стрелки…»)
@export_multiline
var map_help_touch := "Джойстик — идти · «Бег» — бегом · «E» или касание места — войти"
## Размеры подсказок карты в сенсорном режиме (в сцене — 13 и 19 для мыши и клавиатуры)
@export var map_help_font_size := 20
@export var map_prompt_font_size := 26
## Префикс подсказки у места на карте в сенсорном режиме
@export var map_prompt_prefix_touch := "E · "
## Кнопки быстрого меню над игрой: [действие, подпись]; действия — как у TextBox.control_pressed
@export var quick_menu := [
	["auto", "Авто"],
	["skip", "Пропуск"],
	["log", "Журнал"],
	["notes", "Заметки"],
	["save", "Сохр."],
	["load", "Загр."],
	["menu", "Меню"],
]
## Джойстик: радиус хода ручки (px холста) и мёртвая зона (доля радиуса)
@export var joystick_radius := 92.0
@export_range(0.0, 0.9, 0.01) var joystick_deadzone := 0.22
## Сохранять автосейв, когда приложение уходит в фон (Android/iOS могут выгрузить его)
@export var autosave_on_pause := true
## Кнопка «Назад» Android на титуле закрывает игру
@export var back_on_title_quits := true
## Не гасить экран во время игры
@export var keep_screen_on := true
## Веб-сборка на телефоне: показывать на титуле кнопку «На весь экран»
@export var web_fullscreen_button := true
@export var web_fullscreen_label := "На весь экран"
