# Проверка v0.5.1 (2026-10-12)

- `python3 tools/art/month2.py` — ok; импорт Godot ×2.
- `node tools/godot/export_data.cjs` — сцен 330, notes 60; `node tools/godot/js_reference.cjs 200` — home130 more32 neutral17 good8 gone7 bad6.
- GUT: до пересборки эталона 28/29 (parity: шагов на 1 больше, чем в устаревшем эталоне); после — **29/29, 253 asserts — PASS**.
- Скриншот `m2_door` в игре (Xvfb, opengl3): новый кадр отображается, герой бледный с пышными волосами — визуально проверено.
- UNVERIFIED: внешность героя в других кадрах месяца 2 (work, sleep, knock, roofsit, palm, shift, snow, snow_hug).
