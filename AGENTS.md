# AGENTS.md — машинный контекст (единственный источник правил для агентов)

## Проект
Визуальная новелла S^erap^S. Веб-оригинал (корень: `index.html`, `js/`, `css/`, `assets/*.js`) + порт на Godot 4.7.2 (`godot/`). Пользователь пишет по-русски; ответы — кратко, результат первым.

## Команды (из корня)
- Данные: `node tools/godot/export_data.cjs` (story.json) · `--assets` (ассеты + manifest + маркеры из css)
- Пиксель/звук: `node tools/godot/bake_web.cjs [pixel|audio]` (playwright + chromium, ffmpeg)
- Зависимости: `bash tools/godot/fetch_deps.sh` (GUT, шрифты; sha256 проверяются)
- Эталон паритета: `node tools/godot/js_reference.cjs 200` → `godot/tests/fixtures/js_reference.json`
- Импорт: `cd godot && godot --headless --path . --import --quit` (на чистом клоне — дважды)
- Проверка скриптов: `bash tools/godot/check_scripts.sh` → `CHECK OK`
- Линт: `cd godot && gdformat --check scripts tests && gdlint scripts tests`
- Тесты: `cd godot && GODOT_DISABLE_LEAK_CHECKS=1 godot --headless -d --audio-driver Dummy --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- Перф (CPU): `cd godot && godot --headless --audio-driver Dummy --path . res://tests/perf/perf_pixel_map.tscn -- --frames=600`
- Веб: `cd godot && mkdir -p build/web && godot --headless --path . --export-release "Web" build/web/index.html`; смоук: `(cd godot/build/web && python3 -m http.server 8765 &); NODE_PATH=<node_modules> node tools/godot/web_smoke.cjs shots/godot` (env `STEPS`, `PERF`)
- Android: `bash tools/godot/android_setup.sh` (env JAVA_HOME, ANDROID_SDK_ROOT) → `cd godot && touch build/.gdignore && godot --headless --path . --export-debug "Android" build/android/serap-debug.apk`
- Мобильный смоук: `NODE_PATH=<node_modules> node tools/godot/mobile_smoke.cjs shots/mobile` (env `VW`/`VH`/`STEPS` в долях экрана, kind `tap`/`hold:ms`/`drag:dx,dy,ms`)
- iOS: `bash tools/godot/ios_build.sh` (Xcode-проект на любой ОС; на macOS — ещё неподписанный .ipa); `app_store_team_id="UNSIGNED00"` — заглушка, реальный Team ID ставится в Xcode, не коммитить
- Флаги запуска: `-- --touch` / `--no-touch` (сенсорный режим), `--jump=<label>` (dev: сразу в сцену), `--autoplay=<seed>`

## Правила
- Сцены — `.tscn`, настройки — `.tres`/JSON, повторяющиеся объекты — инстансы PackedScene.
- Сюжет меняется только в `js/story*.js` → перегенерировать story.json и эталон паритета → тесты.
- Изменение ядра (`scripts/core/`) требует зелёного `test_parity_js.gd`.
- Вёрстка сверяется с `css/style.css` (последние переопределения побеждают) и скриншотами оригинала.
- Мобильное: всё сенсорное — сцены `scenes/mobile/*.tscn`, параметры — `data/mobile_config.tres`; элементы у краёв экрана — в группе `safe_area`; касания не ломают мышь/клавиатуру (оба режима в тестах).
- Docs обновляются в том же коммите, что и код. Коммиты: `type(scope): summary` + Why/What/Verify/Docs/Revert.
- Статусы: PASS только после реального запуска; иначе UNVERIFIED + команда + ожидаемый вывод.
- Ошибки не глушить; новые проблемы — в `docs/KNOWN_ISSUES.md` и `state.json`.
- Бэкап: песочница агента может откатываться — пушить после каждого значимого шага.

## Границы
- **Всегда:** импорт + линт + GUT перед коммитом; обновлять AI_STATE.md/state.json.
- **Спроси:** смена версии Godot/GUT, удаление сцен/контента, изменение сюжета, смена стиля арта.
- **Никогда:** коммитить `godot/assets/`, `godot/.godot/`, `godot/build/`, `godot/addons/gut/`, секреты; править story.json руками; пушить HTML-превью.

## Где что
Архитектура — `docs/ARCHITECTURE.md`; контракт и паритет — `docs/PORTING_CONTRACT.md`; решения — `docs/DECISIONS/`; замеры — `docs/PERF_TARGETS.md`, `docs/verification/latest.md`; история веб-версии — `docs/AI_CONTEXT.md`.
