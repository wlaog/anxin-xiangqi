# 安心象棋

给长辈的一张清楚、安静、随时能接着下的棋桌。开源、离线、人机对弈，目标平台 Windows 与 Android。

## 第二版进度

- 原创榆木纹棋盘、木质棋子、大字、明确选子与落点反馈，无账号、广告、付费或遥测。
- 公开 Pikafish + NNUE 本地搜索，五档预算、开局候选变化；提示不代走。
- 长将/长捉由引擎识别责任并要求变着，取消第一版的笼统三次重复和棋。
- 执红/执黑、成对悔棋、翻转棋盘、逐步回看、自动续局；兼容第一版存档，AI 失败可重试。
- 固定引擎 Git 子模块和模型 SHA-256，项目与相邻 REA 工具独立。组合应用按 GPL-3.0-or-later 发布。

本地 Windows 便携包目标为 `artifacts/anxin-xiangqi-windows-0.2.0.zip`，完整解压后运行 `anxin_xiangqi.exe`。实际构建、检查和 Android 状态以 [验证记录](docs/VALIDATION.md) 为准。预览在 `artifacts/previews/`，属于 Flutter 测试渲染，不能替代设备实测。

原版 APK 的静态研究、网页运行截图、公开前端模块的证据与未知项见 [第一轮研究](docs/RESEARCH.md) 和 [第二轮研究](docs/DEMO2-RESEARCH.md)。REA 是反编译/分析工具集，不是游戏引擎；游戏运行不需要 REA。APK 不能独自证明安装后全部资源和线上功能，网页目前只实测到登录界面。

## 构建与运行

开发验证版本：Flutter 3.47.7 / Dart 3.13.5、Windows x64 MinGW-w64 GCC 14.2.0（引擎）、Visual Studio 2022（Flutter 外壳）。普通 Git 克隆需要递归子模块；源码发行包已内含上游源码。

```powershell
git submodule update --init --recursive
python scripts/fetch-engine.py
.\scripts\build-native.ps1 -Compiler 'g++.exe' -Make 'mingw32-make.exe'
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter run -d windows --no-pub
flutter build windows --release --no-pub
# 提交核对过的源码后打包，包内包含对应源码和同一模型
python scripts/package-windows.py
```

引擎模型在开发准备阶段下载并校验，随应用打包，运行时不联网。详细预算、裁决口径、平台要求与失败处理见 [ENGINE.md](docs/ENGINE.md)。首次运行的模型加载开销不包括在单步搜索预算中，低端手机仍需校准。

Android 工程共用 Dart/原生源码，支持 arm64-v8a 和 x86_64，最低 Android 10。需完整 Android SDK 36、NDK 28.2.13676358、CMake 3.22.1 与 JDK 21；准备好后 `flutter build apk --release --no-pub`。当前 release 配置使用开发签名，正式发行前应配置自有签名。

Windows 如遇插件符号链接权限问题，在依赖解析完成后运行 `.\scripts\prepare-windows-plugins.ps1`，再用 `--no-pub` 构建。脚本只创建项目生成目录中的目录联接，不修改系统设置。本工作区的 `..\.toolchains\flutter\bin\flutter.bat` 是临时工具路径，不是项目依赖。

可选预览：设置 `ANXIN_PREVIEW_FONT` 指向本机有权使用的中文字体文件，运行 `flutter test tool/preview_test.dart --no-pub`。字体不随包发布。

## 产品边界

保留一个清楚的棋桌，不照搬线上应用的账号、排行、商城和社交。提供大触控文字按钮、无限时、提示、悔棋与续局；小屏九列棋盘仍需实机适老化测试。当前难度名称未做 Elo/腾讯段位映射，规则采用固定 Pikafish 与本项目变着策略，未宣称与腾讯或全部竞赛条款完全一致。

后续主要任务：安卓设备完整验证、长辈试用、入门档校准、复杂长捉题库、残局练习、棋谱导出、语音和可选落子确认。联机另立需求。

设计及开发文档：[需求](docs/PRODUCT.md)、[架构](docs/ARCHITECTURE.md)、[任务清单](docs/ROADMAP.md)、[协作约定](AGENTS.md)。

## 开源与来源

第二版组合应用采用 [GPL-3.0-or-later](LICENSE)，保留第一版 MIT 声明及第三方各自许可，见 [来源通知](THIRD_PARTY_NOTICES.md)。发行包包含对应源码、引擎源码和同一 NNUE。原创木纹的生成提示词见 `assets/art/README.md`；中文使用系统字体。

原 APK、提取素材、反编译产物及私人棋局不进入 Git，也不进入发行包。本项目没有打包腾讯代码、美术、声音或模型。工具来源：[morluto/rea](https://github.com/morluto/rea)；引擎来源：[official-pikafish/Pikafish](https://github.com/official-pikafish/Pikafish)。