# AI_STATE — текущее состояние (2026-10-09, ветка `godot-mobile`)

## Сделано
- Порт веб-новеллы v17.2 на Godot 4.7.2 (`godot/`): сюжет из story.json, подача, карта, звук, сейвы, модалки, концовки.
- Вёрстка окна реплик, портрета и выборов приведена к css v4–v13 (сверено скриншотами).
- Инструменты генерации ассетов/данных/эталона; CI-конфиг; документация handoff; Notion Project Board с базами.
- **v0.19.0 мобильная версия:** stretch `expand` + карта 16:9 в AspectRatioContainer; автозагрузка `Mobile` (сенсорный режим, safe area, «назад», пауза→автосейв, экран не гаснет, полноэкранный режим в вебе); `scenes/mobile/*` (нативный `VirtualJoystick` 4.7, кнопки «E»/«Бег», быстрое меню); `ui/theme_mobile.tres`; пресеты Android (APK без Gradle) и iOS; PWA; CI собирает APK; исправлен YAML CI (двоеточие в имени шага ломало парсинг).
- **iOS:** пресет экспортирует Xcode-проект (export_project_only, iPhone+iPad, iOS 14+, альбомная); `tools/godot/ios_build.sh`; CI job `ios` (macos-15) собирает неподписанный .ipa (ADR-0006).

## В работе
- Нет (проход закрыт, ветка `godot-mobile` не слита в main).

## Следующий шаг (одна команда)
`adb install -r godot/build/android/serap-debug.apk` — проверить на реальном Android-телефоне (KI-009), затем `state.json.next_task`.

## Блокеры
- Нет GPU в песочнице агента → кадровый бюджет на реальном железе не измерен (KI-003).
- CI не запускался на GitHub (KI-007).
- Нет реального телефона и macOS/Xcode: .ipa не собирался, на устройствах не запускалось (KI-009, KI-010).

## Последний зелёный статус
GUT 44/44 (254 asserts) · gdlint/gdformat чисто · CHECK OK · autoplay 42 digest 9a1c118c · mobile_smoke ERRORS none · APK собран · Xcode-проект iOS экспортирован — 2026-10-09.

## Последний SHA
main: `b944650`. Ветка `godot-mobile`: коммит `feat(godot-mobile)` (см. `git log -1 godot-mobile`).
