# 原版研究：天天象棋 4.4.6.2

本页保留第一轮 APK 静态研究，其中“当前产品”是当时状态。第二轮公开前端分析见 [DEMO2-RESEARCH.md](DEMO2-RESEARCH.md)，登录后的网页实测见 [WINDOWS-RESEARCH.md](WINDOWS-RESEARCH.md)；公开引擎现已接入产品，见 [ENGINE.md](ENGINE.md)。Android 原版安装后行为仍未实测。

日期：2026-10-15（Asia/Shanghai）。本轮完成静态清单、Java 类/方法与引擎边界研究，未运行原版游戏。可公开结论进入此文档；样本、提取文件与完整 Evidence 留在忽略目录。

## 样本身份

| 项目 | 观察 |
| --- | --- |
| 用户提供路径 | `tiantian-xiangqi/base.apk.1` |
| 大小 | 198,461,318 字节 |
| SHA-256 | `39f5f0e162f3d5ca47b98180f1fa9592e9f623fd4f692990291da5cd94a0acf4` |
| 包名 / 显示名称 | `com.tencent.qqgame.xq` / 天天象棋 |
| 清单版本 | `4.4.6.2`，versionCode `404060022` |
| SDK 声明 | minSdk 24，targetSdk 33，compileSdk 34 |
| 主启动 Activity 声明 | `com.tencent.gcloud.msdk.core.policy.MSDKPolicyActivity` |
| 外层 APK 原生 ABI | `arm64-v8a` |
| 签名检查 | Android build-tools 35 的 `apksigner verify --print-certs` 返回成功；证书 SHA-256 为 `e90191dc5d8003de2d9ac023231c5953950ea654eedffa9b38de7ca23fffbb70` |

包名与版本来自清单。证书 DN 自报腾讯；本轮没有独立的官方证书基准，不能仅凭 DN 声称已验证官方来源。

`.apk.1` 经 REA 判为普通 ZIP。为使用 Android 路由，创建了内容相同的私有副本 `research/private/target.apk`，重新检查得到相同 SHA-256。没有改动用户原文件。

## 工具与范围

- REA 上游：https://github.com/morluto/rea；克隆于相邻 `rea-tools`，commit `4692bb33300c7cb77b095b6cc0c33da861c1b860`，工作树保持干净。
- 实际运行 REA CLI `6.5.0`，安装于工作区 `.toolchains/rea-cli`；使用可移除的 Node `24.11.0`，校验过 Node 官方 SHA-256。全局 Node 20 未替换。
- JADX 提供者：`jadx-headless-mcp 0.7.1`，JAR SHA-256 `6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75`，与 REA 固定元数据一致；使用本机 JDK 21，每个工作进程堆上限 1536 MiB。
- 使用 CLI，未注册或修改用户 MCP 配置。读取了上游 REA skill、Android 工作流及实际 CLI 帮助。
- `aapt`、`apksigner` 和自有 Python ZIP/DEX/ELF 脚本作为补充观察；它们的结果不冒充 REA Evidence。

## 主要发现与设计影响

### R1：Cocos 业务层与原生 Android 层共存

`assets/src/settings.json` 声明 `CocosEngine: 3.8.8`；外层包包含 3 个 DEX、`libcocos.so`、2 个明文 JavaScript 启动文件，以及多处 `.jsc` 脚本。主要脚本成员 `assets/assets/scripts/index.jsc` 大小 2,907,920 字节，尚未解码。

REA Android 图谱给出 Dalvik/ART、JavaScript、native 三类运行时提示。这是文件路径与格式推断，不是已观察到的运行时调用图。不能仅凭 `.jsc` 扩展名确定具体加密、压缩或字节码格式。

**设计影响：**不必把复现项目也做成 Cocos。保留 Flutter 的双端棋桌；后续研究 UI 行为应追踪 Cocos 入口或实际界面，不能只读 Android Activity。

### R2：Pikafish Java 与 native 边界已对应

包内存在 `lib/arm64-v8a/libpikafishso.so`（756,952 字节）和 `assets/pikafish.nnue`（34,345,726 字节）。ELF 动态符号表的 JNI 导出与 JADX 的 `com.pikafish.androidso.PikafishUtils` 方法清单相符：

| 方法 | Java 描述 | native 地址 |
| --- | --- | --- |
| `engineRun` | `(String) → void` | `0x31074` |
| `getReply` | `() → String` | `0x31008` |
| `startEngine` | `() → void` | `0x31004` |
| `stopEngine` | `() → void` | `0x31000` |
| `stringFromJNI` | `() → String` | `0x30f90` |

地址属于这个 ELF 的分析虚拟地址，不是 Windows 进程地址。JADX 对类静态初始化器返回完整 smali，确认其加载名称为 `pikafishso` 的库。库内还观察到 UCI、`position fen`、`bestmove`、`EvalFile` 等文本。静态文本本身不证明某种模式在运行时采用了这些指令。

### R3：已读到一条具体的 AI 工作线程链路

REA/JADX 的静态引用把 `PikafishUtils` 指向 `com.tencent.qqgame.Utils.AIManager` 和 `PAIRunable`。定向方法恢复得到：

