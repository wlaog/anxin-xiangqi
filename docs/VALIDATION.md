# 验证记录

日期：2026-10-15（Asia/Shanghai）。

## Windows 0.4.0 本地开发版

本轮分支 `feat/apk-informed-review`，版本 `0.4.0+4`；没有推送、创建新版本标签或发布 Release。Android / SDK 工作继续暂停。

- `flutter analyze --no-pub`：最终无问题。最初发现新测试缺少大括号的一条 lint，已修正后重跑。
- `flutter test --no-pub --reporter expanded`：完整 64 项通过，包含原有真实 Windows Pikafish / NNUE 的五档搜索、一步将死、事件循环、44/1920 走法计数、长将长捉与跨实现走法验证。原生库、固定引擎与模型未替换。
- 新增领域测试 9 项：红黑朝向、平进退、前后子、复杂多兵的完整位置说明、吃子、空谱、1024 步记录、不可变快照与走前走后配对拒绝。没有宣称完整 PGN / XQF 或所有中文记谱细则。
- 新增控制器测试 12 项：先裁决后整盘提交；玩家/电脑走棋、悔棋、新局与恢复末步裁决失败保留状态；并发初始化只读取/应手一次；读取中释放；失败操作后的过期 AI 不落子。动作和存储提示分开，坏档保留、写入失败不会被成功落子清掉，成功重试写入后才解除对应警告。
- 新增界面测试 8 项，覆盖键盘选子/取消/落子、单 Tab 入口、翻转逻辑格身份、确认取消后焦点恢复与预览 Esc、放大对弈、思考中不能落子、真实上一着与建议分开、失败新局保留原朝向/建议、同一步数新局使旧建议失效。
- 回看/复制用例检查：AI 完成应手后仍显示打开时快照，回看不改实盘；首末步与列表跳转；200 步长谱只构建可见项；复制完整快照而非后来实盘；复制失败可恢复。剪贴板验证使用平台通道替身，没有冒充实际 Windows 系统剪贴板人工验收。
- 完整套件后，目视预览发现极大字窄窗口首屏主要被标题和底部操作占据。调整为短标题、充分利用宽度及简短固定操作后，重跑 `flutter test test/experience_test.dart test/widget_test.dart --no-pub --reporter expanded`：18 项通过。360×800 与 640×360 均叠加系统 200% 和应用 1.4 倍文字，保留实际 61.6 逻辑像素的正文缩放，分别检查首屏棋盘至少 99% / 75% 可见，导航和返回可达；点击着法只定位外层棋盘，保留内层列表位置。
- 最终可选 `flutter test tool/preview_test.dart --no-pub --reporter expanded`：1 项通过，使用本机中文字体与原创木纹。目视核对桌面双栏回看、选子/应手反馈及 `windows-review-narrow-large-text.png`；窄屏首屏可见完整棋盘，固定“复制”“返回”保留完整辅助功能标签。截图是 Flutter 测试渲染，字体未随包发行。
- 最终 `flutter build windows --release --no-pub` 成功，EXE 的 FileVersion / ProductVersion 均为 `0.4.0+4`。本轮没有启动最终 GUI 做人工完整对局。
- `python scripts/inspect-apk-experience.py tiantian-xiangqi/base.apk.1` 成功；原样本与旧私有 APK 摘要相同。解析 4 个选定预制界面的 4,027 个对象，并逐项核对 535 个字面量 JSON 指针与原始成员的值一致。REA MCP 归档检查与 CLI / JADX 定向证据见 [第四轮 APK 研究](APK-EXPERIENCE.md)。没有运行原版 Android APK。
- `python -m py_compile scripts/inspect-apk-experience.py scripts/package-windows.py`、`git diff --check` 通过；相邻 `rea-tools` 工作树未修改。
- 本地 `python scripts/package-windows.py` 已实际生成 0.4.0 Windows 便携包和完整对应源码。脚本校验便携 ZIP；另检查源码 ZIP 的 CRC、包内源码与单独源码 ZIP 字节一致、EXE/DLL 与最终构建一致、两个包内 NNUE 摘要与固定清单一致，并检查源码未包含原 APK / 从 APK 提取的脚本 / 私有研究目录。`SOURCE-INFO.json` 记录最终打包时的实际 Git 提交；校验值位于本地 `.zip.sha256`。

