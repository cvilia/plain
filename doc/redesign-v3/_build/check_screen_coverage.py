"""逐屏落地覆盖门禁 —— 把「设计里有的，代码里有没有」变成可执行断言。

**为什么需要它**：29 屏高保真里出现的结构性文案（分组小标题、行标题、按钮、
标签、说明句）共 800+ 条，而人工或 AI 逐页对着原型抄，**必然漏**。漏了肉眼也未必看得出
（少一行说明、少一个「已支持」标签，页面照样跑）。这个脚本把它变成 exit code。

数据源：
  · `_build/spec.json`  —— 29 屏的真浏览器实测（由 `_spec_collect.py` 生成）
  · `plain/lib/**/*.dart` —— 工程实况
映射表与文案分类规则见 `screen_map.py`（与 `gen_coding_brief.py` 共用）。

比对分两档（**字面命中优先，兜底命中单独计数**，避免把「搜不到」误报成「没写」）：
  ① 字面：设计稿的值在源码里逐字出现；
  ② 兜底：`flatten()` 的文本视图命中（一句话被 Dart 拆成相邻多个字面量、
     或空白与设计稿不同），或 `screen_map.composed_parts()` 的「词 + 数值（+ 量词）」
     命中（`'${f.label} ¥…'` / `'记账月起始：$d 日'` 这类运行时拼出来的值）。
     兜底命中的条数会在报表里标出。

用法：
  python check_screen_coverage.py                     # 全量体检
  python check_screen_coverage.py --batch B1          # 只判某一批
  python check_screen_coverage.py --screens 9,13,20   # 只判指定屏
  python check_screen_coverage.py --list 9            # 打印第 9 屏的必现清单
  python check_screen_coverage.py --json              # 机读输出
  python check_screen_coverage.py --violations         # 只报违规模式

退出码：被判定范围内**任一项硬缺口 > 0** 即 exit 1。
"""
import argparse
import json
import os
import re
import sys

import screen_map as SM

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))          # redesign-v3/
PROJ = os.path.normpath(os.path.join(ROOT, ".."))          # PlainApp/
PLAIN = os.path.join(PROJ, "plain")
SPEC_JSON = os.path.join(HERE, "spec.json")

# 批次：必须一起交付，中途工程会编译不过或风格不统一
BATCHES = {
    "B0": ([], "地基：AppColors 补 38 个令牌桥接 + 组件层补 TopBar/按钮/分段 + 违规清零"),
    "B1": ([2, 6, 7, 11], "壳与顶栏：底部导航 + 4 个一级页的统一顶栏"),
    "B2": ([3, 4, 5, 12, 13], "记账链路：输入 / 详情 / 分类管理 / 转账三态 / 分割编辑器"),
    "B3": ([6, 15, 20, 21, 22], "资产链路：账户 / 信用卡账单 / 投资 / 贷款 / 净值"),
    "B4": ([7, 23, 24, 25, 26], "报表链路：报表页 / 桑基 / 交叉分析 / 资金年龄 / 预算"),
    "B5": ([9, 14, 16, 17, 18, 19], "管家链路：发现（新 IA）+ 报销 / 提醒 / 规则 / 储蓄 / 首页卡片"),
    "B6": ([1, 8, 10, 27, 28, 29], "数据与设置：引导 / 备份 / 主题 / 家庭 / 开放接口 / 多端"),
}

# 违规模式：设计明确禁止、但工程里还大量存在的写法
VIOLATIONS = [
    ("AppBar(", r"\bAppBar\s*\(", "Material AppBar —— 设计要自定义 .topbar（56 高）"),
    ("ListTile", r"\bListTile\s*\(", "Material ListTile —— 设计要 .row / .crow2"),
    ("Card(", r"\bCard\s*\(", "Material Card —— 设计要 .panel，且不用 elevation"),
    ("ElevatedButton", r"\bElevatedButton\b", "Material ElevatedButton —— 设计要 .btn.primary"),
    ("OutlinedButton", r"\bOutlinedButton\b", "Material OutlinedButton —— 设计要 .btn2"),
    ("SnackBar(", r"\bSnackBar\s*\(", "Material SnackBar —— 设计要 .toast"),
    ("Colors.*", r"\bColors\.[a-zA-Z]", "硬编码色 —— 一律走 context.colors / AppTokens"),
    ("Icons.*", r"\bIcons\.[a-zA-Z]", "Material 图标 —— 设计要 04-ICON-SYSTEM 的 84 枚"),
]


