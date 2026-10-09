#!/usr/bin/env bash
# Сборка iOS-версии Godot-порта (ADR-0006).
# Linux/Windows/macOS: экспорт Xcode-проекта (preset "iOS", export_project_only) → godot/build/ios/
# Только macOS + Xcode: дополнительно собирает неподписанный godot/build/serap-unsigned.ipa
#   (подписать и поставить: Sideloadly/AltStore со своим Apple ID или открыть serap.xcodeproj в Xcode → Team → Run).
# Нужны: шаблон 4.7.2 ios.zip в ~/.local/share/godot/export_templates/4.7.2.stable/ (macOS: ~/Library/Application Support/Godot/export_templates/4.7.2.stable/),
#        ассеты и импорт (START_HERE, шаги 1–2). GODOT=<путь к godot> при необходимости.
set -euo pipefail
cd "$(dirname "$0")/../../godot"
G="${GODOT:-godot}"
mkdir -p build/ios && touch build/.gdignore
"$G" --headless --path . --export-release "iOS" build/ios/serap.xcodeproj
test -f build/ios/serap.pck && test -d build/ios/serap.xcodeproj
echo "xcode project: godot/build/ios/serap.xcodeproj"
if [ "$(uname)" = "Darwin" ] && command -v xcodebuild > /dev/null; then
  cd build/ios
  xcodebuild -project serap.xcodeproj -scheme serap -configuration Release -sdk iphoneos \
    -destination 'generic/platform=iOS' -derivedDataPath dd \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM="" build
  rm -rf Payload && mkdir Payload && cp -R dd/Build/Products/Release-iphoneos/serap.app Payload/
  rm -f ../serap-unsigned.ipa && zip -qry ../serap-unsigned.ipa Payload
  echo "ipa: godot/build/serap-unsigned.ipa"
else
  echo "не macOS: .ipa не собирается (нужен Xcode) — откройте Xcode-проект на Mac или используйте CI job ios"
fi
