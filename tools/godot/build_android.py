#!/usr/bin/env python3
"""Reproducible sideload APK: release engine, ARM32+ARM64, local test signature.
Requires pinned Godot 4.7.2, its android_release.apk, Android SDK and a JDK.
Original project/assets are never resized or recompressed in place.
"""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess


def run(args, env=None):
    subprocess.run([str(a) for a in args], check=True, env=env)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--sdk', default=os.environ.get('ANDROID_HOME', ''))
    parser.add_argument('--java', default=os.environ.get('JAVA_HOME', ''))
    parser.add_argument('--template', required=True, help='4.7.2 android_release.apk')
    parser.add_argument('--stage', required=True, help='disposable NEW build directory')
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    stage = Path(args.stage).resolve()
    out = Path(args.out).resolve()
    sdk = Path(args.sdk).resolve()
    java = Path(args.java).resolve()
    template = Path(args.template).resolve()
    assert args.sdk and args.java and template.is_file(), 'SDK, JDK and template required'
    assert not stage.is_relative_to(root / 'godot'), 'Stage must be outside the Godot source tree'
    assert not stage.exists(), 'Use a new stage directory (nothing will be deleted for you)'
    assert subprocess.check_output([args.godot, '--version'], text=True).startswith('4.7.2.'), 'Godot pin is 4.7.2'
    stage.mkdir(parents=True)
    project = stage / 'godot'
    shutil.copytree(root / 'godot', project,
                    ignore=shutil.ignore_patterns('.godot', 'build', '*.tmp'))
    count = 0
    for folder in ['assets/bg', 'assets/sprites', 'assets/title', 'art/bg', 'art/sprites', 'art/title']:
        for imp in (project / folder).rglob('*.import'):
            text = imp.read_text()
            text = re.sub(r'process/size_limit=\d+', 'process/size_limit=1280', text)
            text = text.replace('mipmaps/generate=true', 'mipmaps/generate=false')
            text = re.sub(r'compress/mode=\d+', 'compress/mode=2', text)
            imp.write_text(text)
            count += 1
    preset = project / 'export_presets.cfg'
    text = preset.read_text()
    marker = '[preset.1.options]'
    before, android = text.split(marker, 1)
    android = android.replace('custom_template/release=""', f'custom_template/release="{template}"')
    android = android.replace('package/signed=true', 'package/signed=false')
    preset.write_text(before + marker + android)
    config = stage / 'config' / 'godot'
    config.mkdir(parents=True)
    (config / 'editor_settings-4.7.tres').write_text(
        '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
        f'export/android/android_sdk_path = "{sdk}"\n'
        f'export/android/java_sdk_path = "{java}"\n')
    env = dict(os.environ, XDG_CONFIG_HOME=str(config.parent), JAVA_HOME=str(java), ANDROID_HOME=str(sdk))
    print(f'Android stage: {count} image import profiles, max 1280, ETC2, no mipmaps.', flush=True)
    run([args.godot, '--headless', '--editor', '--path', project, '--import', '--quit'], env)
    run([args.godot, '--headless', '--editor', '--path', project, '--import', '--quit'], env)
    out.parent.mkdir(parents=True, exist_ok=True)
    unsigned = stage / 'unsigned.apk'
    run([args.godot, '--headless', '--path', project, '--export-release', 'Android', unsigned], env)
    tools = sdk / 'build-tools' / '35.0.0'
    aligned = stage / 'aligned.apk'
    run([tools / 'zipalign', '-f', '-P', '16', '4', unsigned, aligned], env)
    keystore = Path.home() / '.android' / 'debug.keystore'
    if not keystore.exists():
        keystore.parent.mkdir(parents=True, exist_ok=True)
        run([java / 'bin/keytool', '-genkeypair', '-keystore', keystore,
             '-alias', 'androiddebugkey', '-storepass', 'android', '-keypass', 'android',
             '-dname', 'CN=Android Debug,O=Android,C=US', '-keyalg', 'RSA',
             '-keysize', '2048', '-validity', '10000'], env)
    run([tools / 'apksigner', 'sign', '--ks', keystore, '--ks-key-alias', 'androiddebugkey',
         '--ks-pass', 'pass:android', '--key-pass', 'pass:android', '--out', out, aligned], env)
    run([tools / 'apksigner', 'verify', '--verbose', out], env)
    run([tools / 'zipalign', '-c', '-P', '16', '-v', '4', out], env)
    print(f'APK OK: {out} ({out.stat().st_size / 1048576:.1f} MiB). TEST SIGNATURE, not Play Store.', flush=True)


if __name__ == '__main__':
    main()
