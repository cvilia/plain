# 素记图标 assets/icons —— 命名与用法

## 目录职责

`plain/assets/icons/` 是 App 侧图标的**打包源**，由 `redesign-v3/04-ICON-SYSTEM/svg/`
（作图真源）同步而来。`icons.json`（顺序 / 分类 / 码位）留在 `redesign-v3/04-ICON-SYSTEM/`，
不进 assets —— 本目录被 `pubspec.yaml` 整目录声明，**除本 README 外只放要打包的 SVG**。

Flutter **运行时**用 `flutter_svg` 直接加载这些 SVG，不做 path 预解析：

```bash
python plain/tool/import_icons_to_assets.py   # 同步 SVG
python plain/tool/gen_icons_abs.py            # 读 icons.json → 写 lib/design_system/plain_icons_v3.dart
```

UI 里用：

```dart
PlainIcon(PlainIconData.catFood, size: 24, color: ink);  // 任意色，currentColor 语义
CategoryIcon(iconRef: 'food', size: 24);                  // 分类：自动映射 + ink 色
```

- `PlainIcon.size` 传 `null`（默认）时跟随 `IconTheme.of(context).size`，与 `Icon` 语义一致。
- SVG 的 `currentColor` 由 `PlainIcon` 的 `color` / `IconTheme` 经 `ColorFilter.srcIn` 注入。

## 命名规则

```
ic_<group>_<slug>.svg
```

| group | 含义 | 示例 |
| --- | --- | --- |
| `nav` | 底部导航 | `ic_nav_ledger` `ic_nav_add` `ic_nav_assets` |
| `cat` | 分类（12 一级） | `ic_cat_food` `ic_cat_transport` |
| 无 group 前缀 | 操作/记账/状态/通用 | `ic_back` `ic_delete` `ic_calendar` |

- `slug`：snake_case 英文，与 `icons.json` 的 `name` **逐字一致**（这是 API，勿改名）。
- Dart 标识符 = 去掉 `ic_` 后的驼峰：`ic_nav_ledger` → `PlainIconData.navLedger`，
  `ic_cat_food` → `PlainIconData.catFood`，`ic_chevron_up` → `PlainIconData.chevronUp`。

## 画布硬规范（改图必须遵守）

| 项 | 值 |
| --- | --- |
| viewBox | `0 0 24 24` |
| 内容盒 | `[2, 22]` |
| 描边 | `stroke-width="1.75"` round cap/join |
| 填充 | 根 `fill="none"`；实心点 `fill="currentColor" stroke="none"` |
| 颜色 | 只用 `currentColor` |
| 禁止 | filter / 外链 / CSS class / 写死色值 / viewBox 不是 24 |

新增图标**只能追加到 `redesign-v3/_build/gen_icons.py` 的 `ICONS` 列表末尾**（码位连续分配），
然后按上面三步重跑，不要单独往本目录塞 SVG。

## 分类颜色

分类图标颜色不写在 SVG 里，由 `category_icon_v3.dart` 按 iconRef 取
`categoryInkLight/Dark`（INV-1 色板）。
