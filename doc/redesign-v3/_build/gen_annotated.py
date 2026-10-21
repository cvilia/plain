"""生成《单独确认-标注版.html》—— iPhone 16（393 × 852 pt）下的全量规格标注。

产出只有**一个** HTML：
  · 29 屏 1:1 真渲染（画布 = iPhone 16 逻辑分辨率）
  · 每屏叠加：控件描边框 + 序号 + 纵向尺寸线（控件间距）
  · 每屏右侧：逐行规格表（位置 / 尺寸 / 圆角 / 填充 / 边框 / 排版 / 间距）
  · 顶部：全局规范（字阶 / 圆角 / 间距 / 颜色令牌）+ 一致性审计

所有数值都来自 _spec_collect.py 的真浏览器实测（spec.json），
没有一个是手写的 —— 这是本文档一贯的做法：
「按代码写对了、但按实测是错的」在这套交付里已经栽过多次。
"""
import json
import os
import re
import sys

import gen_screens as G
import gen_all_screens as A
import _spec_collect as SC

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
OUT = os.path.join(ROOT, "单独确认-标注版.html")

# ══════════════════════════════════════════════════════════════════════
# 控件中文名 —— 只覆盖高频类。没有条目的直接显示 class 名（研发本来就认它）
# ══════════════════════════════════════════════════════════════════════
LABEL = {
    "screen": "屏幕", "statusbar": "状态栏", "sb-time": "状态栏·时间",
    "sb-marks": "状态栏·信号电量", "topbar": "顶栏", "h1": "页面标题",
    "tb-right": "顶栏·右侧操作", "iconbtn": "图标按钮", "scroll": "滚动内容区",
    "addbody": "记账主体区", "scroll-pad": "底部留白", "grp": "分组", "grp0": "首分组",
    "panel": "面板", "notepanel": "说明面板", "chartpanel": "图表面板",
    "cmppanel": "对比面板", "row": "列表行", "rcol": "行·文字列", "rt": "行·标题",
    "sub": "行·副标题", "sval": "行·右侧值", "ricos": "行·图标位",
    "eyebrow": "分组小标题", "hairline": "分割线", "nav": "底部导航",
    "navitem": "导航项", "navlab": "导航项文字", "navfab": "导航·中央按钮",
    "switch": "开关", "knob": "开关滑块", "tile": "分类格", "tile-n": "分类格名称",
    "key": "键盘键", "tagx": "标签", "dot8": "色点 8", "dot6": "色点 6",
    "hero": "首屏区", "hero-label": "首屏区·标签", "hero-amt": "首屏区·主金额",
    "hero-split": "首屏区·分栏", "hs": "分栏小项", "hs-l": "分栏小项·标签",
    "hs-v": "分栏小项·值", "amt": "金额", "cur": "金额·货币符", "int": "金额·整数",
    "pnt": "金额·小数点", "dec": "金额·小数", "cv": "金额容器",
    "btn": "主按钮", "btn2": "次要按钮", "textbtn": "文字按钮", "segi": "分段项",
    "seg": "分段控件", "ttab": "类型页签", "fab": "悬浮按钮",
    "pbar": "进度条", "prow": "进度行", "prowname": "进度行·名称", "pamt": "进度行·金额",
    "prowfoot": "进度行·脚注", "crow": "对比行", "crow2": "对比行 2",
    "duocol": "双列容器", "cicon": "行·图标", "cnt": "计数", "drag": "拖拽柄",
    "chev": "右箭头", "kvr": "键值行", "cell": "单元格", "rulecond": "规则条件",
    "ruleno": "规则序号", "ricnt": "计数徽标", "thsw": "主题色卡",
    "thtick": "主题色卡·勾选", "ttab on": "类型页签·选中",
    "xz": "选中标记", "b": "块", "avt": "成员头像", "lrow": "图例行",
    "lname": "图例·名称", "lpct": "图例·占比", "lamt": "图例·金额", "lgdot": "图例色点",
    "legend": "图例", "donut": "环形图", "donut-wrap": "环形图容器",
    "dn-c1": "环图·中心金额", "dn-cur": "环图·货币符", "dn-pnt": "环图·小数点",
    "dn-dec": "环图·小数", "dn-c2": "环图·TOTAL", "dn-seg": "环图·扇区",
    "bars": "柱状图", "minibars": "迷你柱图", "stack": "堆叠条", "sankey": "桑基图",
    "skc": "桑基·列标题", "skl": "桑基·分类标签", "skg": "桑基·结余标签",
    "skv": "桑基·金额", "spark": "迷你趋势线", "expr": "表达式", "caret": "光标",
    "xl": "特大金额", "s": "小金额", "tone-ink": "常规色", "tone-income": "收入色",
    "tone-up": "涨色", "tone-dn": "跌色", "on": "选中态", "lock": "禁用态",
    "notel": "备注行", "ml": "备注", "tag": "标记", "ttab-row": "类型页签行",
}

KIND_META = {
    "box":       ("容器 / 面板", "#2563EB"),
    "textbox":   ("带底文字", "#0891B2"),
    "text":      ("文字", "#059669"),
    "icon":      ("图标", "#7C3AED"),
    "divider":   ("分割线", "#DB2777"),
    "container": ("布局容器", "#64748B"),
    "group":     ("布局组", "#94A3B8"),
}

# ══════════════════════════════════════════════════════════════════════
# 规范收敛记录（与 _spec_collect.FIX_CSS 一一对应；此处只用于审计展示）
# ══════════════════════════════════════════════════════════════════════
FIXES = [
    (".segi", "圆角", "9px", "8px  r1", "分段控件选中项", 13),
    (".thsw > i", "圆角", "6px", "8px  r1", "主题页签 18×18 色卡", 20),
    (".ruleno / .ricnt", "圆角", "7px", "8px  r1", "22×22 规则序号 / 计数徽标", 11),
    (".avt", "圆角", "10px", "8px  r1", "30×30 成员头像", 3),
    (".navfab", "圆角", "14px", "12px  r2", "底部导航中央 44×44", 4),
    (".sb-time", "字号", "14.5px", "15px", "状态栏时间（29 屏全覆盖）", 29),
    (".hs-v", "字号", "16px", "15px", "hero 分栏小值", 10),
    ("donut_amount 取档", "字号", "18 / 16", "20 / 15", "环形图中心「放不下就降档」的档位本身越界", 2),
    (".dn-c2", "字号", "8.5px", "12px", "环形图 TOTAL 标签", 1),
    (".skc / .skl / .skg / .skv", "字号", "10 / 10.5 / 12.5px", "12px", "桑基图标签", 8),
    ("屏25「天」/ 屏26「%」", "字号", "0.5em / 0.52em", "0.62em", "内联比率偏离文档规定的金额符号比率", 2),
]

