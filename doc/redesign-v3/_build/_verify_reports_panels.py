"""屏 7（SP-3-01 报表页）面板盒模型对账 —— 第二实现复算。

本机 `flutter test` 挂在 harness 层（WebSocketException），跑不了 widget 级验证，
所以在这里用 **独立第二实现** 按 Flutter 的排版规则（无外边距合并、`Container`
把边框加在内容之外）重算一遍纵向堆叠，再与 `spec.json` 里浏览器实测的几何逐项比对。

真值来源：
  设计侧 —— `spec.json` 屏 7 逐元素实测（浏览器 box 模型）；
  代码侧 —— `plain/lib/features/reports/reports_page.dart` 的实参 + `designLineHeight()`。

判定：`OK` = 本轮已收且对得上；`OPEN` = 已知未收（下游元素会被它带偏，故不参与判定）。
"""

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SPEC = os.path.join(HERE, "spec.json")
SRC = os.path.abspath(
    os.path.join(HERE, "..", "..", "plain", "lib", "features", "reports", "reports_page.dart")
)
TYPO = os.path.abspath(
    os.path.join(HERE, "..", "..", "plain", "lib", "app", "theme", "typography.dart")
)

SCREEN = 7  # 屏号（1-based）


# ── 从源码里读常量，避免把数值抄成第二份真相 ───────────────────────────────
def read_design_line_heights():
    """从 `typography.dart::designLineHeight` 解析 `字号 => 行高` 表。"""
    s = open(TYPO, encoding="utf-8").read()
    m = re.search(r"double designLineHeight\(double fontSize\)\s*\{(.*?)\n\}", s, re.S)
    if not m:
        sys.exit("找不到 designLineHeight()")
    out = {}
    for fm, num, den in re.findall(r"(\d+)\s*=>\s*(\d+)\s*/\s*(\d+)", m.group(1)):
        out[float(fm)] = int(num) / int(den) * float(fm)
    return out


LH = read_design_line_heights()


def read_source_tokens():
    """从 reports_page.dart 抠出本页的间距实参（margin/padding/height）。"""
    s = open(SRC, encoding="utf-8").read()
    tok = {}
    tok["note_top"] = re.search(r"padding: const EdgeInsets\.fromLTRB\(2, (\d+), 2, (\d+)\)", s)
    return s, tok


SRC_TEXT = open(SRC, encoding="utf-8").read()
SCROLL_PAD = 16                 # `.scroll{padding:0 16px}`
SPACING = {"xs": 4.0, "sm": 8.0, "md": 12.0, "lg": 16.0, "xl": 24.0}

# 设计：`.month-note.tight{padding:14px 2px 12px}` / `.cmppanel` / `.chartpanel`
NOTE_PAD = (14.0, 12.0)
CMP = {"margin_top": 4.0, "pad_top": 18.0, "pad_bottom": 10.0}
CHART = {"margin_top": 12.0, "pad_top": 18.0, "pad_bottom": 16.0}
ROW_H = 44.0                    # `.crow{height:44px}`


def spec_items(sc):
    out = {}
    for it in sc["items"]:
        cls = (it.get("cls") or "").strip()
        if cls and cls not in out:
            out[cls] = it
    return out


def by_cls(sc, cls, nth=0):
    hits = [it for it in sc["items"] if (it.get("cls") or "").strip() == cls]
    return hits[nth] if len(hits) > nth else None


