# Porting Contract — веб-оригинал → Godot 4.7.2 (Route B)

Эталон: веб-версия v17.2 (`index.html`, `js/engine.js`, `js/story*.js`, `js/pixel.js`, `js/audio.js`, `css/style.css`, `assets/*.js`).

## Ядро
- `run()`/`next()` из engine.js → `StoryRunner.step()`; шаги say/think/show/hide/bg/music/sfx/flag/stat/note/choice/jump/breath/map/cut/card/final/fx/react/cam/zoom → события.
- Концовки: 6 правил `pickEnding()` → `story.json.endings` (порядок сохранён).
- Формулы: `feel`, `press`, заметки (48), флаги и числа (`num`), `tier()`/`tv()`/`fmt()` — как в JS.

## Состояния и ввод
| Веб | Godot (InputMap) |
|---|---|
| клик / Space / Enter | `vn_advance` |
| Ctrl (удержание) | `vn_skip_hold` |
| Esc · N · A | `vn_menu` · `vn_notes` · `vn_auto` |
| дыхание: удержание Space / ЛКМ | `breath_hold` |
| карта: WASD/стрелки, Shift, E/Enter/Space | `map_*`, `map_run`, `map_interact` |

## Ассеты
- Картинки/музыка: base64 из `assets/*.js` → файлы `godot/assets/**` (`export_data.cjs --assets`), без перекодирования.
- Пиксельные слои и спрайты карты: запекаются из `js/pixel.js` в Chromium (`bake_web.cjs pixel`) → PNG без потерь + `pixel_bake.json`.
- Процедурные SFX/эмбиент (WebAudio): `OfflineAudioContext` → OGG Vorbis (`bake_web.cjs audio`).
- Маркеры окна реплик (крест, «дальше») — PNG из блока «v13: крест-маркер» `css/style.css`.

## Звук
Шины Music/SFX/Ambience; кроссфейд треков по локации (`AudioConfig.loc_tracks`), слой «tense», дождь только на улице, громкости из настроек.

## Вёрстка (css → Godot)
`#textbox` (v4/v4.1/v5): градиент на всю ширину, высота 29 %, отступы 20 % (22 % с портретом), линия и крест на 2.6vh · `#namebox`: Cormorant SC 3.3vh, свечение, подчёркивание 120 % · `#controls`: снизу справа, точки-разделители · `#side`: 16 % ширины, 46 % высоты, картинка 150 % · `#choices button.vbtn`: Lora 2.55vh, ширина 58 %, градиент/рамка, лозы 165 %.

## Что не переносится / приближено
1. Анимации реакций (`@keyframes` jump/shake/nod/…) — приближены твинами (амплитуды и длительности из CSS).
2. Свет героя и мерцание фонарей на карте — опущены (слой Light статичен).
3. `filter: drop-shadow` у портретов и лоз, `backdrop-filter` — не переносятся.
4. Grenze Gotisch без кириллицы → русские заголовки фолбэком Cormorant SC (в вебе — системный Georgia).
5. Процедурный звук не синтезируется в рантайме — запечён петлями (music_tense 9.6 с, rain_loop 6 с).
6. Лозы выбора: левая/правая с прорастанием снизу (clip) и задержкой 0.3 с — есть; верхняя/нижняя лоза и покачивание (swayL5/R5) — опущены.

## Таблица паритета
| Область | Как проверяется | Статус |
|---|---|---|
| Переходы, условия, концовки, статы, заметки | `test_parity_js.gd`: 200 сидов, digest/ending/steps/feel/press/notes = JS | PASS |
| Детерминизм | один сид → один digest; CLI `--autoplay=42` | PASS |
| Сейвы: слоты, автосейв, пустой/битый файл, resume | `test_save_system.gd` (6) | PASS |
| Полный UI-проход (skip): 440 реплик, 19 выборов, 11 карт, концовка | `test_main_smoke.gd` | PASS |
| Окно реплик (ширина, отступы 20/22 %, мысли, имя, кнопки) | `test_text_box.gd` (5) + скриншоты `web_smoke.cjs` против `shots/t_store.png` | PASS |
| Титул, имя, карточка главы, магазин, выбор с наведением | `web_smoke.cjs` (Chromium/SwiftShader), ERRORS none | PASS (host) |
| Пиксельная карта: движение, точки, мини-карта | smoke (11 карт через map_enter) + perf-зонд | PASS логика / UNVERIFIED визуально в браузере |
| Дыхание (ручной ввод) | smoke через breath_result | UNVERIFIED |
| Звук (кроссфейд, SFX) | только Dummy-драйвер | UNVERIFIED на слух |
| Реакции/анимации | визуально по кадрам | ASSUMED близко (п.1) |
