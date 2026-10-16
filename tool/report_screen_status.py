# -*- coding: utf-8 -*-
"""生成《29 屏对齐状态》：把「哪几屏真的按设计稿改完了」做成可复现的一份表。

与 `scan_font_scale.py` / `report_font_scale.py` 同一套路：
门禁（`redesign-v3/_build/check_screen_coverage.py`）管**判**，本脚本只管**出表**。

三个口径，分开列，不混为一谈：
  ① 文案覆盖 —— 硬口径，来自 `spec.json` 的实测文案（444 条），门禁硬比对；
  ② 违规残留 —— 29 屏的目标文件里还剩多少 `AppBar(` / `ListTile(` / `Card(` / `Icons.*`；
  ③ 接线情况 —— 该页面有没有被任何地方 import / 实例化（没接线 = 用户点不到）。

用法：
    python plain/tool/report_screen_status.py [--out 路径.html]

产出默认写到 `PlainApp/29屏对齐状态.html`。
"""
import argparse
import os
import re
import sys
from datetime import date

HERE = os.path.dirname(os.path.abspath(__file__))
PLAIN = os.path.dirname(HERE)                       # plain/
PROJ = os.path.dirname(PLAIN)                       # PlainApp/
sys.path.insert(0, os.path.join(PROJ, "redesign-v3", "_build"))

import check_screen_coverage as C  # noqa: E402
import screen_map as SM            # noqa: E402

VIOLATION_PATTERNS = [
    ("AppBar", r"\bAppBar\s*\("),
    ("ListTile", r"\bListTile\s*\("),
    ("Card", r"\bCard\s*\("),
    ("Icons", r"\bIcons\.[a-zA-Z]"),
]


def load_all_dart():
    """rel（相对 plain/）-> 源码，含 lib / test / tool。"""
    out = {}
    for root, _dirs, files in os.walk(PLAIN):
        rel_root = os.path.relpath(root, PLAIN).replace(os.sep, "/")
        if rel_root.split("/")[0] in (".dart_tool", "build", "windows", "macos",
                                      "linux", "android", "ios", "web"):
            continue
        for f in files:
            if not f.endswith(".dart"):
                continue
            p = os.path.join(root, f)
            out[os.path.relpath(p, PLAIN).replace(os.sep, "/")] = open(
                p, encoding="utf-8", errors="ignore").read()
    return out


def entry_class(src):
    m = re.search(
        r"class\s+(\w+)\s+extends\s+(?:Consumer\w*Widget|StatefulWidget|StatelessWidget)",
        src)
    return m.group(1) if m else None


def reachability(files):
    """target -> (引用者列表, 判定标签)。"""
    out = {}
    for _no, _slug, _title, _status, target, _note in SM.SCREENS:
        base = os.path.basename(target)
        src = files.get(target, "")
        cls = entry_class(src)
        refs = []
        for rel, s in files.items():
            if rel == target:
                continue
            if base in s or (cls and re.search(r"\b" + cls + r"\b", s)):
                refs.append(rel)
        if not refs:
            label = "未接线"
        elif any(r.endswith("app_router.dart") or r == "lib/main.dart" for r in refs):
            label = "路由/入口"
        else:
            label = "页内跳转"
        out[target] = (sorted(refs), label)
    return out


def build_rows():
    spec = C.load_spec()
    lib = C.load_lib()
    files = load_all_dart()
    reach = reachability(files)

    rows = []
    for sc_meta in SM.SCREENS:
        no = sc_meta[0]
        r = C.check_screen(no, spec, lib)
        target = r["target"]
        viol = {name: len(re.findall(pat, files.get(target, "")))
                for name, pat in VIOLATION_PATTERNS}
        refs, label = reach.get(target, ([], "未接线"))
        title = sc_meta[2].split(" ", 1)[1] if " " in sc_meta[2] else sc_meta[2]
        rows.append({
            "no": no, "title": title, "target": target,
            "hard": r["hardInLib"], "hardAll": r["hard"],
            "soft": r["softInLib"], "softAll": r["soft"],
            "loose": r["hardComposed"], "miss": r["missLib"],
            "viol": viol, "violTotal": sum(viol.values()),
            "reach": label, "refs": refs,
        })
    return rows


