# 验证记录

日期：2026-10-15（Asia/Shanghai）。

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

Windows 干净系统/运行库验证、安卓真机安装、两端断网完整对局、退出/后台/进程被杀续局、Narrator/TalkBack、系统缩放、低端机耗时/发热/内存，以及长辈试用。Pikafish 长将长捉变着已接入，复杂竞赛题库仍待扩大。原版 Android UI 尚未实测，网页运行观察仅到登录界面。
