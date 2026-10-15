"""Package a locally built APK together with its exact corresponding sources."""
import gzip
import hashlib
import json
from pathlib import Path
import re
import shutil
import zipfile

from release_sources import create_sources

root = Path(__file__).resolve().parent.parent
apk = root / 'build/app/outputs/flutter-apk/app-release.apk'
manifest = json.loads((root / 'assets/engine/manifest.json').read_text())
version = re.search(r'^version:\s*([^+\s]+)', (root / 'pubspec.yaml').read_text(encoding='utf-8'), re.M)[1]
with zipfile.ZipFile(apk) as package:
    abis = {n.split('/')[1] for n in package.namelist() if n.startswith('lib/')}
    if abis != {'arm64-v8a', 'x86_64'}:
        raise SystemExit(f'Unexpected APK architectures: {abis}')
    for abi in abis:
        if f'lib/{abi}/libanxin_pikafish.so' not in package.namelist():
            raise SystemExit(f'Missing engine for {abi}')
    network = package.read('assets/flutter_assets/assets/engine/pikafish.nnue')
    if hashlib.sha256(network).hexdigest() != manifest['network_sha256']:
        raise SystemExit('APK NNUE does not match the pinned manifest.')
    notices = gzip.decompress(package.read('assets/flutter_assets/NOTICES.Z'))
source = create_sources(root, version)
destination = root / 'artifacts' / f'anxin-xiangqi-android-{version}.zip'
standalone = destination.with_suffix('.apk')
shutil.copyfile(apk, standalone)
with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as package:
    package.write(standalone, standalone.name)
    package.write(source, source.name)
    package.write(root / 'LICENSE', 'LICENSE.txt')
    package.write(root / 'THIRD_PARTY_NOTICES.md', 'PROJECT_THIRD_PARTY_NOTICES.md')
    package.write(root / 'assets/engine/manifest.json', 'ENGINE-MANIFEST.json')
    for license_file in sorted((root / 'licenses').rglob('*')):
        if license_file.is_file():
            package.write(license_file, license_file.relative_to(root).as_posix())
    package.writestr('THIRD_PARTY_NOTICES.txt', notices)
    package.writestr('使用说明.txt', (
        '安心象棋 Android 离线试用版\n\n'
        f'将 {standalone.name} 传到 Android 10 或更新的 64 位设备后安装。\n'
        '当前为开发签名试用包，尚未完成真机验收。\n'
        '默认执红，新开局可选执黑。点棋子再点落点，可悔棋、提示、翻转和回看。\n'
        '全部棋力在本机运行，不需要账号或联网。\n\n'
        f'组合应用采用 GPL-3.0-or-later，完整对应源码与模型在 {source.name}。\n'
        '再次分发请一并提供许可、通知和对应源码。\n'
    ).encode('utf-8'))
with zipfile.ZipFile(destination) as package:
    if package.testzip() is not None:
        raise SystemExit('Android package integrity check failed.')
for path in (destination, standalone):
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    path.with_suffix(path.suffix + '.sha256').write_text(f'{digest}  {path.name}\n', encoding='ascii')
    print(f'{path}\nSHA256 {digest}')
