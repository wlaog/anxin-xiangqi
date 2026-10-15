# 第三方来源

第二版组合应用按 GPL-3.0-or-later 发布；第一版 MIT 声明保留于 `licenses/anxin-0.1-MIT.txt`，第三方内容保留各自许可。

- Windows / Android 工程脚手架由 Flutter 3.47.7 生成，模板启动图标暂时保留。Flutter 的 BSD 许可见 `licenses/flutter-LICENSE.txt`，源项目为 https://github.com/flutter/flutter 。
- Flutter / Dart 与 `shared_preferences` 等运行依赖以 `pubspec.lock` 记录。Windows 便携包包含 Flutter 生成的 `data/flutter_assets/NOTICES.Z`，并附其解压后的可读 `THIRD_PARTY_NOTICES.txt`；重新打包用 `scripts/package-windows.py` 保留这些通知。
- REA 是相邻目录的独立开发工具（MIT），未被打包进游戏。来源与实际版本见 `docs/RESEARCH.md`。
- 原版 APK、反编译输出、原版素材和原版模型仅留在忽略的研究目录，不是本项目发行内容。
- 公开 [Pikafish](https://github.com/official-pikafish/Pikafish) 已作为本地引擎与裁决器引入，固定提交与 NNUE SHA-256 见 `assets/engine/manifest.json`。GPLv3-or-later 许可见 `vendor/pikafish/Copying.txt`，作者见其 `AUTHORS`。便携包附完整对应源码与同一模型，不需要腾讯文件。
- Pikafish 的公开模型训练数据归属说明见固定版本上游 README：Pika Xiangqi Zero 数据采用 [ODbL](https://opendatacommons.org/licenses/odbl/)。模型来自上游 Networks 仓库，不是本项目自行训练。来源与构建限制见 `docs/ENGINE.md`。
- 原创木纹由 imagegen 生成，提示词与用途见 `assets/art/README.md`。系统字体不随包分发。
- MinGW-w64/GCC 的编译器运行库静态进入原生 DLL，其 GPL Runtime Library Exception / MinGW 许可材料随源码及便携包保留于 `licenses/mingw/`。Flutter 的 Windows 外壳仍由 Visual Studio 构建。
- Android 原生库通过 NDK r28c 编译，APK 随附 libc++_shared；NDK 与 LLVM 的许可/异常条款原文保留于 `licenses/android-ndk/` 并进入发行包。
