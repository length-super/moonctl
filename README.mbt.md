# MoonCTL

MoonCTL 是一个用 MoonBit 编写的 CTL（计算树逻辑）有限状态模型检查库。给它一个完整的状态转换图和一条性质，它会判断初始状态是否满足性质，并为常见的可达性与活性结果给出可重放的路径。

它适合检查工作流、协议、工具调用及其他可枚举状态系统。它检查**你提供的模型**，不会从任意 MoonBit 程序自动提取状态图。

## 快速体验

需要 MoonBit 工具链。进入本仓库根目录后运行：

```sh
moon run --target native cmd/main -- examples/buggy.json 'AG !double_charge'
```

预期输出：

```text
FAIL: AG !double_charge
states=4 satisfying=1
counterexample (shortest path):
  new
  --charge--> charged_once
  --retry_without_idempotency--> charged_twice
```

性质失败时退出码为 1。修复后的工作流可运行：

```sh
moon run --target native cmd/main -- examples/fixed.json 'AG !double_charge'
moon run --target native cmd/main -- examples/fixed.json 'AF completed'
```

两条性质都应得到 `PASS`。独立可执行文件对模型或公式输入错误返回 2；`moon run` 是开发包装命令，可能把非零退出码统一报告为 1。

机器可读输出使用 `--json`：

```sh
moon run --target native cmd/main -- --json examples/buggy.json 'AF completed'
```

输出是单个 JSON 对象：`formula` 为输入公式，`report` 含 `schema_version`、`holds`、`state_count`、`satisfying_count`、`satisfying_states`、`trace_role`、`trace` 和 `loop_start`。`satisfying_states[i]` 对应输入模型第 `i` 个状态；循环路径的最后一步重访 `loop_start` 指向的步骤。输入错误时 JSON 模式输出 `{"error":"..."}`。

## 作为库使用

本模块名为 `yelfs/moonctl`。使用 API 可直接构造状态和转移，无需 JSON：

```mbt nocheck
let states : Array[@moonctl.State] = [
  { id: "new", labels: [] },
  { id: "done", labels: ["completed"] },
]
let edges : Array[@moonctl.Edge] = [
  { from: 0, to: 1, action: "finish" },
]
let model = match @moonctl.Model::new(states, edges, initial=0) {
  Ok(m) => m
  Err(_) => abort("invalid model")
}
let property = @moonctl.parse("EF completed")
let report = @moonctl.check(model, property)
assert_true(report.holds())
```

在调用方 `moon.pkg` 中导入 `"yelfs/moonctl" @moonctl`。`Model::new` 验证非空状态、初始索引、状态 ID 唯一性和转移索引。`parse` 与 `load_model_json` 分别以 `ParseError` 和 `ModelJsonError` 报告输入问题。`Report` 提供 `holds()`、`state_count()`、`satisfying_count()`、`satisfies_at(index)`、`trace()`、`trace_role()`、`loop_start()` 和 `to_json()`。

### 用状态 ID 构图

不必手工维护数字索引。`Model::from_named` 接受同样的状态列表和 `NamedEdge`，用状态 ID 指定初态及转移；未知或重复的 ID 会返回错误。

```mbt nocheck
///|
let states : Array[@moonctl.State] = [
  { id: "queued", labels: [], },
  { id: "done", labels: ["completed"], },
]

///|
let edges : Array[@moonctl.NamedEdge] = [
  { from: "queued", to: "done", action: "finish", },
]

///|
let model = @moonctl.Model::from_named(states, edges, "queued")
```

### 从转换函数探索

`explore` 从初态按广度优先调用转换函数，只纳入可达状态。调用方必须给出 `max_states` 和 `max_edges`；前者含初态，后者统计显式转移，不统计死端的隐式自环。刚好达到预算仍可能完成；只有还需发现新状态或转移时才返回 `Incomplete`。状态 ID 再次出现时，其标签集合必须一致。`Incomplete` **不含 `Model`**，因此不能把未探索的行为当成性质通过。

