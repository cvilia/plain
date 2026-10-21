# 04 · 图标系统规范（ICON SPEC）

| 文档属性 | 内容 |
| --- | --- |
| 文档版本 | v3.0 |
| 文档阶段 | 方案设计 · 图标语言 |
| 文档状态 | 可执行 |
| 编写日期 | 2026-10-13 |
| 上游输入 | 《03-SPACING-GEOMETRY》§10；《00-DESIGN-BRIEF》§4 第 11 条 |
| 读者 | 设计师 / 编码 Agent |
| 校对依据 | `icons.json` **119** 条与 `svg/` **119** 个文件一一对应（2026-10-19 精简后复核：0 缺失）；码位自 `0xE001` 起，删条处留空号 |

> ⚠️ **2026-10-19 分类图标精简（爸爸拍板）**：支出默认一级分类定为 **30 个、一一对应 30 枚**图标，
> 分类图标从 100 枚裁到 **31 枚**（30 支出 + 收入「红包」），总图标 188 → **119**。
> · 未用的 69 枚源 SVG 已移到 `04-ICON-SYSTEM/_unused/svg/`（可逆，`import_icons_to_assets.py` 不会拷它）；
> · `icons.json` 同步删条（备份：`icons.json.bak-20261019`），码位不再连续（已删条目的码位空着，不复用）；
> · `gen_icons.py` 仍是 12 枚 category 的旧口径，**不要重跑**。 |

---

## 1. 作图语言（无例外）

| 项 | 值 | 说明 |
| --- | --- | --- |
| 画布 | **24 × 24** | `viewBox="0 0 24 24"`，width/height 与使用尺寸一致 |
| 内容盒 | **[2, 22]**（20 × 20） | 所有路径坐标落在这个区间内 |
| 描边 | **1.75** | 居中描边 → 实际着色范围 `[1.125, 22.875]`，四边光学留白 1.125 |
| 端点 | `stroke-linecap="round"` | 圆头 —— 这是本套图标「安静」的来源：没有一个锐利断口 |
| 拐角 | `stroke-linejoin="round"` | 同上 |
| 填充 | `fill="none"` | **唯一例外**：点状元素（分类圆点、省略号、关节）用 `<circle fill="currentColor" stroke="none" r="1.5">` |
| 颜色 | `currentColor` | 图标文件里**不出现任何具体色值** |
| 圆角矩形 | 一律用 `<rect rx>` | 禁止手写贝塞尔弧 —— 曲率不一致会让「一套语言」变成「一锅拼盘」 |

### 1.1 常用构件（保持跨图标一致）

| 构件 | 规格 |
| --- | --- |
| 大圆 | `r = 8.5`（圆心 12,12） |
| 中圆 | `r = 6.25` / `r = 5` / `r = 4.25` |
| 小圆（旋钮、旋钮孔） | `r = 3.5` / `r = 3.25` / `r = 2.75` / `r = 2.25` |
| 圆点 | `r = 1.35`（分类点）/ `1.5`（关节、点）/ `1.6`（省略号）/ `1.05`（提示号内点） |
| 面板圆角（20 尺寸） | `rx = 2.5` / `2.75` / `3` |
| 面板圆角（10–14 尺寸） | `rx = 1.75` / `1.5` / `1` |
| 直线 | 水平 / 垂直 / 45° 三种；**没有任意角度斜线**（唯一例外：回形针与撤销箭头，本身是曲线语义） |

### 1.2 光学重量一致

- 所有图标**只有一种线重**（1.75），没有「主结构 2px + 细节 1.5px」的分层。
  这样做在 20–24px 时最稳，代价是细节多的图标（如相机、指纹）显得略密 —— 已通过减少细节解决。
- **圆形做视觉补偿**：纯圆形图标（如 `ic_status_info`）用 `r = 8.5`，
  方形图标（如 `ic_cat_other`）用 15 × 15 的外框 —— 圆的直径比方的边长大约 6%，视觉上才等大。
- 逐枚自检方式：`_build/gen_icons.py` 生成 `_build/sprite.html`，用无头 Chrome 出 PNG
  贴图**全量肉眼过一遍**（首轮 84 枚已过；2026-10-14 末尾追加的 16 枚见 §2 统计，同样全量过图）。

> ⚠️ **`gen_icons.py` 只覆盖 12 枚 category**：现有 31 枚分类图标里，其余 19 枚是
> `_tmp_gen_cat_icons_*.py` 直写 SVG + 追加 `icons.json` 的 category 段生成的。
> 直接重跑会删光 `ic_*.svg` 再只重建旧集合，并重写 `icons.json` 丢掉其余条目。
> 2026-10-19 已加 `_guard_no_overwrite()` 硬闸：检测到孤儿图标即 `exit 2`，
> 要真跑需 `--force` 或先把它们补进 `ICONS`。

---

## 2. 命名与码位