KNOWN_EXCEPTIONS = [
    (".minibars > i", "border-radius: 4px 4px 0 0",
     "迷你柱状图的柱顶圆角。柱子宽仅十余 px，套 r1=8 会变成半圆；"
     "属数据可视化惯例，不计入 UI 盒子的圆角语言。"),
    ("12 个分类基色", "见 --cat-*",
     "令牌明文规定：只可用于环形图扇区、列表行 6px 圆点、选中分类格描边；"
     "禁止用于按钮底与正文文字。标注版按此口径保留。"),
    ("0.62× 字号派生", "9.3 / 11.16 / 12.4 / 21.08 / 27.28px",
     "金额四段式的货币符与小数位用 0.62× 父级字号 —— 这是 type.rules 里的明文规则，"
     "不算越界（本版实测共 108 处）。"),
]


def hexof(css):
    """rgb()/rgba() → #RRGGBB（带透明度时附 百分比）。"""
    if not css:
        return ""
    m = re.search(r"rgba?\(([^)]+)\)", css)
    if not m:
        return css
    p = [x.strip() for x in m.group(1).split(",")]
    r, g, b = (int(float(x)) for x in p[:3])
    a = float(p[3]) if len(p) > 3 else 1.0
    h = f"#{r:02X}{g:02X}{b:02X}"
    return h if a >= 0.999 else f"{h} {round(a * 100)}%"


def token_map():
    """令牌值 → 变量名，用于在标注里直接给出「这个色是哪个令牌」。"""
    out = {}
    combo = "subai.light"
    r, e = G.TOK["resolved"][combo], G.TOK["v3Additions"][combo]
    for k, v in G.VAR_MAP:
        out.setdefault(hexof(r[k]), f"--{v}")
    for k, v in G.VAR_MAP_V3:
        out.setdefault(hexof(e[k]), f"--{v}")
    for c in G.TOK["invariants"]["category"]:
        out.setdefault(hexof(c["base"]), f"--cat-{c['ref']}")
    return out


def prep(spec, tokmap):
    """给实测数据补上：显示深度、有效间距、令牌名、是否在首屏内。"""
    for s in spec:
        idx = {it["i"]: it for it in s["items"]}
        for it in s["items"]:
            dep, p = 0, it["par"]
            while p and p in idx:
                dep += 1
                p = idx[p]["par"]
            it["dep"] = dep

            gv, gk = None, ""
            if it["gap"]:
                gy, gx = it["gap"]
                if gx >= 0 and gy < 0:       # 横向并排 → 取水平间距
                    gv, gk = gx, "h"
                else:                        # 纵向堆叠 → 取垂直间距
                    gv, gk = gy, "v"
            it["gv"], it["gk"] = gv, gk
            # 亚像素间距是「行内文本流」的副产品（相邻 span 的字形留白），
            # 不是布局间距 —— 0.55 / 4.63 / 117.56 这类值全部来自这里，
            # 留着会把直方图搅浑，所以判为无效。
            if it["gv"] is not None and (abs(it["gv"] - round(it["gv"])) > 0.05
                                         or abs(it["gv"]) < 1):
                it["gv"] = None
            it["below"] = it["y"] >= SC.CANVAS_H

            if it["bg"]:
                it["bgn"] = tokmap.get(hexof(it["bg"]), "")
            if it["bd"]:
                it["bd"] = re.sub(r"rgba?\([^)]+\)", lambda m: hexof(m.group(0)), it["bd"])
            if it["txt"]:
                it["txt"]["coln"] = tokmap.get(hexof(it["txt"]["col"]), "")
            if it["ic"]:
                it["icn"] = tokmap.get(hexof(it["ic"]), "")
    return spec


def audit(spec):
    """跨屏一致性统计。"""
    its = [it for s in spec for it in s["items"]]
    base = {12, 14, 15, 20, 22, 34, 44}
    der = {round(v * 0.62, 2) for v in base}
    cnt = lambda xs: {k: xs.count(k) for k in sorted(set(xs), key=lambda z: str(z))}

    fsz = [it["txt"]["size"] for it in its if it["txt"]]
    rad = [it["rad"] for it in its if it["rad"] and it["rad"] != "0px"]
    gap = [it["gv"] for it in its if it["gv"] and it["gv"] >= 2]
    pad = [v for it in its if it["pad"] for v in it["pad"] if v]
    bgc = [hexof(it["bg"]) for it in its if it["bg"]]
    txc = [hexof(it["txt"]["col"]) for it in its if it["txt"]]
    icc = [hexof(it["ic"]) for it in its if it["ic"]]

    off_f = sorted({v for v in fsz if v not in base and v not in der})
    off_r = sorted({v for v in rad if v not in
                    ("8px", "12px", "16px", "24px", "999px", "50%", "4px 4px 0px 0px")})

    return {
        "nScreens": len(spec), "nItems": len(its),
        "fontUsed": cnt(fsz), "fontBase": sorted(base), "fontDerived": sorted(der),
        "radUsed": cnt(rad),
        "gapUsed": {k: v for k, v in cnt(gap).items() if v >= 3},
        "padUsed": {k: v for k, v in cnt(pad).items() if v >= 3},
        "padOffGrid": sorted({v for v in pad if v % 4 != 0 and v >= 2}),
        "gapOffGrid": sorted({v for v in gap if v % 4 != 0 and v >= 2}),
        "bgUsed": cnt(bgc), "txUsed": cnt(txc), "icUsed": cnt(icc),
        "offFont": off_f, "offRad": off_r,
        "nDerived": sum(1 for v in fsz if v in der),
        "dividers": len([it for it in its if it["kind"] == "divider"]),
        "icons": len([it for it in its if it["kind"] == "icon"]),
        # 上缘在屏内、下缘越过 852 的元素（滚动内容的自然溢出，画布上把框裁到边缘）
        "clipBelow": len([it for it in its
                          if it["y"] < SC.CANVAS_H and it["y"] + it["h"] > SC.CANVAS_H]),
        "belowFold": len([it for it in its if it.get("below")]),
    }


