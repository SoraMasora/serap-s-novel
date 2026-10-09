# Research Log (Godot-порт)

Дата проверки всех источников: 2026-10-09 (UTC). Канал: прямые HTTP-запросы из песочницы (curl к GitHub API / docs / PyPI) + локальные эксперименты.

## R-001 Какая версия Godot актуальна и стабильна?
- **Источники:** https://api.github.com/repos/godotengine/godot/releases/latest → `4.7.2-stable`, published 2026-08-18.
- **Вывод:** берём 4.7.2-stable, пиним sha256 архива и шаблонов (docs/DEPENDENCIES.md).
- **Влияние:** CI, export_presets, синтаксис .tscn format=3.
- **Уверенность:** высокая (verified).
- **Fallback:** 4.6.x-stable (те же API, кроме новых в 4.7 — не используются).

## R-002 Нужны ли COOP/COEP-заголовки для веб-сборки?
- **Источники:** https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html (разделы «Thread and extension support», примечание про SharedArrayBuffer).
- **Вывод:** при выключенной Thread Support (шаблон `web_nothreads_release`) кросс-доменная изоляция не нужна — сборка работает на обычном хостинге (itch.io, GitHub Pages). Требуются WebAssembly + WebGL 2.0.
- **Влияние:** `export_presets.cfg` (variant/thread_support=false), renderer gl_compatibility.
- **Уверенность:** высокая (verified + локальный запуск через `python3 -m http.server` без заголовков, ERRORS none).
- **Fallback:** threads-сборка + `coi-serviceworker`, если понадобится низкая задержка звука.

## R-003 Какой тест-фреймворк и версия совместимы с 4.7?
- **Источники:** https://api.github.com/repos/bitwes/Gut/releases — v9.7.1 (2026-07-10), v9.6.1 (2026-07-09, помечен latest), v9.7.0 (2026-06-19); заметки v9.7.1: исправления doubles, «Ported changes from 9.6.1».
- **Вывод:** GUT v9.7.1 (самый новый тег), sha256 архива закреплён в fetch_deps.sh. На Godot 4.7.2 — 28/28 тестов проходят.
- **Влияние:** tests/, .gutconfig.json, CI.
- **Уверенность:** высокая (verified запуском).
- **Fallback:** gdUnit4.

## R-004 Линтер/форматтер GDScript
- **Источники:** https://pypi.org/pypi/gdtoolkit/json → 4.5.0; https://api.github.com/repos/Scony/godot-gdscript-toolkit/releases/latest → 4.5.0 (2025-10-09).
- **Вывод:** gdtoolkit 4.5.0; парсер не понимает однострочные лямбды с `if` внутри — переписаны на методы с `bind`.
- **Влияние:** godot/gdlintrc (max-public-methods 40, max-returns 12 — обоснование в файле).
- **Уверенность:** высокая.
- **Fallback:** только `godot --check-only` (tools/godot/check_scripts.sh).

## R-005 Есть ли кириллица в шрифтах оригинала?
- **Источники:** google/fonts @ 51303ca9e8ac9dcea7b12d307ba568fd0e6fcfca (ofl/grenzegotisch, cormorantsc, lora); проверка cmap через fontTools.
- **Вывод:** Grenze Gotisch — нет кириллицы (U+0416 отсутствует); Cormorant SC Bold, Lora, Lora Italic — есть. Для русских заголовков — фолбэк Cormorant SC.
- **Влияние:** ui/theme.tres (FontVariation fallbacks), PORTING_CONTRACT п.4.
- **Уверенность:** высокая (verified локально).
- **Fallback:** Ruslan Display / собственный кириллический готический шрифт (OFL).

