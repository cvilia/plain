# 08-03 · 记一笔（Add Entry）

| 文档属性 | 内容 |
| --- | --- |
| 文档版本 | v3.0 |
| 文档阶段 | 方案设计 · 屏幕规格 |
| 文档状态 | 可执行 |
| 编写日期 | 2026-10-13 |
| 上游输入 | `07-SCREENS.html → screen_add()`；《02-PRD》STORY-1.x、§5.0 G-1~G-7 |
| 读者 | 设计师 / 编码 Agent |
| 校对依据 | 高度与几何由 `_build/_probe.py` 实测；金额宽度由浏览器实测 |

---

## 1. 屏幕任务

**3 秒记一笔。** 数字键盘必须常驻，绝不因内容多少而滚动出屏。
本屏是**唯一「固定型」屏幕** —— 其余七屏都是滚动型，只有这里任何溢出都算 bug。

## 2. 垂直分区与高度预算（实测 844 / 844）

| # | 区块 | 高度 | 弹性 | 说明 |
| --- | --- | --- | --- | --- |
| 1 | `.statusbar` | 47 | `0 0 47` | — |
| 2 | `.topbar` | 56 | `0 0 56` | 左 **✕**（关闭，非返回）+ 标题「记一笔」，**右侧为空** |
| 3 | `.ttabs` | 50 | `0 0 auto` | 类型 Tab：支出 / 收入 / 转账 / 借出 / 借入 |
| 4 | `.amount-block` | 85 | `0 0 auto` | 表达式行 + 金额四段式 |
| 5 | `.addbody` | **288** | `flex:1 1 auto` | 唯一可滚区：分类格 + 属性 chip |
| 6 | `.keypad` | 284 | `0 0 auto` | 4×4 网格，键高 62 |
| 7 | `.safearea` | 34 | `0 0 34` | Home Indicator 保护区 |
| | **合计** | **844** | | ✅ 精确填满 |

### 2.1 为什么中段要可滚

| 情景 | 中段需要 | 可用 288 | 结果 |
| --- | --- | --- | --- |
| 中文 × 标准 | 278 | 288 | ✅ 不滚 |
| 中文 × 特大 | ~300 | 288 | 轻微滚动，**键盘仍在** |
| 英文 × 特大 | ~310 | 288 | 轻微滚动，**键盘仍在** |

`.addbody{flex:1 1 auto;min-height:0;overflow-y:auto}` 的关键是 `min-height:0` ——
没有它 flex 子项不会收缩，键盘会被顶出屏幕。**这是本屏唯一的技术要点，务必写进实现。**

### 2.2 上一版这里是错的（返工记录）

首轮生成时：`.catgrid` 只放 8 个分类 + 1 个「更多」，第 3 行只有 1 个格子（浪费 3 格）；
属性栏是 3 行 × 44 = 133。合计 **947 / 844，溢出 103px，键盘第 4 行被切掉**。
修法：分类补齐 **12 个**（3×4 正好填满）+ 属性栏压成 **一行 chip** + 中段可滚。

## 3. 类型 Tab（区块 3）

```
.ttabs{display:flex;gap:4px;padding:0 12px 6px;overflow-x:auto}
.ttab{height:44px;padding:0 14px;border-radius:12px;font-size:14;font-weight:500;color:muted}
.ttab.on{color:ink;font-weight:600;background:primary-tint;box-shadow:inset 0 0 0 1px primary-ink}
```

- 选中态 = `primary-tint` 底 + **1px 内描边**，不换字号位置（避免选中时行宽跳动）。
- 高度 **44** 满足最小触控；**中文 5 个 Tab 在 358dp 内全放得下**。
- ⚠️ **英文 5 个 Tab（Expense / Income / Transfer / Lend / Borrow）放不下** → 容器 `overflow-x:auto` 横向滚动，滚动条隐藏。这是已实测的必然结果，不是可选项。

## 4. 金额区（区块 4）

```
.amount-block{padding:2px 16px 10px;align-items:flex-end}   ← 左右 16 与全站沟槽一致
├ .expr  14/500 muted tnum  + .caret(2×15 primary 光标)     「25|」
└ .amt-line → amount("25.00","input")   44/600
```

- 左右内缩 **16**（不是 20）。改这一处的直接收益：让最长金额在大档下也放得下。
- 「记一笔」的金额区**右对齐**（`align-items:flex-end`），跟键盘的重心一致。

### 4.1 金额宽度硬约束（浏览器实测）

可用宽度 = 390 − 2×16 = **358**。最长串 `¥99,999,999.99`：

| 档 | 字号 | 实测宽 | 判定 |
| --- | --- | --- | --- |
| 标准 | 44 | 316.14 | ✅ 余 42 |
| 大 | 49.28 | 354.10 | ✅ 余 4 |
| 特大 | 55.44 | **398.26** | ❌ 超 40 |

**规则：向下取到放得下的一档**（特大放不下 → 落大档），不是「固定降一档」。
超过 11 字符时同样处理。**绝不截断、绝不省略号** —— 金额是不允许被裁剪的信息。

## 5. 分类选择器（区块 5 上半）

```
.catgrid{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;padding:10px 16px}
.tile{height:62px;border-radius:12px;flex column;gap:6px;
      background:none;border:1.5px solid transparent}
.tile.on{background:primary-tint;border-color:primary-ink}
```

