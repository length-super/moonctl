# Mooncakes 生态调查（2026-09-29）

## 范围与方法

检查了 [Mooncakes 首页](https://mooncakes.io/)及包详情，并以 `AI / agent / workflow / parser / compiler / database / web / image / crypto / testing / devtool / wasm / visualization` 等词交叉搜索。下载量是 Mooncakes 页面当时显示的累计下载数，不能等同于独立用户数；页面未显示时记为“未显示”。更新时间采用页面显示的相对时间，除非另有说明。“活跃”仅据页面更新时间及可见功能判断，不代表维护承诺。本表选取会影响选题的代表性项目，并非注册表全量快照。

| 方向 | 项目 / 作者 | 功能与可见 API | 使用情况、更新、维护判断 | 对候选方向的影响 |
| --- | --- | --- | --- | --- |
| AI / Agent / RAG | [weopqrst/agent](https://mooncakes.io/docs/weopqrst/agent) / weopqrst | `LLMChain`、`AgentExecutor`、Prompt/Memory、RAG、MCP；版本页称 13 个子包、122 项测试 | 43 下载、上月更新；有持续开发迹象 | 排除通用 Agent/RAG 框架 |
| AI 模型接口 | [QuietlyChan/moonai](https://mooncakes.io/docs/QuietlyChan/moonai) / QuietlyChan | `generate_text`、`embed`、`generate_image`；多模型、MCP、mock | 近期更新；活跃 | 排除 AI SDK 包装 |
| LLM 客户端 | [mizchi/llm](https://mooncakes.io/docs/mizchi/llm) / mizchi | 纯 MoonBit LLM client | 首页最常下载之一；活跃 | 排除 HTTP 模型客户端 |
| MCP | [colmugx/mcp](https://mooncakes.io/docs/colmugx/mcp) / colmugx | `MCPServer::tool` 等服务端/客户端接口，stdio/HTTP | 约 1K 下载，页面显示 21 天前更新；活跃 | 排除通用 MCP SDK |
| MCP | [cogna-dev/mcp-sdk](https://mooncakes.io/docs/cogna-dev/mcp-sdk) / cogna-dev | MCP SDK，文档称通过 39 项协议一致性测试 | 近期页面；活跃 | MCP 一致性基础能力也已有实现 |
| Workflow | [moonbitlang/workflow](https://mooncakes.io/docs/moonbitlang/workflow) / moonbitlang | `Workflow::agent`、并行、fan-out、journal replay | 页面约 845 下载、前日更新；活跃 | 排除多 Agent 工作流 |
| Parser / Compiler | [moonbitlang/parser](https://mooncakes.io/docs/moonbitlang/parser) / moonbitlang | MoonBit AST、lexer、LL(k)/LR parser | 约 168K 下载、昨日更新；活跃 | 排除语言解析器重建 |
| Parser generator | [moonbitlang/yacc](https://mooncakes.io/docs/moonbitlang/yacc) / moonbitlang | LR(1) parser generator | 约 103K 下载；活跃 | 排除通用生成器 |
| Database | [moonbitstack/moondb](https://mooncakes.io/docs/moonbitstack/moondb) / moonbitstack | `Driver` 与 query layer 的类型契约 | 约 63 下载、两天前更新；活跃 | 数据库抽象已出现 |
| Database | [mizchi/sqlite](https://mooncakes.io/docs/mizchi/sqlite) / mizchi | `Database::query`、预处理语句、事务 | 约 9K 下载；曾间隔数月更新 | 排除简单 SQLite binding |
| Web UI | [moonbit-community/rabbita](https://mooncakes.io/docs/moonbit-community/rabbita) / moonbit-community | 声明式组件、typed message、VDOM | 约 78K 下载、4 天前更新；高度活跃 | 排除通用前端组件框架 |
| Web API | [moonbitstack/moonapi](https://mooncakes.io/docs/moonbitstack/moonapi) / moonbitstack | 类型化路由、校验、OpenAPI、WebSocket | 近期更新；活跃 | 排除通用 Web 框架 |
| WASM | [Milky2018/wasm_component](https://mooncakes.io/docs/Milky2018/wasm_component) / Milky2018 | Component Model 解析、校验、WIT 模型 | 约 3 下载、16 小时前更新；活跃 | 排除组件模型基础解析 |
| WASM | [Milky2018/wasmoon](https://mooncakes.io/docs/Milky2018/wasmoon) / Milky2018 | Wasm 解释器/JIT、WASI、Component Model | 约 138 下载、16 小时前更新；活跃 | 排除通用 Wasm runtime |
| Image | [megemini/millow](https://mooncakes.io/docs/megemini/millow) / megemini | 纯 MoonBit 跨平台图像处理 | 约 7 下载；更新时间未显示 | 图像处理不是空白 |
| Audio | [dowdiness/moondsp](https://mooncakes.io/docs/dowdiness/moondsp) / dowdiness | DSP 音频引擎 | 近期更新；活跃 | 排除基础音频 DSP |
| Visualization | [shop1111/frontierlab](https://mooncakes.io/docs/shop1111/frontierlab) / shop1111 | 算法 trace 与离线 HTML 可视化 | 近期更新；活跃 | 通用 trace 展示已有方案 |
| Crypto | [moonbitstack/mooncrypt](https://mooncakes.io/docs/moonbitstack/mooncrypt) / moonbitstack | hash、HMAC、签名等 | 约 532 下载、小时级更新；活跃 | 排除基础密码库 |
| Crypto | [cc06b/mooncry](https://mooncakes.io/docs/cc06b/mooncry) / cc06b | 纯 MoonBit 多种密码算法 | 约 377 下载、分钟级更新；活跃 | 排除密码算法合集 |
| Testing | [moonbitlang/quickcheck](https://mooncakes.io/docs/moonbitlang/quickcheck) / moonbitlang | property-based testing、生成与缩减 | 首页最常下载之一；活跃 | 排除通用随机测试 |
| Testing | [moonbitlang/core/bench](https://mooncakes.io/docs/moonbitlang/core/bench) / moonbitlang | `Bench::bench`、统计报告 | 随 core 更新；活跃 | 排除简单 benchmark 工具 |
| Agent testing | [2515050242/moonagentcheck](https://mooncakes.io/docs/2515050242/moonagentcheck) / 2515050242 | Agent 工具事件契约检查 | 近期更新；已有独立路线 | 排除重复的工具调用检查器 |
| Formal methods | [oyjh0381/moonbdd](https://mooncakes.io/docs/oyjh0381/moonbdd) / oyjh0381 | ROBDD、符号可达性，`Manager::reach` | 16 下载、上月更新；有实质 API | CTL 项目须与符号布尔引擎区分 |
| Formal methods | [okMambaOut/moonpetri](https://mooncakes.io/docs/okMambaOut/moonpetri%400.1.0) / okMambaOut | Petri 网 BFS、最短路径、死锁、PNML | 所查 0.1.0 版 18 下载、19 天前更新；另有 0.1.3 新版；活跃 | 排除另做 Petri 网可达性 |

## 结论

AI 框架、RAG、MCP、常规 Web/数据库/图像/密码和基础测试方向均已有明确作品。形式化方向也已有 BDD 与 Petri 网工具，但它们的公开接口聚焦状态构建、可达性和死锁，未见一个面向**任意有限状态图的 CTL 性质检查**、固定点语义及性质反例/见证的独立 MoonBit 库。这个判断是基于上述可见包与关键词检索的选题判断，并非“全生态绝对不存在”的证明；实现前仍需复核最新注册表。
