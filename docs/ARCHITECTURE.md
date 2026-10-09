# Архитектура Godot-порта (godot/)

## Инварианты
1. **Сюжет — данные.** `data/story.json` генерируется из `js/story*.js` (`tools/godot/export_data.cjs`); условия `when` переведены в выражения Godot `Expression` (`feel<40`, `flag("x")`, `num("v")>=1`, `notes_count()`).
2. **Ядро без узлов.** `StoryRunner` (RefCounted) — чистая логика `run()` из `js/engine.js`: шаг → список событий. UI только рисует события, поэтому ядро тестируется без сцены и сравнивается с JS-эталоном.
3. **Настройки — ресурсы.** `GameConfig`, `AudioConfig`, `PixelConfig` (`scripts/resources/*.gd`) + экземпляры `data/*.tres`. Вёрстка — в `.tscn` и `ui/theme.tres`.
4. **Сцены — .tscn, повторяющееся — PackedScene** (кнопка выбора, сердечко, запись журнала, заметка, вывеска карты, панели модалок).
5. **Сохранения атомарны** (tmp → rename), битый файл → `.bad`, пустой/чужой формат → «нет сейва», без падения.

## Слои
```
data/*.json, data/*.tres          ← tools/godot/*.cjs (генерация из веб-оригинала)
   │
scripts/core/  StoryDB → StoryRunner → AutoPlayer        (логика, детерминизм, паритет)
   │ события: say / card / cut / choice / breath / map / final
scripts/ui/main.gd (scenes/main/main.tscn)              (подача: фоны, персонажи, реплики, выбор, эффекты)
   ├─ scenes/ui/*.tscn   text_box, choice_button, heart, cutscene, chapter_card, breath_game, modal, title, name, ending
   ├─ scenes/pixel/pixel_map.tscn → PixelWorld (SubViewport 320×180 ×4) + MiniMap + PixelSign
   └─ автозагрузки: Game (конфиг, БД, манифест, настройки) · SaveSystem (слоты, автосейв, концовки) · Audio (музыка/дождь/SFX)
```

## Мобильный слой (v0.19.0, ADR-0005)
```
Mobile (autoload, scripts/autoload/mobile.gd)  ← data/mobile_config.tres (MobileConfig)
  ├─ touch_mode: detect_touch(setting, флаги ОС/веба/CLI) → сигнал touch_mode_changed
  ├─ safe area: compute_insets(DisplayServer) → apply_insets() всем узлам группы `safe_area` (по якорям)
  ├─ back_requested (NOTIFICATION_WM_GO_BACK_REQUEST) → main.on_back()
  └─ app_paused/app_resumed → автосейв; keep_screen_on; toggle_fullscreen() (веб)
main.tscn ── TouchQuickMenu (scenes/mobile/touch_quick_menu.tscn) · тема ui/theme_mobile.tres в сенсорном режиме
pixel_map.tscn ── Frame (AspectRatioContainer 16:9) → View/Signs · Touch (pixel_touch_controls.tscn: VirtualJoystick + 2× touch_action_button.tscn)
```
Касания превращаются в те же действия InputMap (`map_*`, `map_run`, `map_interact`, `vn_*`) — логика игры не знает об источнике ввода.

## Схема состояний (main.gd)
`title → name → playing{ say ⇄ choice ⇄ breath ⇄ map ⇄ cut/card } → ending → title`
Модалки (меню, журнал/откат, заметки, слоты, настройки, концовки) блокируют ввод игры; skip/auto — флаги поверх `say`.
Снимок — `StoryRunner.save_snapshot()` (сцена, индекс, флаги, статы, заметки, журнал, музыка, карта); откат — снимок перед выбором.

## Code map
| Папка | Файлы | Тесты | ADR |
|---|---|---|---|
| scripts/core | story_db.gd, story_runner.gd, autoplayer.gd | unit/test_story_runner.gd, integration/test_parity_js.gd | 0003 |
| scripts/autoload | game.gd, save_system.gd | unit/test_save_system.gd | — |
| scripts/audio | audio.gd (scenes/audio/audio.tscn) | integration/test_main_smoke.gd (косвенно) | 0002 |
| scripts/ui | main.gd, text_box.gd, choice_button.gd, … | unit/test_text_box.gd, integration/test_main_smoke.gd | 0001 |
| scripts/pixel | pixel_world.gd, pixel_map.gd, mini_map.gd | perf/perf_pixel_map.tscn, smoke (11 карт) | 0002 |
| scripts/resources | game_config.gd, audio_config.gd, pixel_config.gd | все (загружают .tres) | — |
| scripts/autoload/mobile.gd, scripts/mobile, scenes/mobile | mobile.gd, pixel_touch_controls.gd, touch_action_button.gd, touch_quick_menu.gd, mobile_config.gd | unit/test_mobile.gd, unit/test_touch_controls.gd, integration/test_mobile_main.gd | 0005 |
| tools/godot | export_data, bake_web, js_reference, fetch_deps, web_smoke, mobile_smoke, android_setup, ios_build, check_scripts | `.github/workflows/godot.yml` | 0002, 0004, 0005, 0006 |

## Детерминизм
ГПСЧ Парка–Миллера (`s = s*16807 % 2147483647`, выбор `s % n`) одинаков в `AutoPlayer` и `tools/godot/js_reference.cjs`; digest = sha256 трассы событий. Плейтест логики — L3 (полный путь сюжета, 200 сидов); UI-смоук в skip-режиме проходит игру до концовки на реальных сценах (L2, без попиксельного сравнения кадров).
