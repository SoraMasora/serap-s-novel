#!/usr/bin/env bash
# Настройка экспорта Android для Godot 4.7.2 (APK без Gradle, из шаблона android_*.apk):
# прописывает JDK и Android SDK в настройки редактора и создаёт debug-keystore, если его нет.
# Запуск: JAVA_HOME=<jdk17> ANDROID_SDK_ROOT=<sdk с build-tools> bash tools/godot/android_setup.sh
# Нужны: шаблоны экспорта 4.7.2 (android_debug.apk/android_release.apk) в ~/.local/share/godot/export_templates/4.7.2.stable/
set -euo pipefail
: "${JAVA_HOME:?JAVA_HOME не задан (нужен JDK 17)}"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[ -n "$SDK" ] || { echo "ANDROID_SDK_ROOT не задан" >&2; exit 1; }
ls "$SDK"/build-tools/*/apksigner > /dev/null || { echo "В $SDK нет build-tools/*/apksigner" >&2; exit 1; }
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/godot"
ES="$CFG/editor_settings-4.7.tres"
KS="${GODOT_DEBUG_KEYSTORE:-$HOME/.local/share/godot/keystores/debug.keystore}"
mkdir -p "$CFG" "$(dirname "$KS")"
if [ ! -f "$KS" ]; then
  "$JAVA_HOME/bin/keytool" -genkeypair -v -keystore "$KS" -storepass android -keypass android \
    -alias androiddebugkey -dname "CN=Android Debug,O=Android,C=US" -keyalg RSA -keysize 2048 -validity 10000 > /dev/null 2>&1
  echo "debug keystore: $KS"
fi
if [ ! -f "$ES" ]; then
  printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$ES"
fi
set_es() { # ключ значение
  if grep -q "^$1 = " "$ES"; then sed -i "s|^$1 = .*|$1 = \"$2\"|" "$ES"; else echo "$1 = \"$2\"" >> "$ES"; fi
}
set_es export/android/java_sdk_path "$JAVA_HOME"
set_es export/android/android_sdk_path "$SDK"
set_es export/android/debug_keystore "$KS"
set_es export/android/debug_keystore_user androiddebugkey
set_es export/android/debug_keystore_pass android
echo "android export ok: JDK=$JAVA_HOME SDK=$SDK"
