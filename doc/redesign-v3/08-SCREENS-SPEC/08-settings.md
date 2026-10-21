# 08-08 · 我的 / 设置（Profile & Settings）

| 文档属性 | 内容 |
| --- | --- |
| 文档版本 | v3.0 |
| 文档阶段 | 方案设计 · 屏幕规格 |
| 文档状态 | 可执行 |
| 编写日期 | 2026-10-13 |
| 上游输入 | `07-SCREENS.html → screen_settings()`；《02-PRD》§5.0 基础设置 |
| 读者 | 设计师 / 编码 Agent |
| 校对依据 | 高度由 `_build/_probe.py` 实测（内容 1103 → 溢出 422，滚动可达） |

---

## 1. 屏幕任务

基础设置的**唯一入口**，外加隐私承诺的**持续可见**。
本屏不承担账户体系（无账号、无登录、无会员），**商业化的付费入口不放在这里的第一屏**。

## 2. 垂直分区与高度预算

| # | 区块 | 高度 | 说明 |
| --- | --- | --- | --- |
| 1 | `.statusbar` | 47 | — |
| 2 | `.topbar` | 56 | 左：`ic_nav_profile`；中：我的；右：空 |
| 3 | `.scroll` | 681 | 内容实测 **1103 → 溢出 422**，滚动可达 |
| 4 | `.nav` | 60 | — |
| | 合计 | 844 | ✅ |

本屏内容是八屏里最长的（溢出 422 ≈ 一屏半），分区顺序刻意排成
**承诺在前、高频设置在前、低频与危险项在后**。

## 3. 区块顺序（信息优先级）

```
① 隐私承诺条       ← 常驻，不可折叠
② 记账组：月起始日 / 字体大小 / 记账确认音效 / 保存后停留
③ 安全组：应用锁 / 隐藏金额
④ 外观组：主题 / 深色模式 / 图标
⑤ 数据组：备份 / 恢复 / 导出 / 回收站
⑥ 关于：版本 / 开源许可 / 隐私政策
```

⚠️ **隐私承诺条必须常驻第一屏**，不能收进「关于」。
这是本产品「无广告、无外联、无埋点上报」的商业承诺，**是卖点不是法律条款**。

## 4. 隐私承诺条

```
.privacy-strip{display:flex;gap:12px;align-items:center;margin-top:4px;
  padding:14px 16px;border-radius:16px;background:ok-soft;color:ok-ink}
.pt 14/600    「隐私承诺」
.ps 12/500 opacity:.9   「无广告、无外联、无埋点上报」
```

- 图标 `ic_shield` 20px。
- 用 `ok-soft` / `ok-ink`（绿系）—— **全系统唯一一处大面积语义绿**，
  因为它表达的是「安全/无风险」而不是涨跌。与《05-reports》的涨跌绿**不是一个语义槽**，
  实现时不要互相复用令牌。

## 5. 设置分组

```
.eyebrow  12/600 字距+0.08em muted   margin 分组间隔  ← 「记账」「安全」「外观」
.panel    radius 16 / bg surface / border 1px line
└ 行：min-height 60 / padding 9 16
   ├ .rt/.sub 或单行标签 15/500 ink
   ├ 右值：15/500 muted（如「10 日」「标准」「素白」）+ ic_chevron_right
   └ 或 .switch 开关
```

| 组 | 行 | 控件 | 默认 |
| --- | --- | --- | --- |
| 记账 | 月起始日 | 值 + chevron | 10 日 |
| 记账 | 字体大小 | 值 + chevron | 标准 |
| 记账 | 记账确认音效 | `.switch` | **关** |
| 记账 | 保存后停留在记账页 | `.switch` | 开 |
| 安全 | 应用锁 | `.switch` | 关 |
| 安全 | 隐藏金额 | `.switch` | 关 |
| 外观 | 主题 | 值 + chevron | 素白 |
| 数据 | 备份 / 恢复 / 导出 / 回收站 | 值 + chevron | — |

### 5.1 与产品硬口径的对应

- **基础设置严格等于四项**：月起始日 + 字体大小 + 音效 + 保存后停留。
  其余（应用锁、隐藏金额、主题、数据）属于**扩展设置**，分组上必须与「记账」组分开。
- `sound_enabled` **默认关** —— 上表已按此值画。
- **字体大小三档**：标准 1.00 / 大 1.12 / 特大 1.26（`07-SCREENS.html` 工具条可切三档验证）。

## 6. 开关（`.switch`）

```
.switch{width:48px;height:28px;border-radius:999px;background:line;border:1px solid line;
  position:relative;flex:0 0 48px}
.switch .knob{position:absolute;top:2px;left:2px;width:22px;height:22px;border-radius:50%;
  background:surface;box-shadow:0 1px 2px shadow-1;transition:transform .15s cubic-bezier(.4,0,.2,1)}
.switch.on .knob{transform:translateX(20px)}
```

| 态 | 轨道 | 滑块 | 对比度 |
| --- | --- | --- | --- |
| 关 | `line` | `surface` | 滑块 vs 轨道 ≈ 1.5:1（**靠形状与位置辨态，不靠对比度**） |
| 开 | `primary` | `surface` | `primary #3F3F46` vs `surface #FFFFFF` ≈ **10:1** ✅ |

- 尺寸 **48×28**，滑块 **22**，开位移 **20**（= 48 − 2×2 − 22 − 2）。
- 视觉高 28 < 44 → 由 `::after` 撑 44×44 命中区，**不改变视觉尺寸**。
- ⚠️ 关态「滑块 vs 轨道」对比度天然偏低，因此**选中状态必须同时靠位置与颜色表达**，
  不能只靠颜色（色盲与低视力用户）。

## 7. 中英差异

| 位置 | 中文 | 英文 |
| --- | --- | --- |
| 标题 | 我的 | Profile |
| 承诺 | 隐私承诺 | Privacy promise |
| 组 | 记账 / 安全 / 外观 / 数据 | Ledger / Security / Appearance / Data |
| 月起始日 | 10 日 | Day 10 |
| 字体大小 | 标准 / 大 / 特大 | Standard / Large / X-Large |

最长英文行 `Save and stay on entry page` ≈ 176px，行宽 358 − 右值区 ≈ 250 ✅ 不换行。

## 8. 暗态要点

- `.privacy-strip` 在暗态用 `ok-soft #052E22`（深绿底）+ `ok-ink #6EE7B7`（亮绿字），
  **不是**把亮态浅绿直接压暗 —— 那是「亮态改改当暗态」的典型错法。
- `.switch` 开态在暗态用 `primary #D4D4D8`（浅灰），滑块 `surface #222225` —— 深浅反转但逻辑一致。
- `.panel` 之上再叠 `surface-inset` 的行（如子项）在暗态要**变深**不要变浅。

## 9. 验收点

- [ ] 隐私承诺条在**第一屏可见**，不可折叠
- [ ] 「记账」组严格为四项（月起始日 / 字号 / 音效 / 保存后停留）
- [ ] `sound_enabled` 默认为**关**
- [ ] 开关的开关两态**同时**靠位置与颜色表达，不只靠颜色
- [ ] 三档字号切换后本屏不出现文字截断
- [ ] 暗态 `.privacy-strip` 是独立深绿令牌，不是亮态压暗
- [ ] 无登录 / 账号 / 会员 / 广告入口
