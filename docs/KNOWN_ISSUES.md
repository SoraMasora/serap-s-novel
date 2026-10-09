# Known Issues (Godot-порт)

| ID | Приоритет | Проблема | Воспроизведение | Состояние |
|---|---|---|---|---|
| KI-001 | P3 | При выходе во время музыки: `2 ObjectDB instances leaked` (AudioStreamMP3 + AudioStreamPlaybackMP3), `1 resource still in use: sudno.mp3` | `godot --headless --verbose --audio-driver Dummy --path godot --quit-after 200` | Диагностировано: playback остаётся в AudioServer (удаление асинхронное, при выходе не успевает). `Audio._exit_tree` останавливает плееры — не помогло. Влияния на игру нет. |
| KI-002 | P2 | Веб-сборка 68 МБ, загрузка ~13 с до титула (локальный сервер, headless Chromium) | `web_smoke.cjs` → `boot_ms` | Открыто: можно сжать музыку (ogg q4), wasm-opt, gzip/brotli на хостинге. |
| KI-003 | P2 | В Chromium+SwiftShader (без GPU) Godot-сборка рисует 6–8 FPS, оригинал ~13 FPS; на реальном GPU не измерено | `PERF=600 node tools/godot/web_smoke.cjs` | UNVERIFIED на реальном железе (нужен замер у пользователя). |
| KI-004 | P3 | На чистом клоне первый `--import` печатает «No loader found … .ttf» (тема грузится раньше шрифтов); второй проход чистый | `godot --headless --path godot --import --quit` ×2 | Обход в START_HERE/CI (двойной импорт). |
| KI-005 | P3 | Верхняя/нижняя лозы и покачивание лоз выбора, свет героя на карте, drop-shadow — не перенесены | визуально | Приближения перечислены в PORTING_CONTRACT. |
| KI-006 | P3 | Концовка «expo» не достигается 200 случайными сидами — проверена только логика правила | `node tools/godot/js_reference.cjs 200` | Нужен целевой сценарий-тест. |
| KI-007 | P2 | CI (`.github/workflows/godot.yml`) ни разу не запускался на GitHub | — | UNVERIFIED. |
| KI-008 | P3 | Нет MCP-сервера Godot в среде агента; редактор не открывался в GUI (только headless) | — | Сцены — валидные .tscn (импорт без ошибок), открытие мышью UNVERIFIED. |
