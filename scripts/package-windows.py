"""Package an existing Flutter Windows Release, including readable notices."""
import hashlib
import gzip
from pathlib import Path
import re
import zipfile
import json
from release_sources import create_sources

root = Path(__file__).resolve().parent.parent
release = root / 'build/windows/x64/runner/Release'
if not (release / 'anxin_xiangqi.exe').is_file():
    raise SystemExit('Run flutter build windows --release first.')
if not (release / 'anxin_pikafish.dll').is_file():
    raise SystemExit('The native engine is missing from the bundle.')
manifest = json.loads((root / 'assets/engine/manifest.json').read_text())
network = release / 'data/flutter_assets/assets/engine/pikafish.nnue'
if not network.is_file() or hashlib.sha256(network.read_bytes()).hexdigest() != manifest['network_sha256']:
    raise SystemExit('The bundled NNUE does not match the pinned manifest.')
version = re.search(r'^version:\s*([^+\s]+)', (root / 'pubspec.yaml').read_text(encoding='utf-8'), re.M)[1]
destination = root / 'artifacts' / f'anxin-xiangqi-windows-{version}.zip'
destination.parent.mkdir(parents=True, exist_ok=True)
source_bundle = create_sources(root, version)
instructions = f'''安心象棋

把整个压缩包解压到一个文件夹，双击 anxin_xiangqi.exe 打开。
请保留同一文件夹中的其他文件和 data 文件夹。

默认执红先走，新开局可选择执黑。点自己的棋子，再点标出的可走位置。
“悔一步”会回到您上次落子前。“重新开始”会请您确认。
不需要登录，也不需要联网。程序自动保存，重新打开可继续。
右侧工具可以单独滚动。“使用设置”可调大文字、开启落子前确认和减少动效。
“放大棋盘”中仍能下棋；滚轮上下移动，拖动底部滚动条左右移动棋盘。
键盘按 Tab 进入棋盘，用方向键移动蓝框，回车或空格选子、落子，Esc 取消选择。
“回看棋局”可点走棋记录跳转，查看中文着法和吃子说明，不改变当前棋局。
点“复制完整棋谱”后，可粘贴到记事本自行保存；复制的是打开回看时的整盘记录。
“我的棋局”可查看、改名、收藏和继续旧盘，也可点“保存本局”主动保存当前进度。
重新开始或继续旧盘前会先保存当前盘；若保存失败，棋盘会保留并提示。
棋谱只在这台设备上，删除前会确认。程序保留上一份棋谱库文件作为备份。

这是 {version} 离线试用版。五档本地 Pikafish 陪练，可提示、翻转和回看。
长将长捉要求违规方变着。尚未完成长辈实用性与竞赛规则全量验证。

程序按 GPL-3.0-or-later 开源，对应源码及模型见包内 {source_bundle.name}。
再次分发时请一并提供许可、通知和对应源码；构建说明在源码 README/docs/ENGINE.md。
'''
with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as archive:
    for source in sorted(release.rglob('*')):
        if source.is_file():
            if not source.resolve().is_relative_to(release.resolve()):
                raise ValueError(f'Release entry points outside build directory: {source}')
            archive.write(source, source.relative_to(release).as_posix())
    archive.write(root / 'LICENSE', 'LICENSE.txt')
    archive.write(source_bundle, source_bundle.name)
    archive.write(root / 'THIRD_PARTY_NOTICES.md', 'PROJECT_THIRD_PARTY_NOTICES.md')
    archive.write(root / 'assets/engine/manifest.json', 'ENGINE-MANIFEST.json')
    for license_file in sorted((root / 'licenses').rglob('*')):
        if license_file.is_file():
            archive.write(license_file, license_file.relative_to(root).as_posix())
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
