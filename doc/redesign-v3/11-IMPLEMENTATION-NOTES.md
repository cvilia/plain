# 11 · 实现说明（IMPLEMENTATION NOTES）

| 文档属性 | 内容 |
| --- | --- |
| 文档版本 | v3.0 |
| 文档阶段 | 交付 · 落地指引 |
| 文档状态 | 可执行 |
| 编写日期 | 2026-10-13 |
| 上游输入 | `01-tokens.json`、`04-ICON-SYSTEM/`、`05-COMPONENT-SPECS.md` |
| 读者 | 编码 Agent（Flutter 侧） |
| 校对依据 | 字段名与 `plain/lib/app/theme/tokens.dart` 逐一对齐；颜色字节序以 `color_math.dart` 为准 |

---

## 0. 边界

**本轮不写任何 Dart。** 本文只给「令牌 → Dart」「图标 → Flutter」的映射规则与替换清单，
代码由工程侧自行落地。不要直接改动 `plain/` 下任何文件，`redesign-v3/` 是独立交付物。

---

## 1. 颜色：`#RRGGBBAA` → `0xAARRGGBB`（**字节序相反，最易出错**）

`01-tokens.json` 里所有颜色写成 CSS 的 `#RRGGBBAA`；Dart 的 `Color` 是 `0xAARRGGBB`。

| 来源（JSON） | Dart |
| --- | --- |
| `#F5F5F6FF` | `Color(0xFFF5F5F6)` |
| `#3F3F461F`（alpha = 0x1F） | `Color(0x1F3F3F46)` |
| `#00000052`（overlay） | `Color(0x52000000)` |

⚠️ **不要写正则一把梭**。必须**按段解析**后重排：

```
#RRGGBBAA  →  AA 移到最前  →  0xAARRGGBB
```

若直接把 `#3F3F461F` 去掉 `#` 补 `0xFF` 前缀，会得到 `0xFF3F3F461F`（10 位，报错）
或截断成 `0xFF3F3F46`（**丢掉透明度**，按下态/遮罩全变实心）。

### 1.1 生成建议

在 `gen_tokens.py` 里同时输出一份 `tokens.dart.inc`（不写进 `plain/`，只作对照），
让工程侧**机读**而非手抄。53 字段 × 20 组合 = **1060 个色值**，手抄必错。

---

## 2. 令牌 → `AppTokens` 字段名对齐

`01-tokens.json → resolved` 的 **53 个字段名与 `tokens.dart` 逐一对齐**，已脚本双向比对：

```
dart 53 / json 53
json 有、dart 没有: []      ← 空
dart 有、json 没有: []      ← 空
```

**所以可以直接机读替换，不需要人工核对字段名。** 53 个字段的真实分组：

| 分组 | 字段数 | 字段 |
| --- | --- | --- |
| 中性层 | **11** | `bg` `appBg` `surface` `surface2` `ink` `ink2` `muted` `faint` `line` `lineSoft` `frame` |
| 品牌主色 | 4 | `primary` `primaryDeep` `primarySoft` `primaryTint` |
| 品牌强调 | 4 | `accent` `accentDeep` `accentSoft` `accentGrad` |
| 派生 | 4 | `onPrimary` `onAccent` `primaryInk` `accentInk` |
| 收入 | 4 | `income` `incomeSoft` `incomeLine` `incomeInk` |
| 状态 | 6 | `okSoft` `okInk` `warnSoft` `warnInk` `dnBg` `dnInk` |
| FAB | 3 | `fabBg` `fabFg` `fabIc` |
| 图表/浮层 | 4 | `toastBg` `chartTrack` `barFill` `dash` |
| 辉光 | 2 | `glowPrimary` `glowAccent` |
| Hero 渐变 | **6** | `heroCard0` `heroCard1` `heroGrad0` `heroGrad1` `heroDarkGrad0` `heroDarkGrad1` |
| 阴影 | **5** | `shadow1` `shadow2` `shadow3` `shadowAccent` `shadowPrimary` |
| | **53** | |

⚠️ 三处容易搞错：

1. **`frame` 在中性层里，不是"边框"** —— 它是页面最外层的底衬色，别当成 `line` 的别名。
2. **Hero 渐变 6 个字段**（`heroGrad0/1`、`heroDarkGrad0/1`、`heroCard0/1`）——
   本 v3 方向**明确不用 Hero 渐变**（趋势是「零光晕、零渐变」），故 `07-SCREENS.html` 里
   **这 6 个字段不被消费**。它们在令牌里保留是为兼容，**不是给新界面用的**。