## R-006 Как перенести процедурный WebAudio-звук?
- **Источники:** локальный эксперимент: js/audio.js в headless Chromium с OfflineAudioContext (bake_web.cjs).
- **Вывод:** офлайн-рендер даёт те же сэмплы, что и в браузере; петли music_tense 9.6 с и rain_loop 6 с; 20 SFX + door_shop. Синтезатор в GDScript не нужен.
- **Влияние:** assets/sfx_baked/*.ogg, AudioConfig.
- **Уверенность:** средняя (сходство на слух не проверялось — UNVERIFIED).
- **Fallback:** AudioStreamGenerator с портом синтеза.

## R-007 Как измерять производительность без GPU?
- **Источники:** локальные эксперименты: headless Godot (dummy renderer) — интервал кадров упирается в ~6.9 мс; Performance.TIME_PROCESS даёт CPU-время _process; Chromium + SwiftShader — интервалы requestAnimationFrame.
- **Вывод:** CPU-бюджет логики измерим (tests/perf), GPU-бюджет на реальном железе — нет.
- **Влияние:** docs/PERF_TARGETS.md, KNOWN_ISSUES (KI-003).
- **Уверенность:** средняя.
- **Fallback:** ручной замер в браузере пользователя (`web_smoke.cjs` с PERF=600 на реальной машине).

## R-008 Есть ли в Godot 4.7 встроенный виртуальный джойстик?
- **Источники:** [SRC] https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/scene/gui/virtual_joystick.cpp (свойства `joystick_mode`, `action_left/right/up/down`, `deadzone_ratio`, theme-styleboxes); `godot --doctool` 4.7.2 → `VirtualJoystick.xml`.
- **Вывод:** да, класс `VirtualJoystick` (Control) сам шлёт действия InputMap; свой скрипт с `class_name VirtualJoystick` конфликтует с нативным классом. Сброс удержания — через `NOTIFICATION_RESIZED` + `Input.action_release`.
- **Влияние:** scenes/mobile/pixel_touch_controls.tscn, ADR-0005.
- **Уверенность:** высокая (verified: test_touch_controls.gd, mobile_smoke drag → герой идёт).
- **Fallback:** TouchScreenButton ×4 или собственный Control-джойстик под другим именем.

## R-009 Почему частичная тема с `default_font_size` ломает размеры?
- **Источники:** [SRC] https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/scene/resources/theme.cpp (`Theme::has_font_size` возвращает true при заданном `default_font_size` для любого типа).
- **Вывод:** тема-перекрытие с `default_font_size` перехватывает поиск у всех контролов и отменяет размеры основной темы; в `theme_mobile.tres` размеры заданы явно по типам/вариациям.
- **Влияние:** ui/theme_mobile.tres.
- **Уверенность:** высокая (verified скриншотами mobile_smoke).
- **Fallback:** единая тема со скейлом `content_scale_factor`.

## R-010 Как собрать APK без Gradle и какие опции пресета нужны?
- **Источники:** [SRC] `godot --doctool` 4.7.2 → `EditorExportPlatformAndroid.xml` (options `gradle_build/use_gradle_build`, `architectures/arm64-v8a`, `package/unique_name`, `screen/immersive_mode`, `version/code`); шаблоны `templates/android_debug.apk`, `android_release.apk` из `Godot_v4.7.2-stable_export_templates.tpz`; editor settings `export/android/java_sdk_path`, `android_sdk_path`, `debug_keystore*`.
- **Вывод:** без Gradle нужен только JDK 17 + Android SDK build-tools (apksigner/zipalign) и debug-keystore; Godot подписывает и верифицирует APK сам.
- **Влияние:** export_presets.cfg (preset.1 Android), tools/godot/android_setup.sh, CI.
- **Уверенность:** высокая (verified: APK собран, `aapt2 dump badging`, `apksigner verify`); запуск на устройстве — UNVERIFIED.
- **Fallback:** Gradle-сборка (`gradle_build/use_gradle_build=true` + Android build template) — нужна для AAB.

## R-011 Как в веб-сборке дать полный экран и альбомную ориентацию на телефоне?
- **Источники:** [SRC] `EditorExportPlatformWeb.xml` (doctool 4.7.2: `progressive_web_app/*`, `html/experimental_virtual_keyboard`); MDN Fullscreen API и `screen.orientation.lock` (локальная проверка в Chromium 153 isMobile); сгенерированный `build/web/index.manifest.json` (`display: fullscreen`, `orientation: landscape`).
- **Вывод:** PWA + кнопка «На весь экран» (Fullscreen API из жеста + orientation.lock); на iOS Safari Fullscreen API нет — кнопка скрыта (KI-012).
- **Влияние:** export_presets.cfg (Web), title_screen.tscn, mobile.gd.
- **Уверенность:** средняя (Android Chrome — эмуляция; iOS — UNVERIFIED).
- **Fallback:** «Добавить на экран Домой».
