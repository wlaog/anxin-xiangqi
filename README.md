# 安心象棋

给长辈的一张清楚、安静、随时能接着下的棋桌。开源、离线、人机对弈，目标平台 Windows 与 Android。

源码仓库：[wlaog/anxin-xiangqi](https://github.com/wlaog/anxin-xiangqi)，主分支 `main`。下载与更新说明见 [GitHub Releases](https://github.com/wlaog/anxin-xiangqi/releases)。

## 本轮本地开发：0.4.0

基于用户提供的 APK 补充棋谱界面的静态研究，新增中文走棋记录、带着法列表的逐步回看、首末步与点选跳转、复制完整文字棋谱，以及方向键 / 回车 / 空格 / Esc 的棋盘操作。电脑上一着与建议着法分别标记；回看保留打开时的快照，不改实盘。裁决失败时整盘保持原状，恢复失败保留原档。

本轮仍优先 Windows。分支 `feat/apk-informed-review`；此版本未推送、未发布 Release，下面的 0.3.0 仍是已发布下载版。APK 原始证据和提取结果不进 Git；新增研究及局限见 [第四轮 APK 研究](docs/APK-EXPERIENCE.md)，实际检查见 [验证记录](docs/VALIDATION.md)。文字棋谱可粘贴保存，未实现 XQF / PGN 等格式互通或棋谱导入。

## 当前 Windows 版：0.3.0

当前优先完善 Windows，Android / SDK 工作暂停。新增可保存的大字设置、可选落子确认、减少动效、放大棋盘中继续对弈及桌面侧栏独立滚动。放大视图棋格至少 60 逻辑像素，可拖动滚动条查看整盘；文字放大不会挤压棋子字形。

下载试用：[Windows 0.3.0 便携包](https://github.com/wlaog/anxin-xiangqi/releases/download/v0.3.0/anxin-xiangqi-windows-0.3.0.zip)。完整解压后运行 `anxin_xiangqi.exe`，不要直接在压缩包里运行。右侧工具可单独滚动，“使用设置”中调整文字、确认和动效，“放大棋盘”中可继续下棋。Windows 包附同版本完整对应源码和 NNUE。

开发与再分发可单独下载 [完整对应源码](https://github.com/wlaog/anxin-xiangqi/releases/download/v0.3.0/anxin-xiangqi-source-0.3.0.zip)，内含引擎子模块源码和同一模型；两个压缩包的校验值见 [SHA256SUMS.txt](https://github.com/wlaog/anxin-xiangqi/releases/download/v0.3.0/SHA256SUMS.txt)。不要把 GitHub 自动生成、缺少子模块和模型的 “Source code” 归档当作完整离线源码包。

本地历史安卓产物仍为 [0.2.0 APK](artifacts/anxin-xiangqi-android-0.2.0.apk) 与 [含源码发行包](artifacts/anxin-xiangqi-android-0.2.0.zip)，仅在本地 `artifacts/`，未上传 GitHub。它们尚未通过设备安装对弈验收，不代表 0.3.0 安卓已交付。

## 已有离线能力

- 原创榆木纹棋盘、木质棋子、大字、明确选子与落点反馈，无账号、广告、付费或遥测。
- 公开 Pikafish + NNUE 本地搜索，五档预算、开局候选变化；提示不代走。
- 长将/长捉由引擎识别责任并要求变着，取消第一版的笼统三次重复和棋。
- 执红/执黑、成对悔棋、翻转棋盘、中文走棋记录与可跳转回看、复制完整文字棋谱、自动续局；兼容第一版存档，AI 与裁决失败可重试。
- 棋盘单个 Tab 入口，方向键按屏幕方向移动蓝框，回车/空格走棋，Esc 取消选择；与放大棋盘共用。
- 固定引擎 Git 子模块和模型 SHA-256，项目与相邻 REA 工具独立。组合应用按 GPL-3.0-or-later 发布。

实际检查与限制见 [验证记录](docs/VALIDATION.md)。`artifacts/previews/` 中的棋桌、设置、确认和放大视图是 Flutter 测试渲染，未冒充 Windows 人工对弈截图。

原版 APK 静态研究见 [第一轮研究](docs/RESEARCH.md)，公开前端模块见 [第二轮研究](docs/DEMO2-RESEARCH.md)，扫码登录后的人机开局、选子应手、局内设置和退出确认见 [第三轮实测](docs/WINDOWS-RESEARCH.md)。REA 是反编译/分析工具集，不是游戏引擎；游戏运行不需要 REA。APK 不能独自证明安装后全部资源和线上功能；网页也不能替代 Android 安装后观察。

## 构建与运行

开发验证版本：Flutter 3.47.7 / Dart 3.13.5、Windows x64 MinGW-w64 GCC 14.2.0（引擎）、Visual Studio 2022（Flutter 外壳）。普通 Git 克隆需要递归子模块；源码发行包已内含上游源码。

```powershell
git clone --recurse-submodules https://github.com/wlaog/anxin-xiangqi.git
cd anxin-xiangqi
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
python scripts/package-android.py
```

引擎模型在开发准备阶段下载并校验，随应用打包，运行时不联网。详细预算、裁决口径、平台要求与失败处理见 [ENGINE.md](docs/ENGINE.md)。首次运行的模型加载开销不包括在单步搜索预算中，低端手机仍需校准。

Android 工程共用 Dart/原生源码，支持 arm64-v8a 和 x86_64，最低 Android 10。需完整 Android SDK 36、NDK 28.2.13676358、CMake 3.22.1 与 JDK 21；准备好后 `flutter build apk --release --target-platform android-arm64,android-x64 --no-pub`。当前 release 配置使用开发签名，正式发行前应配置自有签名。Windows 跨盘 Pub 缓存触发的 Kotlin 路径错误通过项目内 `kotlin.incremental=false` 处理。

Windows 如遇插件符号链接权限问题，在依赖解析完成后运行 `.\scripts\prepare-windows-plugins.ps1`，再用 `--no-pub` 构建。脚本只创建项目生成目录中的目录联接，不修改系统设置。本工作区的 `..\.toolchains\flutter\bin\flutter.bat` 是临时工具路径，不是项目依赖。

可选预览：设置 `ANXIN_PREVIEW_FONT` 指向本机有权使用的中文字体文件，运行 `flutter test tool/preview_test.dart --no-pub`。字体不随包发布。

## 产品边界

保留一个清楚的棋桌，不照搬线上应用的账号、排行、商城和社交。提供大触控文字按钮、无限时、提示、悔棋与续局；小屏九列棋盘仍需实机适老化测试。当前难度名称未做 Elo/腾讯段位映射，规则采用固定 Pikafish 与本项目变着策略，未宣称与腾讯或全部竞赛条款完全一致。

后续优先 Windows 长辈试用、实际 Narrator / DPI 验证、入门档校准、复杂长捉题库、原创残局练习、棋谱格式互通与语音辅助，以及原版更多交互补证据。安卓设备验证待恢复该方向后继续；联机另立需求。

设计及开发文档：[需求](docs/PRODUCT.md)、[架构](docs/ARCHITECTURE.md)、[任务清单](docs/ROADMAP.md)、[协作约定](AGENTS.md)。

## 开源与来源

第二版组合应用采用 [GPL-3.0-or-later](LICENSE)，保留第一版 MIT 声明及第三方各自许可，见 [来源通知](THIRD_PARTY_NOTICES.md)。发行包包含对应源码、引擎源码和同一 NNUE。原创木纹的生成提示词见 `assets/art/README.md`；中文使用系统字体。

原 APK、提取素材、反编译产物及私人棋局不进入 Git，也不进入发行包。本项目没有打包腾讯代码、美术、声音或模型。工具来源：[morluto/rea](https://github.com/morluto/rea)；引擎来源：[official-pikafish/Pikafish](https://github.com/official-pikafish/Pikafish)。
