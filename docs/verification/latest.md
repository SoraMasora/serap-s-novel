# Verification — latest (2026-10-09, commit d5d9034 + docs)

Платформа: Linux (Amazon Linux 2023), Godot 4.7.2.stable.official.ed1daf0bf, headless; Chromium 153 (SwiftShader). GitHub Actions — не запускался.

| # | Команда | Результат | Статус |
|---|---|---|---|
| 1 | `node tools/godot/export_data.cjs --assets` | `story.json: scenes 234 rules 6 notes 48` · `assets: 155 files, 18.5 MB` | PASS |
| 2 | `node tools/godot/bake_web.cjs` | `pixel: ok` · `audio: ok 23` | PASS |
| 3 | `bash tools/godot/fetch_deps.sh` | `GUT v9.7.1 ok` · `fonts ok` (sha256 сверены) | PASS |
| 4 | `godot --headless --path . --import --quit` (2-й проход) | без ошибок/предупреждений (1-й проход на чистом клоне — KI-004) | PASS |
| 5 | `bash tools/godot/check_scripts.sh` | `CHECK OK` | PASS |
| 6 | `gdformat --check scripts tests && gdlint scripts tests` | `Success: no problems found` | PASS |
| 7 | GUT (`-gdir=res://tests -ginclude_subdirs`) | Tests 28, Passing 28, Asserts 193, 23.6 s | PASS |
| 8 | `godot --headless --path . -- --autoplay=42` | `ending home, steps 403, digest 9a1c118c…` | PASS |
| 9 | `godot --headless --path . --quit-after 200` | запуск ок; при выходе KI-001 (ObjectDB leak аудио) | PASS с предупреждением |
| 10 | `godot --headless --path . --export-release "Web" build/web/index.html` | 68 МБ (wasm 39.5, pck 30.6) | PASS |
| 11 | `web_smoke.cjs`: титул → «Новая игра» → имя → глава → магазин → выбор → наведение | ERRORS none, boot 12.9 с; скриншоты сверены с `shots/t_store.png` | PASS (host) |
| 12 | perf: `tests/perf/perf_pixel_map.tscn` | см. PERF_TARGETS M-001 | PASS |

## Не проверялось
- CI на GitHub Actions (`.github/workflows/godot.yml`) — UNVERIFIED; ожидается зелёный job `test` с теми же выводами.
- Открытие сцен в редакторе с GUI и правка мышью — UNVERIFIED (`godot -e --path godot`, ожидается: сцены открываются без ошибок).
- Звук на слух, ручной ввод дыхания, пиксельная карта в браузере, FPS на реальном GPU, десктоп-экспорт.
