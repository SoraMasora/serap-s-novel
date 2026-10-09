# ADR-0004: веб-экспорт без потоков, renderer Compatibility
**Решение:** пресет Web на шаблоне `web_nothreads_release`, renderer gl_compatibility, только `data/*.json` как доп. ресурсы, `tests/*` и `addons/gut/*` исключены.
**Контекст:** R-002 — потоки требуют COOP/COEP; новелле не нужен многопоточный звук.
**Альтернативы:** threads + coi-serviceworker; Forward+ (нет в вебе).
**Последствия:** работает на любом статическом хостинге; звук в режиме Sample. Размер сборки 68 МБ (wasm 39.5 + pck 30.6).
**Проверка:** web_smoke.cjs → ERRORS none. **Откат:** включить Thread Support в export_presets.cfg.
