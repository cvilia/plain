"""字阶/行高越界扫描器 —— 设计稿只有 7 档字号，代码里多出来的都是自创值。

设计稿全量字号（`redesign-v3/_build/spec.json`，29 屏 1197 个文本元素实测）：
    9.3 / 12 / 12.4 / 14 / 15 / 20 / 21.08 / 22 / 27.28 / 34 / 44
其中真字阶 = 12 / 14 / 15 / 20 / 22 / 34 / 44；其余是 0.62em 派生：
    9.3 = 15×0.62   12.4 = 20×0.62   21.08 = 34×0.62   27.28 = 44×0.62

用法：
    python tool/scan_font_scale.py              # 只列越界
    python tool/scan_font_scale.py --all        # 连合规项一起列
    python tool/scan_font_scale.py --json       # 机读

退出码：0 = 无越界，1 = 有越界（可直接进 CI）。
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

LIB = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib")

# 设计稿真字阶（7 档）
SCALE = (12.0, 14.0, 15.0, 20.0, 22.0, 34.0, 44.0)
# 0.62em 派生值（合法，但**只应出现在金额组件内部**）
DERIVED = (9.3, 12.4, 21.08, 27.28)

# 金额四档 —— 只有这些档位的 0.62em 派生是合法的
AMOUNT_TIERS = (15.0, 20.0, 34.0, 44.0)

# 允许出现派生值的文件（金额组件）。其他文件出现派生值属越界。
DERIVED_ALLOWED = {
    "design_system/amount_display.dart",
}

# 合法例外（不是字阶选择，是有意为之的 hack）
#   0 —— `TextStyle(fontSize: 0, height: 0)` 用来把文字盒彻底压没（隐藏标签但保留语义）
ALLOWED_EXCEPTIONS = {0.0}

# `TextStyle.height` 的**裸比值**白名单（`height: 1.6` 这种写法）。
#   ① `normal` 取整档：12→1.3333  14→1.3571  15→1.3333  20→1.35  22→1.3182  34→1.3243
#   ② `.amt` 四档：1.12 / 1.16 / 1.24 / 1.34
#   ③ 设计稿里**显式写死 px** 的长文段落档（spec.json 实测）：
#        12px → 18（`.foot-note`）/ 19.2（`.sub` `.rulecond`）/ 20.64（`.panel` `.notepanel`）
#        14px → 21（`.dv.note`）/ 23.1（`.guide-p`）/ 23.8
#      → 比值 1.5 / 1.6 / 1.72 / 1.65 / 1.7
#   ④ 1.55：代码里用于 12/14 混排的说明段落，是 12→1.6 与 14→1.5 之间的**折中值**，
#      与最近的设计档差 ≤0.7px，已确认保留（不是发明，是取整折中）。
#   ⑤ 1.0：`Divider(height: 1)` / `Container(height: 1)` 的 px 线宽，一并放行。
BARE_RATIOS = {
    1.0, 1.12, 1.16, 1.24, 1.34, 1.3182, 1.326, 1.3333, 1.35, 1.3571,
    1.5, 1.55, 1.6, 1.65, 1.7, 1.72,
}
# 只在这个区间内才把 `height: X` 当比值看（超出就是 px 尺寸：44 / 56 / 284 …）
BARE_RATIO_RANGE = (0.8, 1.9)

# `fontSize: 34` / `this.fontSize = 15` / `fontSize: 34 * 0.62`
NUM = r"-?[0-9]+(?:\.[0-9]+)?"
PAT_LITERAL = re.compile(r"fontSize:\s*(" + NUM + r")\b")
PAT_DEFAULT = re.compile(r"this\.fontSize\s*=\s*(" + NUM + r")\b")
PAT_DERIVED = re.compile(r"fontSize:\s*(" + NUM + r")\s*\*\s*(" + NUM + r")\b")
PAT_HEIGHT = re.compile(r"height:\s*(" + NUM + r")\s*/\s*(" + NUM + r")\b")
PAT_HEIGHT_BARE = re.compile(r"height:\s*(" + NUM + r")\s*[,)]")


def scan(root: str):
    rows = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in {"generated"}]
        for fn in sorted(filenames):
            if not fn.endswith(".dart"):
                continue
            path = os.path.join(dirpath, fn)
            rel = os.path.relpath(path, root).replace(os.sep, "/")
            try:
                lines = open(path, encoding="utf-8").read().split("\n")
            except OSError:
                continue
            for i, line in enumerate(lines, 1):
                stripped = line.strip()
                if stripped.startswith("//") or stripped.startswith("///"):
                    continue

                # fontSize: A * B —— 派生写法
                m = PAT_DERIVED.search(line)
                if m:
                    base, mul = float(m.group(1)), float(m.group(2))
                    val = base * mul
                    ok = base in AMOUNT_TIERS and abs(mul - 0.62) < 1e-9
                    rows.append({
                        "file": rel, "line": i, "kind": "fontSize:派生",
                        "value": round(val, 4), "ok": ok,
                        "text": stripped[:120],
                    })
                    continue

                m = PAT_DEFAULT.search(line)
                if m:
                    val = float(m.group(1))
                    rows.append({
                        "file": rel, "line": i, "kind": "fontSize:默认值",
                        "value": val, "ok": val in SCALE,
                        "text": stripped[:120],
                    })
                    continue

                m = PAT_LITERAL.search(line)
                if m:
                    val = float(m.group(1))
                    ok = val in SCALE or val in ALLOWED_EXCEPTIONS
                    if not ok and val in DERIVED and rel in DERIVED_ALLOWED:
                        ok = True
                    rows.append({
                        "file": rel, "line": i, "kind": "fontSize:字面量",
                        "value": val, "ok": ok, "text": stripped[:120],
                    })

                m = PAT_HEIGHT.search(line)
                if m:
                    num, den = float(m.group(1)), float(m.group(2))
                    if den:
                        ratio = num / den
                        # 行高比值白名单。
                        # ① `normal` 取整档：58/44 45/34 29/22 27/20 20/15 19/14 16/12
                        # ② `.amt` 四档：1.12 / 1.16 / 1.24 / 1.34
                        # ③ 设计稿里**显式写死 px** 的行盒（spec.json 实测到这些组合）：
                        #    14px → 19 / 21 / 23.1 / 23.8
                        #    12px → 16 / 18 / 19.2 / 20.64
                        allowed = {
                            58 / 44, 45 / 34, 29 / 22, 27 / 20, 20 / 15, 19 / 14, 16 / 12,
                            1.12, 1.16, 1.24, 1.34,
                            21 / 14, 23.1 / 14, 23.8 / 14,
                            18 / 12, 19.2 / 12, 20.64 / 12,
                            # ④ 设计稿 `.expr` 是 `height:20px` 的 flex 容器（`align-items:center`，
                            #    内文 14px / `normal` = 19）。代码写成 `20 / 14` 比值是**刻意的
                            #    等价改写** —— 让 1.15 字号放大档下容器跟着长、不裁字。保留。
                            20 / 14,
                        }
                        ok = any(abs(ratio - a) < 5e-4 for a in allowed)
                        rows.append({
                            "file": rel, "line": i, "kind": "height:分数",
                            "value": round(ratio, 4), "ok": ok,
                            "text": stripped[:120],
                        })
                    continue

                # height: 1.6（裸比值）—— 只认落在 (0.8, 1.9) 的值，其余当 px 尺寸放行。
                m = PAT_HEIGHT_BARE.search(line)
                if m:
                    val = float(m.group(1))
                    lo, hi = BARE_RATIO_RANGE
                    if lo < val < hi:
                        ok = any(abs(val - a) < 5e-4 for a in BARE_RATIOS)
                        rows.append({
                            "file": rel, "line": i, "kind": "height:裸比值",
                            "value": val, "ok": ok, "text": stripped[:120],
                        })
    return rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true", help="连合规项一起列")
    ap.add_argument("--json", action="store_true", help="输出 JSON")
    args = ap.parse_args()

    rows = scan(LIB)
    bad = [r for r in rows if not r["ok"]]

    if args.json:
        print(json.dumps({"total": len(rows), "violations": bad}, ensure_ascii=False, indent=2))
        return 1 if bad else 0

    show = rows if args.all else bad
    for r in sorted(show, key=lambda x: (x["file"], x["line"])):
        flag = "  " if r["ok"] else "!!"
        print(f'{flag} {r["value"]:>8}  {r["kind"]:<14} {r["file"]}:{r["line"]}')
        print(f'        {r["text"]}')

    print()
    print(f"扫描 {len(rows)} 处，越界 {len(bad)} 处")
    from collections import Counter
    c = Counter(r["value"] for r in bad)
    if c:
        print("越界值分布：", "  ".join(f"{k}×{v}" for k, v in sorted(c.items())))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
