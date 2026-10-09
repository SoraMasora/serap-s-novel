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
