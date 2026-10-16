"""按映射表把越界字号改成设计稿真字阶 —— **只动扫描器报出的那一行**。

为什么不用全局正则替换：`fontSize: 13` 在一个文件里可能出现多次，而有些
（例如金额组件的派生段）是合法的。全局替换会误伤。这里以
`scan_font_scale.py` 报出的 (file, line) 为白名单逐行改。

跑法：
    python tool/apply_font_scale.py            # dry-run，只打印
    python tool/apply_font_scale.py --write    # 真正写盘
"""
from __future__ import annotations

import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import scan_font_scale as S  # noqa: E402

# 代码现值 → 设计稿真字阶。理由见 PlainApp/字阶越界清单.html
MAPPING = {
    13.0: 14.0,   # 次要说明文字 → 设计 `.d{14;muted}`
    11.0: 12.0,   # 微标签 → 设计最小档 12
    10.0: 12.0,   # 图表标签 / 微标签 → 设计最小档 12
    16.0: 15.0,   # 空档 → `.amt.s` / `.ft`
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()

    rows = S.scan(S.LIB)
    targets = [r for r in rows
               if not r["ok"] and r["value"] in MAPPING and r["kind"] != "height:分数"]

    by_file: dict[str, list[dict]] = {}
    for r in targets:
        by_file.setdefault(r["file"], []).append(r)

    total = 0
    changed_files = []
    for rel, items in sorted(by_file.items()):
        path = os.path.join(S.LIB, rel.replace("/", os.sep))
        with open(path, encoding="utf-8") as f:
            lines = f.read().split("\n")

        touched = False
        for r in sorted(items, key=lambda x: x["line"], reverse=True):
            idx = r["line"] - 1
            old, new = r["value"], MAPPING[r["value"]]
            line = lines[idx]
            pat = re.compile(r"(fontSize:\s*)" + re.escape(f"{old:g}") + r"\b")
            if not pat.search(line):
                print(f"  !! 跳过 {rel}:{r['line']} —— 行内找不到 `fontSize: {old:g}`")
                continue
            lines[idx] = pat.sub(lambda m: m.group(1) + f"{new:g}", line, count=1)
            total += 1
            print(f'  {rel}:{r["line"]}  {old:g} → {new:g}')
        if len(lines) != len(open(path, encoding="utf-8").read().split("\n")):
            print(f"  !! 行数变了，拒绝写 {rel}")
            continue

        if args.write:
            with open(path, "w", encoding="utf-8") as f:
                f.write("\n".join(lines))
            touched = True
        if touched:
            changed_files.append(rel)

    print()
    print(f"{'已写盘' if args.write else 'dry-run'}：{total} 处，{len(by_file)} 个文件")
    if args.write:
        for f in changed_files:
            print("  ", f)
    return 0


if __name__ == "__main__":
    sys.exit(main())
