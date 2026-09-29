# GitHub 生态调查（2026-09-29）

## 搜索方法与结果

使用 GitHub 仓库搜索 `moonbit language`、`moonbitlang`、`moonbit-community`、`awesome-moonbit`、`topic:moonbit`、`language:MoonBit`，再用项目方向词查重。GitHub 搜索 API 在第 14 次左右返回未认证请求的 403 限流；后续以公开仓库和议题页面复核。查询时 `topic:moonbit` 返回约 361 项，`language:MoonBit` 返回约 2899 项；这两个数只是搜索索引规模，不能当作实际可用生态包数。

| 仓库 | 可见定位 / 使用情况 | 维护与选题关系 |
| --- | --- | --- |
| [moonbitlang/core](https://github.com/moonbitlang/core) | 标准库，搜索时约 1222 stars | 活跃；QuickCheck/bench 已具备 |
| [moonbitlang/moon](https://github.com/moonbitlang/moon) | 构建与包管理工具，组织页约 424 stars | 活跃；`moon test` 等能力应复用 |
| [moonbitlang/parser](https://github.com/moonbitlang/parser) | 官方 MoonBit 解析器 | 活跃；不再另造语法解析器 |
| [moonbitlang/awesome-moonbit](https://github.com/moonbitlang/awesome-moonbit) | 生态索引，约 158 stars | 用作查重入口，不等于全量注册表 |
| [moonbit-community/crescent](https://github.com/moonbit-community/crescent) | Web 框架 | Web 方向竞争已充分 |
| [moonbit-community/verified](https://github.com/moonbit-community/verified) | `moon prove`/Why3 示例和证明支持 | 已覆盖程序契约证明，不提供通用 CTL 状态图检查 |
| [oyjh0381/MoonBDD](https://github.com/oyjh0381/MoonBDD) | BDD 与符号状态空间 | 与形式化主题相邻；本项目不重建 BDD |
| [okMambaOut/moonpetri](https://github.com/okMambaOut/moonpetri) | Petri 网建模、BFS、死锁 | 与状态图相关；本项目不重建 Petri 网 |
| [2973181701/evalhub](https://github.com/2973181701/evalhub) | LLM 评测与标注平台；页面称 75 项引擎测试 | 排除通用 LLM 评测平台 |
| [dijdzv/moon-release](https://github.com/dijdzv/moon-release) | 发布自动化，含 API 兼容性检查 | 排除单纯 semver/API diff 工具 |
| [mizchi/moon-pprof](https://github.com/mizchi/moon-pprof) | Linux perf 与多目标 pprof | 排除通用 profiler |
| [shop1111/moonbindgen](https://mooncakes.io/docs/shop1111/moonbindgen%400.1.0) | C FFI 声明生成器 | 排除基础 bindgen |

## 已提交 issue、PR、roadmap/TODO

- [moonbitlang/moon #1906](https://github.com/moonbitlang/moon/issues/1906) 请求 `moon test/bench --related PATH...`，说明下游受影响测试选择有真实需求；其对应的 [PR #1855](https://github.com/moonbitlang/moon/pull/1855) 仍开放。因此**不选**依赖图测试筛选器。
- [moonbitlang/moon #1961](https://github.com/moonbitlang/moon/issues/1961) 记录注册表名称在大小写不敏感文件系统上的冲突，提示 Windows/macOS 与 Linux 生态测试需要分别核验。
- [moonbitlang/moonbit-compiler roadmap](https://github.com/moonbitlang/moonbit-compiler) 表示将继续开源编译器/格式化/文档等工具；不宜以“官方完全不做代码智能”为前提选题。
- [moonbitlang/workflow](https://github.com/moonbitlang/workflow) 与 [moonbitlang/openseek](https://github.com/moonbitlang/openseek) 持续更新，说明 Agent 编排与编码 Agent 方向竞争明显。

## 赛事依据

[2026 MoonBit 黑客松本期页面](https://moonbitlang.github.io/Hackathon2026/)写明 9 月第一周至 9 月 30 日，要求可运行、可测试、可维护，以及 README、测试与可复现演示。本地 `osc2026-guide` 中的《2026 MoonBit 国产基础软件开源大赛章程》属于较早赛程，不能把其中 7 月节点当成本期截止日期。奖项与评审仍以本期官方通知为准。

## GitHub 查重结论

对 `MoonBit temporal logic CTL model checker`、`MoonBit LTL`、`site:mooncakes.io/docs CTL model checking` 的公开检索没有发现同定位的成熟 MoonBit 项目。此处仅作当前选题证据。邻近的 MoonBDD、MoonPetri 与 `moon prove` 都要在设计文档中明确界限，后续可提供适配器而不是复制它们的模型构建能力。
