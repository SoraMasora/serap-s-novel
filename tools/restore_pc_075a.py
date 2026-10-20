#!/usr/bin/env python3
"""Restore and verify the PC 0.7.5a runtime resource overlay."""
import base64, hashlib, io, json, pathlib, tarfile
ROOT = pathlib.Path(__file__).resolve().parents[1]
PACK = ROOT / "backup/pc_075a_runtime"
data = b"".join(base64.b64decode(p.read_bytes()) for p in sorted(PACK.glob("part*.b64")))
if hashlib.sha256(data).hexdigest() != (PACK / "SHA256").read_text().strip():
    raise SystemExit("Archive SHA256 mismatch")
with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
    archive.extractall(ROOT, filter="data")
manifest = json.loads((PACK / "MANIFEST.json").read_text())
for rel, expected in manifest.items():
    if hashlib.sha256((ROOT / rel).read_bytes()).hexdigest() != expected:
        raise SystemExit("File SHA256 mismatch: " + rel)
print("Restored and verified", len(manifest), "PC 0.7.5a resources")