def load_spec():
    with open(SPEC_JSON, encoding="utf-8") as fh:
        return json.load(fh)


def load_lib():
    """rel_path -> 源码文本（只收 lib/ 下的 .dart）。"""
    out = {}
    for root, dirs, files in os.walk(os.path.join(PLAIN, "lib")):
        dirs[:] = [d for d in dirs if d not in (".dart_tool", "build")]
        for f in files:
            if f.endswith(".dart"):
                p = os.path.join(root, f)
                rel = os.path.relpath(p, PLAIN).replace("\\", "/")
                out[rel] = open(p, encoding="utf-8", errors="ignore").read()
    return out


def flatten(s):
    """源码 → 文本视图：去掉空白 / 引号 / 逗号 / `$`。

    Dart 允许把一句话拆成**相邻的多个字符串字面量**，编译器会拼成一句，
    但源码里隔着 `'` 和换行 —— 直接子串搜索必然搜不到：

        '桑基图回答的是「钱从哪来…」—— 比环形图更适合看结构，'
        '环形图更适合看占比。',

    本函数把源码压扁，让「设计稿的一句」能与「代码里的几个片段」对上。
    只作为**兜底**：字面命中优先，兜底命中在报表里会单独标出条数。
    """
    return re.sub(r"[\s'\"`,$]", "", s)


def screen_texts(sc):
    """转发到 screen_map（单一事实源），只取 (cls, value) 两列用于比对。"""
    hard, soft, data = SM.screen_texts(sc)
    pair = lambda rows: [(c, v) for c, v, _t in rows]
    return pair(hard), pair(soft), pair(data)


def check_screen(no, spec, lib):
    _, slug, title, status, target, note = SM.by_no(no)
    sc = spec[no - 1]
    hard, soft, data = screen_texts(sc)
    blob = "\n".join(lib.values())
    # 文本视图：见 flatten() 的说明。用于「一句话被拆成相邻字面量」与空白差异。
    blob_flat = flatten(blob)
    blob_no_comma = blob.replace(",", "")
    tgt = lib.get(target, "")

    def hit(rows, hay):
        return [r for r in rows if r[1] in hay]

    hard_lib = hit(hard, blob)
    # 兜底命中（只对字面搜不到的生效，不会把字面命中的重复计入）：
    #   ① 文本视图命中 —— 值被 Dart 拆成相邻的多个字符串字面量，或空白与设计稿不同；
    #   ② 拼接命中   —— 值由「词 + 数值」运行时拼出（`'${f.label} ¥…'`）。
    hard_loose = [
        r for r in hard
        if r not in hard_lib
        and (flatten(r[1]) in blob_flat or SM.composed_hit(r[1], blob_no_comma))
    ]
    hard_lib = hard_lib + hard_loose
    miss_lib = [r for r in hard if r not in hard_lib]
    soft_lib = hit(soft, blob)

    return {
        "no": no, "slug": slug, "title": title, "status": status,
        "target": target, "note": note,
        "exists": target in lib,
        "items": len(sc["items"]),
        "hard": len(hard), "hardInLib": len(hard_lib), "missLib": miss_lib,
        "hardComposed": len(hard_loose),
        "hardInTarget": len(hit(hard, tgt)),
        "soft": len(soft), "softInLib": len(soft_lib),
        "data": len(data),
    }