def esc(s):
    return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


CSS = """
:root{
  --ink:#16161A; --ink2:#38383D; --muted:#5E5E65;
  --line:#E6E4E0; --line2:#F1EFEC; --bg:#FAFAF8; --card:#FFFFFF;
  --ok:#0F6E56; --okbg:#E1F5EE; --warn:#854F0B; --warnbg:#FAEEDA;
  --mono:ui-monospace,SFMono-Regular,Consolas,monospace;
}
*{box-sizing:border-box}
body{margin:0;padding:40px 24px 72px;background:var(--bg);color:var(--ink);
  font:14px/1.6 -apple-system,"Segoe UI","Microsoft YaHei",sans-serif;
  -webkit-font-smoothing:antialiased}
.wrap{max-width:980px;margin:0 auto}
h1{font-size:20px;font-weight:600;margin:0 0 4px;letter-spacing:-.01em}
.sub{color:var(--muted);font-size:12px;margin-bottom:24px}
h2{font-size:14px;font-weight:600;margin:32px 0 10px;color:var(--ink2)}
h2 span{color:var(--muted);font-weight:400;font-size:12px;margin-left:6px}
.stats{display:flex;gap:10px;flex-wrap:wrap;margin-bottom:8px}
.stat{flex:1 1 150px;background:var(--card);border:1px solid var(--line);
  border-radius:10px;padding:10px 12px}
.stat b{display:block;font-size:18px;font-weight:600;letter-spacing:-.02em}
.stat span{font-size:11px;color:var(--muted)}
table{width:100%;border-collapse:collapse;background:var(--card);
  border:1px solid var(--line);border-radius:10px;overflow:hidden}
th,td{padding:6px 10px;text-align:left;font-size:12.5px;vertical-align:top}
th{font-weight:500;color:var(--muted);background:var(--line2);
  border-bottom:1px solid var(--line)}
td{border-bottom:1px solid var(--line2)}
tr:last-child td{border-bottom:none}
td.m{font-family:var(--mono);font-size:11.5px;color:var(--ink2);word-break:break-all}
td.n{white-space:nowrap;color:var(--muted);font-family:var(--mono);font-size:11.5px}
.tag{display:inline-block;padding:0 6px;border-radius:999px;font-size:11px;line-height:18px}
.tag.ok{background:var(--okbg);color:var(--ok)}
.tag.warn{background:var(--warnbg);color:var(--warn)}
.note{background:var(--card);border:1px solid var(--line);border-radius:10px;
  padding:12px 14px;font-size:12.5px;color:var(--ink2)}
.note ul{margin:6px 0 0;padding-left:18px}
.note li{margin:3px 0}
.note code,.inline{font-family:var(--mono);font-size:11.5px;
  background:var(--line2);padding:1px 5px;border-radius:4px}
.kv{display:flex;gap:8px;font-size:12.5px;padding:4px 0}
.kv b{font-weight:500;color:var(--muted);min-width:74px}
"""