# ══════════════════════════════════════════════════════════════════════
# 页面 CSS
# ══════════════════════════════════════════════════════════════════════
ANN_CSS = """
/* ── 标注版外壳 ─────────────────────────────────────────────────── */
*{box-sizing:border-box}
html,body{margin:0}
body{background:#EDEFF2;color:#16181D;
  font:400 13px/1.55 "Inter","MiSans","PingFang SC",system-ui,sans-serif;
  -webkit-font-smoothing:antialiased}
.stage{display:block !important;padding:0 !important;gap:0 !important;justify-content:flex-start !important}
.flabel{display:none !important}
.screenpicker,.toolbar,.vergrouph{display:none !important}

.doc{max-width:1500px;margin:0 auto;padding:22px 26px 90px}

/* ── 顶部：标题与规范总览 ───────────────────────────────────────── */
.hero-doc{background:#fff;border:1px solid #E1E4E9;border-radius:16px;
  padding:22px 26px;margin-bottom:18px}
.hero-doc h1{margin:0 0 4px;font-size:22px;font-weight:700;letter-spacing:-.01em}
.hero-doc .lede{color:#5C6270;font-size:13px;margin-bottom:16px}
.hero-doc .lede b{color:#16181D}
.chips{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:4px}
.chipx{display:inline-flex;align-items:center;gap:6px;height:26px;padding:0 10px;
  border-radius:8px;background:#F1F3F6;font-size:12px;font-weight:600;color:#3A404B}
.chipx b{color:#0F172A;font-weight:700}
.chipx i{width:10px;height:10px;border-radius:3px;display:block}

/* ── 通用卡片 ───────────────────────────────────────────────────── */
.card{background:#fff;border:1px solid #E1E4E9;border-radius:14px;
  padding:16px 18px;margin-bottom:14px}
.card > h2{margin:0 0 3px;font-size:14px;font-weight:700;letter-spacing:.01em}
.card > .hint{color:#71767F;font-size:11.5px;margin-bottom:12px}
.grid2{display:grid;grid-template-columns:repeat(auto-fit,minmax(310px,1fr));gap:16px}

table.mt{width:100%;border-collapse:collapse;font-size:11.5px}
table.mt th{text-align:left;font-weight:600;color:#71767F;padding:5px 8px 5px 0;
  border-bottom:1px solid #E6E9EE;white-space:nowrap}
table.mt td{padding:4px 8px 4px 0;border-bottom:1px solid #F1F3F6;vertical-align:top}
table.mt td.num{font-variant-numeric:tabular-nums;text-align:right;white-space:nowrap;
  color:#3A404B}
.sw{display:inline-block;width:12px;height:12px;border-radius:3px;vertical-align:-2px;
  margin-right:6px;border:1px solid rgba(0,0,0,.14)}
code{font:600 11px/1 "SFMono-Regular",Consolas,monospace;background:#F1F3F6;
  padding:2px 5px;border-radius:4px;color:#2B3140;white-space:nowrap}

/* 徽标 */
.ok{display:inline-block;padding:1px 7px;border-radius:6px;background:#E7F6EE;
  color:#0B7A4B;font-size:11px;font-weight:700}
.warnx{display:inline-block;padding:1px 7px;border-radius:6px;background:#FDECEC;
  color:#B4232A;font-size:11px;font-weight:700}
.mute{color:#8A9099}

/* ── 吸顶工具条 ─────────────────────────────────────────────────── */
.bar{position:sticky;top:0;z-index:60;background:rgba(237,239,242,.94);
  backdrop-filter:blur(8px);border-bottom:1px solid #DDE1E7;padding:9px 0;margin-bottom:16px}
.bar .inner{max-width:1500px;margin:0 auto;padding:0 26px;display:flex;
  align-items:center;gap:14px;flex-wrap:wrap}
.bar .grp{display:flex;align-items:center;gap:6px}
.bar .lab{font-size:11px;font-weight:700;color:#7A8089;letter-spacing:.04em;
  text-transform:uppercase}
.bar button{height:26px;padding:0 11px;border:1px solid #D8DCE3;background:#fff;
  border-radius:7px;font:600 11.5px/1 inherit;color:#3A404B;cursor:pointer}
.bar button.on{background:#16181D;border-color:#16181D;color:#fff}
.bar input{height:26px;padding:0 10px;border:1px solid #D8DCE3;border-radius:7px;
  font:400 12px/1 inherit;width:190px;outline:none}
.bar input:focus{border-color:#16181D}
.bar select{height:26px;padding:0 6px;border:1px solid #D8DCE3;border-radius:7px;
  font:600 11.5px/1 inherit;color:#3A404B;background:#fff;max-width:250px;outline:none}
.bar .stat{margin-left:auto;font-size:11.5px;color:#71767F;font-variant-numeric:tabular-nums}

/* ── 单屏区块 ───────────────────────────────────────────────────── */
.spec{background:#fff;border:1px solid #E1E4E9;border-radius:16px;
  margin-bottom:20px;overflow:hidden}
.spec-h{display:flex;align-items:baseline;gap:12px;padding:13px 20px;
  border-bottom:1px solid #EDF0F4;background:#FAFBFC}
.spec-h .no{font:700 12px/1 "SFMono-Regular",Consolas,monospace;color:#fff;
  background:#16181D;border-radius:6px;padding:5px 8px;letter-spacing:.02em}
.spec-h h3{margin:0;font-size:14.5px;font-weight:700}
.spec-h .meta{margin-left:auto;font-size:11.5px;color:#71767F;
  font-variant-numeric:tabular-nums}
.spec-body{display:flex;align-items:flex-start;gap:0}

/* 画布区：左右留出量尺寸的空档 */
.cvwrap{flex:0 0 auto;padding:34px 30px 30px 62px;border-right:1px solid #EDF0F4;
  background:#F7F9FB}
/* ⚠️ 描边必须用 box-shadow 而不是 border —— border 会挤压内容盒，
   .screen 会被压成 391×850，而 spec.json 是按 393×852 实测的，
   于是叠加层与渲染当场错位 2px。这条踩过一次，别再改回去。 */
.frame{position:relative;width:393px !important;height:852px !important;
  background:#fff;border:0;
  box-shadow:0 0 0 1px #E1E4E9, 0 1px 3px rgba(16,24,40,.10),
             0 10px 28px rgba(16,24,40,.07)}
.ovl{position:absolute;inset:0;pointer-events:none;z-index:9;overflow:visible}
/* ⚠️ 描边框必须套一层裁切容器。
   .screen 自己 overflow:hidden，但叠加层挂在 .frame 上，而 .frame 是 overflow:visible
   —— 滚动内容的框（如 SP-1-03 的 .catpanel 866 高、起始 y=151）会直接溢出到机身外，
   实测第 5 屏有 4 个框越界、最远下溢 165px。
   .ovl 本身不能裁剪（左侧尺寸线画在 left:-30px，要露在机身外），
   所以只把 .ov / .bd 收进 .ovclip 里裁，尺寸线留在 .ovl 上。 */
.ovl .ovclip{position:absolute;inset:0;overflow:hidden;pointer-events:none}
.ovl .ov{position:absolute;border:1px solid var(--c);opacity:.42;pointer-events:auto;
  cursor:crosshair}
.ovl .ov.hi{opacity:1;border-width:2px;box-shadow:0 0 0 2px rgba(255,255,255,.9) inset;
  z-index:20}
.ovl .ov.dim{opacity:.10}
/* 内容越过屏幕下缘时的「仍有下文」标记（框被裁掉了，用它提示后面还有） */
.ovl .cut{position:absolute;font:700 11px/1 "SFMono-Regular",Consolas,monospace;
  color:#DB2777;pointer-events:none}
.ovl .bd{position:absolute;min-width:15px;height:15px;padding:0 3px;border-radius:4px;
  background:var(--c);color:#fff;font:700 9.5px/15px "SFMono-Regular",Consolas,monospace;
  text-align:center;transform:translate(-7px,-7px);display:none;z-index:30;
  pointer-events:none;white-space:nowrap}
body.shownum .ovl .bd{display:block}
.ovl .bd.hi{display:block;z-index:31;height:16px;line-height:16px}
/* 分割线在画布上单独加粗描出，便于一眼找到 */
.ovl .ov.k-divider{border-color:#DB2777;border-width:2px;opacity:.95}
/* 纵向尺寸线（画在左侧空档里） */
.ovl .dim{position:absolute;width:0;border-left:1px dashed #B9C0CA}
.ovl .dim::before,.ovl .dim::after{content:"";position:absolute;left:-3px;width:7px;
  border-top:1px solid #B9C0CA}
.ovl .dim::before{top:0}.ovl .dim::after{bottom:0}
.ovl .diml{position:absolute;font:700 9.5px/1 "SFMono-Regular",Consolas,monospace;
  color:#5C6270;background:#F7F9FB;padding:1px 3px;border-radius:3px;
  transform:translate(-100%,-50%);white-space:nowrap}

/* 规格表区 */
.tbwrap{flex:1 1 auto;min-width:0;padding:12px 16px 16px}
.tbscroll{max-height:900px;overflow:auto;border:1px solid #EDF0F4;border-radius:10px}
table.st{width:100%;border-collapse:separate;border-spacing:0;font-size:11.5px}
table.st th{position:sticky;top:0;z-index:5;background:#F7F9FB;text-align:left;
  font-weight:600;color:#71767F;padding:7px 8px;border-bottom:1px solid #E6E9EE;
  white-space:nowrap}
table.st td{padding:5px 8px;border-bottom:1px solid #F4F6F8;vertical-align:top}
table.st tr:hover td{background:#F7FAFF}
table.st tr.hi td{background:#EAF2FF}
table.st tr.dimop{opacity:.42}
table.st td.i{font:700 10.5px/1 "SFMono-Regular",Consolas,monospace;color:#5C6270;
  white-space:nowrap}
table.st td.el{white-space:nowrap;max-width:210px;overflow:hidden;text-overflow:ellipsis}
table.st td.el .cn{color:#16181D;font-weight:600}
table.st td.el .cl{color:#8A9099;font-size:10.5px;
  font-family:"SFMono-Regular",Consolas,monospace}
table.st td.n{font-variant-numeric:tabular-nums;text-align:right;white-space:nowrap}
table.st td.col{font-family:"SFMono-Regular",Consolas,monospace;font-size:10.5px;
  color:#2B3140;white-space:nowrap}
table.st td.tx{max-width:260px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;
  color:#3A404B}
table.st .kd{display:inline-block;width:7px;height:7px;border-radius:2px;
  margin-right:6px;vertical-align:1px}
table.st .ind{display:inline-block;border-left:1px solid #DFE4EA;
  height:11px;vertical-align:-2px;margin-right:5px}
table.st tr.grprow td{background:#FAFBFC;font-weight:600}
.fil{display:inline-flex;align-items:center;gap:5px}
.fil i{width:11px;height:11px;border-radius:3px;display:block;
  border:1px solid rgba(0,0,0,.16);flex:0 0 auto}
.dv{font-weight:700;color:#DB2777}
.bgchip{display:inline-block;padding:1px 6px;border-radius:5px;background:#F1F3F6;
  color:#5C6270;font-size:10.5px;font-weight:600}
"""


