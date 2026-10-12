# Проверка v0.6.1 (2026-10-13)

- `bash tools/restore_assets.sh` — 108 файлов, SHA256 ок; «осиротевших» `.import` больше нет.
- `node tools/godot/export_data.cjs --assets` — scenes 350, notes 61, assets 168; `node tools/godot/js_reference.cjs 200` — home 130, more 32, neutral 17, good 8, gone 7, bad 6.
- GUT: **31/31, 286 asserts — PASS** на полном арте.
- Скриншоты `tools_dev/shot.gd` (Xvfb, opengl3): `store_1` — `timur_grin`, `store_2` — `timur` рядом с Серой (пропорции совпадают), `cg_shift` — новый Тимур.
- UNVERIFIED: веб-версия визуально не проверялась.