1. `AIManager.sendPAI(String, String, String)` 创建工作线程，传入操作编号 2 和至多三条字符串。
2. `PAIRunable.run()` 通过 `ENGINE_LOCK` 串行化引擎操作。操作 0 调用启动方法，准备模型文件，设置 `EvalFile`，设置 `Hash` 为 16，再发送 `isready`。
3. 操作 2 依次转发第一条命令及非空的第二、第三条命令；操作 1 调用停止方法。
4. `AIManager.copyNetFiles()` 检查应用私有目录中的网络文件；不存在时先复制为临时文件，再重命名为 `pikafish.nnue`。

这比“包里有一个同名库”的证据更具体：Java 层确实包含对应调用实现。它仍是**静态恢复**，不证明启动条件、用户模式、具体命令内容、异常分支可达性或调用次数。

**设计影响：**未来通过 `AiEngine` 接入公开引擎，管理初始化、模型准备、串行命令、异步回复、停止与清理。沿用本项目已有的过期请求失效机制。原版的 `Hash=16` 是引擎缓存配置，不等于某个难度档。

### R4：原型与强棋力路线分开交付

当前产品仍使用自研轻量 AI，能够完全离线运行。后续优先研究公开 [Pikafish](https://github.com/official-pikafish/Pikafish) 的 UCI/NNUE 适配，避免从 APK 复制 native 库或模型。

官方仓库标注 GPLv3。接入前核对具体版本、模型来源、构建方法、发布许可与对应源码交付方式；当前的 MIT 自有代码说明不代表未来包含引擎的整个发行包都只有 MIT。没有引入 Pikafish 依赖，也没有改变本项目许可。

## 可追溯 Evidence

下列原始 JSON 位于 `research/private/`，未进入 Git。长 ID 用于复验，不是对外托管链接。

| 文件 | Evidence ID / 用途 |
| --- | --- |
| `rea-apk.json` | `ev_c0afd8a8162fbc88aade96eb9137f36535b3b443dffb395f1dee899e3ee87bac`，APK 检查 |
| 内含 inventory 子证据 | `ev_33e0a0c731ea183c29e268eb4468dcde5acd3e57555ee20fb0c1f939574afd95`，清单 |
| `rea-android-graph.json` | `ev_51eb23da399d395bafe7dc97f5aec3bc8f9fcdcb05d06cbf7764420f266cdab2`，Android 图谱 |
| `rea-pikafish-class.json` | `ev_a0f65bb2f25146f83003008c9e7aaa62bdc4793466e423964c4f6bb9b4bfccfb`，方法签名 |
| `rea-pikafish-clinit.json` | `ev_e0af1a0c9e9927293a0cffd6825c0964a83342d6922026dd4e5168f7d19539f0`，库加载 |
| `rea-pikafish-references.json` | `ev_f52457fd9c78c686f0198d9fcbcf8a4575452e0f309ecb747cc3f6fbb687ab41`，静态 using-node 引用 |
| `rea-pai-run.json` | `ev_ede0c4bbd1c0398779b5f821371b810b844eb29796bcc1d08487711272ef63c4`，初始化与命令分发 |
| `rea-send-pai.json` | `ev_839f5b51099e83237669bf97843eb8df1ba2254e549f91a46814bb761e3a0ab3`，工作线程入口 |
| `rea-copy-nets.json` | `ev_e84cb0f41db3057d3fa177d5dde216009099b3094c115ba51df029ff0cb905d5`，模型文件准备 |

清单有大小写折叠冲突提示，Windows 上没有进行盲目的全包解压；仅提取明确选择的条目。图谱中的桥接候选属于路径推断，不能与后续 JADX 的具体静态引用混为一谈。ZIP 清单看不到 APK Signing Block；签名观察另由 apksigner 提供。

## 复验入口

通用元数据脚本（Python 标准库，不执行 APK）：

```powershell
python scripts/inspect-apk.py tiantian-xiangqi/base.apk.1
```

REA 常规命令如下。先选择支持的 Node、REA 6.5.0、校验过的 JADX JAR 和完整 JDK 17+；本工作区缓存位于相邻 `.toolchains`。参数以所用发布版帮助为准。

```powershell
rea inspect-artifact research/private/target.apk --format json --full-output
rea inspect-android-class research/private/target.apk com.pikafish.androidso.PikafishUtils
rea trace-android-references research/private/target.apk com.pikafish.androidso.PikafishUtils
rea inspect-android-method research/private/target.apk com.tencent.qqgame.Utils.PAIRunable run --overload-index 0
```

完整输出写到忽略目录，不提交反编译源码。可公开的研究文档只保留行为描述、签名、摘要与证据索引。

## 尚未回答

- `.jsc` 的实际表示与具体 Cocos 调用入口。
- 原版每个难度的搜索深度、时间、棋力限制或随机策略。
- 用户选子、落点反馈、悔棋与结束提示的实际交互。
- 原版棋局保存格式、保存时机、退出/来电恢复。
- 这套引擎在何种原版模式下被调用，是否有其他引擎路径。
- 原版比赛规则和长将长捉裁决实现。

后续先围绕这些问题补证据，不扩展到账号、服务端协议或支付系统。