- **12 个一级支出分类全平铺 = 3 行 × 4 列，不多不少。** 不设「更多」格 —— 12 个都在眼前，没有可折叠的余量。
- 每格 = **分类图标 23px（色 `--cat-ink-{ref}`）+ 名称 12/500**。
- **未选中格 `background:none`** —— 这是与上一版的关键分野：**不给每个格子垫淡彩底板**。
- 选中格同时改底色、描边、文字色与字重四件事，确保非色彩单通道也**可辨**（色盲友好）。

> 为什么这里用图标而不是圆点：**选择器是辨认场景**。12 个图标能显著缩短找分类的时间；
> 而流水行用圆点是因为那是**扫读场景**，图形会抢金额的注意力。同一套数据，两种表达。

## 6. 属性 chip（区块 5 下半）

```
.attrchips{display:flex;flex-wrap:wrap;gap:8px;padding:2px 16px 10px}
.chip{height:40px;padding:0 12px;border-radius:999px;border:1px solid line;
      background:surface;gap:6px;font-size:12;font-weight:600;color:ink2}
.chip.ph{border-style:dashed;color:muted;font-weight:500}   ← 未填写用虚线
```

三个 chip：`💳 招行储蓄卡` / `📅 今天` / `✎ 添加备注`。

**这是一处有意的设计改动**：首版是 3 行 × 44px 的全宽属性行（共 133px），
在 844 里根本放不下。压成一行 chip 后：

| | 首版 | 现在 |
| --- | --- | --- |
| 高度 | 133 | **52** |
| 交互 | 3 行逐行点 | 1 行 3 个 chip |
| 视觉 | 表格感 | 更轻 |

三者都有默认值（账户/今天/空），「3 秒记账」的路径上**根本不会碰它们**，
因此降低视觉权重是正确取舍。chip 高 40 < 44 触控 → 用 `::after` 撑命中区（见 §8）。

## 7. 数字键盘（区块 6）

```
.keypad{display:grid;grid-template-columns:repeat(4,1fr);gap:6px;padding:8px 12px 10px}
.key{height:62px;border-radius:12px;background:surface-2;border:1px solid line;box-shadow:0 1px 2px shadow-1;
     font-size:22;font-weight:500;tnum}
.key.ok{grid-column:span 2;background:accent;border-color:accent;color:on-accent;font-size:15;font-weight:600}
```

布局：`1 2 3 ⌫` / `4 5 6 ✕` / `7 8 9 ␣` / `. 0 [保存]`

- **键高 62**，每键 **87×62**（`(390−24−18)/4 = 87`）。
- **键帽必须有实体**：`surface-2` 底 + 1px `line` + `shadow-1`。
  上一版「键盘无键帽」（纯文字浮在底色上）是明确的失败点，这里三条都给上。
- **保存键跨 2 列 = 180 宽**，用 `accent` —— 键盘里唯一的色彩，视线自然落上去。
- 键位顺序照 **G-3：只有数字、小数点、退格、清空、OK**。无「+ − × ÷」，无历史记录条。
- `.key.ok` 的 `on-accent` 由 `inkFor(accent, fabBg, 3.0)` 推出（**不能直接用 accent** ——
  10 主题 10/10 不达标，最差 1.00:1；详见《01-tokens》`gates`）。

## 8. 状态与触控

| 元素 | 视觉高 | 命中区 | 按下 |
| --- | --- | --- | --- |
| `.ttab` | 44 | 44 | 底色 `surface-inset` |
| `.chip` | 40 | **44**（`::after`） | 底色 `surface-inset` |
| `.tile` | 62 | 62 | `surface-inset` + `scale(.96)` |
| `.key` | 62 | 62 | `primary-tint` + `scale(.96)` |
| `.key.ok` | 62 | 62 | `accent-pressed` + `scale(.96)` |
| `.iconbtn` | 44 | 44 | `surface-inset` + `scale(.93)` |

按压时长 **100ms**，缓动 `cubic-bezier(.34,1.56,.64,1)`（见《06-INTERACTION》）。

## 9. 中英差异

| 位置 | 中文 | 英文 | 处理 |
| --- | --- | --- | --- |
| 类型 Tab | 5 个共 ~200 | 5 个共 ~430 | **横向滚动**（已实测放不下） |
| 标题 | `记一笔` | `New Entry` | ✅ |
| 分类名 | `餐饮`/`食材` 2 字 | `Dining`/`Groceries` | 12/500，单行 ellipsis |
| chip | `招行储蓄卡` | `CMB Savings` | ✅ 358dp 内 3 个 chip 不换行 |

## 10. 暗态要点

- 键帽在暗态**必须比背景亮**：`appBg #1A1A1D` → 键 `surface2 #2B2B2F`（+1px `line`）。
  若键帽用 `surface`，与背景几乎同色，键盘会「消失」。
- 保存键在暗态用 `accent #FDBA74`（提亮降饱和），文字 `on-accent #4C4C4C`。
- 分类图标的 `cat-ink` 在暗态**自动换为高亮变体**（`--cat-ink-*` 在暗态组已是亮色），
  无需改类名 —— 换主题即换值。

## 11. 验收点

- [ ] 键盘 4 行**全部可见**，`保存` 键完整（首版此处返工过）
- [ ] 三档字号 × 中英 6 种组合下，键盘都在视口内
- [ ] `¥99,999,999.99` 在三档下都不截断（特大档自动降到能放下的一档）
- [ ] 12 个分类格 3 行 4 列填满，**无空格子**
- [ ] 未选中格**没有底色**
- [ ] 键帽三件套齐备：底色 + 1px 描边 + 阴影
- [ ] `.key.ok` 的 `on-accent` 在 **10 主题 × 亮暗**全部 ≥3:1
