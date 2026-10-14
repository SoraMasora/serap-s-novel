# Проверка v0.7.3

- PASS: отключены 6 новых CG: c3_calm_wings, c3_calm_notyou, c3_calm_photo, c3_pl_wait, c3_angel_a, c3_angel_b.
- PASS: после экспорта SHA256 story.json идентичен 0.7.2. Сюжет, выборы, флаги и обычная постановка не менялись.
- PASS: 67 активных кадров; каталоги веб и Godot совпадают.
- PASS: импорт Godot 4.7.2, CHECK OK, gdformat 41 files unchanged, gdlint no problems.
- PASS: GUT 38/38, 332 asserts (включая паритет по существующим 200 эталонным прогонам и все 22 исключения CG).
- PASS: локальный Chromium проверил каждый из шести ответов: пустой ключ кадра, 0 page errors.
- UNVERIFIED: ручное прохождение всех веток, физический GPU, Android и GitHub CI.

Бэкап перед правками: backup/v0.7.2-before-extra-cg-removal (563cad02).
