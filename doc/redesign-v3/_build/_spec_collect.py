"""把全部 29 屏按 **iPhone 16（393 × 852 pt）** 重排，再用真浏览器实测每个元素的
几何与样式，输出 _build/spec.json。

为什么必须实测而不能照 CSS 推：
  · 屏内大量弹性布局（flex:1 / gap / auto 高度），CSS 里没有绝对的 y 与高度；
  · 本文档的历史教训是「按代码写对了、但按实测是错的」——
    位置尺寸这类数值一旦手写就必然与渲染不符。

⚠️ 临时 HTML 必须写进 redesign-v3/ 根目录（@font-face 走 `12-FONTS/` 相对路径）。
⚠️ 视口必须 > 520px，否则命中 `@media(max-width:520px){.frame{transform:scale(.82)}}`，
   getBoundingClientRect 返回的是缩放后的假值。
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

import gen_screens as G
import gen_all_screens as A

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

# ── 画布真值：iPhone 16 = 393 × 852 pt（@3x，硬件 1179 × 2556）──
CANVAS_W, CANVAS_H = 393, 852

SIZE_CSS = """
/* ══ 画布改成 iPhone 16 逻辑分辨率 ══
   上游 .frame 写死 390×844（= iPhone 14/15 档）。这里只覆盖尺寸，
   内部一切布局照旧由 flex 自适应 —— 宽 +3 / 高 +8 会自然重排。 */
.frame{width:393px !important;height:852px !important}
"""

FIX_CSS = """
/* ══════════════════════════════════════════════════════════════════════
   规范一致性修正 —— 把全部页面收敛回 01-tokens.json 的刻度
   ──────────────────────────────────────────────────────────────────────
   上游 29 屏是分三批（V1.0 11 + V2.0 8 + V3.0 10）做的，
   批与批之间在「非主体控件」上漂了刻度。实测（见 spec.json）共 11 个来源：

   ① 圆角：令牌 radius = { r1:8, r2:12, r3:16, r4:24, pill:999 }
      明文规则「全局 4 档 + 全圆。不许出现第 5 个圆角值。」
      实测漂出 6 / 7 / 9 / 10 / 14 —— 下面逐个收敛，取就近档位。
   ② 字号：令牌 type.scale = { 44, 34, 22, 15, 20, 15, 14, 12 }
      另有「金额货币符与小数 = 0.62× 字号」的明文规则（这是合法派生，
      实测出现的 9.3 / 11.16 / 21.08 / 27.28 都属此类，不动）。
      真正越界的是下面 5 处。
   ══════════════════════════════════════════════════════════════════════ */

/* ── ① 圆角收敛 ───────────────────────────────────────────────────── */
.segi{border-radius:8px}              /* 9  → 8   r1 ；分段控件选中项 */
.thsw > i{border-radius:8px}          /* 6  → 8   r1 ；主题色卡 18×18 */
.ruleno,.ricnt{border-radius:8px}     /* 7  → 8   r1 ；22×22 序号 / 计数徽标 */
.avt{border-radius:8px}               /* 10 → 8   r1 ；30×30 成员头像 */
.navfab{border-radius:12px}           /* 14 → 12  r2 ；底部导航中央 44×44 */

/* ── ② 字号收敛 ───────────────────────────────────────────────────── */
.sb-time{font-size:15px}              /* 14.5 → 15 ；状态栏时间（29 屏全覆盖） */
.hs-v{font-size:15px}                 /* 16   → 15 ；hero 分栏小值 */
.dn-c1{font-size:20px}                /* 环形图中心的**兜底值**；真实值由 donut_amount()
                                         内联写入，取档序列已由 _fix_donut_tiers() 改为
                                         (20,15,14,12) —— 原 (18,16,14,12) 里 18 与 16 都越界。
                                         注意 .dn-pnt / .dn-cur / .dn-dec 不在这里设，
                                         它们靠继承与 0.62em 跟随父级。 */
.dn-c2{font-size:12px}                /* 8.5  → 12 ；环形图 TOTAL 标签 */
.skc,.skl,.skg,.skv{font-size:12px}   /* 10 / 10.5 / 12.5 → 12 ；桑基图标签
                                         （源码里是 SVG font-size 属性，CSS 覆盖之） */

