# Verification — latest (2026-10-09, ветка `godot-mobile`, v0.19.0)

Платформа: Linux (Amazon Linux 2023), Godot 4.7.2.stable.official.ed1daf0bf, headless; Chromium 153 (SwiftShader); JDK 17.0.20.1, Android build-tools 35.0.0. GitHub Actions и реальные телефоны — не запускались.

| # | Команда | Результат | Статус |
|---|---|---|---|
| 1 | `node tools/godot/export_data.cjs --assets` · `bake_web.cjs` · `fetch_deps.sh` | как на main (story.json 234 сцены, ассеты 155 файлов) | PASS |
| 2 | `godot --headless --path . --import --quit` (2-й проход) | без ошибок | PASS |
| 3 | `bash tools/godot/check_scripts.sh` | `CHECK OK` (включая Mobile) | PASS |
| 4 | `gdformat --check scripts tests && gdlint scripts tests` | `42 files would be left unchanged` · `Success: no problems found` | PASS |
| 5 | GUT (`-gdir=res://tests -ginclude_subdirs`) | Tests 44, Passing 44, Asserts 254 (+16 мобильных: test_mobile 5, test_touch_controls 5, test_mobile_main 6) | PASS |
| 6 | `godot --headless --path . -- --autoplay=42` | `ending home, steps 403, digest 9a1c118c…` — совпадает с main (ядро не тронуто) | PASS |
| 7 | perf `tests/perf/perf_pixel_map.tscn -- --frames=600` | avg 1.24 мс, p99 1.94 мс | PASS |
| 8 | `godot --headless --path . --export-release "Web" build/web/index.html` | ок; `index.manifest.json`: display fullscreen, orientation landscape | PASS |
| 9 | `mobile_smoke.cjs` (Pixel 7 UA, 844×390, isMobile/hasTouch): титул → имя (экранная клавиатура) → глава → касания → быстрое меню | ERRORS none, boot 12.8 с | PASS (host) |
| 10 | `mobile_smoke.cjs` с `--jump=d1`: карта, drag джойстика, «E» | ERRORS none; герой идёт, карта 16:9, вывески на месте | PASS (host) |
| 11 | `godot --headless --path . --export-debug "Android" build/android/serap-debug.apk` | 58,6 МБ; `aapt2 dump badging`: com.soramasora.seraps 19/0.19.0, arm64-v8a, targetSdk 36; `apksigner verify` ок | PASS (build) |
| 12 | `python3 -c "yaml.safe_load(...godot.yml)"` | парсится (на main падал на строке 45 — исправлено) | PASS |
| 13 | `bash tools/godot/ios_build.sh` (Linux, preset iOS export_project_only) | Xcode-проект `serap.xcodeproj` + `serap.pck` 30,6 МБ; Info.plist: landscape L/R, UIRequiresFullScreen, UIStatusBarHidden; pbxproj: com.soramasora.seraps, iOS 14.0, TARGETED_DEVICE_FAMILY "1,2", 0.19.0/19; ERROR 0 | PASS (export) |
| 14 | GUT на чистом клоне ветки (после отката песочницы) | 44/44, 254 asserts | PASS |

## Не проверялось
- APK на реальном Android-телефоне (KI-009) — `adb install -r godot/build/android/serap-debug.apk`; ожидается: альбомная, касания листают текст, джойстик/«E»/«Бег» на карте, «назад» → меню, сворачивание → автосейв.
- Сборка .ipa (`xcodebuild`) и запуск на iPhone (KI-010) — нужен macOS; ожидается артефакт CI `ios-unsigned-ipa`.
- CI на GitHub Actions (KI-007) — ожидаются артефакты `web-build`, `android-debug-apk`, `ios-xcode-project`, `ios-unsigned-ipa`.
- Звук на слух, FPS на реальном GPU, редактор с GUI.
