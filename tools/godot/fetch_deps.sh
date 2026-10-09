#!/usr/bin/env bash
# Загрузка закреплённых сторонних зависимостей Godot-порта (не коммитятся: бинарные файлы).
# Версии/хэши — docs/DEPENDENCIES.md. Запуск из корня репо: bash tools/godot/fetch_deps.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
G=godot
GUT_TAG=v9.7.1
GUT_SHA256=14969aa46adc84aa08cdd21b9f6d1a64addd92ae60b36f02d0521ed305aa4086
FONTS_REV=51303ca9e8ac9dcea7b12d307ba568fd0e6fcfca
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
check() { echo "$2  $1" | sha256sum -c --status || { echo "SHA256 mismatch: $1" >&2; sha256sum "$1" >&2; exit 1; }; }
if [ ! -f "$G/addons/gut/plugin.cfg" ]; then
  curl -fsSL -o "$tmp/gut.zip" "https://github.com/bitwes/Gut/archive/refs/tags/$GUT_TAG.zip"
  check "$tmp/gut.zip" "$GUT_SHA256"
  unzip -q "$tmp/gut.zip" -d "$tmp"
  mkdir -p "$G/addons"; rm -rf "$G/addons/gut"; cp -r "$tmp"/Gut-*/addons/gut "$G/addons/gut"
  echo "GUT $GUT_TAG ok"
fi
mkdir -p "$G/assets/fonts"
fetch_font() { # путь_в_google_fonts имя_файла sha256
  local out="$G/assets/fonts/$2"
  [ -f "$out" ] && check "$out" "$3" && return 0
  curl -fsSL -o "$out" "https://raw.githubusercontent.com/google/fonts/$FONTS_REV/ofl/$1"
  check "$out" "$3"
}
fetch_font "grenzegotisch/GrenzeGotisch%5Bwght%5D.ttf" GrenzeGotisch.ttf 701b299d8dc002a2b4bea2ff0f1272c0e4081a2835914354804565c410d0c637
fetch_font "cormorantsc/CormorantSC-Bold.ttf" CormorantSC-Bold.ttf 78f70c79b5c0a1e66641d4b4a2e2ed32e1a45774b3de94e56f8de68510219177
fetch_font "lora/Lora%5Bwght%5D.ttf" Lora.ttf 822a6621ccbe8d97d20ac88c1c41f5615c9c2c202eaa75f272cd452aac6475a7
fetch_font "lora/Lora-Italic%5Bwght%5D.ttf" Lora-Italic.ttf 22d8d8854b53807aa664ca34f2031a9ed57a1d0dea296b8b96cdd3aad937a2b3
curl -fsSL -o "$G/assets/fonts/OFL-GrenzeGotisch.txt" "https://raw.githubusercontent.com/google/fonts/$FONTS_REV/ofl/grenzegotisch/OFL.txt"
curl -fsSL -o "$G/assets/fonts/OFL-CormorantSC.txt" "https://raw.githubusercontent.com/google/fonts/$FONTS_REV/ofl/cormorantsc/OFL.txt"
curl -fsSL -o "$G/assets/fonts/OFL-Lora.txt" "https://raw.githubusercontent.com/google/fonts/$FONTS_REV/ofl/lora/OFL.txt"
echo "fonts ok"
