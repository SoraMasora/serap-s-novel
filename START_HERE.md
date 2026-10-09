# START HERE — S^erap^S (Serap's Novel)

Визуальная новелла про Серафиму. Две реализации в одном репо:
- **веб-оригинал** (`index.html`, `js/`, `css/`, `assets/*.js`) — эталон сюжета и подачи (v17.2);
- **порт на Godot 4.7.2** (`godot/`) — Route B, паритет с вебом проверяется тестами (`docs/PORTING_CONTRACT.md`).

## Стек и версии (пины — `docs/DEPENDENCIES.md`)
Godot 4.7.2-stable (GDScript, renderer gl_compatibility) · GUT 9.7.1 · gdtoolkit 4.5.0 · Node 24 · Playwright 1.63 + Chromium · ffmpeg.

## 5 команд (из корня репо)
```bash
node tools/godot/export_data.cjs --assets && node tools/godot/bake_web.cjs && bash tools/godot/fetch_deps.sh   # 1. данные+ассеты+зависимости
cd godot && godot --headless --path . --import --quit; godot --headless --path . --import --quit                 # 2. импорт (2-й проход чистый)
gdformat --check scripts tests && gdlint scripts tests                                                            # 3. линт
GODOT_DISABLE_LEAK_CHECKS=1 godot --headless -d --audio-driver Dummy --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit   # 4. тесты
mkdir -p build/web && godot --headless --path . --export-release "Web" build/web/index.html                       # 5. веб-сборка
```
Редактор: `godot -e --path godot` (после шагов 1–2). Игра: `godot --path godot`.
Детерминированный прогон: `godot --headless --audio-driver Dummy --path godot -- --autoplay=42` → `AUTOPLAY {digest, ending…}`.

## Мобильная версия (ветка `godot-mobile`, v0.19.0)
```bash
JAVA_HOME=<jdk17> ANDROID_SDK_ROOT=<sdk с build-tools> bash tools/godot/android_setup.sh                          # один раз: JDK/SDK/debug-keystore в настройки редактора
cd godot && mkdir -p build/android && touch build/.gdignore && godot --headless --path . --export-debug "Android" build/android/serap-debug.apk
(cd godot/build/web && python3 -m http.server 8765 &); NODE_PATH=<node_modules> node tools/godot/mobile_smoke.cjs shots/mobile   # смоук: телефон 844×390, касания
godot --path godot -- --touch --jump=d1                                                                           # десктоп: сенсорный режим + сразу на карту d1
```
Сенсорный слой — `scenes/mobile/*.tscn` + автозагрузка `Mobile`; параметры — `data/mobile_config.tres`, тема — `ui/theme_mobile.tres` (ADR-0005).

## Карта репозитория
| Путь | Что |
|---|---|
| `godot/project.godot` | проект, автозагрузки Game/SaveSystem/Audio, действия ввода |
| `godot/scenes/` | `.tscn`: main, ui/*, pixel/*, audio |
| `godot/scenes/mobile/` | сенсорный слой: джойстик+кнопки карты, быстрое меню, сенсорная кнопка |
| `godot/scripts/core/` | StoryDB, StoryRunner (порт `run()` из js/engine.js), AutoPlayer |
| `godot/scripts/{ui,pixel,audio,autoload,resources}/` | подача, пиксельная карта, звук, сейвы/настройки, классы ресурсов |
| `godot/data/` | `story.json` (234 сцены, генерируется), `*.tres` (настройки), `pixel_bake.json`, `assets_manifest.json` |
| `godot/tests/` | GUT: unit, integration (паритет с JS, UI-смоук), perf, fixtures |
| `godot/assets/`, `godot/addons/gut/` | **не в git** — генерируются/скачиваются шагом 1 (ADR-0002) |
| `tools/godot/` | export_data, bake_web, js_reference, fetch_deps, web_smoke, check_scripts |
| `docs/` | ARCHITECTURE, PORTING_CONTRACT, RESEARCH_LOG, DECISIONS, KNOWN_ISSUES, verification, PERF_TARGETS… |
| `AGENTS.md`, `AI_STATE.md`, `state.json` | правила для агентов и текущее состояние |

## Что сделано
- Весь сюжет (234 сцены, 6 правил концовок, 48 заметок) идёт из `story.json`, сгенерированного из `js/story*.js`.
- Подача: реплики-субтитры как в css v13, портреты/реакции, сердечки, выборы с лозами, катсцены, карточки глав, дыхание, дождь, меню, журнал с откатом, заметки, 3 слота + автосейв, концовки, настройки.
- Пиксельная карта прогулок (запечённые слои js/pixel.js, герой, Сера, NPC, мини-карта).
- Паритет: 200 сидов совпали с JS-эталоном по digest/концовке/статам.
- Мобильная версия: Android APK (arm64, альбомная, immersive), веб-PWA, касания, быстрое меню, виртуальный джойстик, безопасные зоны, «назад» Android, автосейв при сворачивании. GUT 44/44.

## Notion
Project Board: https://app.notion.com/p/32a8d6006e1c49df9efc9fc5a4b38f02 (Tasks, Research Questions, Decisions, Measurements, Skills).

## Что дальше
`state.json.next_task` и `AI_STATE.md`. Открытые проблемы — `docs/KNOWN_ISSUES.md`.

## Чего не делать
- Не править `godot/data/story.json` руками — правь `js/story*.js` и перегенерируй.
- Не коммитить `godot/assets/`, `godot/addons/gut/`, `godot/.godot/`, `godot/build/`.
- Не собирать сцены кодом в рантайме, не хардкодить настройки в скриптах (они в `data/*.tres`).
- Не называть проверку PASS без реального запуска.