| 项 | 规则 |
| --- | --- |
| 文件名 | `ic_<组>_<名>.svg` 或 `ic_<名>.svg`；全小写 + 下划线 |
| 组前缀 | `ic_nav_*` 导航 / `ic_cat_*` 分类 / `ic_status_*` 状态 / `ic_chart_*` 图表 / 其余为操作与通用 |
| 码位 | 自 **`0xE001`** 起；2026-10-19 精简后共 **119** 枚，删条的码位留空不复用 |
| 码位稳定性 | ⚠️ 本轮为**全新一套造型**，与旧 `PlainIcons` **无继承关系**。映射表以此 `icons.json` 为准，不承诺与旧字体一致 |
| 增补规则 | 新图标**只能追加末尾**，不得插入中间（会移动后续所有码位） |

**分类统计（100 枚）**

| 组 | 数量 | 成员 |
| --- | --- | --- |
| 导航 `nav` | 5 | `ic_nav_ledger` `ic_nav_report` `ic_nav_add` `ic_nav_assets` `ic_nav_profile` |
| 分类 `category` | 12 | `ic_cat_food` `ic_cat_grocery` `ic_cat_shopping` `ic_cat_daily` `ic_cat_transport` `ic_cat_housing` `ic_cat_telecom` `ic_cat_entertainment` `ic_cat_medical` `ic_cat_study` `ic_cat_social` `ic_cat_other` |
| 操作 `op` | 27 | 首批 19：`ic_back` `ic_chevron_right` `ic_chevron_left` `ic_chevron_down` `ic_close` `ic_search` `ic_filter` `ic_edit` `ic_delete` `ic_check` `ic_plus` `ic_minus` `ic_more` `ic_more_vertical` `ic_share` `ic_undo` `ic_sort` `ic_drag_handle` `ic_scan`<br>2026-10-14 追加 8：`ic_chevron_up` `ic_circle_plus` `ic_circle_minus` `ic_play` `ic_list_check` `ic_merge` `ic_folder_plus` `ic_folder_move` |
| 状态 `status` | 9 | 首批 8：`ic_status_success` `ic_status_error` `ic_status_warning` `ic_status_info` `ic_lock` `ic_offline` `ic_empty` `ic_loading`<br>追加 1：`ic_mood` |
| 记账 `entry` | 13 | 首批 12：`ic_calendar` `ic_account` `ic_note` `ic_amount` `ic_transfer` `ic_budget` `ic_recurring` `ic_export` `ic_import` `ic_attachment` `ic_goal` `ic_receipt`<br>追加 1：`ic_history` |
| 图表 `chart` | 5 | `ic_chart_pie` `ic_chart_bars` `ic_chart_line` `ic_trend_up` `ic_trend_down` |
| 通用 `ui` | 29 | 首批 23：`ic_settings` `ic_bell` `ic_moon` `ic_sun` `ic_palette` `ic_font` `ic_volume` `ic_qr` `ic_copy` `ic_star` `ic_tag` `ic_shield` `ic_fingerprint` `ic_storage` `ic_image` `ic_camera` `ic_eye` `ic_eye_off` `ic_cloud` `ic_wallet` `ic_card` `ic_arrow_up_right` `ic_arrow_down_left`<br>追加 6：`ic_gift` `ic_trophy` `ic_flame` `ic_celebration` `ic_cloud_upload` `ic_cloud_download` |

**分类图标 ↔ 分类 iconRef 映射**（`categoryColorMap` 按 iconRef 键控，配色不随改名漂移）

| iconRef | 一级分类 | 图标 |
| --- | --- | --- |
| `food` | 餐饮 | `ic_cat_food` |
| `fruit` | 食材 | `ic_cat_grocery` |
| `shopping` | 购物 | `ic_cat_shopping` |
| `daily` | 日用 | `ic_cat_daily` |
| `transport` | 交通 | `ic_cat_transport` |
| `housing` | 居住 | `ic_cat_housing` |
| `telecom` | 通讯 | `ic_cat_telecom` |
| `entertainment` | 娱乐 | `ic_cat_entertainment` |
| `medical` | 医疗 | `ic_cat_medical` |
| `study` | 学习 | `ic_cat_study` |
| `social` | 人情 | `ic_cat_social` |
| `other` | 其他 | `ic_cat_other` |

---

## 3. 状态着色规则

图标本身只有 `currentColor`，**颜色由容器给**。四态规则：

| 状态 | 颜色 token | 不透明度 | 说明 |
| --- | --- | --- | --- |
| **默认（导航未选中）** | `muted` | 1.0 | 未选中的 Tab、次要操作 |
| **默认（内容区图标）** | `ink2` | 1.0 | 列表行、设置项、属性栏 |
| **选中** | `primaryInk` | 1.0 | 选中 Tab；分类色场景改用 `categoryInk` |
| **按下** | 同选中色 | 1.0 + 容器叠色 | **图标不换色**，由容器的按压反馈承担（见《06》） |
| **禁用** | `disabledFg` | 1.0 | ⚠️ **不用 `opacity`** —— 半透明叠加会让对比度不可测，改用算好的 `disabledFg` token |
| **分类色场景** | `categoryInk[iconRef]` | 1.0 | 只用于：环形图图例、分类格选中态、分类管理列表 |
| **分类色圆点** | `categoryColor[iconRef]` | 1.0 | 列表行左侧 6px 圆点、图例色点 —— **这是分类基色唯一允许的用法** |

