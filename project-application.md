# MoonCTL 项目申报书

- **项目名称：** MoonCTL（MoonBit CTL 模型检查库）
- **GitHub：** https://github.com/length-super/moonctl （`main` 已有至少 10 个有效开发提交）
- **项目类型：** 原创项目；非语言移植。

## 项目简介、方向与通用性

**方向：开发者工具／形式化验证基础库。** 输入有限状态、标签、转移与 CTL 公式，输出安全性／活性判定及可重放路径。同一 API 可检查工作流、并发协议和 Agent 流程；不绑定业务框架，支持 WASM、WASM GC、JavaScript、Native。

## 预期使用场景

1. **支付重试：** 输入创建、扣款、重试、完成状态；检查 `AG !double_charge`、`AF completed`。绕过幂等键和无限重试时输出 `FAIL` 及反例；修复后均 `PASS`，用于上线前审查。
2. **分布式锁：** 输入双客户端获取、释放、停留转移；检查 `AG !both_hold` 及“持锁后必释放”。故障模型指出竞争和无限持锁，修复后均 `PASS`；DOT 图标红路径供协议评审。
3. **Agent 审批：** 输入提议、审批、拒绝、执行状态；检查 `AG !unapproved_execution`、`AF (approved | denied)`。绕过审批时两项 `FAIL`；封堵旁路后均 `PASS`，用于权限流程回归。

## 拟实现的核心功能与交付

已完成完整 CTL 运算符、固定点求值、具名／预算探索建模、有限与循环证据、JSON／DOT 输出、批量性质套件及不可达状态诊断。交付三组故障／修复模型、README、演示、测试、CI 和 Apache-2.0 许可证；复现见 `docs/scenarios.md`。

## 原创性与参考来源

原创实现，示例与测试亦为本项目编写。选题参考 [MoonBDD](https://github.com/oyjh0381/MoonBDD)、[MoonPetri](https://github.com/okMambaOut/moonpetri) 与 `moon prove` 的生态定位；本项目提供独立的 CTL 检查能力，未移植其代码。**移植项目的来源与许可证项不适用。**
