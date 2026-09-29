# MoonCTL：三分钟演示脚本

## 0–30 秒：问题

一个支付流程有 `new → charged_once → completed`。正常测试只会走这条路径。若重试绕过幂等键，另有 `charged_once → charged_twice`，重复扣款仍可能发生。目标性质是：所有路径始终不会重复扣款，`AG !double_charge`。

## 30–120 秒：检查与定位

打开 `examples/buggy.json`，展示状态标签和 `retry_without_idempotency` 转移。运行：

```sh
moon run --target native cmd/main -- examples/buggy.json 'AG !double_charge'
```

输出 `FAIL`，并列出 `new → charged_once → charged_twice` 的最短反例。接着运行：

```sh
moon run --target native cmd/main -- examples/buggy.json 'AF completed'
```

这条性质也失败：`retry_forever` 构成一条始终无法保证完成的路径。输出的 `repeat from step ... forever` 指明循环入口。

## 120–180 秒：修复与效果

打开 `examples/fixed.json`，展示重试被幂等处理且只能走向完成状态。运行：

```sh
moon run --target native cmd/main -- examples/fixed.json 'AG !double_charge'
moon run --target native cmd/main -- examples/fixed.json 'AF completed'
moon test --target native --deny-warn
```

两条性质都变为 `PASS`。强调模型是明确列出的有限状态图，结果针对该图成立；MoonCTL 可作为库嵌入新的工作流或协议模型。
