#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
python3 tools/validate_assets.py
"$GODOT_BIN" --headless --path godot --editor --import --quit
"$GODOT_BIN" --headless --path godot --editor --import --quit
"$GODOT_BIN" --headless -d --audio-driver Dummy --path godot -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
