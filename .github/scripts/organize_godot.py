#!/usr/bin/env python3
"""One-time migration to a standalone Godot repository. Run from the repository root."""
import hashlib,json,pathlib,shutil,subprocess,sys
ROOT=pathlib.Path.cwd()
assert (ROOT/'godot/project.godot').is_file(), 'Run from repository root'

def move(src,dst):
 s=ROOT/src; d=ROOT/dst
 if s.exists():
  d.parent.mkdir(parents=True,exist_ok=True)
  assert not d.exists(),str(d)
  shutil.move(s,d)

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
# Restore the entire runtime BEFORE removing the legacy build inputs.
subprocess.run(['bash','tools/restore_assets.sh'],check=True)
subprocess.run(['node','tools/godot/export_data.cjs','--assets'],check=True)
subprocess.run([sys.executable,'tools/restore_pc_075a.py'],check=True)
# Save all original asset libraries and art sources, without keeping the browser engine.
move('assets','source_assets/embedded')
move('art_sources','source_assets/art')
move('tools/art/src','source_assets/original')
move('docs/art','source_assets/manifests')
move('docs/verification/admin_panel.png','source_assets/reference/admin_panel.png')
# These are obsolete Android-specific files and a manual script from the old main,
# absent from the supplied PC project. Working touch controls under scripts/pixel remain.
for rel in ['godot/data/mobile074_overrides.json','godot/scenes/mobile','godot/scripts/mobile',
            'godot/tools_dev/mobile_preview.gd','godot/tools_dev/mobile_preview.gd.uid',
            'godot/tests/manual/loop_visual.gd']:
 p=ROOT/rel
 if p.is_dir():shutil.rmtree(p)
 elif p.exists():p.unlink()
# Replace obsolete recovery advice now that all resources ship with the project.
for rel,old,new in [
 ('godot/scripts/autoload/game.gd','запустите node tools/godot/export_data.cjs --assets','восстановите отсутствующие файлы проекта из Git'),
 ('godot/scripts/pixel/pixel_world.gd','запустите tools/godot/bake_web.cjs','восстановите отсутствующие файлы проекта из Git'),
]:
 p=ROOT/rel; text=p.read_text(); assert old in text,rel
 p.write_text(text.replace(old,new))
# Capture the exact Godot resource bytes and the preserved source assets.
asset_paths=[]
for folder in ['godot/assets','godot/art','source_assets','godot/addons/gut']:
 for p in (ROOT/folder).rglob('*'):
  if p.is_file() and not p.name.endswith(('.import','.pyc')) and '__pycache__' not in p.parts:
   asset_paths.append(p)
manifest={p.relative_to(ROOT).as_posix():digest(p) for p in sorted(asset_paths)}
# Remove legacy root content and temporary migration support after restoration.
keep={'godot','source_assets','.git','.github','tools'}
for p in list(ROOT.iterdir()):
 if p.name in keep:continue
 if p.is_dir():shutil.rmtree(p)
 else:p.unlink()
# Source image files have already moved out; the old tools depend on the removed web app.
shutil.rmtree(ROOT/'tools')
(ROOT/'tools').mkdir()
for p in list((ROOT/'.github').iterdir()):
 if p.is_dir():shutil.rmtree(p)
 else:p.unlink()
