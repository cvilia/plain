# 08-07 · 分类管理（Categories）

| 文档属性 | 内容 |
| --- | --- |
| 文档版本 | v3.0 |
| 文档阶段 | 方案设计 · 屏幕规格 |
| 文档状态 | 可执行 |
| 编写日期 | 2026-10-13 |
| 上游输入 | `07-SCREENS.html → screen_categories()`；《02-PRD》STORY-5.x；《08 数据模型》分类表 |
| 读者 | 设计师 / 编码 Agent |
| 校对依据 | 高度由 `_build/_probe.py` 实测（内容 890 → 溢出 286，滚动可达） |

---

## 1. 屏幕任务

**改名、调序、开关、增删**分类。
本屏是「只改 `name` 不改 `key`」这条硬规则在 UI 上的落点，**必须在规格层面写死**。

## 2. 垂直分区与高度预算

| # | 区块 | 高度 | 说明 |
| --- | --- | --- | --- |
| 1 | `.statusbar` | 47 | — |
| 2 | `.topbar` | 56 | 左：返回；中：分类管理；右：`ic_plus` |
| 3 | `.segwrap` | 48 | 支出 / 收入 分段控件（`.seg` 36 + `padding-bottom` 12） |
| 4 | `.scroll` | 693 | 内容实测 890 → 溢出 197，滚动可达 |
| | 合计 | 844 | ✅ |

> 本屏**无 `.footbar` 也无 `.nav`** —— 二级页用返回离开；新建入口仅保留顶栏 `ic_plus`。

## 3. 分段控件

```
.seg{display:flex;background:surface-inset;border-radius:12px;padding:3px;height:36px}
.segi{flex:1;border-radius:9px;font-size:14;font-weight:500;color:muted}
.segi.on{background:surface;color:ink;font-weight:600;box-shadow:0 1px 2px shadow-1}
```

- 支出 / 收入两个一级 Tab，**只切换列表，不改变页面结构**。
- 选中态换底色 + 换文字色 + 换字重（三通道），不靠单色区分。
- `.segi` 视觉高 30 < 44 → 由 `::after` 撑到 44 命中区（见 `05-COMPONENT-SPECS` §24）。

## 4. 分类行（`.crow2`）

```
.crow2{display:flex;align-items:center;gap:12px;min-height:72px;padding:12px 16px}
.crow2 + .crow2{border-top:1px solid line-soft}
├ .cicon  24px 定宽，内放 24px 分类图标（色 `--cat-ink-{ref}`）
├ .rcol   flex:1 列
│   ├ .rt   15/500 ink      「餐饮」
│   └ .sub  12/500 muted    「三餐、外卖、堂食」
├ .cnt   12/500 muted       「128 笔」
└ ic_drag_handle 18px      色 `faint`，拖拽排序手柄
```

### 4.1 ⚠️ `.rcol` 的作用域坑（真实踩过）

CSS 里 `.rcol` 的 `flex-direction:column` **必须是独立类**，不能写成 `.row .rcol`。
本屏用的是 `.crow2` 而不是 `.row`，写成后代选择器就命中不了，
结果**分类名与别名被挤成一行**：`餐饮三餐、外卖、堂食` —— 看起来像忘了加分隔符，
实际是样式作用域没命中。**已改为独立类 `.rcol`。**

### 4.2 两行文字的分工

| 行 | 内容 | 来源 |
| --- | --- | --- |
| `.rt` | 分类名（≤6 字） | `categories.name` |
| `.sub` | 别名 / 包含范围 | `categories.note` |

⚠️ **`categories.note`（分类备注）≠ `transactions.note`（账单备注）**：
两者字段不同、组件不同、生命周期不同，**禁止共用字段、共用组件、互相引用**。
分类备注 ≤30 字，**截断不报错**；不进搜索/筛选/统计/索引，但**进备份与云同步**。

## 5. 硬规则：只改 name，不改 key

| 允许 | 禁止 |
| --- | --- |
| 改分类 `name`（显示名） | 改分类 `key`（稳定标识） |
| 改别名 / 备注 | 删除一级分类（只能停用） |
| 调整顺序（拖拽手柄） | 改分类的 `iconRef`（图标冲突） |
| 增删自定义二级分类 | 改预置分类的 id（`preset_${key}`） |

> 原因：预置分类 id = 运行时 `preset_${key}`，**改 key 等于把所有历史账目的分类引用打断**。
> `seedPresetCategories` 只在表为空时播种，因此**预置清单调整只对新装生效** ——
> 这一条要写进实现说明，否则会有人以为改清单能影响存量用户。

## 6. 新增入口

- 仅保留顶栏 `ic_plus` 作为新建分类入口。
- 点击后进入新增分类页（本交付未含该屏，属二期）：名称 + 图标 + 备注 + 父级。

## 7. 拖拽排序

- 手柄 `ic_drag_handle` 才可拖，**行本身长按不触发拖拽**（与「长按=宫格操作」的全局手势不冲突）。
- 排序写入 `categories.sort_order`，**不写 `key`**。
- 移动端拖拽的替代路径：长按手柄 → 弹出「上移 / 下移 / 置顶」菜单（无障碍必需）。

## 8. 中英差异

| 位置 | 中文 | 英文 |
| --- | --- | --- |
| 标题 | 分类管理 | Categories |
| 分段 | 支出 / 收入 | Expense / Income |
| 笔数 | `128 笔` | `128 entries` |
| 新建 | 新建分类 | New category |

`128 entries` ≈ 66px 在 `.cnt` 12/500 下不挤掉 `.rcol` ✅。
`New category` ≈ 78px 在 `.btn2` 内不换行 ✅。

## 9. 暗态要点

- 分类图标用 `--cat-ink-*`，暗态组已是**提亮变体**，换主题即换值，无需改类名。
- `.seg` 的 `surface-inset` 在暗态是 `#1B1B1D`，比 `appBg #1A1A1D` 略深 —— 分段槽要**比页面深**才像凹槽。
- `.crow2` 分隔线 `line-soft #2B2B32` 在 `surface #222225` 上可见 ✅。

## 10. 验收点

- [ ] 分类名与别名**分两行**显示（不是挤成一行）
- [ ] `.rcol` 为独立类，全站可复用
- [ ] 拖拽手柄是唯一拖拽入口，长按行不触发拖拽
- [ ] 无任何改 `key` 的 UI 入口
- [x] 仅保留顶栏一个新增入口