def scan_violations(lib, targets):
    """按文件统计违规模式；targets=None 表示全库。"""
    rows = []
    for name, pat, why in VIOLATIONS:
        per = []
        for rel, txt in sorted(lib.items()):
            if targets is not None and rel not in targets:
                continue
            n = len(re.findall(pat, txt))
            if n:
                per.append((rel, n))
        rows.append((name, why, sum(n for _, n in per), per))
    return rows


def fmt_gap(rows, limit=6):
    return "、".join(v for _, v in rows[:limit]) + ("…" if len(rows) > limit else "")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--batch", default=None, help="B0–B6")
    ap.add_argument("--screens", default=None, help="逗号分隔屏号，如 9,13,20")
    ap.add_argument("--list", type=int, default=None, help="打印某屏必现清单")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--violations", action="store_true", help="只报违规模式")
    ap.add_argument("--quiet-soft", action="store_true")
    a = ap.parse_args()

    spec = load_spec()
    lib = load_lib()

    if a.list:
        sc = spec[a.list - 1]
        hard, soft, data = screen_texts(sc)
        _, slug, title, status, target, note = SM.by_no(a.list)
        print(f"# 屏{a.list} {title}  [{status}]  → {target}")
        print(f"# {note}")
        print(f"\n## 必现结构性文案（{len(hard)} 条，门禁硬比对）")
        for cls, v in hard:
            print(f"  [{cls}] {v}")
        print(f"\n## 软比对文案（{len(soft)} 条，受用户数据影响）")
        for cls, v in soft:
            print(f"  [{cls}] {v}")
        print(f"\n## 样例数据（{len(data)} 条，不比对）")
        return 0

    if a.screens:
        want = [int(x) for x in a.screens.split(",") if x.strip()]
    elif a.batch:
        if a.batch not in BATCHES:
            print("未知批次：", a.batch, "可选", list(BATCHES))
            return 2
        want = BATCHES[a.batch][0] or [s[0] for s in SM.SCREENS]
    else:
        want = [s[0] for s in SM.SCREENS]

    if a.violations:
        targets = {SM.by_no(n)[4] for n in want} if (a.batch or a.screens) else None
        rows = scan_violations(lib, targets)
        print(f"# 违规模式扫描（范围：{'指定批次' if targets else '全库 lib/'}）\n")
        for name, why, tot, per in rows:
            flag = "✗" if tot else "✓"
            print(f"{flag} {name:<18} {tot:>4} 处   {why}")
            for rel, n in per[:6]:
                print(f"      {n:>3}  {rel}")
        return 0

    res = [check_screen(n, spec, lib) for n in want]

    if a.json:
        print(json.dumps(res, ensure_ascii=False, indent=1))
        return 0

    print(f"{'#':<3} {'状态':<8} {'目标文件':<46} {'硬文案':>7} {'软文案':>7} 说明")
    print("-" * 120)
    bad = 0
    for r in res:
        if r["missLib"]:
            bad += 1
            mark, tail = "✗", "缺：" + fmt_gap(r["missLib"])
        else:
            composed = r["hardComposed"]
            mark = "✓"
            tail = "（含 %d 条拼接命中）" % composed if composed else ""
        print("%-3d %-8s %-46s %3d/%-3d %3d/%-3d %s %s"
              % (r["no"], r["status"], r["target"].replace("lib/", ""),
                 r["hardInLib"], r["hard"], r["softInLib"], r["soft"], mark, tail))
    print("-" * 120)
    th = sum(r["hard"] for r in res)
    hi = sum(r["hardInLib"] for r in res)
    print("结构性文案覆盖：%d/%d = %.1f%%   未达标屏数：%d/%d"
          % (hi, th, 100 * hi / max(th, 1), bad, len(res)))

    if not a.quiet_soft:
        print("\n软比对文案（参考，不作为通过条件）：")
        for r in res:
            if r["soft"]:
                print("  屏%-3d %d/%d" % (r["no"], r["softInLib"], r["soft"]))

    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
