# 第四轮：从 APK 的棋谱界面声明改进离线棋桌

日期：2026-10-15（Asia/Shanghai）。本轮继续优先 Windows，不恢复 Android / SDK 工作。

## 本轮问题与样本

问题是：原版包内如何组织走棋记录、逐步回看与棋谱操作？其中哪些设计适合安心象棋的离线棋桌？

原样本仍为 `tiantian-xiangqi/base.apk.1`，198,461,318 字节，SHA-256：

`39f5f0e162f3d5ca47b98180f1fa9592e9f623fd4f692990291da5cd94a0acf4`

本轮重新计算原文件和旧私有 `target.apk` 的摘要，两者一致。版本、清单和第一轮 Java / native 引擎边界可复用 [RESEARCH.md](RESEARCH.md)，未把旧结果冒充本轮重新反编译。此前网页运行证据仍单独保留在 [WINDOWS-RESEARCH.md](WINDOWS-RESEARCH.md)。

## 实际研究与可追溯位置

- 当前助手实际通过 REA 6.5.0 MCP 的 `open_binary` 打开原文件，并调用 `inspect_artifact` 的摘要视图。`.apk.1` 按 ZIP 路由检查，记录 5,172 个包成员；这是归档清单，不是 Android 功能验证。
- MCP 的 JADX 未配置。复用本机已有 REA 6.5.0 CLI、JADX 0.7.1 JAR 与完整 JDK 21，在子进程中设置提供者参数；没有重新安装工具或改用户 MCP 配置。
- 原 APK 未安装、未执行，没有发起登录、服务器请求或设备操作。
- 用独立 Python 标准库脚本读取 Cocos 资源索引和选中的合并 JSON。格式依据 [Cocos 3.8 构建说明](https://docs.cocos.com/creator/3.8/manual/en/editor/publish/build-guide.html) 与 [引擎 v3.8.8 的序列化定义](https://github.com/cocos/cocos-engine/blob/v3.8.8/cocos/serialization/deserialize.ts)。仅解释 v1 的类型表、属性掩码、分组节和已存字面量；不实例化类、不调用自定义反序列化器，也不执行脚本。

完整 REA Evidence、资源字面量与 JSON 指针在忽略目录 `research/private/apk-round4/`。Python 的结果不是 REA Evidence。

| 证据 | ID / 私有文件 |
| --- | --- |
| 本轮归档检查，完整父证据 | `ev_ba4a78f09740a8e7529601876fe9e2a5d87ea2385ea82428b335841508ac7f6b` |
| 归档摘要视图 | `ev_8cd0ee4c4d4ab34676ffb9887f6adaacc6396e9ee389ab2516027fbf64e9224b` |
| 上述 MCP 会话的完整导出 | `rea-evidence-bundle.json`，3 条记录 |
| `com.tencent.qqgame.xq.AppActivity` 类清单 | `ev_9f7ac2ead836f98a62ecd66e1a62fac1d4adbfd26b51348fbc117abc51ccf61c`，`rea-xq-app-activity.json` |
| `AppActivity.onBackPressed` 方法 | `ev_fa45c4f2235222e8cbaf049c7869fbd97923e4e182c1e55956188d39e52192ce`，`rea-on-back-pressed.json` |
| 4 个指定预制界面的资源解析 | `resource-experience.json`；每项含原成员 SHA-256、分组节、原始 JSON 指针、未解释的引用类型 |

JADX JAR 的 SHA-256 仍为 `6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75`，本次实际工作进程报告 Java 21.0.3、单 worker、1536 MiB 堆上限。

## 静态发现

`assets/assets/Bundle-QipuAI/cc.config.json` 将以下三个资源映射到 `import/04/044dd4567.json` 的分组节 0、1、2。该合并 JSON 为 110,503 字节，SHA-256：

`66f1bc344a1b475a100eae9c9ee859d15458a2741d7a0d94ce8f9b94dea7fa4c`

| 指定资源 | 实际已存声明 | 可以支持的结论 |
| --- | --- | --- |
| `QiPuAI/QiPuMoveStatisticPanelForPotrait` | `cc.Label._string` 含逐步导航与翻转文字；属性含 `m_btnPreMove`、`m_btnNextMove`、`m_btnFlip` | 包内包含将记录统计、前后步导航和棋盘朝向放在同一界面的声明 |
| `QiPuAI/QipuMenuComponent` | 标签含保存、分享、编辑、收藏、局面等棋谱操作；属性含 `m_btnSaveEdit`、`m_btnImport`；还存有点击处理方法名 | 棋谱操作在资源层被组织为独立菜单；不证明功能当前可用、免费或离线 |
| `QiPuAI/QipuStatisticsItem` | 属性含 `m_labelStepName`、`m_btnFindFen` | 存在单条着法/局面相关项的声明；默认文字与实际列表内容没有由本轮运行验证 |

复验字面量例：节 0 的 `/5/0/0/20/4/0/1`、节 1 的 `/5/1/0/86/4/0/1` 分别定位导航和保存标签。指针指向选中的原始合并 JSON，属性名从同文件类型表与掩码解出，不是靠相邻字符串猜测。

另外检查了 `Bundle-BattleBase:ChessPreviewPanel`。其实际字面量和字段围绕装扮、升级和特效预览，因此本轮不将这个名称当作对局复盘证据。对应合并 JSON 为 `assets/assets/Bundle-BattleBase/import/03/031496ba0.json`，SHA-256 `7378a265b7779d9ef6c1742ee7f2e55c5f7cb65ef946fca237aa40c26638bfc7`。

JADX 恢复的 Android 返回键方法只把调用交给 `SDKWrapper`。它没有建立棋局保存、恢复或退出确认的实现证据。本轮不据此声称原版 Android 已实现某种续局策略。

## 安心象棋的独立实现

以下为本项目设计与代码，不是复制原版脚本，也不宣称原版具有相同细节：

1. 走棋记录由走前局面和坐标走法生成，普通走法使用中文记法，附带明确起终位置及吃子说明。复杂多兵歧义保留完整位置，不冒充全部标准记谱。
2. 回看保留打开瞬间的不可变棋局快照。首步、末步、前后步和记录列表跳转使用同一份历史；回看时电脑后来完成应手不会改变这份快照。
3. 用户主动点击后可复制完整文字棋谱，便于自行保存或交流。这不是 PGN / XQF 导出，也没有新增导入、不可信棋谱解析或联网分享。
4. 棋盘增加单个 Tab 入口、可见键盘光标、方向键导航、回车/空格选子落子及 Esc 取消；翻转和放大共用同一走棋入口。键盘导航属于本项目可访问性设计，本轮没有原版 Android 键盘运行证据。
5. 电脑上一着、建议着法和键盘光标分别表达，避免把提示误认成已经走出的棋。仍保留原有可选落子确认、原创木纹与五档固定公开引擎。

功能交付与已运行检查以 [VALIDATION.md](VALIDATION.md) 为准。

## 复验与剩余未知

```powershell
python scripts/inspect-apk-experience.py tiantian-xiangqi/base.apk.1
# 可用 --asset 'Bundle:精确资源路径' 选择其他已在一个分组内的资源。
```

JADX 复验使用已准备的 REA 6.5.0、JAR 0.7.1 与完整 JDK 17+：

```powershell
rea inspect-android-class research/private/target.apk com.tencent.qqgame.xq.AppActivity --format json --full-output
rea inspect-android-method research/private/target.apk com.tencent.qqgame.xq.AppActivity onBackPressed --overload-index 0 --format json --full-output
```

本轮只读 4 个指定预制界面，解析了 4,027 个普通及嵌入对象。引用、资源依赖、自定义反序列化器、未存默认值、动态内容和处理方法可达性仍未解释；属性和字面量存在不证明运行结果。主要 `.jsc` 仍未解码；原版各难度真实参数、悔棋消耗、终局规则、安装后下载资源与续局行为仍未知。

本项目尚有独立后续工作：原创残局、正式棋谱互通格式、声音/语音、Windows 实际 Narrator / DPI / 长辈试用。原生搜索的提前取消与排队取消还需要请求身份和真实并发验证，本轮没有把 Dart 丢弃过期落子当作原生工作已停止的证明。