# ══════════════════════════════════════════════════════════════════════
# 渲染器 JS
# ══════════════════════════════════════════════════════════════════════
RENDER_JS = r"""
<script>
(function () {
  var P = JSON.parse(document.getElementById('SPEC').textContent);
  var SPEC = P.spec, LABEL = P.label, KM = P.kind, TOK = P.tok;
  var W = P.cw, H = P.ch;
  var filterKind = '', q = '', onlyFirst = true;

  // 把实测规格挂到 window 上，方便外部探针/控制台独立核对
  // （不参与渲染逻辑，删掉也不影响显示）。
  window.PLAIN_SPEC = { w: W, h: H, screens: SPEC, label: LABEL, kind: KM, tok: TOK };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c];
    });
  }
  function nameOf(it) {
    var c = (it.cls || '').split(/\s+/).filter(function (x) { return x && x !== 'on' && x !== 'lock'; });
    var key = c.join(' ');
    var cn = LABEL[it.cls] || LABEL[c[0]] || '';
    var cl = it.cls || it.tag;
    if (it.cls === 'on') { cn = '选中态'; cl = it.tag + '.on'; }
    return { cn: cn, cl: cl };
  }
  function radOf(r) {
    if (!r || r === '0px') return '';
    return r.replace(/px/g, '').replace(/\s+/g, ' ');
  }
  function n(v) { return (Math.round(v * 10) / 10).toString(); }

  // ── 1. 重排版面：每帧变成 [画布 | 规格表] ──────────────────────────
  var stage = document.querySelector('.stage');
  SPEC.forEach(function (s, fi) {
    var fr = document.querySelector('.frame[data-screen="' + fi + '"]');
    if (!fr) return;
    fr.remove();

    var sec = document.createElement('section');
    sec.className = 'spec';
    sec.id = 's' + s.no;
    sec.innerHTML =
      '<div class="spec-h"><span class="no">' + String(s.no).padStart(2, '0') + '</span>' +
      '<h3>' + esc(s.title) + '</h3>' +
      '<span class="meta">iPhone 16 · ' + s.canvas[0] + ' × ' + s.canvas[1] + ' pt · ' +
      '元素 ' + s.items.length + ' · 分割线 ' +
      s.items.filter(function (i) { return i.kind === 'divider'; }).length + '</span></div>' +
      '<div class="spec-body"><div class="cvwrap"></div><div class="tbwrap">' +
      '<div class="tbscroll"></div></div></div>';

    var cvwrap = sec.querySelector('.cvwrap');
    fr.style.cssText = '';
    cvwrap.appendChild(fr);
    sec.querySelector('.tbscroll').innerHTML = table(s);

    stage.appendChild(sec);
    overlay(fr, s);

    fr.addEventListener('mouseover', function (e) {
      var b = e.target.closest('.ov');
      if (b) hiRow(sec, +b.getAttribute('data-i'), true);
    });
    fr.addEventListener('mouseout', function (e) {
      var b = e.target.closest('.ov');
      if (b) hiRow(sec, +b.getAttribute('data-i'), false);
    });
  });

  // ── 2. 画布叠加层 ────────────────────────────────────────────────
  function overlay(fr, s) {
    var ovl = document.createElement('div');
    ovl.className = 'ovl';
    var html = '<div class="ovclip">';   // 描边框 / 序号角标 收在这里裁，别溢出机身

    // 2a. 控件描边 + 序号
    s.items.forEach(function (it) {
      if (it.below) return;                       // 首屏之下不画（在表里标出）
      var col = (KM[it.kind] || [0, '#999'])[1];
      html += '<div class="ov k-' + it.kind + '" data-i="' + it.i + '" style="' +
        'left:' + it.x + 'px;top:' + it.y + 'px;width:' + it.w + 'px;height:' +
        Math.max(it.h, 1) + 'px;--c:' + col + '"></div>';
      // 角标贴着元素左上角；若这样会被下缘裁掉，就翻到元素上方
      var by = it.y;
      if (by + 16 > H) by = Math.max(0, it.y - 16);
      html += '<div class="bd" data-i="' + it.i + '" style="left:' + it.x + 'px;top:' +
        by + 'px;--c:' + col + '">' + it.i + '</div>';
      // 下缘越过屏幕：框会被裁，补一个 ▾ 说明「内容还有下文」
      if (it.y + it.h > H)
        html += '<div class="cut" style="left:' + Math.min(it.x + it.w - 4, W - 10) +
          'px;top:' + (H - 13) + 'px">▾</div>';
    });

    html += '</div>';   // /.ovclip

    // 2b. 纵向尺寸线：只画浅层（dep<=3）且间距 >=4 的相邻控件
    s.items.forEach(function (it) {
      if (it.below || it.gk !== 'v' || it.gv == null || it.gv < 4 || it.dep > 3) return;
      var y0 = it.y - it.gv, y1 = it.y;
      if (y0 < 0) return;
      html += '<div class="dim" style="left:-30px;top:' + y0 + 'px;height:' +
        Math.max(y1 - y0, 1) + 'px"></div>';
      html += '<div class="diml" style="left:-33px;top:' +
        ((y0 + y1) / 2) + 'px">' + n(it.gv) + '</div>';
    });

    // 2c. 左右页边距尺寸线
    var scr = s.items[0];
    if (scr) {
      html += '<div class="diml" style="left:16px;top:-14px;transform:translate(-50%,0)">' +
        '0,0</div>';
    }
    ovl.innerHTML = html;
    fr.appendChild(ovl);
  }

  // ── 3. 规格表 ────────────────────────────────────────────────────
  function table(s) {
    var h = '<table class="st"><thead><tr>' +
      '<th>#</th><th>元素</th><th>位置 x, y</th><th>尺寸 宽 × 高</th>' +
      '<th>圆角</th><th>填充 / 边框</th><th>文字 · 字号 / 字重 · 颜色</th>' +
      '<th>间距</th></tr></thead><tbody>';

    s.items.forEach(function (it) {
      var nm = nameOf(it);
      var kd = KM[it.kind] || ['', '#999'];
      var ind = '';
      for (var k = 0; k < Math.min(it.dep, 7); k++) ind += '<span class="ind"></span>';

      var fill = '';
      if (it.bg) {
        var nmTok = it.bgn ? ' <span class="bgchip">' + esc(it.bgn) + '</span>' : '';
        fill += '<span class="fil"><i style="background:' + it.bg + '"></i>' +
          esc(hex(it.bg)) + '</span>' + nmTok;
      }
      if (it.bd) fill += (fill ? '<br>' : '') + '<span class="bgchip">边框 ' +
        esc(it.bd.replace('rgb', '').replace(/\s+/g, ' ')) + '</span>';

      var tx = '';
      if (it.txt) {
        tx = esc(it.txt.v.length > 26 ? it.txt.v.slice(0, 26) + '…' : it.txt.v) +
          '  <span class="mute">' + n(it.txt.size) + 'px / ' + it.txt.wt + '</span> ' +
          '<span class="fil"><i style="background:' + it.txt.col + '"></i>' +
          hex(it.txt.col) + '</span>';
        if (it.txt.coln) tx += ' <span class="bgchip">' + esc(it.txt.coln) + '</span>';
      } else if (it.ic) {
        tx = '<span class="mute">图标</span> <span class="fil"><i style="background:' +
          it.ic + '"></i>' + hex(it.ic) + '</span>' +
          (it.icn ? ' <span class="bgchip">' + esc(it.icn) + '</span>' : '');
      } else if (it.kind === 'divider') {
        tx = '<span class="dv">分割线</span>';
      }

      var gap = '';
      if (it.gv != null && it.gv !== 0) {
        gap = (it.gk === 'h' ? '左 ' : '上 ') + '<b>' + n(it.gv) + '</b>';
      } else if (it.gv === 0) gap = '0';
      var meta = '';
      if (it.pad) meta += '内边距 ' + it.pad.filter(function (v) { return v; }).join('/');
      if (it.ovf) meta += (meta ? ' · ' : '') + '可滚动';
      if (it.below) meta += (meta ? ' · ' : '') + '<span class="warnx">首屏之下</span>';

      h += '<tr data-i="' + it.i + '" class="k-' + it.kind + '">' +
        '<td class="i"><span class="kd" style="background:' + kd[1] + '"></span>' + it.i + '</td>' +
        '<td class="el" title="' + esc(nm.cl) + '">' + ind +
        (nm.cn ? '<span class="cn">' + esc(nm.cn) + '</span> ' : '') +
        '<span class="cl">' + esc(nm.cl) + '</span></td>' +
        '<td class="n">' + n(it.x) + ', ' + n(it.y) + '</td>' +
        '<td class="n">' + n(it.w) + ' × ' + n(it.h) + '</td>' +
        '<td class="col">' + esc(radOf(it.rad)) + '</td>' +
        '<td class="col">' + (fill || '<span class="mute">—</span>') + '</td>' +
        '<td class="tx">' + (tx || '<span class="mute">—</span>') +
        (meta ? '<br><span class="mute">' + meta + '</span>' : '') + '</td>' +
        '<td class="n">' + (gap || '<span class="mute">—</span>') + '</td></tr>';
    });
    return h + '</tbody></table>';
  }

  function hex(c) {
    var m = /rgba?\(([^)]+)\)/.exec(c || '');
    if (!m) return c || '';
    var p = m[1].split(',').map(function (x) { return parseFloat(x); });
    var a = p.length > 3 ? p[3] : 1;
    var s = '#' + [p[0], p[1], p[2]].map(function (v) {
      return ('0' + Math.round(v).toString(16)).slice(-2);
    }).join('').toUpperCase();
    return a >= 0.999 ? s : s + ' ' + Math.round(a * 100) + '%';
  }

  // ── 4. 悬停联动 ──────────────────────────────────────────────────
  function hiRow(sec, i, on) {
    var tr = sec.querySelector('tr[data-i="' + i + '"]');
    if (tr) tr.classList.toggle('hi', on);
    var b = sec.querySelector('.bd[data-i="' + i + '"]');
    var ov = sec.querySelector('.ov[data-i="' + i + '"]');
    if (b) b.classList.toggle('hi', on);
    if (ov) ov.classList.toggle('hi', on);
  }
  document.addEventListener('mouseover', function (e) {
    var tr = e.target.closest('tr[data-i]');
    if (!tr) return;
    var sec = tr.closest('.spec');
    if (!sec) return;
    hiRow(sec, +tr.getAttribute('data-i'), true);
    var fr = sec.querySelector('.frame');
    var t = fr.getBoundingClientRect(), b = tr.getBoundingClientRect();
    if (b.top < t.top || b.bottom > t.bottom) tr.scrollIntoView({ block: 'nearest' });
  });
  document.addEventListener('mouseout', function (e) {
    var tr = e.target.closest('tr[data-i]');
    if (!tr) return;
    var sec = tr.closest('.spec');
    if (sec) hiRow(sec, +tr.getAttribute('data-i'), false);
  });

  // ── 5. 工具条 ────────────────────────────────────────────────────
  var bar = document.getElementById('bar');
  bar.addEventListener('click', function (e) {
    var b = e.target.closest('button');
    if (!b) return;
    if (b.dataset.kind !== undefined) {
      filterKind = b.dataset.kind;
      Array.prototype.forEach.call(bar.querySelectorAll('[data-kind]'), function (x) {
        x.classList.toggle('on', x === b);
      });
      apply();
    } else if (b.dataset.tog) {
      var k = b.dataset.tog;
      if (k === 'num') { document.body.classList.toggle('shownum'); b.classList.toggle('on'); }
      if (k === 'first') { onlyFirst = !onlyFirst; b.classList.toggle('on', onlyFirst); apply(); }
    }
    // 注意：跳屏已改为 <select id="jump">（见下方 change 监听），
    // 这里原先还有一支 b.dataset.jump 的死分支，已删 —— 工具条上并无 data-jump 按钮。
  });
  var inp = document.getElementById('q');
  inp.addEventListener('input', function () { q = inp.value.trim().toLowerCase(); apply(); });

  var jp = document.getElementById('jump');
  if (jp) jp.addEventListener('change', function () {
    var el = document.getElementById(jp.value);
    if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  });

  function apply() {
    var shown = 0;
    document.querySelectorAll('.spec').forEach(function (sec) {
      var tb = sec.querySelectorAll('tr[data-i]');
      var vis = 0;
      tb.forEach(function (tr) {
        var it = itemOf(sec, tr);
        var okK = !filterKind || it.kind === filterKind ||
          (filterKind === 'box' && (it.kind === 'box' || it.kind === 'textbox')) ||
          (filterKind === 'layout' && (it.kind === 'group' || it.kind === 'container'));
        var okQ = !q || (it.cls || it.tag).toLowerCase().indexOf(q) >= 0;
        var okF = !(onlyFirst && it.below);
        var ok = okK && okQ && okF;
        tr.classList.toggle('dimop', !ok);
        if (ok) vis++;
      });
      var ov = sec.querySelectorAll('.ov');
      ov.forEach(function (b) {
        var it = itemOf(sec, b);
        var ok = !filterKind || it.kind === filterKind ||
          (filterKind === 'box' && (it.kind === 'box' || it.kind === 'textbox')) ||
          (filterKind === 'layout' && (it.kind === 'group' || it.kind === 'container'));
        var okQ = !q || (it.cls || it.tag).toLowerCase().indexOf(q) >= 0;
        var okF = !(onlyFirst && it.below);
        b.classList.toggle('dim', !(ok && okQ && okF));
      });
      shown += vis;
    });
    document.getElementById('stat').textContent =
      '当前显示 ' + shown + ' / ' + P.total + ' 个元素';
  }
  var IDX = {};
  function itemOf(sec, el) {
    var no = sec.id.slice(1);
    if (!IDX[no]) {
      IDX[no] = {};
      SPEC[+no - 1].items.forEach(function (it) { IDX[no][it.i] = it; });
    }
    return IDX[no][+el.getAttribute('data-i')];
  }

  apply();
})();
</script>
"""