def render(rows):
    hard_ok = [r for r in rows if not r["miss"]]
    hard_sum = sum(r["hard"] for r in rows)
    hard_hit = sum(r["hard"] for r in rows if not r["miss"])
    wired = [r for r in rows if r["reach"] != "未接线"]
    dirty = [r for r in rows if r["violTotal"]]

    P = []
    P.append('<!DOCTYPE html>\n<html lang="zh-CN">\n<head>\n<meta charset="utf-8">')
    P.append('<title>素记 · 29 屏对齐状态</title>')
    P.append("<style>%s</style>\n</head>\n<body>\n<div class=\"wrap\">" % CSS)
    P.append('<h1>素记 Plain · 29 屏对齐状态</h1>')
    P.append('<div class="sub">%s · 口径与产出脚本见 <code>plain/tool/report_screen_status.py</code>'
             '　·　文案真值来自 <code>redesign-v3/_build/spec.json</code>（真浏览器实测）</div>'
             % date.today().isoformat())

    P.append('<div class="stats">')
    P.append('<div class="stat"><b>%d/29</b><span>文案门禁达标屏</span></div>' % len(hard_ok))
    P.append('<div class="stat"><b>%d/%d</b><span>结构性文案覆盖</span></div>' % (hard_hit, hard_sum))
    P.append('<div class="stat"><b>%d</b><span>已接线（可达）</span></div>' % len(wired))
    P.append('<div class="stat"><b>%d</b><span>仍有 Material 残留的屏</span></div>' % len(dirty))
    P.append("</div>")

    P.append('<h2>A · 逐屏状态<span>硬文案 = 门禁硬比对；「兜底」= 值被 Dart 拆成相邻字面量'
             '或运行时拼接（词与数值都在源码里）</span></h2>')
    P.append("<table>")
    P.append("<tr><th style=\"width:3%\">#</th><th style=\"width:22%\">页面</th>"
             "<th style=\"width:26%\">目标文件</th><th style=\"width:8%\">硬文案</th>"
             "<th style=\"width:7%\">软文案</th><th style=\"width:6%\">兜底</th>"
             "<th style=\"width:9%\">Material</th><th style=\"width:9%\">接线</th>"
             "<th>引用者</th></tr>")
    for r in rows:
        cls = "ok" if not r["miss"] else "warn"
        hard = "%d/%d" % (r["hard"], r["hardAll"])
        if not r["miss"]:
            hard += ' <span class="tag %s">齐</span>' % cls
        else:
            hard = '<span class="tag warn">缺 %d</span>' % len(r["miss"])
        viol = "—" if not r["violTotal"] else " ".join(
            "%s%d" % (k, v) for k, v in r["viol"].items() if v)
        reach = ('<span class="tag ok">%s</span>' % r["reach"]
                 if r["reach"] != "未接线" else '<span class="tag warn">未接线</span>')
        refs = "、".join(x.replace("lib/", "").replace("test/", "test:")
                         for x in r["refs"][:3]) or "—"
        P.append("<tr><td class=\"n\">%d</td><td>%s</td><td class=\"m\">%s</td>"
                 "<td class=\"n\">%s</td><td class=\"n\">%d/%d</td><td class=\"n\">%s</td>"
                 "<td class=\"n\">%s</td><td>%s</td><td class=\"m\">%s</td></tr>"
                 % (r["no"], esc(r["title"]), esc(r["target"].replace("lib/features/", "")),
                    hard, r["soft"], r["softAll"],
                    r["loose"] or "—", viol, reach, esc(refs)))
    P.append("</table>")

    P.append('<h2>B · 未接线的屏<span>页面按设计做完了，但没有任何地方 import 它 —— '
             '用户点不到</span></h2>')
    P.append('<div class="note">')
    unwired = [r for r in rows if r["reach"] == "未接线"]
    if unwired:
        P.append("<ul>")
        for r in unwired:
            P.append("<li>屏 %d · %s　<code>%s</code></li>"
                     % (r["no"], esc(r["title"]), esc(r["target"].replace("lib/", ""))))
        P.append("</ul>")
        P.append('<div class="kv"><b>接法</b><span>照《编码指令-29屏UI对齐》的 IA：'
                 '屏 9「发现」是新入口，屏 13/20–25/27–29 从发现页或对应一级页跳。</span></div>')
    else:
        P.append("无。")
    P.append("</div>")

    P.append('<h2>C · 29 屏内的 Material 残留<span>设计明令换掉的写法</span></h2>')
    P.append('<div class="note">')
    if dirty:
        P.append("<ul>")
        for r in dirty:
            items = "、".join("%s×%d" % (k, v) for k, v in r["viol"].items() if v)
            P.append("<li>屏 %d · %s　<code>%s</code>　%s</li>"
                     % (r["no"], esc(r["title"]),
                        esc(r["target"].replace("lib/", "")), items))
        P.append("</ul>")
    else:
        P.append("无。")
    P.append("</div>")

    return "\n".join(P)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(PROJ, "29屏对齐状态.html"))
    a = ap.parse_args()
    rows = build_rows()
    html = render(rows)
    with open(a.out, "w", encoding="utf-8") as fh:
        fh.write(html)
    ok = sum(1 for r in rows if not r["miss"])
    wired = sum(1 for r in rows if r["reach"] != "未接线")
    print("文案达标 %d/29 · 已接线 %d/29 · 有 Material 残留 %d 屏 -> %s"
          % (ok, wired, sum(1 for r in rows if r["violTotal"]), a.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
