#!/usr/bin/env bash
# Проверка компиляции всех GDScript (ошибки парсинга/типов). Запуск из корня репо.
set -uo pipefail
cd "$(dirname "$0")/../../godot"
fail=0
for f in $(find scripts tests -name '*.gd' | sort); do
  out=$(godot --headless --path . --check-only --script "res://$f" 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error|ERROR:" | grep -v "Failed to compile depended" | grep -v "Identifier not found: \(Game\|Audio\|SaveSystem\|Mobile\)" | grep -v "Failed to load script")
  if [ -n "$out" ]; then echo "== $f"; echo "$out" | head -8; fail=1; fi
done
[ $fail = 0 ] && echo "CHECK OK"
exit $fail
