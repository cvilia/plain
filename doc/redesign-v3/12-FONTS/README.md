# 12 · 字体（FONTS）

本目录是 **MiSans 4 字重的交付副本**，供 `07-SCREENS.html` 与后续高保真页面离线加载。

| 文件 | 字重 | `OS/2.usWeightClass` | 大小 |
| --- | --- | --- | --- |
| `MiSans-Regular.ttf` | Regular | 400 | 1.63 MB |
| `MiSans-Medium.ttf` | Medium | 500 | 1.63 MB |
| `MiSans-Semibold.ttf` | Semibold | 600 | 1.62 MB |
| `MiSans-Bold.ttf` | Bold | 700 | 1.61 MB |

合计 6.34 MB。**禁 CDN，本地文件加载。**

---

## 1. 授权

MiSans 由小米发布，采用**小米官方免费商用授权**（随 MIUI 字体开放），允许：

- 商业与非商业使用
- 本地打包进应用、随产品分发
- 修改与再分发（需保留授权说明）

**不需要付费、不需要署名前置、不限制分发渠道。** 本工程选择它正是因为「免费可商用 + 本地打包 + 无 CDN」。

> ⚠️ 授权条款由小米单方面发布，**上线前建议再核对一次官方最新文本**。
> 若后续条款收紧，替代顺序：HarmonyOS Sans（华为，同为免费商用）→ 思源黑体 Noto Sans SC（SIL OFL 1.1）。
> 替代字体必须重新验证 §3 的两项数值。

---

## 2. 为什么是 MiSans（实测，非偏好）

落笔前用 `fontTools` 直读仓库内 4 个 TTF，事实如下：

| 检查项 | 结果 |
| --- | --- |
| 字重刻度 | 400 / 500 / 600 / 700 ✅ 标准刻度，可做硬层级 |
| GSUB 特性 | 含 `pnum` + **`tnum`** ✅ 有等宽数字 |
| 货币符号 | `¥` = `$` = 578/1000 ✅ 存在且宽度合理 |
| upm | 1000 ✅ 与 24 网格图标可互算 |

对比之下，**Inter 在本机与仓库内均不存在**，引入它需要新增打包约 450 KB；
而 MiSans 已经打包、已经被工程引用、且 tnum 齐备 —— 因此 Inter 在字体栈中**降级为可选增强**，
排在 MiSans 之后（目标机若装了 Inter 才会命中）。

详见 `02-TYPE-SYSTEM.md` §1。

---

## 3. 两条必须遵守的数值

### 3.1 数字是比例宽度 —— 必须开 tnum

| 字符 | Regular 宽度 | tnum 开启后 |
| --- | --- | --- |
| `0` | 634 | 594 |
| `1` | **403** | 594 |
| `8` | 630 | 594 |

`1` 比 `0` 窄 **36%**。不开 tnum 时两行金额的小数点会错位。

- **CSS**：`font-variant-numeric: tabular-nums; font-feature-settings: "tnum" 1;`
- **Flutter**：`fontFeatures: const [FontFeature.tabularFigures()]`

`07-SCREENS.html` 已在 `html,body` 上**全站开启**。`tnum` 只作用于 `0-9` 与相关标点，
**不影响任何汉字**，因此全局开启没有副作用。

### 3.2 字重刻度是改写过的 —— 不要用上游原文件替换

工程内这 4 个字重的 `usWeightClass` / `fsSelection` / `head.macStyle`
已被构建脚本（`plain/tool/build_fonts_misans.py`）**规范化改写**过，
使 CSS `font-weight: 500/600/700` 能精确命中。

> ⚠️ **不要从上游下载原版 MiSans 覆盖本目录** —— 上游字重刻度非标准，
> 覆盖后 500/600 会落到错误的档，层级关系垮掉。

---

## 4. 同步义务

本目录是 `plain/assets/fonts/misans/` 的**副本**。

工程侧若重新生成字体，**必须同步覆盖本目录 4 个文件**。校验方式：

```bash
# 两侧 sha256 应逐一相等
sha256sum plain/assets/fonts/misans/MiSans-*.ttf redesign-v3/12-FONTS/MiSans-*.ttf
```

`07-SCREENS.html` 的 `@font-face` 使用**双 src 回退**：

```css
src: url("12-FONTS/MiSans-Regular.ttf") format("truetype"),      /* 交付自包含优先 */
     url("../plain/assets/fonts/misans/MiSans-Regular.ttf") …;   /* 仓库路径兜底 */
```

因此「单独打包 redesign-v3」与「留在原仓库」两种情况都能正常加载。
若把 redesign-v3 单独分发，**本目录必须一起打包**，否则回退到仓库路径会 404。

---

## 5. 未收录字符

MiSans 的字符集覆盖 GB2312 + ASCII + 常用 UI 符号。以下类型会**逐字回退系统字体**：

- 生僻汉字（GB2312 外）
- 部分符号：`⚠ ↔ ◦ ✔ ✗` 等
- Emoji（本设计系统**禁止使用 emoji 作图标**）

回退只影响该字符的观感，不影响布局骨架。**图标一律走 `04-ICON-SYSTEM`，不依赖字体字符。**
