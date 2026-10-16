"""素记 Plain · 图标 Dart 绑定生成器【路线 B：flutter_svg 运行时加载】。

唯一权威源：
  plain/assets/icons/ic_*.svg            —— 由 plain/tool/import_icons_to_assets.py 从
                                             redesign-v3/04-ICON-SYSTEM/svg/ 同步而来
  redesign-v3/04-ICON-SYSTEM/icons.json  —— 提供顺序 / 分类 / 码位（由 redesign-v3/_build/gen_icons.py 产出）

唯一产出：
  plain/lib/design_system/plain_icons_v3.dart

★ 为什么不再解析路径
  早期版本（跟本文件同名）会把 SVG path 展开成绝对坐标的 `IconOp` 元组、配一个
  `CustomPaint` 画出来，并且把 `size` 写死 24。那套已经废弃：
    · 现在 PlainIcon 走 `SvgPicture.asset('assets/icons/ic_*.svg')`，Flutter 侧不 parse；
    · size 缺省跟随 `IconTheme.of(context).size`，与 `Icon` 语义一致。
  改图标 → 重跑 `redesign-v3/_build/gen_icons.py` → `plain/tool/import_icons_to_assets.py`
  → 本脚本。三步之外不需要任何手改。

  本文件保留的 tokenize / arc_to_cubics / parse_path / parse_svg 只服务几何门禁脚本
  `plain/tool/check_icon_geom.py`（校验每枚图标是否落在内容盒 [2,22]），不参与产出。
"""
from __future__ import annotations

import json
import math
import re
from pathlib import Path

ROOT = Path(r"C:\Users\lizhenyu\WorkBuddy\Dev\PlainApp")
SVG_DIR = ROOT / "plain" / "assets" / "icons"
ICONS_JSON = ROOT / "redesign-v3" / "04-ICON-SYSTEM" / "icons.json"
OUT = ROOT / "plain" / "lib" / "design_system" / "plain_icons_v3.dart"

# ══════════════════════════════════════════════════════════════ 路径解析（仅自检用）

NUM = re.compile(r"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?")


def tokenize(d: str) -> list[str]:
    """Split SVG path into commands and numbers. Handles 1-2, 0 0 1-2.24-2.05."""
    tokens: list[str] = []
    i = 0
    n = len(d)
    while i < n:
        ch = d[i]
        if ch.isalpha():
            tokens.append(ch)
            i += 1
            continue
        if ch in " ,\t\r\n":
            i += 1
            continue
        m = NUM.match(d, i)
        if not m:
            raise ValueError(f"bad path char {ch!r} at {i} in {d!r}")
        tokens.append(m.group())
        i = m.end()
    return tokens


def arc_to_cubics(x0, y0, rx, ry, phi_deg, large, sweep, x1, y1):
    """SVG elliptical arc → cubic beziers (endpoints x0,y0 → x1,y1)."""
    if rx == 0 or ry == 0:
        return [("L", x1, y1)]
    phi = math.radians(phi_deg)
    cosp, sinp = math.cos(phi), math.sin(phi)

    dx2, dy2 = (x0 - x1) / 2.0, (y0 - y1) / 2.0
    x1p = cosp * dx2 + sinp * dy2
    y1p = -sinp * dx2 + cosp * dy2

    rx, ry = abs(rx), abs(ry)
    lam = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
    if lam > 1:
        s = math.sqrt(lam)
        rx *= s
        ry *= s

    num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
    den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
    num = max(num, 0.0)
    co = math.sqrt(num / den) if den else 0.0
    if large == sweep:
        co = -co
    cxp = co * rx * y1p / ry
    cyp = -co * ry * x1p / rx
    cx = cosp * cxp - sinp * cyp + (x0 + x1) / 2.0
    cy = sinp * cxp + cosp * cyp + (y0 + y1) / 2.0

    def ang(ux, uy, vx, vy):
        dot = ux * vx + uy * vy
        len_ = math.hypot(ux, uy) * math.hypot(vx, vy)
        if len_ == 0:
            return 0.0
        c = max(-1.0, min(1.0, dot / len_))
        a = math.acos(c)
        if ux * vy - uy * vx < 0:
            a = -a
        return a

    theta = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    delta = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not sweep and delta > 0:
        delta -= 2 * math.pi
    elif sweep and delta < 0:
        delta += 2 * math.pi

    segs = max(1, int(math.ceil(abs(delta) / (math.pi / 2))))
    step = delta / segs
    k = 4.0 / 3.0 * math.tan(step / 4.0)
    out = []
    for s in range(segs):
        t0 = theta + s * step
        t1 = t0 + step
        cos0, sin0 = math.cos(t0), math.sin(t0)
        cos1, sin1 = math.cos(t1), math.sin(t1)
        p0x = cx + rx * cosp * cos0 - ry * sinp * sin0
        p0y = cy + rx * sinp * cos0 + ry * cosp * sin0
        p1x = cx + rx * cosp * cos1 - ry * sinp * sin1
        p1y = cy + rx * sinp * cos1 + ry * cosp * sin1
        d0x = -rx * cosp * sin0 - ry * sinp * cos0
        d0y = -rx * sinp * sin0 + ry * cosp * cos0
        d1x = -rx * cosp * sin1 - ry * sinp * cos1
        d1y = -rx * sinp * sin1 + ry * cosp * cos1
        out.append((
            "C",
            p0x + k * d0x, p0y + k * d0y,
            p1x - k * d1x, p1y - k * d1y,
            p1x, p1y,
        ))
    return out


