# ADR-0002: бинарные ассеты не в git — воспроизводимая генерация
**Решение:** `godot/assets/**` и `godot/addons/gut/` не коммитятся; они генерируются из `assets/*.js` (export_data --assets), запекаются из `js/pixel.js`/`js/audio.js` (bake_web) и скачиваются с проверкой sha256 (fetch_deps).
**Контекст:** бэкап в GitHub идёт через API push_files (только UTF-8 текст, ≤1 МБ на пакет); исходники ассетов уже в репо (base64 в assets/*.js, 24 МБ). Git LFS недоступен в этом канале.
**Альтернативы:** Git LFS (нет доступа из агента); коммит бинарников (невозможно через push_files).
**Последствия:** на чистом клоне нужен шаг 1 из START_HERE (Node + Chromium + ffmpeg); первый импорт Godot нужно выполнить дважды.
**Проверка:** CI-шаг «Data, assets, deps» + `git diff --exit-code godot/data/story.json`. **Откат:** добавить `godot/assets/` в LFS и убрать из .gitignore.
