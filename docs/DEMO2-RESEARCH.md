# 第二轮：运行观察与公开脚本

日期：2026-10-15。研究工具仍为 REA 6.5.0 CLI，不把 CLI 使用描述为 MCP 已连接。

本页为第二轮历史记录。后续用户扫码后的真实人机对局、设置和退出行为见 [WINDOWS-RESEARCH.md](WINDOWS-RESEARCH.md)。

## 实际运行观察

REA `capture-browser-scenario` 使用本机 Edge、独立临时配置、已知起始地址 `https://h5login.qqchess.qq.com/`，等待 25 秒，记录截图、URL、DOM、无障碍树和有预算限制的网络事件。没有操作用户原来的已登录 Edge 标签页，也未复制其 cookies。

最终画面为木色背景、红色“将”字、微信/QQ 登录入口、条款勾选区。棋盘由 Cocos canvas 承载；DOM/无障碍树不能直接给出棋子控件。未登录，没有验证登录后的玩法或任何收费功能，也没有替用户勾选条款。

证据：`ev_74af748e5b62194c23faefb73bf7aaa333be6234325eefd862ac428dd53389db`，私有文件 `research/private/demo2/web-settle.result.json` 与 `web-settled.png`。事件采集存在预算遗漏，不是完整流量记录；浏览器由提供者在结束后关闭。

## 公开脚本的定向分析

从页面实际请求取得 `assets/scripts/index.2f7fc.js`，12,723,521 字节，SHA-256 `e325ae021b522b38baa790446a42cc31e4c24402d12370c60906191be92204a5`。命名 `System.register` 模块清单包含 2,865 项。用 Babel AST 选出六个完整模块调用再交给 REA 静态分析，未执行这些代码。

REA 证据：`ev_54897a08f10aa50184deb4ab06bd126bc699d98333dbbf6e8eba3f2056e4f5f6`，完整结果 `research/private/demo2/web-analysis.json`。抽取区间为 JS 字符偏移，不当作网络原始字节偏移：

| 模块 | 区间（左闭右开） | 发现 |
| --- | --- | --- |
| AIEngine.js | 342702–610598 | 浏览器侧象棋搜索实现线索 |
| AIEngineProxy.ts | 610960–618554 | 引擎代理层 |
| AILevels.ts | 620341–623988 | 九档难度名；默认深度 2/3/4/5/7/9/12/18/25；可从配置改用节点数/深度，并有随机增深逻辑 |
| AIManager.ts | 623990–663571 | 对局 AI 调度入口 |
| AIPFManager.ts | 663573–672028 | Pikafish 协议、worker 和资源准备分支 |
| AIZoneSelecteScene.ts | 687316–692128 | 人机区域选择入口 |

`AIPFManager` 中观察到浏览器分支通过 `fetch` 获取 worker、WASM 与 NNUE 资源的地址，以及小程序/原生的不同桥接分支。这证明包内代码包含动态取资源的设计；**不证明当前登录页已经执行这些分支，也不证明 Android 版具体下载了同样的资源**。公开网页版本与 APK 4.4.6.2 不能直接混为一个版本。

## 对产品的影响

APK 足以研究包内引擎和桥接，但不足以还原完整线上应用：还需要安装后资源、远端配置和实际交互证据。网站能补充公开前端线索，不能替代 Android 真机观察。

本项目采用公开 [Pikafish](https://github.com/official-pikafish/Pikafish)，固定子模块提交与公开 NNUE 的 SHA-256，不复用 APK 中的引擎二进制、模型、贴图或业务代码。原版多档难度的实现线索支持“调整搜索预算”的方向，安心象棋的五档预算独立设计，不映射腾讯段位、不宣称等同腾讯棋力。

素材改用原创木纹加程序绘制；原版木质质感是观察参考，产品仍围绕大字、清晰落点、悔棋、续局、离线使用。账号、排行榜、支付、社交与在线赛事不纳入离线版本。
