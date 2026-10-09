# Dependencies (пины)

| Что | Версия | Проверка | Где используется |
|---|---|---|---|
| Godot | 4.7.2-stable (ed1daf0bf) | sha256 `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4` (linux.x86_64.zip) | всё |
| Export templates | 4.7.2-stable | sha256 `f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011` (.tpz) | веб-, Android-экспорт (android_debug/release.apk) |
| GUT | v9.7.1 | sha256 `14969aa46adc84aa08cdd21b9f6d1a64addd92ae60b36f02d0521ed305aa4086` (tag zip) | tests/ |
| gdtoolkit | 4.5.0 (pip) | версия | линт/формат |
| Google Fonts | rev 51303ca9e8ac9dcea7b12d307ba568fd0e6fcfca | sha256 каждого файла в fetch_deps.sh | GrenzeGotisch, CormorantSC-Bold, Lora, Lora-Italic |
| Node | 24.x | — | tools/godot/*.cjs |
| Playwright | 1.63.0 + Chromium | — | bake_web.cjs, web_smoke.cjs |
| ffmpeg | любой с libvorbis | — | bake_web.cjs audio |
| JDK | 17 (Temurin 17.0.20.1+1) | `java -version` | Android-экспорт (apksigner, keytool) |
| Android SDK build-tools | 35.0.0 (+ platform-tools) | `apksigner --version` | Android-экспорт без Gradle; targetSdk 36 задан шаблоном 4.7.2 |
| Xcode | из образа `macos-15` GitHub Actions (локально любой с iOS SDK ≥ 14) | `xcodebuild -version` | сборка .ipa (job `ios`, `ios_build.sh` на macOS) |
