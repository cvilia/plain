"""只读探针：把 spec.json 里所有带 txt 的元素按 (fontSize, lineHeight, weight) 归组统计。

用途：确定设计稿里每个字号在**实际渲染**下的行盒高度，用于修正 typography.dart
与 designLineHeight()。禁止手写这部分数值。

跑法：
  python _probe_lh.py            # 全量分组
  python _probe_lh.py amt        # 只看 cls 含 amt 的
"""
import json
import os
import sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
SPEC = os.path.join(HERE, "spec.json")


def as_px(v):
    if v is None:
        return None
    s = str(v).strip()
    if s.endswith("px"):
        s = s[:-2]
    try:
        return float(s)
    except ValueError:
        return None


def main():
    flt = sys.argv[1] if len(sys.argv) > 1 else None
    with open(SPEC, encoding="utf-8") as f:
        spec = json.load(f)

    buckets = Counter()
    samples = {}
    for screen in spec:
        for it in screen.get("items", []):
            txt = it.get("txt")
            if not txt:
                continue
            cls = it.get("cls") or ""
            if flt and flt not in cls:
                continue
            size = txt.get("size")
            lh = txt.get("lh")
            wt = txt.get("wt")
            ls = txt.get("ls")
            key = (size, lh, wt, ls)
            buckets[key] += 1
            samples.setdefault(key, (screen.get("title"), cls, it.get("h")))

    print(f"{'size':>7} {'lh':>10} {'wt':>5} {'ls':>8} {'n':>4}  sample")
    print("-" * 96)
    # 按 size 数值排序（数字优先，非数字排后面）
    def sort_key(kv):
        s = kv[0]
        try:
            return (0, float(str(s).rstrip("px")))
        except (TypeError, ValueError):
            return (1, 0.0)

    for key, n in sorted(buckets.items(), key=sort_key):
        size, lh, wt, ls = key
        title, cls, h = samples[key]
        print(f"{str(size):>7} {str(lh):>10} {str(wt):>5} {str(ls):>8} {n:>4}  {cls[:34]} | {title} | h={h}")


if __name__ == "__main__":
    main()
