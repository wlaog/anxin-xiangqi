"""Corresponding sources shared by both offline release packages."""
import hashlib
import json
import subprocess
import zipfile


def create_sources(root, version):
    def git(*args):
        return subprocess.check_output(['git', '-C', str(root), *args])

    if git('status', '--porcelain').strip():
        raise SystemExit('Commit reviewed source changes before creating a release.')
    manifest = json.loads((root / 'assets/engine/manifest.json').read_text())
    network = root / 'assets/engine/pikafish.nnue'
    if hashlib.sha256(network.read_bytes()).hexdigest() != manifest['network_sha256']:
        raise SystemExit('Source NNUE does not match the pinned manifest.')
    destination = root / 'artifacts' / f'anxin-xiangqi-source-{version}.zip'
    destination.parent.mkdir(parents=True, exist_ok=True)
    sources = git('ls-files', '--recurse-submodules', '-z').decode('utf-8').split('\0')
    with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name in sorted(set(sources) - {''}):
            path = root / name
            if path.is_file():
                archive.write(path, f'anxin-xiangqi/{name}')
        archive.write(network, 'anxin-xiangqi/assets/engine/pikafish.nnue')
        archive.writestr('anxin-xiangqi/SOURCE-INFO.json', json.dumps({
            'application_commit': git('rev-parse', 'HEAD').decode().strip(),
            'engine_commit': manifest['engine_commit'],
            'network_sha256': manifest['network_sha256'],
        }, indent=2))
    return destination
