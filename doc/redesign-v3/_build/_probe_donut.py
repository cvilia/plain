"""探针：环形图中心金额的「放得下」阈值表。

环几何（修复前）  ：r=46, stroke=13, 画布 124 -> 内孔 (46-6.5)*2 = **79.0**
环几何（修复后）  ：r=52, stroke=13, 画布 136 -> 内孔 (52-6.5)*2 = **91.0**
可用宽 = 内孔 - 2*margin（margin 取 2px）

中心金额走四段式：货币符 0.62em / 整数 1em / 小数点 1em / 小数 0.62em
⚠️ 数字取 **tnum 宽度 594/1000**（`.dn-c1` 带 `font-variant-numeric:tabular-nums`）；
   逗号与句号 tabular 不改变形状，取 hmtx 实测值。

只读，不写文件。
"""
import os
from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.normpath(os.path.join(HERE, "..", "12-FONTS", "MiSans-Semibold.ttf"))

f = TTFont(FONT)
upm = f["head"].unitsPerEm
cmap, hmtx = f.getBestCmap(), f["hmtx"]

TAB_DIGIT = 0.594          # 实测：44px 单数字 26.14 = 44 * 594/1000


def adv(ch):
    g = cmap.get(ord(ch))
    return None if g is None else hmtx[g][0] / upm


CUR, COMMA, PERIOD = adv("¥"), adv(","), adv(".")


def width_4part(v, size):
    """v 形如 '5,879.50'（不含货币符）。返回四段式总宽。"""
    ints, dec = (v.split(".") + [""])[:2]
    small = size * 0.62
    w = CUR * small
    nd = sum(1 for c in ints if c.isdigit())
    nc = ints.count(",")
    w += nd * TAB_DIGIT * size + nc * COMMA * size
    if dec:
        w += PERIOD * size + len(dec) * TAB_DIGIT * small
    return w


def width_plain(v, size):
    w = CUR * size
    for c in v:
        if c.isdigit():
            w += TAB_DIGIT * size
        elif c == ",":
            w += COMMA * size
        elif c == ".":
            w += PERIOD * size
    return w


OLD_HOLE = (46 - 6.5) * 2
NEW_HOLE = (52 - 6.5) * 2
MARGIN = 2.0

print("修复前 内孔 %.1f / 可用 %.1f   |   修复后 内孔 %.1f / 可用 %.1f"
      % (OLD_HOLE, OLD_HOLE - 2 * MARGIN, NEW_HOLE, NEW_HOLE - 2 * MARGIN))
print()
print("当前规格对比（一行为 1em，未走四段式）：")
for v in ("5,879.50", "86,420.50", "99,999,999.99"):
    print("  %-14s @17px 修复前 %6.2f %s   修复后 %6.2f %s"
          % ("¥" + v, width_plain(v, 17),
             "OK" if width_plain(v, 17) <= OLD_HOLE - 2 * MARGIN else "OVER",
             width_plain(v, 17),
             "OK" if width_plain(v, 17) <= NEW_HOLE - 2 * MARGIN else "OVER"))

print()
print("修复后四段式阈值表（可用宽 %.1f）：" % (NEW_HOLE - 2 * MARGIN))
AVAIL = NEW_HOLE - 2 * MARGIN
for size in (18, 17, 16, 15, 14, 13, 12):
    ok = []
    for v in ("5,879.50", "86,420.50", "999,999.99", "9,999,999.99",
              "99,999,999.99"):
        w = width_4part(v, size)
        ok.append("%s %s(%.1f)" % ("¥" + v, "OK " if w <= AVAIL else "OVER", w))
    print("  %2dpx  %s" % (size, "  |  ".join(ok)))

print()
print("→ 结论（把这 3 行写进规格，而不是让实现去猜）：")
print("   ① 环改 r=52 / stroke=13 / 画布 136 → 内孔 91（原 79）")
print("   ② 中心金额走四段式，整数档 **18px**")
print("     实测 `¥5,879.50` = %.2fpx / `¥86,420.50` = %.2fpx，均在 %.1f 内"
      % (width_4part("5,879.50", 18), width_4part("86,420.50", 18), AVAIL))
print("   ③ 超长值向下取档，18 → 15 → 13；仍放不下则改用万/亿量级缩写"
      "（**新增待拍板 T-9**）")
for size in (18, 17, 16, 15, 14, 13, 12):
    if width_4part("99,999,999.99", size) <= AVAIL:
        print("     极端值 ¥99,999,999.99 需降到 **%dpx**" % size)
        break
else:
    print("     极端值 ¥99,999,999.99 在任何档位都放不下 → 必须缩写")
