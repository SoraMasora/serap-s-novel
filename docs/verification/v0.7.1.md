# Проверка v0.7.1 · только ответный кадр

## Объём правки
По уточнению автора убрана замена сцен иллюстрациями. Сценарные исходники js/story.js, story3.js, story4.js и экспортированный story.json полностью совпадают с 0.6.3, включая все оригинальные команды фона, персонажей, камеры, реплики и маршруты.

CG — отдельный непрозрачный слой поверх неизменённой сцены. Он включается только после нажатия варианта диалога на одну первую реплику; следующий вызов run скрывает его. Обычный диалог, карты и переходы не включают кадр. Сохранение слоя вынесено отдельно от сюжетного состояния. Существующие картинки/спрайты не перерисованы.

## PASS
- Полное сравнение двух story.json: идентичны, 350 сцен.
- node tools/godot/export_data.cjs --assets: 257 файлов; каталог 89 ответных кадров сохранён.
- 200 JS reference runs: home 130, more 32, gone 7, good 8, neutral 17, bad 6; GUT parity PASS.
- Godot import, CHECK OK, gdformat/gdlint: 41 files unchanged, no problems.
- GUT: **36/36, 306 asserts**. 89 сцен проверены через UI: состояние runner после ответного кадра совпадает с исходным StoryRunner. Дополнительно: реальное нажатие варианта, скрытие на следующей строке, save/load, сохранение оригинального bg/chars.
- Godot/Xvfb/X11/OpenGL(llvmpipe): c1_room_good, три состояния (ordinary, reply, next), снимки просмотрены. Спрайт и фон оригинала возвращаются после одной ответной реплики.
- Локальный Chromium web smoke: исходный обычный диалог без overlay; нажатие кнопки choice вызывает один кадр; следующий run возвращает исходную сцену; save/load сохраняет одно-репличный показ. JS page errors: 0. Веб-кадр просмотрен.

## Исправления в процессе проверки
Новый интеграционный тест сначала не загрузился из-за невыведенного типа локальной переменной saved. Добавлен явный Dictionary, затем повторно выполнены CHECK OK, линт и полный GUT. Ошибка теста не входит в финальную сборку.

## Ограничения / UNVERIFIED
- Визуальная проверка выборочная, не ручное прохождение всех вариантов. Все 89 ответных веток охвачены автоматическим тестом, но вся веб-игра не проходилась вручную.
- Ответные кадры статичные; мелкие надписи и детали рисунка могут варьироваться. Это не изменения исходных ассетов.
- Физический GPU, Android, экспорт Godot Web и GitHub CI в этом прогоне не проверялись.
- Известные предупреждения об утечке музыкального ресурса при выходе screenshot-helper относятся к KI-001.

## Воспроизведение
```bash
bash tools/restore_assets.sh
bash tools/godot/fetch_deps.sh
node tools/godot/export_data.cjs --assets
node tools/godot/bake_web.cjs
node tools/godot/js_reference.cjs 200
cd godot
godot --headless --audio-driver Dummy --path . --import --quit
godot --headless --audio-driver Dummy --path . --import --quit
gdformat --check scripts tests && gdlint scripts tests
GODOT_DISABLE_LEAK_CHECKS=1 godot --headless -d --audio-driver Dummy --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
