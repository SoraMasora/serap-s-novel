#!/usr/bin/env bash
# Восстановить бинарные ассеты Godot (арт, звук, исходники кадров) из backup/godot_assets.
# Использование: bash tools/restore_assets.sh   (из корня репозитория)
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp)
for f in backup/godot_assets/part*.b64; do base64 -d "$f"; done > "$tmp"
want=$(cat backup/godot_assets/SHA256)
got=$(sha256sum "$tmp" | cut -d' ' -f1)
[ "$want" = "$got" ] || { echo "SHA256 не совпал: $got != $want" >&2; rm -f "$tmp"; exit 1; }
tar -xzf "$tmp"
rm -f "$tmp"
echo "ok: восстановлено $(wc -l < backup/godot_assets/FILES.txt) файлов"