def parse_path(d: str) -> list[tuple]:
    """Return list of absolute ops: ('M',x,y)|('L',x,y)|('Q',x1,y1,x,y)|('C',...)|('Z',)."""
    tokens = tokenize(d)
    ops: list[tuple] = []
    i = 0
    cx = cy = sx = sy = 0.0
    cmd = ""
    last_cmd = ""

    def num():
        nonlocal i
        v = float(tokens[i])
        i += 1
        return v

    while i < len(tokens):
        t = tokens[i]
        if len(t) == 1 and t.isalpha():
            cmd = t
            i += 1
        elif cmd in ("M", "m") and last_cmd in ("M", "m"):
            cmd = "L" if cmd == "M" else "l"
        elif not cmd:
            raise ValueError("path starts with number")

        rel = cmd.islower()
        C = cmd.upper()

        if C == "M":
            x, y = num(), num()
            if rel:
                x, y = cx + x, cy + y
            cx, cy = x, y
            sx, sy = x, y
            ops.append(("M", x, y))
        elif C == "L":
            x, y = num(), num()
            if rel:
                x, y = cx + x, cy + y
            cx, cy = x, y
            ops.append(("L", x, y))
        elif C == "H":
            x = num()
            if rel:
                x = cx + x
            cx = x
            ops.append(("L", cx, cy))
        elif C == "V":
            y = num()
            if rel:
                y = cy + y
            cy = y
            ops.append(("L", cx, cy))
        elif C == "Q":
            x1, y1, x, y = num(), num(), num(), num()
            if rel:
                x1, y1, x, y = cx + x1, cy + y1, cx + x, cy + y
            ops.append(("Q", x1, y1, x, y))
            cx, cy = x, y
        elif C == "T":
            x, y = num(), num()
            if rel:
                x, y = cx + x, cy + y
            # reflect previous Q control — rare in this set
            ops.append(("L", x, y))
            cx, cy = x, y
        elif C == "C":
            x1, y1, x2, y2, x, y = (num() for _ in range(6))
            if rel:
                x1, y1, x2, y2, x, y = cx + x1, cy + y1, cx + x2, cy + y2, cx + x, cy + y
            ops.append(("C", x1, y1, x2, y2, x, y))
            cx, cy = x, y
        elif C == "S":
            x2, y2, x, y = num(), num(), num(), num()
            if rel:
                x2, y2, x, y = cx + x2, cy + y2, cx + x, cy + y
            # assume first control = current point (no prior C in these icons)
            ops.append(("C", cx, cy, x2, y2, x, y))
            cx, cy = x, y
        elif C == "A":
            rx, ry, rot, laf, sf, x, y = (num() for _ in range(7))
            if rel:
                x, y = cx + x, cy + y
            for op in arc_to_cubics(cx, cy, rx, ry, rot, int(laf), int(sf), x, y):
                if op[0] == "L":
                    ops.append(op)
                    cx, cy = op[1], op[2]
                else:
                    ops.append(op)
                    cx, cy = op[5], op[6]
        elif C == "Z":
            ops.append(("Z",))
            cx, cy = sx, sy
        else:
            raise ValueError(f"unsupported cmd {cmd}")
        last_cmd = cmd

    return ops


def parse_svg(text: str) -> list[tuple]:
    """Extract geometry: list of (kind, ...). kind: path|fillPath|strokeCircle|fillCircle|strokeRect|fillRect."""
    ops: list[tuple] = []
    for m in re.finditer(r"<path\s+d=\"([^\"]+)\"([^>]*)/?>", text, re.I):
        attrs = m.group(2) or ""
        filled = 'fill="currentColor"' in attrs and 'stroke="none"' in attrs
        ops.append(("fillPath" if filled else "path", m.group(1)))
    for m in re.finditer(
        r"<circle\s+cx=\"([^\"]+)\"\s+cy=\"([^\"]+)\"\s+r=\"([^\"]+)\"([^>]*)/?>", text, re.I
    ):
        extra = m.group(4) or ""
        filled = 'fill="currentColor"' in extra or 'stroke="none"' in extra
        ops.append(
            ("fillCircle" if filled else "strokeCircle",
             float(m.group(1)), float(m.group(2)), float(m.group(3)))
        )
    for m in re.finditer(
        r"<rect\s+x=\"([^\"]+)\"\s+y=\"([^\"]+)\"\s+width=\"([^\"]+)\"\s+height=\"([^\"]+)\""
        r"(?:\s+rx=\"([^\"]+)\")?([^>]*)/?>",
        text,
        re.I,
    ):
        extra = m.group(6) or ""
        filled = 'fill="currentColor"' in extra
        rx = float(m.group(5)) if m.group(5) else 0.0
        ops.append(
            ("fillRect" if filled else "strokeRect",
             float(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4)), rx)
        )
    return ops