3. `accentGrad` 的类型是 **`Gradient`**，不是色值 —— 转 Dart 时不要按 `Color` 解析。

### 2.1 `v3Additions`：10 个「代码侧还没有」的新令牌

`01-tokens.json → v3Additions` 是**本方向新增、`AppTokens` 里尚不存在**的 10 个字段：

| 字段 | 用途 |
| --- | --- |
| `lineStrong` / `lineStrongSoft` | 输入框描边、次按钮描边（比 `line` 更可见） |
| `focusRing` | 焦点环，需 ≥3:1 |
| `surfaceInset` | 凹槽底（分段控件槽、按下态） |
| `disabledFg` / `disabledBg` | 禁用态，**用色值而不是 `opacity`** |
| `overlay` | 弹层遮罩 |
| `skeleton` | 骨架屏底 |
| `primaryPressed` / `accentPressed` | 按下底，由 `pressed_fill()` 反方向位移推出 |

⚠️ 这 10 个已经在 `07-SCREENS.html` 里以 CSS 变量形式全部消费（`--line-strong` … `--accent-pressed`），
**但 `AppTokens` 里没有** → 落地时是「补字段」而非「改字段」，不会破坏现有构造调用。
见 §7 代码侧缺口。

### 2.2 ⚠️ 交付值与代码值的差异（**落地前必读**）

字段名对齐 ≠ 值相同。`resolved` 里的 53 个字段**名字与代码一致，但中性层的值被刻意改过**。
改动范围已量化（脚本 `_build/_probe_drift.py`，只读）：

| 项 | 代码侧 | 交付侧 | 是否一致 |
| --- | --- | --- | --- |
| 字段名 | 53 | 53 | ✅ **零差异** |
| 品牌种子 `primary`/`accent`（10 主题 × 亮暗 = 20 组） | `theme_registry.dart` | `resolved` | ✅ **零差异** |
| tone 分组 | cool 7 / warm 2 / neutral 1 | cool 7 / warm 2 / neutral 1 | ✅ **零差异** |
| 中性层 10 个字段的值 | `_toneLight` / `_toneDark` | v3 去暖版 | ⚠️ **已改**（见下） |

**唯一改动的是中性层，且只有一件事：去暖。**

| tone | 代码 `bg` 的 R−B | 交付 `bg` 的 R−B | 主题数 |
| --- | --- | --- | --- |
| `cool` | −2 | −2 | 7（青瓷/靛蓝/竹青/海盐/藕荷/桃夭/绯樱） |
| `warm` | **+14** ← 米黄 | **+3** | 2（杏黄/豆绿） |
| `neutral` | **+2** | **−1** | 1（素白） |

同时把三个 tone 的 `surface` 统一为**纯白 `#FFFFFF`**（代码侧是 `#FCF8F1` / `#FAFAF8` / `#F8FAF9`，各自带一点底色的色相）。

> **为什么必须改**：代码侧 `warm` 的页面底是 `#F6F1E8`、面板是 `#FCF8F1` —— 两个都是米黄，
> 只是深浅差一点。这就是「米黄叠米黄、面板与页面分不开」的**代码侧根因**，
> 也是上一版被否决的第一条。改成「页面留 3 度暖、面板纯白」后分离感立刻出来。
>
> ⚠️ **注意这个差是门禁查不出来的**：`layerstep` 只看明度比（改前 1.063 / 改后 1.080，
> 两者都 ≥1.02 都「通过」）。**问题在色相重复，不在明度**。
> 所以落地后若有人为了「好看一点」把 `surface` 从 `#FFFFFF` 改成 `#FDFCFA`，门禁不会报警，
> 但毛病会原样回来 —— 这是本交付最需要守住的一条（见 `README.md` 风险 1）。

---

## 2b. `AppTokens` 字段数：**53**，不是 48

文档（含 `12-设计规范系统.md`）曾写「48 字段」，**实为 53**。数法很重要：

- ✅ 数**构造函数里 `this.xxx` 的个数** → 53
- ❌ 数「字段声明」→ 会数成 22（声明处一行可以写多个 `final Color a, b, c;`）

若将来令牌变动，重跑上面那段双向比对脚本即可，**不要凭记忆改分组表**。
见《10-CHANGELOG》待拍板 **T-1**。

---

## 3. 颜色派生：**不要自己发明亮度算法**

`01-tokens.json` 的值是用 `_build/plain_color.py` 复现 `plain/lib/app/theme/color_math.dart` 算出来的，
函数逐一对齐：

