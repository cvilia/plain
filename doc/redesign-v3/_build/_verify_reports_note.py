# -*- coding: utf-8 -*-
"""第二实现复算：屏 7 `.month-note.tight` 的几何是否与 `spec.json` 实测吻合。

为什么需要它：本机 `flutter test` 挂在 harness 层（`WebSocketException`），
widget 级渲染断言跑不了。于是用 Python 按**设计稿 CSS 常量**独立推算一遍
Flutter 侧写下的盒模型，再与真浏览器实测的 `spec.json` 逐项对账。

推算依据（全部来自 `gen_screens.py` 的 CSS + `spec.json` 实测）：
  .scroll{padding:0 16px}               -> 实测 pad [0,16,0,16]
  .month-note{gap:6px}                  -> Row(spacing:6)
  .month-note.tight{padding:14px 2px 12px} -> Padding.fromLTRB(2,14,2,12)
  .month-note svg{width:13px}           -> PlainIcon(size:13)
  .dot-sep{margin:0 2px}                -> Padding.symmetric(horizontal:2)
  .cmppanel{margin-top:4px}             -> 下一块紧邻（本页未写 gap，见「未做」）

退出码：任一项 > 0.01px 偏差即 exit 1。
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SPEC = os.path.join(HERE, "spec.json")

SCROLL_PAD_X = 16.0      # .scroll
NOTE_PAD = (14.0, 2.0, 12.0, 2.0)   # .month-note.tight: top right bottom left
NOTE_GAP = 6.0           # .month-note gap
ICON = 13.0              # <svg width="13" height="13">
DOT_MARGIN = 2.0         # .dot-sep margin:0 2px
LINE = 16.0              # 12px 的 normal 行盒（spec.json 实测 h=16）
CMPPANEL_MARGIN_TOP = 4.0


def main():
    spec = json.load(open(SPEC, encoding="utf-8"))
    sc = spec[6]                                    # 屏 7，0-based
    items = sc["items"]

    # 按类名/文案查找，不写死下标（spec.json 会随设计稿重跑而变）
    scroll = next(i for i in items if "scroll" in (i.get("cls") or ""))
    note = next(i for i in items if "month-note" in (i.get("cls") or ""))
    kids = [i for i in items if i.get("par") == note["i"]]
    icon = next(i for i in kids if i.get("kind") == "icon")
    label = next(i for i in kids if (i.get("txt") or {}).get("v", "").startswith("记账"))
    dot = next(i for i in kids if (i.get("txt") or {}).get("v") == "·")
    count = next(i for i in kids if (i.get("txt") or {}).get("v", "").startswith("共"))
    cmppanel = next(i for i in items
                    if i.get("y") > note["y"] and i.get("kind") == "box"
                    and "panel" in (i.get("cls") or ""))

    top, right, bottom, left = NOTE_PAD
    scroll_top = scroll["y"]

    # ── Flutter 侧推算（按写下的盒模型） ─────────────────────────────
    got = {}
    got["scroll.topPad"] = 0.0                      # ListView 不写 top
    got["note.y"] = scroll_top + got["scroll.topPad"] + 0.0
    got["note.h"] = top + LINE + bottom             # 14 + 16 + 12
    icon_left = SCROLL_PAD_X + left
    got["icon.x"] = icon_left
    got["icon.y_center"] = got["note.y"] + top + LINE / 2
    label_left = icon_left + ICON + NOTE_GAP
    got["label.x"] = label_left
    dot_left = label_left + label["w"] + NOTE_GAP + DOT_MARGIN
    got["dot.x"] = dot_left
    count_left = dot_left + dot["w"] + DOT_MARGIN + NOTE_GAP
    got["count.x"] = count_left
    got["cmppanel.y"] = got["note.y"] + got["note.h"] + CMPPANEL_MARGIN_TOP

    # ── 真浏览器实测 ────────────────────────────────────────────────
    want = {
        "note.y": note["y"],
        "note.h": note["h"],
        "icon.x": icon["x"],
        "icon.y_center": icon["y"] + icon["h"] / 2,
        "label.x": label["x"],
        "dot.x": dot["x"],
        "count.x": count["x"],
        "cmppanel.y": cmppanel["y"],
    }

    print("%-16s %10s %10s %8s" % ("项", "推算", "实测", "差"))
    print("-" * 50)
    bad = 0
    for k in want:
        d = got[k] - want[k]
        flag = "" if abs(d) <= 0.01 else "  ✗"
        if flag:
            bad += 1
        print("%-16s %10.2f %10.2f %8.2f%s" % (k, got[k], want[k], d, flag))
    print("-" * 50)
    print("不一致项 %d / %d" % (bad, len(want)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