```mbt nocheck
let result = @moonctl.explore(
  initial,
  state => transitions_from(state),
  max_states=1000,
  max_edges=5000,
)
match result {
  Ok(Complete(model)) => {
    let report = @moonctl.check(model, @moonctl.parse("AG !double_charge"))
    println("holds=\{report.holds()}")
  }
  Ok(Incomplete(limit, states, edges)) =>
    println("incomplete: \{Repr(limit)}, \{states} states, \{edges} edges")
  Err(error) => println("invalid exploration: \{Repr(error)}")
}
```

完整可运行版本：`moon run --target wasm-gc examples/explore`。转换回调必须对同一状态 ID 稳定地返回该状态的全部可能转移；若历史会改变后续行为，应把相关历史纳入状态 ID。预算约束的是 MoonCTL 保存的图，不限制回调内部自行分配的内存。

## JSON 模型格式

`examples/buggy.json` 展示完整格式：

```json
{
  "initial": 0,
  "states": [
    {"id": "new", "labels": ["safe"]},
    {"id": "charged", "labels": ["safe"]}
  ],
  "edges": [
    {"from": 0, "to": 1, "action": "charge"}
  ]
}
```

状态和转移索引从 0 开始。每个状态的 `id` 必须唯一；`labels` 是在该状态为真的原子命题。`action` 用于输出路径。无出边的状态按隐式 `<stutter>` 自环解释，使每条计算路径无限延续。输入图必须列出系统的全部相关状态和转移；缺失的行为无法被检查出来。

## 公式与语义

| 公式 | 含义 |
| --- | --- |
| `p`, `true`, `false` | 原子命题与布尔常量 |
| `!p`, `p & q`, `p \| q` | 否定、合取、析取 |
| `EX p`, `AX p` | 存在 / 所有下一状态满足 `p` |
| `EF p`, `AF p` | 存在 / 所有路径最终到达 `p` |
| `EG p`, `AG p` | 存在 / 所有路径始终满足 `p` |
| `E[p U q]`, `A[p U q]` | 存在 / 所有路径保持 `p` 直到 `q` |

`!` 高于 `&`，`&` 高于 `|`；可用括号分组。`U` 是强直到：必须最终到达右式。标识符支持 ASCII 字母、数字、下划线、连字符、点和冒号；`true`、`false`、`EX` 等关键字保留。

求值采用有限图固定点算法，`holds()` 只报告**初始状态**的真值。`satisfying_count()` 是全图中满足该公式的状态数，可能包括初始状态不可达的状态。

对顶层 `EX p`、`EF p`、`E[p U q]` 的成功，以及 `AX p`、`AG p` 的失败，`trace()` 返回最短有限见证或反例。`A[p U q]` 失败时优先返回最短的有限违反路径；若失败只能由无限等待造成，则返回一条循环路径。`AF p` 的失败和 `EG p` 的成功也返回循环路径；`loop_start()` 指向第一次出现的循环入口，末尾步骤是重访该状态。其他结果的 `trace()` 暂为空；这不影响真假判定。循环路径保证有效，但未优化为最短。

## 验证与演示

```sh
moon check --target all --deny-warn
moon test --target wasm-gc --deny-warn
moon test --target native --deny-warn
moon run --target wasm-gc examples/explore
```

测试中另有一个独立参考求值器：它在小图上逐条枚举简单路径并识别循环，与正式求值器的前驱固定点算法分开；测试对照每个状态的真值，并重放所有生成的有限和循环路径。三分钟演示脚本见 [docs/demo.md](docs/demo.md)。调研依据与竞品比较见 [mooncake-ecosystem-analysis.md](mooncake-ecosystem-analysis.md)、[github-ecosystem-analysis.md](github-ecosystem-analysis.md) 和 [project-proposal.md](project-proposal.md)。

## 当前边界

- 使用显式有限图，单个时序子公式的固定点求值按状态和转移数线性增长；按需探索有明确预算，手工构图仍由调用方控制规模；尚无符号状态压缩。
- 模型是否忠实于业务系统由建模者负责；`PASS` 只适用于已给出的图与标签。
- CLI 使用 native 后端；核心库已按 MoonBit 的 wasm、wasm-gc、js、native 目标检查。

Apache-2.0 许可。此仓库当前只在本地开发与验证，尚未发布到 GitHub 或 Mooncakes。