| Python（本交付） | Dart（工程） | 用途 |
| --- | --- | --- |
| `hx()` / `contrast()` | 同名 | 解析与 WCAG 对比度 |
| `mix(a, b, t)` | `Color.lerp` 语义 | **sRGB 分量线性插值** |
| `composite(fg, alpha, bg)` | source-over 合成 | 半透明叠底 |
| `ink_for(fg, bg, target)` | `inkFor` | 找达标前景 |
| `pick_on(deep, target)` | `pickOn` | 按钮上的标签色 |
| `ink_for_layers(fg, bgs, target)` | `inkForLayers` | 对**多个宿主**都达标 |
| `accent_sheen` / `hero_safe` | 同名 | 品牌色变体 |

⚠️ **`mix` 必须是 sRGB 分量上的线性插值**，不是 HSL/OKLab 的插值。
用 HSL 会得到与浏览器/Flutter 合成结果**不一致**的颜色 —— 对比度门禁的结论随之失效。
（本交付的第一版就写错了 HSL 版本，已整文件重写为位对齐实现。）

⚠️ **`fabIc` 不能直接用 `accent`**：10 个主题 **10/10 不达标**，最差 **1.00:1**。
必须走 `inkFor(accent, fabBg, 3.0)`。**只验默认主题 `subai` 是看不出来的** ——
令牌一改必须 10 主题 × 2 亮度全跑。

---

## 4. 图标 → Flutter：两条路线

> **✅ 已拍板：走路线 B（`flutter_svg`）。** 落地链路：
> `redesign-v3/_build/gen_icons.py`（作图） → `plain/tool/import_icons_to_assets.py`（同步 SVG 到 `assets/icons/`）
> → `plain/tool/gen_icons_abs.py`（产 `plain/lib/design_system/plain_icons_v3.dart`）。
> 旧的 `PlainIcons` 字体、`assets/fonts/plain_icons/`、`lib/design_system/plain_icons.dart`
> 与 `pubspec.yaml` 的字体声明**已全部删除**。路线 A 保留为历史记录（含踩坑细节）。

### 路线 A：转图标字体（历史方案，未采用）

- `04-ICON-SYSTEM/icons.json` 已给 **`codepoint`（`0xE001`–`0xE054` 连续）**，可直接生成 `IconData`。
- 生成 `PlainIconsV3` 常量类 + `ref → IconData` 映射表。
- ⚠️ **`hmtx.lsb` 必须等于 `glyf.xMin`**。不等时，凡尊重 `lsb` 的渲染器
  （FreeType、`fontTools.getGlyphSet()`、**Chrome 与 Flutter 共用的一套字体后端**）
  会按 `lsb - xMin` 平移轮廓。实测过一枚返回箭头**整体左移 7.20 格（24 网格）**，
  在 App 里 `Icon()` 会贴在图标盒左边缘。
  → 生成后用**全量逐枚**比对「字体渲染」与「SVG 渲染」的内容框位置，别抽查。
- ⚠️ 加图标后必跑一次 `verify_icons.py` 量光学尺寸。SVG 已统一 24 网格 / 1.75 描边，
  字体化时注意 **upm 取 1000、ascent 1000**，这样「一个字形盒 == 一个 `Icon(size)` 盒」。

### 路线 B：`flutter_svg` 直读 SVG

- 直接消费 `04-ICON-SYSTEM/svg/*.svg`，保真度最高、支持任意 `currentColor`。
- 代价：图标多时解析开销与包体积上升；需要预编译（`vector_graphics`）。

| | 路线 A 字体 | 路线 B SVG |
| --- | --- | --- |
| 与 `Icons.*` 同构 | ✅ | ✗ |
| 保真 | 需校验 lsb | ✅ 原生 |
| 体积 | 一个字体文件 | 84 个文件 |
| 多色 / 细粒度动画 | ✗ | ✅ |

**结论**：编码侧已选 **B**（`flutter_svg`）—— 保真原生、支持 `currentColor`，100 枚的解析开销可接受。
最终由工程侧拍板（见《10-CHANGELOG》**T-3**）。

### 4.1 ⚠️ 内联 SVG sprite 的 `fill` 坑（本轮踩过，务必带到实现）

把 SVG 内联成 `<symbol>` 时，**根 `<svg>` 上的 `fill="none"` 会丢**。
SVG 默认 `fill` 是 **black**，于是**每一枚含闭合路径的图标都会被填成实心黑块**；
只有纯开放路径的图标（如导航的几条线）侥幸正常，**肉眼极易漏过**。

**对策**：
1. 生成器里给 `<symbol>` 显式加 `fill="none"`；
2. 加**断言** —— 源文件缺 `fill="none"` 直接报错，不静默出黑块；
3. 自检：`grep -c 'viewBox="0 0 24 24" fill="none"' 07-SCREENS.html` 应等于 **84**。

