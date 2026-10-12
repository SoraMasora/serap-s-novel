# Проверка v0.6.0 (2026-10-12)

- `node tools/godot/export_data.cjs --assets` — scenes 350, notes 61; `node tools/godot/js_reference.cjs 200` — home 130, more 32, neutral 17, good 8, gone 7, bad 6.
- `gdformat --check scripts tests && gdlint scripts tests` — чисто.
- GUT: **31/31, 286 asserts — PASS** (локально без «осиротевших» `.import` из `godot/art`, см. KI-015).
- Скриншоты `tools_dev/shot.gd` (Xvfb, opengl3): `react('clap')` 0.3/0.6 с, `react('angry')` 0.4/0.8 с — кадры меняются; `m2_tea` — CG вручения; `m2_roof` — `m2_rx` (дым от сигарет), с `c3nosmoke` — `m2_rt` (чай); `m2_door_timur` — новый Тимур; Матвей `stern`.
- UNVERIFIED: `m2_shift` у автора (KI-016); веб-версия визуально не проверялась.
