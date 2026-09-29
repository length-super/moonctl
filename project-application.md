# MoonCTL 项目申报书

- **项目名称：** MoonCTL——MoonBit CTL 时序性质检查库
- **项目方向：** 开发者工具／形式化验证基础库
- **GitHub 仓库：** https://github.com/length-super/moonctl
- **项目类型：** 原创项目，非移植；Apache-2.0 许可证

## 项目简介与通用价值

MoonCTL 接收有限状态图与 CTL（计算树逻辑）公式，判断系统在不同分支和循环下是否满足安全性、活性要求，并输出可重放的证据路径。MoonBit 已有布尔决策图、Petri 网及程序契约工具；本项目补充**通用状态图的时序性质检查**。开发者可通过 MoonBit API 或 JSON 为工作流与协议建模；核心库支持 WASM、WASM GC、JavaScript、Native。

## 预期使用场景

1. **支付重试：** 输入创建、扣款、重试、完成状态；检查 `AG !double_charge` 和 `AF completed`。故障模型显示重复扣款与无限重试路径；修复幂等与重试转移后两项通过，供上线前审查。
2. **分布式锁：** 输入双客户端获取、持有、释放的转移；检查 `AG !both_hold` 和持锁后必释放。故障模型暴露同时持锁与无限持锁；修复后两项通过，DOT 图标红反例供协议评审。
3. **Agent 审批：** 输入提议、批准、拒绝、执行状态；检查 `AG !unapproved_execution` 和 `AF (approved | denied)`。故障模型暴露绕过审批且没有最终决定的路径；封堵旁路后两项通过，供权限流程回归。

## 拟实现的核心功能与交付

- **建模与求值：** 校验状态、标签与转移；按预算探索可达图；解析八类 CTL 时序运算符，以固定点算法求值。探索不完整时明确报告，不给出误导性的通过结果。
- **结果与集成：** 为常见性质输出有限或循环证据，提供 JSON／DOT 输出及 CLI 批量检查接口。
- **交付与验证：** 三组故障／修复示例、可运行演示、README、API 文档、跨目标测试和 CI；已发布 [Mooncakes 0.2.0](https://mooncakes.io/docs/length-super/moonctl@0.2.0)。

## 原创性与参考说明

源码、测试和示例均为原创。选题对照 [MoonBDD](https://github.com/oyjh0381/MoonBDD)、[MoonPetri](https://github.com/okMambaOut/moonpetri) 及 `moon prove` 的定位；MoonCTL 提供独立的 CTL 检查能力，未移植其代码。因此，移植项目的来源及许可证项不适用。
