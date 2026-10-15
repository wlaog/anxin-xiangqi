# 验证记录

日期：2026-10-15（Asia/Shanghai）。

## Windows 0.6.0 离线练习 Demo

分支 `feat/offline-learning-demo`，版本 `0.6.0+6`。报告建议的八项功能各有可操作的演示流程，范围见 [演示说明](DEMO-0.6.md)；不是完整题库、完整棋谱格式兼容或整份报告的正式产品验收。只做本地提交、Windows 构建与打包，不推送或发布，Android 仍暂停。

- `flutter test --no-pub --reporter expanded`：完整 **101 项通过**，其中新增 16 项；最后完整测试日志为忽略的 `artifacts/study-all-tests.log`。包含全部原有真实 Pikafish / NNUE 回归，以及 13 道自有小题的真实原生合法着法、目标终局、局面与坐标导出导入、变着分支和自定义局面建议检查。两道镜像残局在说明中明示，未把题数当作独立战术类型数。
- 领域与存储检查：非法将帅、仕相、兵卒、棋子数量、照面和计数拒绝；分支前缀复用、回退换路和完整研究往返；非法后续、重复节点、分支环、未知格式及过长文字拒绝；错题、练过状态串行更新；写失败不提交、重试恢复；坏档保留。练习笔记使用真实临时目录检查备份、重开、第二实例外部修改拒绝覆盖；与 0.5 共用同一文件存储实现。
- 界面检查：实盘入口、答错保持棋盘、错题再练、答对保存、回退保留两条路线、保存与继续研究、完整分支剪贴板导出导入、导入失败保留当前研究、简洁复盘、摆棋错误与成功、覆盖草稿取消及写失败重试、关闭研究后迟到建议不改实盘。360×800 与 640×360 使用 2.8 倍文字检查选题、提示、摆棋、导入取消和返回。剪贴板和失败通道用替身，未冒充真实系统剪贴板全量验收。
- `flutter analyze --no-pub` 最终无问题；初次检查中类型、模式表达式、导入与大括号 lint 已修正。早期用例把“无棋可走”全当成“将军”，已改为分别检查真实将军状态；另修正了嵌套弹窗测试定位到下层返回按钮的漏验，最终用例明确确认复盘已关闭。
- `cmake -S tool/audio_smoke -B artifacts/audio-smoke -G "Visual Studio 17 2022" -A x64` 和 Release 构建实际运行，通过同一生产 `audio_output.cpp` 检查三种提示音、普通话 SAPI 请求和非法类型拒绝，全部返回成功。结果在忽略的 `artifacts/audio-smoke-result.txt`；此检查证明 API 接受请求，不证明人耳听到或音色适宜。异步播放内存保留与语音清队列使用微软文档规定的生命周期，参考 [PlaySound](https://learn.microsoft.com/it-it/previous-versions/dd743680%28v%3Dvs.85%29) 和 [ISpVoice::Speak](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/ee125024%28v%3Dvs.85%29)。
- 已用 computer-use 启动真实 Release 程序，打开“练习与研究”，选择“双车封住宫门”，实际点击红车完成题目，看到完成提示和 1/13 进度，再返回原有执黑实盘，棋盘保持原样；在真实设置中调用了提示音、中文报棋试听，均显示成功返回。本次验收留下这一道示例练习进度，没有删除原棋局。发现试听结果在设置弹窗后面后，将状态移至弹窗内，并用界面故障注入测试检查错误提示确实出现在设置弹窗中。最终构建再次打开真实设置、试听报棋并滚动查看，已确认成功提示位于弹窗内；本次启动的窗口均已关闭。
- `ANXIN_PREVIEW_FONT=C:/Windows/Fonts/msyh.ttc` 下运行 `flutter test tool/study_preview_test.dart --no-pub --reporter expanded`：1 项通过。目视检查桌面残局、编辑器、分支，以及窄屏和横屏大字共 5 幅预览；都在忽略的 `artifacts/previews/windows-study-*.png`。这些文件是 Flutter 测试渲染，实际程序另由上面的 GUI 检查验证；本机字体未打包。
- `flutter build windows --release --no-pub` 成功，EXE 的 FileVersion / ProductVersion 为 `0.6.0+6`。`python -m py_compile scripts/package-windows.py`、`git diff --check` 通过。引擎源码、模型和原有陪练预算没有替换；新增研究建议请求使用已有第三档预算。
- 在代码提交 `b5d7e3f5f637045687cc015c902dc40909d089a8` 的干净工作树上实际运行 `python scripts/package-windows.py`，生成 Windows 便携包及完整对应源码。独立核对两个 ZIP 的 CRC、包内源码 ZIP 与单独源码 ZIP 字节一致、38 个 `lib/` 和 Windows 宿主源码与工作区一致、EXE/DLL 与最终构建一致、两包 NNUE 与固定清单一致；确认源码不含原 APK、提取脚本、私有研究、个人产物或签名材料。摘要在忽略的 `artifacts/study-package-verification.json`，包内 `SOURCE-INFO.json` 记录上述代码提交。
- `artifacts/anxin-xiangqi-windows-0.6.0.zip`：119705541 字节，SHA-256 `68d84dc9603c71f3451286087f127dcdb8c0ec33d9ca0580304915d484a8c795`。`artifacts/anxin-xiangqi-source-0.6.0.zip`：53759237 字节，SHA-256 `7dd6b2646f9039613baabcf567f15513f3f83b74e289200802a8016f08ba2874`。两包旁均有 `.zip.sha256`；后续本节文档提交不改变已打包代码身份。

仍未完成：长辈实际试用、听感与音量验收、真实 Narrator / 全部 DPI / 干净系统验证、完整人工对弈、断电和进程强杀恢复、全部棋谱格式互通及 Android 真机验收。自由研究须手动保存，Demo 只有一个保存位置；多窗口保护拒绝覆盖，不合并。复盘没有引擎评分或失误诊断，13 题都是一步任务，没有多步课程或自动应手的完整残局闯关。原版 APK 本轮未重新运行或补做逆向。

## Windows 0.5.0 本地棋谱库

分支 `feat/offline-game-library`，版本 `0.5.0+5`。本轮实现报告中的第一项本地多盘棋谱库；原创残局和声音辅助尚未实现。未推送、打标签或发布 Release，Android / SDK 工作仍暂停。

- 最终 `flutter analyze --no-pub` 无问题。最终 `flutter test --no-pub --reporter expanded`：完整 **85 项通过**，含原有真实 Windows Pikafish / NNUE、棋规及键盘交互回归。最后一轮日志保存在忽略的 `artifacts/library-tests-final.log`。
- 新增 21 项测试：库的串行保存、改名收藏与多盘重开；损坏条目和重复身份隔离保留；整个库损坏时禁止覆盖；写失败不提交内存；新局前保存失败保留当前盘；旧存档稳定身份迁移；保存中迟到 AI；棋规非法棋谱不能继续；终局归档；延迟终局写入不能覆盖悔棋后离开的最终记录；当前续局保存失败时仍可独立归档。
- 真实文件检查覆盖主文件与上一份备份、主文件缺失时恢复、主文件损坏时不静默回滚、路径被目录占用时替换失败仍保留备份，以及第二个库实例检测外部变化后拒绝覆盖。不是完整断电、进程强杀或所有文件系统故障注入；没有宣称多窗口编辑可以自动合并。
- 新增真实原生工作流：使用固定 Pikafish / NNUE 下完一轮、自动保存旧盘、重放裁决、继续旧盘并核对原生合法走法。引擎源码、模型和搜索预算未替换。其余失败注入用可控存储和裁决替身，未冒充真实磁盘故障或原生引擎失败。
- 新增界面检查覆盖真实棋桌入口、回看不改实盘、改名收藏、删除取消及确认、继续旧盘前保存当前盘；360×800、640×360 均以系统 200% 叠加应用 1.4 倍文字检查滚动、改名、删除确认和返回；120 份棋谱按可见范围构建，首屏 Card 少于 10 个；手动保存失败可重试。
- `ANXIN_PREVIEW_FONT=C:/Windows/Fonts/msyh.ttc` 下实际运行 `flutter test tool/library_preview_test.dart --no-pub --reporter expanded`：1 项通过。目视核对 `windows-library.png`、`windows-library-narrow.png`、`windows-library-landscape.png`，统一放大新界面的删除和取消按钮。截图为 Flutter 测试渲染，不是 Windows 人工使用截图，字体不随包发行。
- 最终 `flutter build windows --release --no-pub` 成功；构建 EXE 的 FileVersion 与 ProductVersion 均为 `0.5.0+5`。本轮没有启动最终 GUI 做人工完整对局，也未进行真实 Narrator、干净系统、长辈试用或 Android 验收。
- `python -m py_compile scripts/package-windows.py`、`git diff --check` 通过。代码提交 `11f37fa69e8087ff4a85bec254c6c568638d3787` 后实际运行 `python scripts/package-windows.py`，生成本地 0.5.0 Windows 便携包与完整对应源码。两个 ZIP 的 CRC 检查通过；包内源码 ZIP 与单独源码 ZIP 字节一致；全部 `lib/` 源码与已提交工作区一致；EXE/DLL 与最终构建一致；两包 NNUE 哈希与固定清单一致；源码不含原 APK、私有研究目录或签名材料。
- 便携包 `artifacts/anxin-xiangqi-windows-0.5.0.zip`，SHA-256：`8edca190555f87ea25fdcd33dd178243a514e4e976dfe32fe1c309fb9fe3e55f`。源码包 `artifacts/anxin-xiangqi-source-0.5.0.zip`，SHA-256：`f6f715b06e5f1f0395cfd5d8fe99e99b8100103dda8d0d8ab4fcebc1c84f0c43`。旁边各有校验文件；`library-package-verification.json` 为本地检查摘要。包内 `SOURCE-INFO.json` 指向上述代码提交，本节后续文档记录不改变已打包源码身份。

## APK 功能差距报告

本次为文档与静态研究，游戏版本保持 `0.4.0+4`。报告见 [功能对比与适老化建议](APK-FUNCTION-GAP-REPORT.md)，Word 版保存在忽略的本地 `artifacts/reports/`。

- 全部 54 个 `.jsc` 解码成功，经过嵌入长度、GZIP CRC32 / ISIZE 与 UTF-8 校验；再次核对全部解码文件的大小和 SHA-256 与清单一致。主脚本由 Babel 语法解析并索引出 2866 个命名模块；没有执行目标脚本。
- REA 整文件分析触及隔离工作进程堆限制，保留部分结果后改为四个问题范围。39 个模块、561901 字节均解析成功；训练与棋谱应用图为 complete，分析与联网应用图为 partial，四组语义关系均有 unknown。完整 10 条 Evidence 已导出到 `research/private/apk-comprehensive/rea-evidence-bundle.json`。
- 68 个 bundle 中的 1190 个场景或预制体索引项已解析，处理同名不同类型及跨 bundle 重定向；独立回查 88887 个字面字段的 JSON 指针与原始成员值一致。此检查不证明运行可达、动态组件、默认值或自定义反序列化语义完整。
- Word 共 15 页、3 张表、37 项功能比较。DOCX ZIP CRC、正文与 Markdown 的逐段逐单元格一致性检查通过。标题使用黑色 Title 样式，清除继承的装饰线；表格跨页重复表头。
- 已调用技能的 `render_docx.py`，因本机没有 LibreOffice `soffice.exe` 失败。使用已安装 Microsoft Word 的 COM 导出 PDF，再用受管 Poppler 渲染 140 DPI 页面 PNG，逐页目视检查全部 15 页；最终措辞修改仅改变第 13 页，重新渲染并复查该页。PDF、PNG 与构建辅助脚本只保留在私有研究目录。Word COM 的 PowerShell 退出曾阻塞，已清理本次创建的隐藏实例；最终使用 VBScript 完成打开、导出和正常退出。
- 最终 Word SHA-256：`8a0dde899d94734e9ffb18269580c5b3d58929cec4186f1e8e4f9ff2ae15b3b4`。数据与文档检查摘要保存在私有 `report-verification.json`。
- 未安装运行原 APK、未访问其账号或服务器、未修改游戏代码，也未重跑 Flutter 测试、构建或打包。原版运行可用性、实际离线范围、当前活动开放状态、完整原生语义与手机体验仍未验证；适老化优先级为设计建议，未冒充长辈试用结论。

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
