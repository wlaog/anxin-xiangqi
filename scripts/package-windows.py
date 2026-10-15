"""Package an existing Flutter Windows Release, including readable notices."""
import hashlib
import gzip
from pathlib import Path
import re
import zipfile

root = Path(__file__).resolve().parent.parent
release = root / 'build/windows/x64/runner/Release'
if not (release / 'anxin_xiangqi.exe').is_file():
    raise SystemExit('Run flutter build windows --release first.')
version = re.search(r'^version:\s*([^+\s]+)', (root / 'pubspec.yaml').read_text(encoding='utf-8'), re.M)[1]
destination = root / 'artifacts' / f'anxin-xiangqi-windows-{version}.zip'
destination.parent.mkdir(parents=True, exist_ok=True)
instructions = f'''安心象棋

把整个压缩包解压到一个文件夹，双击 anxin_xiangqi.exe 打开。
请保留同一文件夹中的其他文件和 data 文件夹。

您执红先走。点自己的棋子，再点有圆点的位置。
“悔一步”会回到您上次落子前。“重新开始”会请您确认。
不需要登录，也不需要联网。程序自动保存，重新打开可继续。

这是 {version} 离线原型，陪练仅供休闲，尚未完成长辈实用性验证。
'''
with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as archive:
    for source in sorted(release.rglob('*')):
        if source.is_file():
            if not source.resolve().is_relative_to(release.resolve()):
                raise ValueError(f'Release entry points outside build directory: {source}')
            archive.write(source, source.relative_to(release).as_posix())
    archive.write(root / 'LICENSE', 'LICENSE.txt')
    archive.writestr('使用说明.txt', instructions.encode('utf-8'))
    notices = release / 'data/flutter_assets/NOTICES.Z'
    if notices.is_file():
        archive.writestr('THIRD_PARTY_NOTICES.txt', gzip.decompress(notices.read_bytes()))
with zipfile.ZipFile(destination) as archive:
    if archive.testzip() is not None:
        raise ValueError('Package integrity check failed')
digest = hashlib.sha256(destination.read_bytes()).hexdigest()
destination.with_suffix('.zip.sha256').write_text(f'{digest}  {destination.name}\n', encoding='ascii')
print(destination)
print(f'SHA256 {digest}')
