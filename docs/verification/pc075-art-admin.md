# ПК 0.7.5 — графика и админ-панель

## Результат
- PASS: Godot 4.7.2 stable, импорт ресурсов, CHECK OK.
- PASS: gdformat --check scripts tests + gdlint scripts tests; 55 файлов.
- PASS: полный GUT — 86/86 тестов, 2279 assertions, 11 test scripts.
- PASS: JS parity test_deterministic_playthroughs_match_js и loop fixtures.
- PASS: Xvfb 1280×720, OpenGL Compatibility / Mesa llvmpipe; настоящие события F9/Esc, пауза/возврат, порог 7 концовок, truth/freed, обновление титула и галереи. Скриншот admin_panel.png.
- PASS: новые 12 фоновых/CG текстур разрешаются из art/bg; liza_cry доступен; все четыре реплики Лизы сохраняют cry; street_snow включён в loop_outdoor_bgs.

## Сравнение с присланным архивом 0.7.4
Сверка выполнена непосредственно с SERAPS-PC-0.7.4-all-CG-fixes.zip.
Набор 443 сцен и определения 12 концовок совпадают. Отличаются ровно 8 визуальных команд в 4 сценах: три street → street_snow, один show cry и четыре эмоции cry в репликах Лизы. Ни текст, ни выборы, ни переходы не изменены. Точный diff: ../art/pc075_story_visual_changes.json.

157 обработанных кадров (включая 12 новых/переработанных) и 39 исключений перечислены с SHA-256 в ../art/pc075_art_manifest.json. 23 перезаписанных старых art/bg файла сохранены в backup/art_bg_0.7.4. Изменённые исходники из присланного архива сохранены в backup/pc_0.7.4_sources.

## Ограничения
- Общая цветовая обработка не означает полной перерисовки 157 кадров; старые различия линии/анатомии могут сохраниться.
- Полный ручной просмотр всех кадров в прохождении: UNVERIFIED.
- Нативная Windows-сборка, производительность на реальном GPU и прослушивание аудио: UNVERIFIED. Архив содержит проект Godot, не .exe.
- Корневой HTML-клиент не обновлён; прежние отключения CG сохранены.
- Старый verify_preservation.cjs не помечается PASS: он сравнивает с 0.7.3 и сообщает изменённые исходники, включая прежние изменения choice_cg. В этой версии используется приведённая выше прямая сверка с входным 0.7.4.
- При закрытии графического запуска остаётся известное предупреждение очистки аудиоресурса (KI-001), не ошибка новой панели.

## Повторная проверка
```bash
cd godot
godot --headless --path . --import --quit
cd ..
bash tools/godot/check_scripts.sh
cd godot
gdformat --check scripts tests
gdlint scripts tests
GODOT_DISABLE_LEAK_CHECKS=1 godot --headless -d --audio-driver Dummy --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
