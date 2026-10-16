# -*- coding: utf-8 -*-
"""素记 Plain · MiSans 字体子集构建。

把小米 MiSans 的 4 个字重子集化后落到 assets/fonts/misans/，供 Flutter 使用。

用法：
    python tool/build_fonts_misans.py                 # 构建
    python tool/build_fonts_misans.py --src <目录>    # 指定 MiSans 源目录
    python tool/build_fonts_misans.py --check         # 只校验产物 sha，不重建

设计约束（改动前先读）：
  1. 字符集 = GB2312 全集(7445) ∪ ASCII ∪ 符号表 —— 固定不随源码变化，
     所以新增文案无需重跑；只有出现 GB2312 以外的字才需要重新构建。
     脚本末尾会拿 lib/ 实际用字做覆盖自检，缺字直接报错退出。
  2. MiSans 的字重刻度是非标准的（Regular 内部是 330、Bold 是 630），
     Flutter 只认 pubspec 声明的 weight，所以这里把 OS/2.usWeightClass /
     fsSelection / head.macStyle 一并改写成标准 400/500/600/700，
     避免其它平台按字体自带值二次匹配。
  3. 产物可复现：head.created/modified 钉死 + recalcTimestamp=False。
"""
import argparse
import hashlib
import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "..", "assets", "fonts", "misans")
LIB_DIR = os.path.join(HERE, "..", "lib")
DEFAULT_SRC = r"C:\Users\lizhenyu\Downloads\MiSans\ttf"

# 上游文件 → (输出文件名, Flutter FontWeight, 标准 usWeightClass, subfamily)
WEIGHTS = [
    ("MiSans-Regular.ttf",  "MiSans-Regular.ttf",  400, 400, "Regular"),
    ("MiSans-Medium.ttf",   "MiSans-Medium.ttf",   500, 500, "Medium"),
    ("MiSans-Semibold.ttf", "MiSans-Semibold.ttf", 600, 600, "Semibold"),
    ("MiSans-Bold.ttf",     "MiSans-Bold.ttf",     700, 700, "Bold"),
]

FAMILY = "MiSans"

# 保留的 OpenType 特性：tnum 是金额对齐的关键，其余为比例/全宽数字与本地化标点。
KEEP_FEATURES = ["tnum", "pnum", "fwid", "hwid", "calt", "locl", "case"]

# 钉死的时间戳：2000-01-01 (Mac epoch)。必须 ≥ 2082844800，
# 否则 fontTools 会当成 unix 秒自动加 Mac 偏移并告警。
PINNED_TS = 3029524800

# lib/ 里出现但可安全排除的码位：emoji、变体选择符、BOM —— 由系统字体兜底。
IGNORE_MISSING = {0xFEFF, 0xFE0F, 0x1F514}


def build_charset():
    """GB2312 全集 + ASCII + 符号表。"""
    chars = set()
    # GB2312 全量：0xA1-0xA9 符号区 + 0xB0-0xF7 汉字区
    for b1 in range(0xA1, 0xF8):
        for b2 in range(0xA1, 0xFF):
            try:
                chars.add(bytes([b1, b2]).decode("gb2312"))
            except Exception:
                pass
    # ASCII 可打印区
    chars |= {chr(c) for c in range(0x20, 0x7F)}
    # 符号表：覆盖 GB2312 没有的常用 UI 符号（货币、数学、箭头、几何、圈号、引号）
    chars |= set(
        "£¤¥¢€₩₽₺₹₫₴₱₦₡₲₪₭₮₸₾₼฿"
        "°±×÷≈≠≤≥∞√∑∏∫∆∇∂∝∠⊥∩∪∈∉⊂⊃∅−⚠✓✗✔✘"
        "←→↑↓↔↕⇐⇒⇔↖↗↘↙↩↪⤴⤵"
        "●○◎◉◆◇■□▲▼△▽★☆▪▫•◦‣‰‱№™©®§¶†‡"
        "℃℉′″″、。，；：？！（）【】〔〕〈〉《》「」『』"
        "–—…‘’“”′″·～〜∣‖"
        "①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳"
    )
    return chars


def check_lib_coverage(charset):
    """lib/ 实际用字必须被字符集覆盖（排除 emoji 等回退字符）。"""
    import glob
    used = set()
    for p in glob.glob(os.path.join(LIB_DIR, "**", "*.dart"), recursive=True):
        with open(p, encoding="utf-8") as fh:
            used |= set(fh.read())
    missing = sorted(
        c for c in used
        if ord(c) > 0x1F and ord(c) not in IGNORE_MISSING and c not in charset
    )
    if missing:
        print("✗ lib/ 用字未被字符集覆盖，请把下列字符加进 build_charset()：")
        for c in missing:
            print(f"    U+{ord(c):04X}  {c!r}")
        return False
    print(f"✓ 覆盖自检通过：lib/ 用字 {len(used)} 个全部命中（emoji 由系统字体兜底）")
    return True