/* 屏 25 的「天」与屏 26 的「%」是内联 em 比率（.5em / .52em），
   偏离文档规定的 0.62em。用 [style] 限定只打内联的那几个，
   不碰 .amt.s .dec{font-size:1em} 这类正常规则。 */
.amt .dec[style]{font-size:.62em !important}
.hero-amt > span[style]{font-size:.62em !important}

/* ── ③ 明确保留的例外（图表内部，不属 UI 盒子语言）─────────────────
   .minibars > i{border-radius:4px 4px 0 0} —— 迷你柱状图的柱顶圆角，
   是数据可视化惯例（柱子宽仅十余 px，套 r1=8 会变成半圆）。
   本条不修正，改在标注版的「一致性审计」里列为已知例外。 */
"""

COLLECTOR = r"""
<script>
(function () {
  function alpha(c) {
    if (!c || c === 'transparent') return 0;
    var m = c.match(/rgba?\(([^)]+)\)/);
    if (!m) return 0;
    var p = m[1].split(',');
    return p.length > 3 ? parseFloat(p[3]) : 1;
  }
  function directText(el) {
    var t = '';
    for (var i = 0; i < el.childNodes.length; i++) {
      var n = el.childNodes[i];
      if (n.nodeType === 3) t += n.nodeValue;
    }
    return t.replace(/\s+/g, ' ').trim();
  }
  function num(v) { var f = parseFloat(v); return isNaN(f) ? 0 : f; }
  function r2(v) { return Math.round(v * 100) / 100; }
  function visible(el) {
    var cs = getComputedStyle(el);
    return cs.display !== 'none' && cs.visibility !== 'hidden' && parseFloat(cs.opacity) !== 0;
  }

  window.addEventListener('load', function () {
    var RES = [];
    try {
      document.querySelectorAll('.frame').forEach(function (fr, fi) {
        var scr = fr.querySelector('.screen');
        var sr = scr.getBoundingClientRect();
        var items = [], n = 0;

        // par = 最近一个「被收录的祖先」序号，用来在规格表里做树形缩进
        function walk(el, depth, par) {
          if (!visible(el)) return;                 // 整棵子树都不渲染，直接剪掉
          var cs = getComputedStyle(el);
          var tag = el.tagName.toLowerCase();
          var isIcon = (tag === 'svg');
          var r = el.getBoundingClientRect();
          var w = r.width, h = r.height;

          var bg = cs.backgroundColor, a = alpha(bg);
          var bwT = num(cs.borderTopWidth), bwL = num(cs.borderLeftWidth);
          var hasBox = (a > 0.01) || (bwT > 0.01);
          var txt = directText(el);
          var hasKids = el.children.length > 0;
          var pl = num(cs.paddingLeft), pt = num(cs.paddingTop);
          var pr = num(cs.paddingRight), pb = num(cs.paddingBottom);

          // 分割线：高 0.5~2.2 且有一定宽度（排除 40×0 这类塌陷容器）
          var isDiv = !isIcon && h >= 0.5 && h <= 2.2 && w >= 6;
          var hasPad = !!(pl || pt || pr || pb);

          // ★ 收录口径：只要「占位且在视觉/结构上有意义」就收
          //   —— 容器也必须收（.statusbar 无底色无边框，靠 hasKids 才进得来；
          //      .rcol / .ricos / .amt 这类纯布局包裹层同样是研发要照抄的盒子）
          var keep = (w > 0.5 && h > 0.5) &&
                     (isIcon || isDiv || hasBox || txt || hasKids);

          var myIdx = par;
          if (keep && tag !== 'use' && tag !== 'path') {
            n++;
            var cls = el.className;
            if (cls && cls.baseVal !== undefined) cls = cls.baseVal;

            // 与「上一个同级的可见元素」的间距（垂直取 y，水平取 x）
            var gy = null, gx = null, pv = el.previousElementSibling;
            while (pv && !visible(pv)) pv = pv.previousElementSibling;
            if (pv) {
              var q = pv.getBoundingClientRect();
              gy = r2(r.top - q.bottom);
              gx = r2(r.left - q.right);
            }

            items.push({
              i: n, par: par, tag: tag, d: depth,
              cls: (cls || '').toString(),
              x: r2(r.left - sr.left), y: r2(r.top - sr.top),
              w: r2(w), h: r2(h),
              bg: a > 0.01 ? bg : '',
              bd: bwT > 0.01 ? (cs.borderTopWidth + ' ' + cs.borderTopStyle + ' ' + cs.borderTopColor) : '',
              bdSide: (bwL > 0.01 && Math.abs(bwL - bwT) > 0.01) ? ('L ' + cs.borderLeftWidth + ' ' + cs.borderLeftColor) : '',
              rad: cs.borderRadius,
              pad: hasPad ? [pt, pr, pb, pl] : null,
              mar: (num(cs.marginTop) || num(cs.marginLeft)) ? [num(cs.marginTop), num(cs.marginLeft)] : null,
              gap: (gy !== null) ? [gy, gx] : null,
              ovf: (cs.overflowY === 'auto' || cs.overflowY === 'scroll') ? 'scroll' : '',
              txt: txt ? { v: txt, size: num(cs.fontSize), wt: cs.fontWeight,
                           col: cs.color, lh: cs.lineHeight, ls: cs.letterSpacing } : null,
              ic: isIcon ? cs.color : '',
              kind: isIcon ? 'icon'
                  : isDiv ? 'divider'
                  : (txt && hasBox) ? 'textbox'
                  : hasBox ? 'box'
                  : txt ? 'text'
                  : (hasPad ? 'container' : 'group')
            });
            myIdx = n;
          }
          for (var i = 0; i < el.children.length; i++) walk(el.children[i], depth + 1, myIdx);
        }

        walk(scr, 0, 0);
        var lab = fr.querySelector('.flabel');
        RES.push({
          no: fi + 1,
          title: (lab ? lab.textContent : '').trim(),
          canvas: [Math.round(sr.width), Math.round(sr.height)],
          items: items
        });
      });
    } catch (e) {
      RES = [{ error: String(e && e.stack || e) }];
    }
    document.body.innerHTML = '<pre id="P">' +
      JSON.stringify(RES).replace(/&/g, '\\u0026').replace(/</g, '\\u003c').replace(/>/g, '\\u003e') +
      '</pre>';
  });
})();
</script>
"""


def _fix_donut_tiers():
    """把环形图中心的「向下取档」序列换到 8 级字阶上。

    原序列 (18, 16, 14, 12) 里的 18 与 16 都不在 type.scale
    { 44, 34, 22, 20, 15, 14, 12 } 内 —— 这正是《10-CHANGELOG》T-9
    留下的尾巴（当时只定了「放不下就降档」，没管档位本身合不合字阶）。

    新序列 (20, 15, 14, 12)：全部落在字阶内，且仍严格递减。
    宽度算式与阈值表原样保留（数字按 tnum 594/1000 计），
    所以「放得下」的判定逻辑一字未改，只是候选值换了。

    实现方式：替换 gen_screens 模块上的同名函数。screen_reports 调用它时
    走的是模块全局查找，因此在生成前替换即可生效 —— 这样就不必改基础
    生成器 gen_screens.py（本轮约定「只产出一个新 HTML」）。
    """
    TAB, CUR, COM, PNT = 0.594, 0.610, 0.288, 0.277
    TIERS = (20, 15, 14, 12)

    def donut_amount(v, avail=87.0):
        ints, dec = (v.split(".") + [""])[:2]

        def w(size):
            small = size * 0.62
            x = CUR * small
            x += sum(1 for c in ints if c.isdigit()) * TAB * size
            x += ints.count(",") * COM * size
            if dec:
                x += PNT * size + len(dec) * TAB * small
            return x

        size = next((s for s in TIERS if w(s) <= avail), TIERS[-1])
        return (f'<tspan class="dn-cur">¥</tspan>{ints}'
                f'<tspan class="dn-pnt">.</tspan>'
                f'<tspan class="dn-dec">{dec}</tspan>', size)

    G.donut_amount = donut_amount


def page_parts():
    """返回 (style_css, sprite_html, frames_html)。标注版直接复用这三件。"""
    _fix_donut_tiers()
    theme_css = G.theme_vars("subai", "light")
    swatch = "\n".join(
        f"  --th-{tid}-p: {G.TOK['resolved'][f'{tid}.light']['primary']};\n"
        f"  --th-{tid}-a: {G.TOK['resolved'][f'{tid}.light']['accent']};"
        for tid, _, _ in A.THEMES10)

    parts = []
    for i in range(len(A.SCREENS)):
        title, fn = A.SCREENS[i]
        parts.append(f'<section class="frame" data-screen="{i}">'
                     f'<div class="flabel">{title}</div>'
                     f'<div class="bezelless">{fn()}</div></section>')

    css = f"{A.CSS}\n{A.SANK_STYLE}\n{SIZE_CSS}\n{FIX_CSS}\n.stage{{\n{theme_css}\n{swatch}\n}}"
    return css, G.sprite(), "".join(parts)


def base_html():
    """29 屏 + iPhone 16 画布 + 规范收敛，不含任何标注。"""
    css, sprite, frames = page_parts()
    return f"""<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>素记 Plain · 规格标注底稿</title>
