# 三个可复现的使用场景

这些示例都是明确列出的有限状态模型。`PASS` 只证明模型满足公式，不代替对真实系统的建模和实现审查。

## 1. 支付重试与幂等性

支付状态包括创建、首次扣款、重复扣款和完成；`retry_without_idempotency` 会走到重复扣款状态，`retry_forever` 形成无法保证完成的循环。使用 `AG !double_charge` 检查安全性，用 `AF completed` 检查所有路径最终完成。

```sh
moon run --target native cmd/main -- --suite examples/buggy.json examples/payment.suite
moon run --target native cmd/main -- --suite examples/fixed.json examples/payment.suite
```

预期分别为 `1/3 passed` 与 `3/3 passed`。失败模型的反例会指出重试转移；修复模型将重试归并为幂等处理。

## 2. 分布式锁与互斥

两个客户端竞争同一把锁。故障模型允许持锁时第二个客户端绕过守卫获取锁，也允许客户端无限停留在持锁状态。`AG !both_hold` 检查互斥；`AG (!(a_holds | b_holds) | AF free)` 检查每次持锁后沿所有路径最终释放。

```sh
moon run --target native cmd/main -- --suite examples/lock-buggy.json examples/lock.suite
moon run --target native cmd/main -- --suite examples/lock-fixed.json examples/lock.suite
```

预期分别为 `0/2 passed` 与 `2/2 passed`。可对互斥失败执行 `--dot examples/lock-buggy.json 'AG !both_hold'`，导出标红的竞争路径。

## 3. Agent 工具调用审批

Agent 提出工具调用后必须经过人工或策略审批。故障模型允许 `bypass_review` 直接执行，且这条路径永远没有审批决定。`AG !unapproved_execution` 检查安全性；`AF (approved | denied)` 检查每条路径最终得到决定。

```sh
moon run --target native cmd/main -- --suite examples/agent-buggy.json examples/agent.suite
moon run --target native cmd/main -- --suite examples/agent-fixed.json examples/agent.suite
```

预期分别为 `0/2 passed` 与 `2/2 passed`。真实 Agent 的审批历史必须编码进状态和标签，才能让这些性质代表实际业务约束。
