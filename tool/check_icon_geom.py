"""独立几何门禁：把 v3 全部图标展开为绝对坐标并求包围盒，检查是否落在内容盒 [2, 22]。

用法：
    python plain/tool/check_icon_geom.py        # 越界即 exit 1

刻意不复用任何生成器的判定逻辑：路径解析用 plain/tool/gen_icons_abs.py 的纯解析函数
（tokenize / arc_to_cubics / parse_path / parse_svg），贝塞尔按采样求极值，
描边按 1.75/2 = 0.875 外扩，最终报告「描边后绘制范围」。
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_icons_abs import parse_path, parse_svg  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ICO = ROOT / "redesign-v3" / "04-ICON-SYSTEM"
BOX = (2.0, 22.0)
HALF_STROKE = 1.75 / 2.0
SAMPLES = 64


def bez3(p0, p1, p2, p3):
    pts = []
    for i in range(SAMPLES + 1):
        t = i / SAMPLES
        u = 1 - t
        x = u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0]
        y = u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1]
        pts.append((x, y))
    return pts


def bez2(p0, p1, p2):
    pts = []
    for i in range(SAMPLES + 1):
        t = i / SAMPLES
        u = 1 - t
        x = u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0]
        y = u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]
        pts.append((x, y))
    return pts


def path_points(d: str):
    ops = parse_path(d)
    pts, cur = [], (0.0, 0.0)
    for op in ops:
        k = op[0]
        if k == "M":
            cur = (op[1], op[2]); pts.append(cur)
        elif k == "L":
            cur = (op[1], op[2]); pts.append(cur)
        elif k == "Q":
            seg = bez2(cur, (op[1], op[2]), (op[3], op[4])); pts += seg
            cur = (op[3], op[4])
        elif k == "C":
            seg = bez3(cur, (op[1], op[2]), (op[3], op[4]), (op[5], op[6])); pts += seg
            cur = (op[5], op[6])
        elif k == "Z":
            pass
    return pts


def icon_bbox(svg_text: str):
    xs, ys = [], []
    for el in parse_svg(svg_text):
        k = el[0]
        if k in ("path", "fillPath"):
            for (x, y) in path_points(el[1]):
                xs.append(x); ys.append(y)
        elif k in ("strokeCircle", "fillCircle"):
            _, cx, cy, r = el
            xs += [cx - r, cx + r]; ys += [cy - r, cy + r]
        elif k in ("strokeRect", "fillRect"):
            _, x, y, w, h, rx = el
            xs += [x, x + w]; ys += [y, y + h]
    if not xs:
        return None
    return min(xs), min(ys), max(xs), max(ys)


def main() -> int:
    doc = json.loads((ICO / "icons.json").read_text(encoding="utf-8"))
    bad, exempt_hits = [], []
    for rec in doc["icons"]:
        f = ICO / rec["file"]
        bb = icon_bbox(f.read_text(encoding="utf-8"))
        if bb is None:
            bad.append((rec["name"], "EMPTY"))
            continue
        x0, y0, x1, y1 = bb
        # 几何（路径中心线）越界
        geo = (x0 < BOX[0] - 1e-6 or y0 < BOX[0] - 1e-6
               or x1 > BOX[1] + 1e-6 or y1 > BOX[1] + 1e-6)
        # 绘制范围（含描边）
        paint_viol = (x0 - HALF_STROKE < 1.125 - 1e-6 or y0 - HALF_STROKE < 1.125 - 1e-6
                      or x1 + HALF_STROKE > 22.875 + 1e-6 or y1 + HALF_STROKE > 22.875 + 1e-6)
        if geo:
            bad.append((rec["name"], f"geo [{x0:.3f},{y0:.3f}]-[{x1:.3f},{y1:.3f}]"))
        if paint_viol and not geo:
            exempt_hits.append((rec["name"], f"paint [{x0-HALF_STROKE:.3f},{y0-HALF_STROKE:.3f}]-"
                                             f"[{x1+HALF_STROKE:.3f},{y1+HALF_STROKE:.3f}]"))
    print(f"total icons: {doc['count']}")
    print(f"geometry out-of-box (center-line): {len(bad)}")
    for n, note in bad:
        print("   !", n, note)
    print(f"paint-extent out-of-box only: {len(exempt_hits)}")
    for n, note in exempt_hits:
        print("   ~", n, note)
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