<style>
{css}
</style></head>
<body data-theme="subai" data-mode="light">
{sprite}
<div class="stage">{frames}</div>
</body></html>
"""


def measure(html):
    p = os.path.join(ROOT, "._ann_base.html")
    with open(p, "w", encoding="utf-8") as fh:
        fh.write(html.replace("</body>", COLLECTOR + "</body>"))
    prof = tempfile.mkdtemp()
    url = "file:///" + p.replace("\\", "/").lstrip("/")
    cmd = [CHROME, "--headless=new", "--disable-gpu", "--no-first-run",
           "--allow-file-access-from-files", "--user-data-dir=" + prof,
           "--virtual-time-budget=6000", "--window-size=1500,1000", "--dump-dom", url]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=240)
    shutil.rmtree(prof, ignore_errors=True)
    try:
        os.remove(p)
    except OSError:
        pass

    s = r.stdout
    i, j = s.find('<pre id="P">'), s.find("</pre>", s.find('<pre id="P">'))
    if i < 0:
        raise SystemExit("采集失败，DOM 尾部：\n" + s[-2000:])
    raw = s[i + len('<pre id="P">'):j]
    # --dump-dom 会做 HTML 实体转义；JS 侧已把 & < > 换成 \u 形式，剩下的只有 &amp; 等
    raw = (raw.replace("&amp;", "&").replace("&lt;", "<")
              .replace("&gt;", ">").replace("&quot;", '"').replace("&#39;", "'"))
    return json.loads(raw)


def main():
    html = base_html()
    spec = measure(html)
    out = os.path.join(HERE, "spec.json")
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(spec, fh, ensure_ascii=False, separators=(",", ":"))

    if spec and spec[0].get("error"):
        print("!! 页面内异常：\n" + spec[0]["error"])
        return 1

    print(f"屏数 {len(spec)} | 写入 {out} {os.path.getsize(out) // 1024} KB")
    tot = sum(len(s["items"]) for s in spec)
    print(f"元素总数 {tot}（均值 {tot // len(spec)} / 屏）")
    print("\n画布（应全部 393×852）：")
    bad = [s for s in spec if s["canvas"] != [CANVAS_W, CANVAS_H]]
    print("  异常:", [f'{s["no"]} {s["title"][:14]} {s["canvas"]}' for s in bad] or "无")

    from collections import Counter
    kinds = Counter(it["kind"] for s in spec for it in s["items"])
    print("\n元素类型分布：", dict(kinds))
    print("\n每屏元素数（前 8 / 后 4）：")
    for s in spec[:8] + spec[-4:]:
        print(f'  {s["no"]:02d} {s["title"][:22]:24s} {len(s["items"]):3d}')
    return 0


if __name__ == "__main__":
    sys.exit(main())