Flutter 侧同理：若用任何「提取 SVG 内部内容」的转换流程，都要确认 `fill: none` 被保留。

---

## 5. 排版落地

```dart
// 全站 MiSans；金额靠 tabularFigures 对齐，不靠换字体
const kNumFamily = 'MiSans';
const kUiFamily   = 'MiSans';
const kUiFallback = ['Inter', 'HarmonyOS Sans SC', 'PingFang SC', 'Noto Sans CJK SC'];

// ⚠️ 金额渲染必须带 tabularFigures
// MiSans 的 '1' 只有 '0' 的 63% 宽（403 vs 634 / 1000），不开 tnum 小数点对不齐
TextStyle amountStyle(TextStyle base) =>
    base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
```

### 5.1 字体资产

- 交付副本：`12-FONTS/MiSans-{Regular,Medium,Semibold,Bold}.ttf`（6.34 MB）。
- 工程已有：`plain/assets/fonts/misans/`。**两者须逐一 sha256 相等**（见 `12-FONTS/README.md` §4）。
- ⚠️ **不要用上游原版 MiSans 覆盖** —— 工程内 4 个字重的
  `usWeightClass` / `fsSelection` / `head.macStyle` 已被 `build_fonts_misans.py` 规范化改写过，
  上游原文件的字重刻度非标准，覆盖后 500/600 会落到错误档。

### 5.2 字阶（8 级封闭）

`amount-input 44` / `amount-xl 34` / `amount-l 22` / `amount-s 15` /
`title 20` / `heading 15` / `body 14` / `caption 12`

- 行高是**语言的函数**：`height = lang == 'zh' ? 1.65 : 1.45`（`body`）。
  这是全系统唯一一处「同一个值有两个数」。
- 字号三档：标准 1.00 / 大 1.12 / 特大 1.26，**只对字号列做 `round(size × k)`**，
  行高比、字距 em、字重全部不变。
- ⚠️ **金额区宽度硬约束（实测）**：`¥99,999,999.99` @ MiSans 600 tnum
  = 标准 316.14 / 大 354.10 / 特大 **398.26**，可用宽 **358**。
  → 规则是**向下取到放得下的一档**，**绝不截断**。

---

## 6. 组件替换清单

| 原有 | 换成 | 备注 |
| --- | --- | --- |
| `Material` `ElevatedButton` | `.btn.primary` 规格 | 52 高 / r12 / 无 elevation |
| `OutlinedButton` | `.btn2` | 44 高 / 1px `lineStrong` |
| `Card` | `.panel` | r16 / `surface` / **1px `line`**，不用 elevation |
| `ListTile` | `.row` / `.crow2` | min-60 / 72，`line-soft` 分隔，**无前置淡彩底板** |
| `Switch` | `.switch` | 48×28 / 滑块 22 / 位移 20；**关态靠位置不只靠色** |
| `TabBar` | `.seg` / `.ttabs` | seg 36（命中区 44）/ ttab 44 |
| `SnackBar` | `.toast` | `toastBg` + 12/500，见 `05` §15 |
| `Dialog` | `.dialog` | r24 + `overlay`，见 `05` §16 |
| `Icon(Icons.*)` | `04-ICON-SYSTEM` | 100 枚，**不用 Material Icons** |
| `Container(decoration: BoxShadow…)` | `shadow-1/2/3` | ⚠️ 亮态是**暖黑** `rgba(48,41,30,·)`，不是纯黑 |

⚠️ **`tokens.shadow1/2/3` 是纯黑旧值**，与 `01-tokens.json` 的暖黑不同，别混用。
新建 `shadows.dart` 时注意：`painting.dart` **不导出 `Brightness`**，参数收 `bool isDark`。

---

## 7. 需要补的代码侧缺口

依据是 `plain/lib/app/theme/` 与 `plain/lib/design_system/` 的**当前实况**（非文档转述）。

| 缺口 | 说明 |
| --- | --- |
| `AppTokens` 缺 | 上面 §2.1 的 **10 个 v3 新字段**：`lineStrong` `lineStrongSoft` `focusRing` `surfaceInset` `disabledFg` `disabledBg` `overlay` `skeleton` `primaryPressed` `accentPressed` |
| `AppColors` 缺 | `faint`（`AppTokens` 已有，`AppColors` 没有） |
| `Spacing` 缺 | `hair`、`xl5`、`xxxl` |
| `Radii` 缺 | `xs`、`xl`；且 `sm` 是 8 而令牌是 **9**，需对齐 |
| `motion` | **完全没有** → 新建 `motion.dart`，类名用 **`MotionDurations`**（`Durations` 与 material 同名类冲突） |
| `shadows` | 亮态投影应为**暖黑** `rgba(48,41,30,·)`，而 `tokens.shadow1/2/3` 是纯黑旧值。新建 `shadows.dart` 时注意 `painting.dart` **不导出 `Brightness`**，参数收 `bool isDark` |