def main():
    spec = json.load(open(SPEC, encoding="utf-8"))
    sc = spec[SCREEN - 1]

    scroll = by_cls(sc, "scroll")
    note = by_cls(sc, "month-note tight")
    cmp_panel = by_cls(sc, "panel cmppanel")
    cmp_eb = by_cls(sc, "eyebrow")                       # 屏 7 第一个 eyebrow
    crows = [it for it in sc["items"] if (it.get("cls") or "").strip() == "crow"]
    charts = [it for it in sc["items"] if (it.get("cls") or "").strip() == "panel chartpanel"]
    donut_wrap = by_cls(sc, "donut-wrap")
    legend = by_cls(sc, "legend")
    bars = [it for it in sc["items"] if (it.get("cls") or "").strip() == "bars"][0]
    eyebrows = [it for it in sc["items"] if (it.get("cls") or "").strip() == "eyebrow"]

    # ── 代码侧实参自检：确认本轮的四个改动都在源码里 ──────────────────────
    # `chartpanel` 盒模型共 3 处：两块 chartpanel + 那块设计里没有的 `_ComparisonCard`（对齐用）。
    src_checks = {
        "cmppanel margin-top:4": "margin: const EdgeInsets.only(top: Spacing.xs)" in SRC_TEXT,
        "cmppanel padding:18/16/10": "padding: const EdgeInsets.fromLTRB(16, 18, 16, 10)" in SRC_TEXT,
        "chartpanel padding:18/16/16 ×3":
            SRC_TEXT.count("padding: const EdgeInsets.fromLTRB(16, 18, 16, 16)") == 3,
        "chartpanel margin-top:12 ×3":
            SRC_TEXT.count("margin: const EdgeInsets.only(top: Spacing.md)") == 3,
        "scroll 末尾 24": "bottom: Spacing.xl" in SRC_TEXT,
        "面板底色全走 surfaceCard":
            SRC_TEXT.count("colors.surfaceCard,") == 4,
        "无 colors.surface 铺卡片": SRC_TEXT.count("colors.surface,") == 0,
        "`.crow` 高 44": "SizedBox(height: 44, child: Center(child: row))" in SRC_TEXT
        and "height: 43," in SRC_TEXT,
        "`.cd` 宽 76": "width: 76," in SRC_TEXT,
        "eyebrow 移入面板":
            "_sectionTitle" not in SRC_TEXT and SRC_TEXT.count("const _Eyebrow(") == 5,
    }

    # ── 代码侧纵向堆叠（Flutter 规则：无外边距合并；边框占布局） ──────────────
    y = scroll["y"]
    stack = {}

    y += NOTE_PAD[0]
    y += LH[12]                       # 图标/文本行盒（`.month-note` 12px）
    y += NOTE_PAD[1]
    stack["month-note 块底"] = (y, note["y"] + note["h"])

    y += CMP["margin_top"]
    stack["cmppanel 顶"] = (y, cmp_panel["y"])
    y += 1                            # border（`*{box-sizing:border-box}` 之外：Flutter 加在外面）
    y += CMP["pad_top"]
    stack["cmppanel eyebrow 顶"] = (y, cmp_eb["y"])
    y += LH[12] + SPACING["sm"]       # eyebrow 行盒 + `.eyebrow{margin-bottom:8px}`
    for i, cr in enumerate(crows):
        stack[f"crow{i + 1} 顶"] = (y, cr["y"])
        y += ROW_H
    y += CMP["pad_bottom"] + 1
    stack["cmppanel 底"] = (y, cmp_panel["y"] + cmp_panel["h"])

    y += CHART["margin_top"]
    stack["chartpanel① 顶"] = (y, charts[0]["y"])
    y += 1 + CHART["pad_top"]
    stack["chartpanel① eyebrow 顶"] = (y, eyebrows[1]["y"])
    y += LH[12] + SPACING["sm"] + SPACING["xs"]
    stack["donut 顶"] = (y, donut_wrap["y"] + 4)
    y += 136                          # `SizedBox(width: size, height: size)`
    y += SPACING["lg"]                # ⚠️ OPEN：代码 16，设计 `.donut-wrap{padding-bottom:14px}`
    stack["legend 顶（OPEN）"] = (y, legend["y"])

    # legend 行高（代码 6+6 padding + 15px 文本未写 height → 1.5714）
    legend_row = 6 * 2 + 15 * 1.5714
    y += legend_row * 5
    y += CHART["pad_bottom"] + 1
    stack["chartpanel① 底（OPEN）"] = (y, charts[0]["y"] + charts[0]["h"])

    y += CHART["margin_top"]
    stack["chartpanel② 顶（OPEN）"] = (y, charts[1]["y"])
    y += 1 + CHART["pad_top"]
    stack["chartpanel② eyebrow 顶（OPEN）"] = (y, eyebrows[2]["y"])
    y += LH[12] + SPACING["sm"]
    stack["bars 顶（OPEN）"] = (y, bars["y"])

    # ── 输出 ────────────────────────────────────────────────────────────
    print("== 代码侧实参自检 ==")
    for k, v in src_checks.items():
        print(f"  [{'OK ' if v else 'FAIL'}] {k}")

    print(f"\n== 纵向堆叠对账（设计线高: " + ", ".join(f"{k:g}→{v:g}" for k, v in sorted(LH.items())) + "）==")
    fixed = [
        "month-note 块底", "cmppanel 顶", "cmppanel eyebrow 顶",
        "crow1 顶", "crow2 顶", "crow3 顶", "cmppanel 底",
        "chartpanel① 顶", "chartpanel① eyebrow 顶", "donut 顶",
    ]
    ok = bad = 0
    for name, (got, want) in stack.items():
        d = got - want
        mark = "OK" if abs(d) <= 0.05 else "OPEN"
        if name in fixed:
            mark = "OK" if abs(d) <= 0.05 else "DIFF"
            ok += mark == "OK"
            bad += mark == "DIFF"
        elif mark == "OK":
            mark = "OK*"      # OPEN 区里的巧合命中，不计入判定
        print(f"  [{mark:4}] {name:<26} 代码 {got:7.2f}  设计 {want:7.2f}  Δ {d:+7.2f}")

    print(f"\n== 本轮已收项：{ok}/{len(fixed)} 吻合，{bad} 偏差 ==")

    print("\n== 已知未收（下游会被带偏，故单独列）==")
    print("  · `.donut-wrap{padding:4px 0 14px}` 下 14px —— 代码 `SizedBox(height: Spacing.lg)`=16（+2）")
    print(f"  · `.lrow{{height:40px}}` —— 代码 legend 行 = 12(padding) + 15px 文本未写 height"
          f"（1.5714）= {legend_row:.2f}（-{40 - legend_row:.2f}/行 × 5）")
    print("  · `.lpct{flex:0 0 48px}` / `.lamt{flex:0 0 92px}` —— 代码 52 / 110")
    print("  · `.legend` 行内 `.dot8` 无横向内边距 —— 代码多 `padding: horizontal 4`")
    print("  · `.bars` svg h=72（单系列 + opacity 0.35→1.0 阶梯 + y=66.5 基线，14 根样例柱）")
    print("    —— 代码 `_DailyBars` 为「日 × 双系列 + 轴标签 + 图例」，高 92 + 两段 8 + 两行文本")
    print("  · 设计三块面板到「每日支出」为止 —— 代码多一块 `_ComparisonCard`")
    return 1 if (bad or not all(src_checks.values())) else 0


if __name__ == "__main__":
    sys.exit(main())