# ══════════════════════════════════════════════════════════════ Dart 代码生成

CAT_ORDER = ["nav", "category", "op", "status", "entry", "chart", "ui"]
CAT_LABEL = {
    "nav": "nav · 底部导航",
    "category": "category · 一级分类",
    "op": "op · 操作",
    "status": "status · 状态",
    "entry": "entry · 记账",
    "chart": "chart · 图表",
    "ui": "ui · 通用",
}

HEADER = '''/// Quiet Ledger icons — flutter_svg 从 assets/icons/ 运行时加载。
///
/// **本文件由 `plain/tool/gen_icons_abs.py` 生成，不要手改。**
/// 权威源：`plain/assets/icons/ic_*.svg`（24 grid · 描边 1.75 · currentColor）。
/// 改图标三步：`redesign-v3/_build/gen_icons.py` → `plain/tool/import_icons_to_assets.py`
/// → `plain/tool/gen_icons_abs.py`。
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

@immutable
class PlainIconData {
  const PlainIconData._(this.name);

  /// File stem, e.g. `ic_cat_food` → `assets/icons/ic_cat_food.svg`.
  final String name;

  String get assetPath => 'assets/icons/$name.svg';

  static const double grid = 24;

__ENTRIES__

  static const Map<String, PlainIconData> byName = {
__LOOKUP__
  };

  static final List<PlainIconData> all = byName.values.toList(growable: false);
}

/// SVG icon from assets/icons/. Drop-in for `Icon`.
///
/// Uses flutter_svg — no custom path parsing. Color via `color` or IconTheme.
class PlainIcon extends StatelessWidget {
  const PlainIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final PlainIconData icon;

  /// 视觉尺寸。传 `null`（默认）时跟随 `IconTheme.of(context).size`，
  /// 与 `Icon` 的语义完全一致 —— 这样 `Icon(Icons.x)` 换成
  /// `PlainIcon(PlainIconData.y)` 后，在 `IconButton(iconSize: 18)` 之类的
  /// 语境里尺寸不会从 18 悄悄跳回 24。
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Color? iconColor = color ?? IconTheme.of(context).color;
    final double box = size ?? IconTheme.of(context).size ?? 24;
    final Widget child = SvgPicture.asset(
      icon.assetPath,
      width: box,
      height: box,
      colorFilter: iconColor == null
          ? null
          : ColorFilter.mode(iconColor, BlendMode.srcIn),
      placeholderBuilder: (_) => SizedBox(width: box, height: box),
    );
    if (semanticLabel != null) {
      return Semantics(label: semanticLabel, child: child);
    }
    return child;
  }
}
'''


def camel(name: str) -> str:
    parts = name.replace(".svg", "").split("_")
    if parts and parts[0] == "ic":
        parts = parts[1:]
    return parts[0] + "".join(p.title() for p in parts[1:]) if parts else name


def main() -> None:
    meta = json.loads(ICONS_JSON.read_text(encoding="utf-8"))
    records = meta["icons"]

    # 按分类分组输出：常量表顺序不影响语义，分组只为可读。
    rank = {c: i for i, c in enumerate(CAT_ORDER)}
    ordered = sorted(enumerate(records), key=lambda kv: (rank.get(kv[1]["category"], 99), kv[0]))
    ordered = [r for _, r in ordered]

    on_disk = {p.stem for p in SVG_DIR.glob("ic_*.svg")}
    missing = [r["name"] for r in records if r["name"] not in on_disk]

    entry_lines: list[str] = []
    lookup_lines: list[str] = []
    seen_fields: set[str] = set()
    prev_cat = None
    for rec in ordered:
        name = rec["name"]
        cat = rec["category"]
        field = camel(name)
        assert field not in seen_fields, f"duplicate Dart field for {name}: {field}"
        seen_fields.add(field)
        if cat != prev_cat:
            if prev_cat is not None:
                entry_lines.append("")
            entry_lines.append(f"  // ── {CAT_LABEL.get(cat, cat)} ──")
            prev_cat = cat
        one_line = f"  static const PlainIconData {field} = PlainIconData._('{name}');"
        if len(one_line) <= 80:
            entry_lines.append(one_line)
        else:
            # 与 dart format（tall style）保持一致：逐参数换行，生成的文件不需要再 format。
            entry_lines.append(
                f"  static const PlainIconData {field} = PlainIconData._(\n"
                f"    '{name}',\n"
                f"  );"
            )
        lookup_lines.append(f"    '{name}': {field},")

    out = (
        HEADER.replace("__ENTRIES__", "\n".join(entry_lines))
        .replace("__LOOKUP__", "\n".join(lookup_lines))
    )
    OUT.write_text(out, encoding="utf-8")

    print(f"wrote {OUT.relative_to(ROOT)}  ({len(records)} icons, {len(ordered)} entries)")
    if missing:
        print("!! icons.json 里有、assets/icons/ 里没有：", missing)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