> 已存在、可直接复用的：`plain/lib/design_system/` 下多个文件，
> 含 `plain_icons_v3.dart`（图标绑定，**生成物**）、`category_icons.dart`（ref 清单）、
> `category_icon_v3.dart`（ref → 图标 + 分类色）、`category_avatar.dart`、`amount_text.dart`、
> `plain_back_button.dart`、`donut_chart.dart`、`app_toast.dart`、`confirm_dialog.dart` 等。
> 其中 `plain_icons_v3.dart` 是**生成物**，不进代码评审；旧 `plain_icons.dart` **已删除**。

---

## 8. 历史硬约定（继续有效）

- **颜色与图标此后以本目录 `redesign-v3/` 为唯一准。**

  ⚠️ **实地核实（2026-10-13）**：以下路径**当前已不存在**，任何文档再引用它们即断链：

  | 曾存在 | 现状 |
  | --- | --- |
  | `redesign/flutter/` | **已删除**，不要复活 |
  | `ui-kit/` | **不存在**（原含 00-foundation 令牌与图标真值、`_build/` 出图管线） |
  | `redesign/screens/` | **不存在** |
  | 文档 `15-MiSans字体接入说明.md` | **不存在**（字体口径已收进 `02-TYPE-SYSTEM.md`） |
  | 文档 `16-UI资源使用说明.md` | **不存在**（落地口径已收进本文） |
  | 文档 `17-交给编码Agent的执行指南.md` | **不存在**（落地顺序已收进本文 §9） |

  ⚠️ **追加核实（2026-10-14）**：图标确定走路线 B 后，以下**旧字体方案产物已删除**，同样不要复活：

  | 曾存在 | 现状 |
  | --- | --- |
  | `plain/lib/design_system/plain_icons.dart` | **已删除**（323 枚 `IconData`，零外部引用） |
  | `plain/assets/fonts/plain_icons/PlainIcons.ttf` | **已删除**（78 KB） |
  | `plain/pubspec.yaml` 的 `PlainIcons` family 声明 | **已删除**（含 `assets/fonts/plain_icons/` 目录） |
  | `plain/tool/gen_plain_icons_v3.py` | **降级为废弃存根**（跑它会报错退出，不写盘） |

  取而代之：`plain/lib/design_system/plain_icons_v3.dart`（`flutter_svg` 绑定，生成物）+
  `plain/assets/icons/ic_*.svg`（整目录打包，只放 SVG）。

  仍然存在、可继续引用的：`01`–`14`、`18-UI视觉重构指令.md`、`HANDOFF.md`、
  `assets/`、`图标方案/`、`plain/`。**令牌与图标真值一律取本目录**，不要再回查旧路径。
- **分类只改 `name`，不改 `key`**（预置 id = 运行时 `preset_${key}`）。
  `seedPresetCategories` 只在表为空时播种 → **预置清单调整只对新装生效**。
- **分类备注（`categories.note`）≠ 账单备注（`transactions.note`）**：
  字段、组件、生命周期都不同，禁止共用、禁止互相引用。
- `AppTokens` 按 **53 字段**对齐；`kSchemaVersion = 3`；`Money.maxCents = 9999999999`。
- 编号是**跨文档外部引用契约**，新增条目**追加末尾，不插队**。

---

## 9. 落地顺序建议

1. **令牌**：按 §1 生成 `tokens.dart.inc`，机读替换 53 字段 → 跑 1168 项门禁复验。
2. **字体**：确认 `12-FONTS/` 与 `plain/assets/fonts/misans/` sha256 一致；补 `tabularFigures`。
3. **图标**：已拍板走**路线 B**（`flutter_svg`）—— 按 `_build/gen_icons.py` → `import_icons_to_assets.py` → `gen_icons_abs.py` 三步重跑即可；旧字体路线已废弃。
4. **组件**：按 §6 逐项替换，先做按钮 / 行 / 面板 / 开关四类（覆盖 8 屏 80% 面积）。
5. **屏幕**：按 `08-SCREENS-SPEC/` 逐屏实现，验证顺序 = 高度预算 → 中英 → 亮暗。
