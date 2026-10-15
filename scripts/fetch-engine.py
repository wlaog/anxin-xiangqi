"""Prepare the exact public NNUE. Runtime never downloads anything."""
import hashlib
import json
from pathlib import Path
import urllib.request

root = Path(__file__).resolve().parent.parent
manifest = json.loads((root / 'assets/engine/manifest.json').read_text())
target = root / 'assets/engine/pikafish.nnue'

def valid(path):
    return path.is_file() and path.stat().st_size == manifest['network_bytes'] and hashlib.sha256(path.read_bytes()).hexdigest() == manifest['network_sha256']

if not valid(target):
    temporary = target.with_suffix('.download')
    urllib.request.urlretrieve(manifest['network_url'], temporary)
    if not valid(temporary):
        temporary.unlink()
        raise SystemExit('Upstream network changed or download corrupted. Expected pinned SHA-256; refusing replacement.')
    temporary.replace(target)
print(f'NNUE verified: {manifest["network_sha256"]}')
