# Проверка v0.7.0 (2026-10-13)

## PASS
- `node tools/godot/export_data.cjs --assets`: 350 сцен, 61 заметка; 257 ассетов, 30.6 MB.
- `node tools/godot/js_reference.cjs 200`: home 130, more 32, gone 7, good 8, neutral 17, bad 6.
- Godot headless import; `bash tools/godot/check_scripts.sh` — CHECK OK.
- `gdformat --check scripts tests && gdlint scripts tests` — no problems.
- GUT **34/34, 292 asserts**. Добавлены проверки 89 CG-сцен и файлов, скрытия сценических спрайтов, принятых hand/hug и чайного b_ns.
- Все невизуальные поля команд (реплики, выборы, эффекты на отношения, условия, переходы, звук, заметки) сравнены с 0.6.3: без изменений во всех 350 сценах.
- `tools_dev/shot.gd`, Xvfb, opengl3: c1_store_sorry, c1_room_good, c1_pastor_defend, c3_q_silent, m2_shift_a, m2_cold_knock, m2_roof_b_ns, c1_hug_ok; дополнительно c1_room_good после 2 шагов — возврат обычного фона и одного спрайта.
- На первом скриншоте m2_cold_knock лицо обрезалось краем окна; иллюстрация перекомпонована и повторно проверена.

## Ограничения / UNVERIFIED
- Это выборочная визуальная проверка игрового окна, не ручное прохождение всех маршрутов. 89 сцен проверены автоматическим тестом первого диалога.
- Все CG статичные, WebP 1376×768 q85; мелкие надписи на упаковках и граффити могут быть неточными, детали дизайна немного варьируются. Надпись на главной бутылке c1_shift_joke удалена.
- На выходе screenshot-helper сохраняется известная утечка музыкального ресурса (KI-001); это не ошибка загрузки CG.
- Веб-визуал, Android, реальный GPU и GitHub CI не проверялись.

## Воспроизведение
```bash
bash tools/restore_assets.sh
node tools/godot/export_data.cjs --assets
node tools/godot/js_reference.cjs 200
cd godot
godot --headless --audio-driver Dummy --path . --import --quit
gdformat --check scripts tests && gdlint scripts tests
GODOT_DISABLE_LEAK_CHECKS=1 godot --headless -d --audio-driver Dummy --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

## Повторный прогон после восстановления окружения
- Восстановлены все 89 исходных кадров; запечены пиксельная карта и 23 звука; GUT v9.7.1 и закреплённые шрифты восстановлены с SHA256-проверкой.
- Двойной импорт (первый проход сообщил об ещё не импортированных шрифтах, второй — чистый); CHECK OK; линт PASS; GUT 34/34, 292 asserts; 200 эталонных прогонов.
- Все 350 сцен сравнены по невизуальным полям: совпадают.
- 9 контрольных состояний повторно отрендерены через Xvfb/X11/OpenGL (llvmpipe) и просмотрены; возврат обычного спрайта и обрезка у двери подтверждены. Для прогона потребовались библиотеки X11; это восстановление среды, не изменение игры.