(ROOT/'.github/workflows').mkdir(parents=True)
# Files embedded in this migration payload are written last.
payload=json.loads('{"README.md": "# S^erap^S — Godot\\n\\nСамостоятельный проект визуальной новеллы **0.7.5a** для **Godot 4.7.2**.\\n\\n## Запуск\\n\\n1. Склонируйте репозиторий или скачайте его ZIP.\\n2. В Godot импортируйте **`godot/project.godot`**.\\n3. Дождитесь импорта ресурсов и нажмите **F5**.\\n\\nВсе изображения, звуки, музыка, шрифты и GUT уже включены обычными файлами. Для запуска не нужны Node.js, браузерная версия, распаковка base64-архивов или скачивание зависимостей.\\n\\n- **F9** — админ-панель.\\n- Сохранения находятся в `user://`, а не в репозитории.\\n- Это исходный проект, не готовый EXE. Для экспорта нужны шаблоны Godot той же версии.\\n\\n## Структура\\n\\n| Папка | Содержимое |\\n| --- | --- |\\n| `godot/` | Проект, сцены, код, сценарий, игровые ресурсы, настройки, тесты и GUT |\\n| `source_assets/` | Исходные библиотеки ассетов, исходники арта, манифесты и контрольные суммы |\\n| `tools/` | Проверка ресурсов и запуск тестов |\\n| `.github/workflows/` | Автоматическая проверка Godot-проекта |\\n\\n`source_assets/embedded/` — сохранённые исходные библиотеки ресурсов старой версии, **не браузерная игра и не зависимость запуска**. Их байты сохранены; движок, HTML/CSS и старые сборочные скрипты удалены из текущей структуры.\\n\\n## Проверки\\n\\nPython 3 нужен только для проверки файлов; для самой игры достаточно Godot.\\n\\n```bash\\npython3 tools/validate_assets.py\\nbash tools/test.sh\\n```\\n\\nЕсли Godot не в PATH:\\n\\n```bash\\nGODOT_BIN=/path/to/godot bash tools/test.sh\\n```\\n\\n`source_assets/SHA256.json` фиксирует контрольные суммы сохранённых ресурсов. При намеренной замене ассета обновляйте и соответствующую сумму, а не отключайте проверку.\\n\\n## История и права\\n\\nИстория коммитов не переписывалась. Старый веб-код, инструкции и резервные копии доступны в предыдущих коммитах и в сохранённой ветке `S-erap-S-game`.\\n\\nЛицензии GUT и шрифтов сохранены рядом с соответствующими файлами. Исходные манифесты арта находятся в `source_assets/manifests/`. Права и условия использования материалов очисткой не изменяются.\\n", ".gitignore": "# Godot-generated cache and exports\\n.godot/\\nbuild/\\nexports/\\n# Local tools, OS files and private export configuration\\n__pycache__/\\n*.pyc\\n.DS_Store\\nThumbs.db\\n.env\\n.env.*\\nexport_credentials.cfg\\n# Keep game textures, audio, fonts, import settings and addon dependencies tracked.\\n", "godot/.gitignore": ".godot/\\nbuild/\\nexports/\\nexport_credentials.cfg\\n", "tools/validate_assets.py": "#!/usr/bin/env python3\\n\\"\\"\\"Verify that preserved game resources and source assets are present and unchanged.\\"\\"\\"\\nimport hashlib, json, pathlib, sys\\nroot = pathlib.Path(__file__).resolve().parents[1]\\nmanifest = json.loads((root / \\"source_assets/SHA256.json\\").read_text())\\nerrors = []\\nfor relative, expected in manifest.items():\\n    path = root / relative\\n    if not path.is_file():\\n        errors.append(\\"Missing: \\" + relative)\\n    elif hashlib.sha256(path.read_bytes()).hexdigest() != expected:\\n        errors.append(\\"Changed: \\" + relative)\\nif errors:\\n    print(\\"\\\\n\\".join(errors), file=sys.stderr)\\n    sys.exit(1)\\nprint(\\"Verified\\", len(manifest), \\"preserved resource/source files\\")\\n", "tools/test.sh": "#!/usr/bin/env bash\\nset -euo pipefail\\ncd \\"$(dirname \\"$0\\")/..\\"\\nGODOT_BIN=\\"${GODOT_BIN:-godot}\\"\\npython3 tools/validate_assets.py\\n\\"$GODOT_BIN\\" --headless --path godot --editor --import --quit\\n\\"$GODOT_BIN\\" --headless --path godot --editor --import --quit\\n\\"$GODOT_BIN\\" --headless -d --audio-driver Dummy --path godot -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit\\n", ".github/workflows/godot.yml": "name: Godot\\non:\\n  push:\\n    paths: [\\"godot/**\\", \\"tools/**\\", \\"source_assets/**\\", \\".github/workflows/godot.yml\\"]\\n  pull_request:\\n    paths: [\\"godot/**\\", \\"tools/**\\", \\"source_assets/**\\", \\".github/workflows/godot.yml\\"]\\n  workflow_dispatch:\\npermissions:\\n  contents: read\\njobs:\\n  test:\\n    runs-on: ubuntu-24.04\\n    timeout-minutes: 30\\n    env:\\n      GODOT_VERSION: 4.7.2-stable\\n      GODOT_SHA256: cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4\\n    steps:\\n      - uses: actions/checkout@v4\\n      - uses: actions/setup-python@v5\\n        with:\\n          python-version: \\"3.13\\"\\n      - name: Install pinned Godot\\n        run: |\\n          curl -fsSL -o /tmp/godot.zip \\"https://github.com/godotengine/godot/releases/download/$GODOT_VERSION/Godot_v${GODOT_VERSION}_linux.x86_64.zip\\"\\n          echo \\"$GODOT_SHA256  /tmp/godot.zip\\" | sha256sum -c\\n          unzip -q /tmp/godot.zip -d /tmp/godot\\n          sudo install -m 755 \\"/tmp/godot/Godot_v${GODOT_VERSION}_linux.x86_64\\" /usr/local/bin/godot\\n      - name: Verify assets, import and run GUT tests\\n        run: bash tools/test.sh\\n"}')
for rel,content in payload.items():
 p=ROOT/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(content,encoding='utf-8')
(ROOT/'source_assets/SHA256.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
# Do not accidentally include editor caches, imports generated during checks or build output.
for folder in ['godot/.godot','godot/build']:
 p=ROOT/folder
 if p.exists():shutil.rmtree(p)
subprocess.run([sys.executable,'tools/validate_assets.py'],check=True)
print('Standalone Godot layout prepared; preserved',len(manifest),'asset/source files')