**禁止**：
- 不给图标加底板色块（上一版「淡彩圆角方块托图标」已否决）。
- 不用 `categoryColor` 直接给图标描边（对比度不足，必须用 `categoryInk`）。
- 不用 emoji / 汉字 / 图片代替图标。
- 不混入 Material Icons 或旧 `PlainIcons` 造型 —— 混用即视为交付不合格。

---

## 4. 尺寸与用法

| 尺寸 | 用途 |
| --- | --- |
| **16** | 行内（紧跟文字的小提示、Chip 内） |
| **20** | 控件内（按钮、输入框前后缀、列表行尾部） |
| **22** | 底部导航、返回键 |
| **24** | 分类宫格、设置项、区块标题 |
| **40** | 空态主图形、对话框顶部 |
| **56** | 引导页、大空态 |

**对齐**：图标容器尺寸 = 视觉尺寸，但要按「一条左线」对齐时，容器比视觉尺寸**左右各小 2dp 的补偿**在居中对齐场景不需要；只有与文字并排时才用 baseline 对齐（见《03》§7）。

---

## 5. 从 SVG 到 Flutter（两条路，二选一）

> **✅ 已拍板：走路线 B（`flutter_svg`）。** 落地形态如下，路线 A 的步骤保留为历史记录。
>
> | 项 | 落点 |
> | --- | --- |
> | 作图源 | `redesign-v3/04-ICON-SYSTEM/svg/ic_*.svg`（`_build/gen_icons.py` 产出） |
> | 打包 | `plain/assets/icons/ic_*.svg`（`plain/tool/import_icons_to_assets.py` 同步，**整目录打包，别往里放别的东西**） |
> | Flutter 绑定 | `plain/lib/design_system/plain_icons_v3.dart` —— `PlainIconData`（119 枚常量 + `byName`）+ `PlainIcon` 包 `SvgPicture.asset`；`size` 传 `null` 时跟随 `IconTheme.of(context).size`，与 `Icon` 语义一致 |
> | 生成脚本 | `plain/tool/gen_icons_abs.py`（**只产常量绑定，不再预解析 path、不产 `IconOp` / `CustomPaint`**） |
> | 已删除 | 旧 `PlainIcons` 字体（323 枚）、`assets/fonts/plain_icons/`、`lib/design_system/plain_icons.dart`、`pubspec.yaml` 的 `PlainIcons` family |
> | 码位 | 仍按 `icons.json` 自 `0xE001` 连续分配，当前作**映射表标识**用；未落字体 `cmap` |
>
> 若将来改回字体方案，先读下面路线 A 的 `hmtx.lsb` 陷阱与《11》§4 的实测记录。

### 路线 A · 转图标字体（历史方案，未采用）

| 步骤 | 说明 |
| --- | --- |
| 1 | 用 `fontTools` 把每枚 SVG 转字形（stroke 必须先展平为填充轮廓） |
| 2 | `upm = 1000`、`ascent = 1000` → **一个字形盒 == 一个 `Icon(size)` 盒** |
| 3 | ⚠️ **`hmtx.lsb` 必须 == `glyf.xMin`**。不相等时，尊重 lsb 的渲染器（FreeType、Chrome、Flutter 共用同一套后端）会把轮廓平移 `lsb − xMin`，图标会贴到盒边缘 |
| 4 | 码位按 `icons.json` 写入 `cmap`；生成 `plain_icons.dart` 常量表 |
| 5 | 校验：把图标在 HTML 里用字体渲一遍、再用 SVG 画一遍，**全量逐枚**比对内容框位置 |

### 路线 B · `flutter_svg` 直接吃 SVG

| 说明 | 代价 |
| --- | --- |
| 直接用 `04-ICON-SYSTEM/svg/*.svg` 作为 asset | 运行时解析 XML，首帧成本高于字体；但**零转换损耗**，且颜色天然支持 `currentColor` 替换 |
| 适合 | 图标数量继续增长、或需要双色/多色图标时 |

> 本轮交付的是**矢量源文件**，两条路线都能落地。**编码侧已选 B**（见上方拍板表；见《10-CHANGELOG》T-4）。

---

## 6. 与上一版图标语言的具体差异

| 项 | 旧 `PlainIcons` / Material | v3 |
| --- | --- | --- |
| 网格 | 混合（Material 24 + 手绘 18.48） | 统一 24 / 内容盒 20 |
| 描边 | 混合（Material 填充 + 手绘描边） | 统一 1.75 描边、无填充 |
| 端点 | 混合（方头 / 圆头） | 统一圆头 |
| 光学等大 | 手绘与 Lucide 需要 0.8518 缩放补偿 | **同一套坐标体系，无需缩放补偿** |
| 分类图标 | 分类色直接上图标 | 图标单色 + 6px 分类色圆点 |
| 颜色 | 硬编码进 SVG | 一律 `currentColor` |
