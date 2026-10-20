#!/usr/bin/env python3
"""Verify that preserved game resources and source assets are present and unchanged."""
import hashlib, json, pathlib, sys
root = pathlib.Path(__file__).resolve().parents[1]
manifest = json.loads((root / "source_assets/SHA256.json").read_text())
errors = []
for relative, expected in manifest.items():
    path = root / relative
    if not path.is_file():
        errors.append("Missing: " + relative)
    elif hashlib.sha256(path.read_bytes()).hexdigest() != expected:
        errors.append("Changed: " + relative)
if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print("Verified", len(manifest), "preserved resource/source files")
