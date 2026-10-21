# 08-01 · 引导（Onboarding）

| 文档属性 | 内容 |
| --- | --- |
| 文档版本 | v3.0 |
| 文档阶段 | 方案设计 · 屏幕规格 |
| 文档状态 | 可执行 |
| 编写日期 | 2026-10-13 |
| 上游输入 | `07-SCREENS.html → screen_guide()` |
| 读者 | 设计师 / 编码 Agent |
| 校对依据 | 高度由 `_build/_probe.py` 实测；本屏只出亮中一张（首启页无暗态差异验收要求） |

---

## 1. 屏幕任务

**首启唯一一屏。** 在 3 秒内说清三件事：这是什么、它不做什么、数据在哪。
然后给一个动作。**不做多步引导、不做滑动分页、不做权限申请**（本地应用无可申请权限）。

## 2. 垂直分区与高度预算

| # | 区块 | 高度 | 弹性 | 说明 |
| --- | --- | --- | --- | --- |
| 0 | `.statusbar` | 47 | 固定 | — |
| 1 | `.guide-top` | 44 | `0 1 auto` | 字标「素记 Plain」15/700 字距 +0.06em |
| 2 | `.guide-h` | 58 | `0 1 auto` | 主张标题 20/600，`margin:30 0 8 2` |
| 3 | `.guide-p` | 27 | `0 1 auto` | 副题 14/400 muted `line-height 1.65` |
| 4 | `.guide-hero` | 115 | `0 1 auto` | 两条 `hairline` 夹一个金额块 |
| 5 | `.featlist` | 204 | `0 1 auto` | 3 条特性，各 `padding:14 0` + `border-top line-soft` |
| 6 | `.guide-foot` | 118 | `margin:auto 0 0` | 主按钮 + 脚注，**被 auto margin 顶到底部** |
| | 内容合计 | ~579 | | 余量由 `.guide-foot` 的 auto margin 吸收 |

- 页面左右内缩 **24**（`.page-guide{padding:0 24px}`），比内容屏的 16 更宽松 —— 引导页只有文字，需要更长的行宽呼吸。
- **无 `.topbar`、无 `.nav`**：首启不给人迷路的入口。

## 3. 信息顺序（这里改过一次）

```
字标 → 主张 → 副题 → 产品实样（金额区）→ 3 条特性 → CTA
```

⚠️ **首版是「字标 → 金额 → 主张 → …」，已返工。**
原因：用户第一次打开时没有数据，一上来看到「本月结余 ¥12,480.00」会以为在看别人的余额。
把主张提到前面、实样放在它后面，读起来才是「一句话说明 → 给你看证据」。
**顺序本身就是信息**，不能因为金额视觉冲击力强就把它放第一位。

## 4. 金额区（区块 4）

```
.hairline      1px line
.hero-label    12/600 字距+0.08em muted   margin:16 0 8 2   「本月结余」
.hero-amt      34/700 tnum                margin:18 0 18    ¥12,480.00
.hairline      1px line
```

两条 `hairline` 把这个金额块**框出来**，但**没有卡片底、没有圆角、没有阴影** ——
用一个区间而不是一个盒子来强调。这是本设计系统里「结构靠线」的标准示范。

## 5. 特性列表（区块 5）

| 图标 | 标题 | 副题 |
| --- | --- | --- |
| `ic_nav_add` | 三秒记一笔 | 只记数字，不填表格 |
| `ic_lock` | 数据只在你手机里 | 没有账号，没有服务器 |
| `ic_palette` | 十套配色，昼夜两态 | 冷底暖点，久看不累 |

```
.feat{display:flex;gap:14px;padding:14px 0;border-top:1px solid line-soft}
.feat svg{color:ink-2;margin-top:1px}          ← 图标中性色，不上品牌色
.fcol{flex-direction:column;gap:3px}
.ft 15/500 ink   .fs 12/500 muted
```

- 三条特性各占一行，**只靠 `line-soft` 分隔**，无卡片、无底板。
- 图标 22px，颜色 `ink-2` —— 引导页的图标是**说明性**的，不该抢色彩的戏。

## 6. CTA（区块 6）

```
.btn.primary   52 高 / r12 / primary 底 / on-primary 字 / 15/600 / 全宽
.foot-note     12/400 muted 居中  line-height 1.5
```

- 文案「开始记账」，点击 → `data-goto="ledger"` 进首页。
- 脚注「数据全部本地存储 · 卸载前请先备份」——**这是免责也是承诺**，必须留。
- 按钮距底 **34**（`.guide-foot{padding:0 0 34px}`）。

## 7. 中英差异

| 位置 | 中文 | 英文 |
| --- | --- | --- |
| 字标 | 素记 Plain | Plain |
| 主张 | 记账，三秒钟的事 | Log it in three seconds. |
| 副题 | 本地存储 · 无广告 · 无理财 | Local only · No ads · No investing |
| CTA | 开始记账 | Get started |

主张标题 20px 英文更长，`line-height 1.4` 下**允许折两行**（已留 `.guide-h` 的 58px 高度余量）。

## 8. 验收点

- [ ] 首启**无权限弹窗、无网络请求、无登录入口**
- [ ] 金额区**没有卡片底/圆角/阴影**，只有两条 `hairline`
- [ ] 特性图标为 `ink-2` 中性色，不是品牌色
- [ ] CTA 距底 34，且随视口高度变化**始终贴底**（`margin:auto 0 0`）
- [ ] 英文主张折两行时，`featlist` 与 CTA 不重叠