def rewrite_name(font, subfamily):
    """重写 name 1/2/3/4/6/16/17，清除上游残留。"""
    name = font["name"]
    for nid in (1, 2, 3, 4, 6, 16, 17):
        name.removeNames(nameID=nid)
    full = f"{FAMILY} {subfamily}"
    ps = f"{FAMILY}-{subfamily}"
    typo_family = FAMILY
    for pid, peid, lid in ((3, 1, 0x409), (1, 0, 0)):
        name.setName(FAMILY, 1, pid, peid, lid)
        name.setName(subfamily, 2, pid, peid, lid)
        name.setName(f"{FAMILY};{ps}", 3, pid, peid, lid)
        name.setName(full, 4, pid, peid, lid)
        name.setName(ps, 6, pid, peid, lid)
        name.setName(typo_family, 16, pid, peid, lid)
        name.setName(subfamily, 17, pid, peid, lid)


def normalize_weight(font, weight):
    """把非标准刻度改写成 400/500/600/700 标准值。"""
    os2 = font["OS/2"]
    os2.usWeightClass = weight
    # fsSelection: bit5 BOLD / bit6 REGULAR
    if weight >= 700:
        os2.fsSelection = (os2.fsSelection & ~0x40) | 0x20
    else:
        os2.fsSelection = (os2.fsSelection & ~0x20) | 0x40
    font["head"].macStyle = 1 if weight >= 700 else 0


def build_one(src_dir, src_name, out_name, weight, subfamily):
    src_path = os.path.join(src_dir, src_name)
    out_path = os.path.join(OUT_DIR, out_name)

    opts = subset.Options()
    opts.layout_features = KEEP_FEATURES
    opts.hinting = False          # 移动端渲染器自带 hinting，丢掉省体积
    opts.glyph_names = False      # post 表转 format 3
    opts.notdef_outline = True
    opts.recalc_bounds = True     # 刷新 glyf xMin（TrueType 要求 lsb == xMin）
    opts.drop_tables = ["FFTM"]

    font = TTFont(src_path, recalcTimestamp=False)
    subsetter = subset.Subsetter(options=opts)
    subsetter.populate(unicodes=[ord(c) for c in CHARSET])
    subsetter.subset(font)

    # 请求了但源字体本身没有的码位 —— 这些交给系统字体回退，不算错误，
    # 但必须显式列出来，否则会误以为"字体覆盖了"。
    got = set(font.getBestCmap())
    missing = sorted(ord(c) for c in CHARSET if ord(c) not in got)

    rewrite_name(font, subfamily)
    normalize_weight(font, weight)

    font["head"].created = PINNED_TS
    font["head"].modified = PINNED_TS
    font.recalcTimestamp = False  # 只钉不关无效

    font.save(out_path)
    font.close()
    return out_path, missing


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=DEFAULT_SRC, help="MiSans 源目录（含 ttf/）")
    ap.add_argument("--check", action="store_true", help="只校验产物 sha，不重建")
    args = ap.parse_args()

    global CHARSET
    CHARSET = build_charset()
    print(f"字符集大小：{len(CHARSET)}")

    if args.check:
        ok = True
        for _, out_name, _, _, _ in WEIGHTS:
            p = os.path.join(OUT_DIR, out_name)
            if not os.path.exists(p):
                print(f"✗ 缺少 {out_name}")
                ok = False
            else:
                print(f"  {out_name}  {os.path.getsize(p)/1048576:5.2f} MB  {sha256(p)[:16]}")
        return 0 if ok else 1

    if not check_lib_coverage(CHARSET):
        return 1

    if not os.path.isdir(args.src):
        print(f"✗ MiSans 源目录不存在：{args.src}")
        return 1

    os.makedirs(OUT_DIR, exist_ok=True)
    total = 0
    print(f"\n输出 → {os.path.normpath(OUT_DIR)}\n")
    print(f"{'文件':<22}{'体积':>9}  {'sha256':<18} weight")
    print("-" * 66)
    missing_report = None
    for src_name, out_name, weight, std_w, subfamily in WEIGHTS:
        src_path = os.path.join(args.src, src_name)
        if not os.path.exists(src_path):
            print(f"✗ 源文件缺失：{src_path}")
            return 1
        out_path, missing = build_one(args.src, src_name, out_name, std_w, subfamily)
        if missing_report is None:
            missing_report = missing
        size = os.path.getsize(out_path)
        total += size
        print(f"{out_name:<22}{size/1048576:6.2f} MB  {sha256(out_path)[:16]:<18} {weight}")
    print("-" * 66)
    print(f"{'合计':<22}{total/1048576:6.2f} MB")

    if missing_report:
        print(f"\n源字体未提供、交由系统回退的码位（{len(missing_report)} 个）：")
        for cp in missing_report:
            print(f"    U+{cp:04X}  {chr(cp)!r}")
        print("  以上字符 Flutter 会按 fontFamilyFallback 逐字回退到系统字体。")
    else:
        print("\n字符集全部被源字体覆盖。")
    return 0


if __name__ == "__main__":
    CHARSET = set()
    sys.exit(main())
