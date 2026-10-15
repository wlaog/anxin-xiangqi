# 第三方来源

本项目自有实现采用 MIT；第三方内容保留各自许可。

- Windows / Android 工程脚手架由 Flutter 3.47.7 生成，模板启动图标暂时保留。Flutter 的 BSD 许可见 `licenses/flutter-LICENSE.txt`，源项目为 https://github.com/flutter/flutter 。
- Flutter / Dart 与 `shared_preferences` 等运行依赖以 `pubspec.lock` 记录。Windows 便携包包含 Flutter 生成的 `data/flutter_assets/NOTICES.Z`，并附其解压后的可读 `THIRD_PARTY_NOTICES.txt`；重新打包用 `scripts/package-windows.py` 保留这些通知。
- REA 是相邻目录的独立开发工具（MIT），未被打包进游戏。来源与实际版本见 `docs/RESEARCH.md`。
- 原版 APK、反编译输出、原版素材和原版模型仅留在忽略的研究目录，不是本项目发行内容。
- 公开 Pikafish（GPLv3）当前仅被研究和评估，没有作为产品依赖引入。
