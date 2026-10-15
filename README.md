# 安心象棋

给长辈的一张清楚、安静、随时能接着下的棋桌。开源、离线、人机对弈，目标平台为 Windows 与 Android。

## 当前阶段

本项目处于离线原型阶段，以中国象棋玩法和面向长辈的使用需求独立实现。已经对用户提供的天天象棋 `4.4.6.2` APK 完成第一轮 REA/JADX 静态研究，确认 Cocos 配置及本地 Pikafish 调用链；尚未恢复 `.jsc` 业务脚本或实测原版 UI。具体证据和局限见 [研究记录](docs/RESEARCH.md)。

技术采用 Flutter / Dart，规则、AI、界面共用。REA 是开发时的分析工具，不是游戏引擎，也不进入应用运行依赖。删除或移走相邻的 `rea-tools` 后，本项目仍应能独立构建。

已实现：用户执红与本地 AI 对弈，三档陪练，大字棋盘、合法落点、将军和终局提示，悔棋与新局确认，本地自动保存及重放恢复。坏档保留到用户明确重新开始，保存失败有文字提示。当前 20 项自动测试通过，包括初始局面三层走法计数和 AI 思考期间的悔棋/重开。

当前工作区可直接试用 [Windows 便携包](artifacts/anxin-xiangqi-windows-0.1.0.zip)：完整解压后双击 `anxin_xiangqi.exe`。也可查看 [桌面预览](artifacts/previews/windows.png) 和 [手机尺寸预览](artifacts/previews/android.png)。这些本地产物不进入 Git。Windows Release 已构建并通过启动检查；安心象棋 Android APK 尚未生成，本机 NDK 安装不完整，见 [验证记录](docs/VALIDATION.md)。

## 开发与运行

安装稳定版 Flutter，然后在本目录运行：

当前开发验证版本为 Flutter **3.47.7 / Dart 3.13.5**，依赖解析见已提交的 `pubspec.lock`。

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
# 安卓：连接开启 USB 调试的手机，先用 flutter devices 查看设备编号
flutter run -d <设备编号>
```

```powershell
flutter build windows --release
flutter build apk --release
```

Windows 构建后，可运行 `python scripts/package-windows.py` 生成便携包、使用说明、MIT 许可、可读第三方通知及 SHA-256 校验文件。

Windows 需要 Visual Studio 的“使用 C++ 的桌面开发”工作负载；安卓需要 Android SDK、相应 JDK、构建工具和已接受的 SDK 许可。用 `flutter doctor -v` 查看缺项。安卓正式发布前必须自行配置发布签名；开发签名构建不是商店发布包。

本工作区另有临时 SDK：`..\.toolchains\flutter\bin\flutter.bat`。这只是本机便利路径，不是项目依赖，也不应提交到本仓库。

若 Windows 报 `Building with plugins requires symlink support`，可以启用 Windows 开发者模式；也可在首次 `pub get` 已解析好依赖后执行本项目的局部替代方案：

```powershell
.\scripts\prepare-windows-plugins.ps1
flutter build windows --release --no-pub
```

脚本只在项目的生成目录创建目录联接，不修改系统设置。依赖变化导致插件目录重建后，需要重新执行。安卓 SDK 未自动识别时，在当前 PowerShell 设置 `$env:ANDROID_HOME` 指向自己的 SDK，并用 `$env:JAVA_HOME` 选择合适的 JDK，不要照抄其他机器的绝对路径。

可选本机界面预览：设置 `ANXIN_PREVIEW_FONT` 指向有权使用的中文字体文件，运行 `flutter test tool/preview_test.dart --no-pub`，生成 `artifacts/previews/` 下的桌面和手机尺寸 PNG。它不是原生设备截图。

## 产品约定

- 打开即进入棋桌；默认执红先行。AI 全部在本机运行，不需要账号或 API 密钥。
- 大字、高对比、文字按钮；点棋子再点落点，不要求拖动或精确双击。
- 无倒计时催促；提供合法落点提示、悔棋、重新开始与自动续局。
- 默认保留棋局，不把失败、误触或退出变成惩罚。
- 规则正确性优先于 AI 棋力。原型 AI 只用于休闲陪练，不宣称大师水平。

详细内容见 [产品需求](docs/PRODUCT.md)、[技术方案](docs/ARCHITECTURE.md)、[任务清单](docs/ROADMAP.md)、[验证记录](docs/VALIDATION.md)、[REA 调研流程](docs/RESEARCH.md)。后续代理请先读 [AGENTS.md](AGENTS.md)。

## 开源与来源

本项目自有代码采用 MIT 许可证，见 [LICENSE](LICENSE)。依赖保留各自许可。棋盘与棋子由代码绘制，使用系统中文字体；不打包腾讯名称、图标、美术、声音、棋谱库或反编译代码。原 APK、提取物及完整研究输出放在 Git 忽略目录。Pikafish 尚未接入产品；其公开版本标注 GPLv3，接入时需确定对应发布许可、源码交付与模型来源，不能沿用“全包只有 MIT”的表述。

上游工具：[morluto/rea](https://github.com/morluto/rea)。Flutter 平台文档：[Windows](https://docs.flutter.dev/platform-integration/windows/building)、[Android](https://docs.flutter.dev/platform-integration/android/setup)。