本地产物为 `artifacts/anxin-xiangqi-windows-0.4.0.zip`、`artifacts/anxin-xiangqi-source-0.4.0.zip`，以及 `build/windows/x64/runner/Release/anxin_xiangqi.exe`；产物、原 APK 和完整原始研究数据均未提交。

仍未验证：实际 Windows 系统剪贴板、物理键盘 / Narrator、DPI、干净系统、断网人工完整对局及长辈试用。原版 `.jsc` 未解码，安装后各模式、真实难度参数、悔棋消耗和续局仍未知。原生搜索在尚未开始或排队时可能丢失取消、全局引擎复用首个模型配置，为源码推导的后续工作，未声称运行复现或本轮修复。原有 Android 设备验收限制继续有效。

## Windows 0.3.0

本轮按用户要求暂停 Android / SDK 工作，未生成 0.3.0 Android 包，未把共用代码测试当作安卓实机验收。

- `flutter analyze --no-pub`：无问题。
- `flutter test --no-pub`：35 项通过，含真实 Windows Pikafish / NNUE 的五档搜索、一步将死、事件循环与长将长捉回归。
- 设置随 v2 存档保存，缺失或局部损坏的设置不丢弃合法棋局；重开仍保留偏好。
- 新增落子确认测试：确认前不走棋、取消保留选择、确认后电脑应手、棋局被替换后旧确认失效。
- 新增系统 200% 字号叠加应用 1.4 倍文字的设置及确认流程；360×800 可完成操作且无溢出。
- 放大棋盘支持选子和对弈，放大/缩小及返回不改变棋局；最小棋格 60 逻辑像素，支持双向滚动。
- 最终桌面滚动调整后，重跑 10 项界面测试全部通过；其中放大对弈和 640×360 大字测试显式使用 `TargetPlatform.windows`。手动滚动条关闭其局部默认滚动条，避免 Windows 重复滚动条。
- Windows 模式预览测试 1 项通过，使用本机中文字体与预加载原创木纹生成棋桌、设置、确认、放大视图并目视核对。预览是测试渲染，不是设备人工对弈截图；字体未打包。本轮预览脚本只更新 Windows 图片。
- 最终 `flutter build windows --release --no-pub` 成功；EXE 文件版本为 `0.3.0+3`。隐藏启动最终产物，5 秒内保持运行，随后仅关闭该测试进程。这是启动检查，不是完整人工对局验收。
- `python -m py_compile scripts/package-windows.py`、`git diff --check` 通过。便携包脚本要求干净 Git、校验打包模型 SHA-256、附完整对应源码并验证 ZIP；源码内 `SOURCE-INFO.json` 记录实际提交。
- 原版网页已实测人机开局、选子、电脑应手、局内设置和退出确认，公开行为规格和 REA 证据索引见 [WINDOWS-RESEARCH.md](WINDOWS-RESEARCH.md)。个人截图和原始记录保留在 Git 忽略目录。