def esc(s):
    return (str(s).replace("&", "&amp;").replace("<", "&lt;")
            .replace(">", "&gt;").replace('"', "&quot;"))


def html_table(rows, head):
    h = '<table class="mt"><thead><tr>' + "".join(f"<th>{esc(x)}</th>" for x in head) + "</tr></thead><tbody>"
    for r in rows:
        h += "<tr>" + "".join(
            f'<td class="{"num" if is_num else ""}">{v}</td>'
            for v, is_num in r) + "</tr>"
    return h + "</tbody></table>"


def chip_list(items):
    return "".join(
        f'<span class="chipx">{("<i style=\"background:%s\"></i>" % c) if c else ""}'
        f'{lab}<b>{val}</b></span>' for lab, val, c in items)


def build():
    if not os.path.exists(os.path.join(HERE, "spec.json")):
        raise SystemExit("先跑 _spec_collect.py 生成 spec.json")
    spec = json.load(open(os.path.join(HERE, "spec.json"), encoding="utf-8"))
    spec = prep(spec, token_map())
    au = audit(spec)
    base_css, sprite, frames = SC.page_parts()

    # ── 审计区 HTML ───────────────────────────────────────────────
    fixrows = []
    for sel, kind, old, new, why, cnt in FIXES:
        fixrows.append([
            (f"<code>{esc(sel)}</code>", False),
            (kind, False),
            (f'<span class="warnx">{esc(old)}</span>', False),
            (f'<span class="ok">{esc(new)}</span>', False),
            (f"{esc(why)} <span class='mute'>×{cnt}</span>", False),
        ])

    excrows = [[(f"<code>{esc(a)}</code>", False), (f"<code>{esc(b)}</code>", False),
                (esc(c), False)] for a, b, c in KNOWN_EXCEPTIONS]

    fontrows = []
    for v, c in au["fontUsed"].items():
        tag = ("8 级字阶" if v in au["fontBase"] else
               "0.62× 派生（金额符号）" if v in au["fontDerived"] else "越界")
        cls = "ok" if tag != "越界" else "warnx"
        fontrows.append([(f"{v}px", True), (f'<span class="{cls}">{tag}</span>', False),
                         (str(c), True)])
    fontrows.sort(key=lambda r: -float(r[2][0]))

    radrows = [[(f"<code>{esc(k)}</code>", False), (str(v), True)] for k, v in au["radUsed"].items()]
    gaprows = [[(f"{k}px", True), (str(v), True)] for k, v in sorted(au["gapUsed"].items())]
    padrows = [[(f"{k}px", True), (str(v), True)] for k, v in sorted(au["padUsed"].items())]

    # ⚠️ 一律走 html_table —— 直接手写 join 会把 ("12px", True) 这种元组原样打印出来
    t_font = html_table(fontrows, ["字号", "归类", "处数"])
    t_rad = html_table(radrows, ["圆角", "处数"])
    t_gap = html_table(gaprows, ["相邻间距", "处数"])
    t_pad = html_table(padrows, ["内边距", "处数"])

    tokrows = []
    for label, d in (("填充", au["bgUsed"]), ("文字", au["txUsed"]), ("图标", au["icUsed"])):
        for hx, c in sorted(d.items(), key=lambda x: -x[1])[:9]:
            nm = TOK_NAMES.get(hx, "")
            tokrows.append([
                (label, False),
                (f'<span class="sw" style="background:{hx.split()[0]}"></span><code>{esc(hx)}</code>', False),
                (esc(nm), False), (str(c), True)])

    t_tok = html_table(tokrows, ["用途", "色值", "令牌", "处数"])

    jumpopts = "".join(
        f'<option value="s{s["no"]}">{s["no"]:02d} · {esc(s["title"])}（{len(s["items"])} 元素）</option>'
        for s in spec)

    kindchips = "".join(
        f'<span class="chipx"><i style="background:{c}"></i>{esc(k)}<b>{sum(1 for s in spec for it in s["items"] if it["kind"] == k)}</b></span>'
        for k, (_, c) in KIND_META.items())

    stat_chips = chip_list([
        ("屏幕", au["nScreens"], None),
        ("画布", "393×852", None),
        ("元素", au["nItems"], None),
        ("分割线", au["dividers"], None),
        ("图标", au["icons"], None),
        ("字号种类", len(au["fontUsed"]), None),
        ("圆角种类", len(au["radUsed"]), None),
        ("越下缘", au["clipBelow"], None),
        ("首屏之下", au["belowFold"], None),
    ])

    head = f"""<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>素记 Plain · 规格标注版 · iPhone 16 (393 × 852)</title>
<style>
{base_css}
{ANN_CSS}
</style></head>
<body data-theme="subai" data-mode="light" class="shownum">
{sprite}

<div class="bar" id="bar"><div class="inner">
  <span class="lab">类型</span>
  <div class="grp">
    <button data-kind="" class="on">全部</button>
    <button data-kind="box">容器/面板</button>
    <button data-kind="text">文字</button>
    <button data-kind="icon">图标</button>
    <button data-kind="divider">分割线</button>
    <button data-kind="layout">纯布局</button>
  </div>
  <input id="q" placeholder="搜 class 名，如 panel / hairline">
  <div class="grp"><span class="lab">跳屏</span>
    <select id="jump">{jumpopts}</select></div>
  <div class="grp">
    <button data-tog="num" class="on">序号</button>
    <button data-tog="first" class="on">只标首屏</button>
  </div>
  <span class="stat" id="stat"></span>
</div></div>

<div class="doc">
  <div class="hero-doc">
    <h1>素记 Plain · 全量规格标注</h1>
    <div class="lede">画布 <b>iPhone 16 — 393 × 852 pt</b>（@3x，硬件 1179 × 2556）。
      本文件把 29 屏里<b>每一个占位元素</b>的位置、尺寸、圆角、填充、边框、排版与相邻间距
      全部实测标出；数值取自真浏览器 <code>getBoundingClientRect</code> +
      <code>getComputedStyle</code>，无一处手写。</div>
    <div class="chips">{stat_chips}</div>
  </div>

  <div class="card">
    <h2>① 规范一致性 —— 全部 29 屏已收敛到同一套刻度</h2>
    <div class="hint">上游 29 屏分三批完成（V1.0 11 + V2.0 8 + V3.0 10），批与批之间在「非主体控件」上漂了刻度。本版按
      <code>01-tokens.json</code> 的明文规则统一，逐项列在下面。</div>
    <div class="grid2">
      <div>
        {t_font}
      </div>
      <div>
        {t_rad}
        <div style="height:14px"></div>
        {t_gap}
      </div>
    </div>
  </div>

  <div class="card">
    <h2>② 本版做了哪些修正（11 项，全部收敛到令牌刻度）</h2>
    <div class="hint">令牌明文：圆角「全局 4 档 + 全圆，不许出现第 5 个圆角值」＝ r1 8 / r2 12 / r3 16 / r4 24 / pill 999；
      字阶 = 44 / 34 / 22 / 20 / 15 / 14 / 12（金额货币符与小数位另有 0.62× 派生规则）。</div>
    {html_table(fixrows, ["选择器", "类别", "原值", "收敛为", "说明"])}
  </div>

  <div class="card">
    <h2>③ 一致性结论</h2>
    <div class="grid2">
      <div>
        <table class="mt"><tbody>
          <tr><td>字号越界</td><td>{"<span class='ok'>0 处 ✔</span>" if not au["offFont"] else "<span class='warnx'>" + ", ".join(map(str, au["offFont"])) + "</span>"}</td></tr>
          <tr><td>圆角越界</td><td>{"<span class='ok'>0 处 ✔</span>" if not au["offRad"] else "<span class='warnx'>" + ", ".join(map(str, au["offRad"])) + "</span>"}</td></tr>
          <tr><td>金额 0.62× 派生</td><td><span class="ok">{au["nDerived"]} 处</span>（文档明文规则，非越界）</td></tr>
          <tr><td>非 4 基数的内边距</td><td>{esc(", ".join(f"{v}px" for v in au["padOffGrid"]))} <span class="mute">（内容级留白，非布局栅格）</span></td></tr>
          <tr><td>非 4 基数的相邻间距</td><td>{esc(", ".join(f"{v}px" for v in au["gapOffGrid"]))} <span class="mute">（行内 / 控件内部留白；布局留白见上表 8 / 12 / 16 / 28 / 32 / 46）</span></td></tr>
        </tbody></table>
        <div style="height:12px"></div>
        <div class="hint" style="margin:0">元素类型分布（点击工具条可按类型筛选）：</div>
        <div class="chips" style="margin-top:8px">{kindchips}</div>
      </div>
      <div>
        {t_tok}
        <div style="height:14px"></div>
        <div class="hint" style="margin:0 0 6px">内边距（出现 ≥3 次的值）</div>
        {t_pad}
      </div>
    </div>
  </div>

  <div class="card">
    <h2>④ 明确保留的例外</h2>
    <div class="hint">以下三项**不**收敛，理由写在表里；它们是「有意为之」而非漂移。</div>
    {html_table(excrows, ["对象", "值", "为什么保留"])}
  </div>

  <div class="card">
    <h2>⑤ 怎么读这份标注</h2>
    <div class="hint" style="margin:0">
      · <b>画布上</b>：每个控件一圈描边（颜色＝类型），角标数字＝下表序号；
      左侧虚线是<b>控件之间的纵向间距</b>（只画浅层、≥4px 的，否则会糊）。
      <br>· <b>表格里</b>：按父子关系缩进；<code>位置 x, y</code> 以屏幕左上角为原点、单位 pt。
      <br>· <b>悬停联动</b>：鼠标停在表格某行，画布上对应控件会高亮；反之亦然。
      <br>· <b>分割线</b>：一律<code>.hairline</code>，实测 <b>高 1pt、底色 <code>#E4E4E8</code>（--line）</b>，
      宽度随所在卡片内容宽（345 或 361），在画布上用品红描出。
      <br>· <b>首屏之下</b>：内容超出一屏的元素仍列出并标记（<span class="warnx">首屏之下</span>＝上缘已在 852 之外），画布上不画框。
      <br>· <b>越出下缘</b>：有的元素上缘在屏内、下缘超过 852（滚动内容的自然溢出，例如 SP-1-03 的分类面板高 866）。
      这类框会被<strong>裁到屏幕边缘</strong>（不画到机身外），并在右下留一个品红 <b>▾</b> 提示「后面还有内容」；
      <strong>它的真实高度以下表为准</strong>，不要照画布上被裁后的高度去量。
    </div>
  </div>
</div>

<div class="stage">{frames}</div>

<script id="SPEC" type="application/json">{json.dumps({
        "spec": spec, "label": LABEL, "kind": KIND_META, "tok": TOK_NAMES,
        "cw": SC.CANVAS_W, "ch": SC.CANVAS_H, "total": au["nItems"],
    }, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")}</script>
{RENDER_JS}
</body></html>
"""
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(head)
    print("written:", OUT, os.path.getsize(OUT) // 1024, "KB")
    print("screens:", len(spec), "| items:", au["nItems"])
    print("字号越界:", au["offFont"] or "无")
    print("圆角越界:", au["offRad"] or "无")
    return 0


TOK_NAMES = {}


if __name__ == "__main__":
    TOK_NAMES = token_map()
    sys.exit(build())
