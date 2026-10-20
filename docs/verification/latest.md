# Проверка v0.7.4 (death-cg + скример)

- PASS: GUT 70/70, 1981 asserts (`GODOT_DISABLE_LEAK_CHECKS=1 godot --headless -d --audio-driver Dummy --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`). Новые: `test_every_death_shows_her_last_moment_before_aftermath`, `test_screamer_variants_are_known_and_rotate`, `tests/integration/test_loop_scare.gd` (7 тестов).
- PASS: `bash tools/godot/check_scripts.sh` → CHECK OK; `gdformat --check scripts tests` → 52 files unchanged; `gdlint scripts tests` → no problems.
- PASS: `node tools/godot/verify_preservation.cjs` — исходные сцены, концовки и защищённые файлы не изменились.
- PASS: импорт Godot 4.7.2 без ошибок (новые webp, ogg, шейдер).
- PASS: Xvfb/OpenGL llvmpipe, реальные прохождения сцен смерти dev-скриптом `godot/tools_dev/play_loop.gd`; он же проверен на восстановление профиля игрока (md5 памяти, концовок, прочитанного и автосейва совпали после запуска): room/burst, store/lull, road/title, train/whisper, cross/false, cliff/мягкий режим, neck/lull после шести смертей. Кадры `dm_*` → `d_*`, скример и возврат в меню с заблокированной «Новой игрой» на скриншотах.
- UNVERIFIED: звук на слух (`loop_shriek`, `loop_ring`, `loop_breath`; ожидаемо — резкий визг, звон после обрыва, дыхание слева), аппаратный GPU, экспорт EXE/APK, GitHub CI.