Windows 0.3.0 在 `feat/windows-3` 分支完成，标签 `v0.3.0` 对应提交 `fef0a26`；历史 `v0.1.0`、`v0.2.0` 保留。源码发布位置为 [wlaog/anxin-xiangqi](https://github.com/wlaog/anxin-xiangqi)，主分支 `main`。按用户追加授权发布 [v0.3.0 Release](https://github.com/wlaog/anxin-xiangqi/releases/tag/v0.3.0)：Windows 便携 ZIP、完整对应源码 ZIP、`SHA256SUMS.txt`。上传前核对标签/源码身份、两个 ZIP 完整性和包内对应源码一致性，上传后核对远端大小与 GitHub 返回的 SHA-256；没有修改既有版本标签。发布说明见 [v0.3.0.md](releases/v0.3.0.md)。便携包仍以包内对应源码和 `SOURCE-INFO.json` 为准。

仍须完成：Windows 干净系统与运行库验证、实际显示 DPI 缩放、Narrator / 键盘、完整断网人工对局与长辈试用；原创残局练习、棋谱导出、声音 / 语音未实现。最高难度原版运行链路、悔棋/提示消耗、终局和退出续局仍未知。以下记录为第二版历史，不表示本轮继续了安卓工作。

## 第二版当前验证

- `flutter analyze --no-pub`：无问题。
- `flutter test --no-pub`：28 项通过，包含真实原生引擎/NNUE，而非仅模拟 AI。
- 原生 GCC 14.2.0 构建成功；DLL 静态链接编译器运行库，导入仅有 KERNEL32/msvcrt/SHELL32。
- 原生 44/1920 走法计数，长将/长捉变着、正常应将、允许循环和棋、270 个半回合的跨实现走法比较通过。
- 五档真实搜索都返回合法走法；一步将死通过；事件循环可继续运行。
- 控制器验证执黑首着、悔棋边界、五档/执棋方存档恢复、AI 失败重试、提示不代走；保留旧的过期结果/坏档回归。
- 界面验证窄屏、桌面、横屏 200% 文字，无溢出；提示、翻转、回看不修改棋局通过。
- 重新生成并目视核对原创木纹、棋字及桌面/手机尺寸预览。字体与纹理预加载后截图，字体未打包；仍不是设备实测。
- `flutter build windows --release --no-pub`：成功。构建产物隐藏启动，5 秒内保持运行后关闭；这是启动检查，不是人工完整对弈。最终小幅选子状态修复后重跑 5 项界面验证并再次构建。
- NDK r28c 完整下载，按 [Android 官方历史下载页](https://github.com/android/ndk/wiki/Unsupported-Downloads#r28c) 的 748,118,221 字节与 SHA1 `086bba43ff2f5eb0e387b15c8278bb4e0d89ba1d` 核验，已补齐原不完整安装，`source.properties` 为 28.2.13676358。没有删除其他 SDK 内容。
- 已用 SDK 原有许可补齐 Build-Tools 36、Platform 36/35 与 CMake 3.22.1。修复 Flutter 预填 ABI 列表残留 armeabi-v7a 的配置错误：先清空，再只加 arm64-v8a/x86_64。
- 修复 Kotlin 增量缓存无法跨 C: Pub 缓存与 D: 项目路径相对化的问题，项目内设置 `kotlin.incremental=false`，不移动用户缓存。
- `flutter build apk --release --target-platform android-arm64,android-x64 --no-pub` 成功，最终增量构建约 49.8 秒。APK 约 93.4 MB（89.1 MiB），版本 0.2.0 / code 2，minSdk 29 / targetSdk 36。
- ZIP 内容核验仅有两种 64 位 ABI，两者均含原生引擎及 libc++；随包 50,241,100 字节 NNUE 的 SHA-256 与清单一致；release 未声明 INTERNET 权限。AndroidX 自动生成的应用内 signature 级接收器权限仍在。
- `apksigner verify --verbose`：签名验证通过，v2 签名，当前为开发签名；`zipalign -c -P 16 4` 通过。两种引擎 ELF 的 PT_LOAD 对齐均为 16,384 字节；仍未在 16 KB 页设备实测。
- 本轮建立独立 API 35 测试 AVD，未复制用户原 AVD 的用户数据。模拟器日志曾报告冷启动完成，但多次无法通过 ADB 列出/连接设备，因此**没有安装原版或安心象棋到该模拟器，没有安卓 UI/模型加载/对弈实测通过记录**。测试模拟器和独立 ADB 服务在结束时关闭，私有日志保留。
- 两端本地发行包均包含对应源码、固定子模块源码、同一 NNUE、许可与来源通知，打包脚本检查干净 Git 状态、模型哈希和 ZIP 完整性。包体与源码不进 Git；校验值在 `artifacts/*.sha256`，源码内 `SOURCE-INFO.json` 记录对应提交。

Git：第一版保留为 `v0.1.0`，第二版使用 `feat/demo-2` 分支，固定引擎子模块；未发布远端仓库。

复杂竞赛裁决、低端手机预算、入门档难度、系统辅助功能和长辈试用仍待验证。不能把以下第一版记录当作第二版设备验收。

## 第一版历史记录

## 已执行

| 检查 | 实际结果 |
| --- | --- |
| `flutter analyze --no-pub` | 无问题 |
| `flutter test --no-pub` | 20 项通过 |
| 规则计数 | 初始局面 1/2/3 层分别为 44 / 1920 / 79666，与公开 [perft 原始讨论](https://talkchess.com/viewtopic.php?t=76430) 中的计数一致 |
| 棋规边界 | 兵过河、马腿、象眼、象不过河、炮架、九宫、送将、将帅照面、将死与困毙、休闲和棋 |
| 控制器 | 交替落子、成对悔棋、AI 思考中重开/悔棋、存档重放、轮到 AI 的中断恢复、坏档保留、保存失败、真实 isolate AI |
| 界面 | 360×800、1280×800、640×360，200% 文字缩放无溢出；点选走子、悔棋、新局取消/确认 |
| `flutter test tool/preview_test.dart --no-pub` | 1 项通过，生成并目视检查桌面 1280×800 与手机 412×915 PNG；修复中文按钮字体与窄屏重复信息 |
| `flutter build windows --release --no-pub` | 成功，生成 `build/windows/x64/runner/Release/anxin_xiangqi.exe` |
| Windows 启动检查 | 隐藏启动构建产物，5 秒内保持运行，随后关闭；这不是手工完整对弈验证 |
| `python scripts/package-windows.py` | 成功，ZIP 完整性检查通过，包含程序、使用说明、MIT 许可与可读第三方通知 |
| `python scripts/inspect-apk.py tiantian-xiangqi/base.apk.1` | 成功，生成私有 SHA-256、ZIP/DEX/ELF 与桥接方法记录 |
| REA 6.5.0 + JADX 0.7.1 | APK 清单、Android 图谱、类/引用/定向方法检查成功，详见 RESEARCH.md |
| 项目 skill 验证 | `quick_validate.py .agents/skills/xiangqi-research` 通过 |

工具链：Flutter 3.47.7 / Dart 3.13.5；Visual Studio Enterprise 2022 17.13.3；Windows SDK 10.0.26100.0。研究侧另用 Node 24.11.0 与本机 JDK 21。

## 本地产物

- `artifacts/anxin-xiangqi-windows-0.1.0.zip`。
- SHA-256：`11acdbcb856ad1865e9b5399ed915c842ae6dc986936291ece8ab28eb8034e61`，旁边另有 `.zip.sha256` 文件。
- `artifacts/previews/windows.png` 与 `android.png`：Flutter 测试渲染，使用本机中文字体，**不是安卓设备截图**，字体未打包。
- `research/private/`：原 APK 的同内容副本、提取文件及完整工具输出，全部被 Git 忽略。

## 第一版 Android 构建失败（第二版已修复）

已找到并复用 `E:\IDE\Android` SDK、Android Studio JDK 21；Gradle 9.3.1 的 ZIP 已下载并按官方 SHA-256 验证。包装器改用同版本较小的 bin 分发，并固定校验值。

实际执行了 `flutter build apk --release --no-pub`，在配置 `:app` 时失败：

```text
[CXX1101] NDK at E:\IDE\Android\ndk\28.2.13676358
did not have a source.properties file
```

本次依赖准备产生了不完整的 NDK 安装目录（当前仅 `.installer`）及 SDK `.temp` 中的部分下载。没有把它标记为安装完成，也未删除该 SDK 目录。后续应先确认没有安装任务运行，再修复/重新安装同版本 NDK；不要覆盖其他已有 NDK。还需让 SDK 管理器补齐构建实际要求的平台与工具，随后重跑构建。

因此当时没有安心象棋 Android APK。第二版已修复工具链并生成 APK，见本页开头；Android 真机验收仍未完成。release 暂用开发签名。

## 发布前仍须完成

Windows 干净系统/运行库验证、安卓真机安装、两端断网完整对局、退出/后台/进程被杀续局、Narrator/TalkBack、系统缩放、低端机耗时/发热/内存，以及长辈试用。Pikafish 长将长捉变着已接入，复杂竞赛题库仍待扩大。原版 Android UI 尚未实测；后续网页登录后的观察见本页顶部第三轮链接。
