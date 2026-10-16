"""把 `scan_font_scale.py` 的结果渲染成一份可评审的 HTML 决策清单。

跑法：
    python tool/report_font_scale.py            # 写到 PlainApp/字阶越界清单.html
    python tool/report_font_scale.py -o x.html

为什么是「生成」而不是手写：越界项会随代码变化，手写的清单必然过期。
"""
from __future__ import annotations

import argparse
import html
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import scan_font_scale as S  # noqa: E402

# 建议映射 + 理由 + 负面影响。key = 代码现值。
PROPOSALS: dict[float, dict[str, str]] = {
    16.0: {
        "target": "15",
        "reason": "设计稿最小正文档是 15（`.amt.s` / `.ft`）。16 是 15 与 20 之间的空档，"
                  "两处是金额（`formatAmount` 输出）→ 必须走 `.amt.s`；另两处是区块标题 / 统计值。",
        "risk": "几乎为零。行盒 16→20（设计 `normal` 就是 20），但 16px 未写 height 时"
                "继承 19/14 得到 21.7，**反而更高**，改后是净减小。",
    },
    24.0: {
        "target": "22（部分 20）",
        "reason": "设计稿无 24。22 是 `.amt.l` 卡片主数字档。三处性质不同："
                  "连续天数 = 卡片主数字→22；密码圆点（`letterSpacing: 8`）→22；"
                  "日历月份标题 w600 语义上是标题→**20** 更贴。",
        "risk": "日历标题若取 22 会与同屏其它标题（20）不一致；密码圆点改小 2px 视觉变轻，"
                "但圆点盒是固定尺寸，不影响布局。",
    },
    28.0: {
        "target": "22 或 34",
        "reason": "设计稿无 28。`safe_to_spend_card` 是首页**次级卡片**的重点数字，"
                  "设计里同级卡片数字用 `.amt.l` = **22**；若定位与 hero 同级才用 34。"
                  "首页 hero 已是 34，此处取 22 才有层级差。",
        "risk": "取 22 数字视觉降一档，若产品上希望「安全可花」压过 hero 则需要拍板改 34。",
    },
    13.0: {
        "target": "14",
        "reason": "22 处里绝大多数是「次要说明文字」（`inkSecondary` / `inkTertiary`）。"
                  "设计里这个语义正是 14（`.d{font-size:14;color:muted}` —— 详情行的次要文本），"
                  "而 12 是 eyebrow / 标签档。13 卡在中间，无设计依据。",
        "risk": "次要行行盒 13→19，**列表整体变高约 6%**。若有固定高的行容器（如 `SizedBox(height: 38)`）"
                "会挤压；需逐处看父容器是否定高。这是本轮 53 处里唯一**可能引起可见布局位移**的一档。",
    },
    11.0: {
        "target": "12",
        "reason": "设计稿最小字号就是 12（`.fs` 12/500、`.hs-l` 12/600、`.eyebrow` 12/600）。"
                  "11 无依据。",
        "risk": "微标签变宽约 9%。裸 `Text` 在 `Row` 内且无 `Flexible` 时可能溢出换行"
                "（F 类已知风险点）。",
    },
    10.0: {
        "target": "12",
        "reason": "设计稿最小 12。`safe_to_spend_card` 的「剩 N 天」、报表坐标轴标签都在此列。",
        "risk": "**风险最高的一档**：图表坐标轴 / 图例标签空间极紧，10→12 可能重叠或溢出。"
                "建议单独复核 `reports_page.dart` 的 3 处轴标签与 `donut_chart` 的扇区标签。",
    },
    0.0: {
        "target": "保持 0（例外）",
        "reason": "不是字阶选择，是「把文字盒压没但保留语义」的 hack。已在扫描器里白名单。",
        "risk": "无。但建议后续换成 `Visibility` / `ExcludeSemantics` 之类更显式的写法。",
    },
}


def esc(s: str) -> str:
    return html.escape(s, quote=True)


def md(s: str) -> str:
    """先转义再还原行内 Markdown 记号 —— 理由/风险文案里写作方便，
    直接塞进 HTML 会显示成字面的星号与反引号。"""
    import re
    out = esc(s)
    out = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", out)
    out = re.sub(r"`(.+?)`", r"<code>\1</code>", out)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("-o", "--out", default=None)
    args = ap.parse_args()

    rows = S.scan(S.LIB)
    bad = [r for r in rows if not r["ok"]]

    out = args.out or os.path.join(
        os.path.dirname(os.path.dirname(HERE)), "字阶越界清单.html")

    # 按现值分组
    groups: dict[float, list[dict]] = {}
    for r in bad:
        groups.setdefault(r["value"], []).append(r)

    parts: list[str] = []
    parts.append(f"""<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>素记 · 字阶越界清单</title>
<style>
:root{{--ink:#101012;--ink2:#5E5E65;--ink3:#8A8A92;--line:#E4E4E8;--bg:#FBFBFC;
--warn:#B4410E;--warnbg:#FFF6F0;--ok:#0F7A5A;--code:#F4F4F6}}
*{{box-sizing:border-box}}
body{{margin:0;padding:40px 32px 80px;background:var(--bg);color:var(--ink);
font:14px/1.6 "MiSans","PingFang SC",system-ui,sans-serif;-webkit-font-smoothing:antialiased}}
.wrap{{max-width:1080px;margin:0 auto}}
h1{{font-size:26px;font-weight:600;margin:0 0 6px;letter-spacing:-.01em}}
.sub{{color:var(--ink2);margin:0 0 32px;font-size:13px}}
h2{{font-size:16px;font-weight:600;margin:36px 0 12px}}
h3{{font-size:14px;font-weight:600;margin:22px 0 8px}}
table{{width:100%;border-collapse:collapse;background:#fff;border:1px solid var(--line);border-radius:10px;overflow:hidden}}
th,td{{text-align:left;padding:9px 12px;border-bottom:1px solid var(--line);vertical-align:top;font-size:13px}}
th{{background:#F6F6F8;font-weight:600;color:var(--ink2);white-space:nowrap}}
tr:last-child td{{border-bottom:none}}
code{{background:var(--code);padding:1px 5px;border-radius:4px;font-size:12px;
font-family:ui-monospace,Consolas,monospace}}
.mono{{font-family:ui-monospace,Consolas,monospace;font-size:12px;color:var(--ink2)}}
.big{{font-size:20px;font-weight:600;color:var(--warn)}}
.pill{{display:inline-block;padding:1px 8px;border-radius:99px;font-size:12px;
background:var(--warnbg);color:var(--warn);font-weight:600}}
.box{{background:#fff;border:1px solid var(--line);border-radius:10px;padding:16px 18px;margin:12px 0}}
.box.risk{{background:var(--warnbg);border-color:#F2D8C8}}
ul{{margin:6px 0 0;padding-left:20px}}li{{margin:2px 0}}
.scale{{display:flex;gap:6px;flex-wrap:wrap;margin:10px 0 4px}}
.scale span{{padding:4px 12px;border-radius:8px;background:#fff;border:1px solid var(--line);
font-family:ui-monospace,monospace;font-size:13px}}
.scale span.on{{background:#101012;color:#fff;border-color:#101012}}
.muted{{color:var(--ink3)}}
</style></head><body><div class="wrap">
<h1>素记 · 字阶越界清单</h1>
<p class="sub">数据源：<code>plain/tool/scan_font_scale.py</code> 扫描 <code>plain/lib</code>（{len(rows)} 处）
· 真值源：<code>redesign-v3/_build/spec.json</code>（29 屏实测）</p>""")

    # 字阶
    parts.append("<h2>一、设计稿的真字阶（实测，非文档描述）</h2>")
    parts.append('<div class="scale">' + "".join(
        f'<span class="on">{v:g}</span>' for v in S.SCALE) + "</div>")
    parts.append('<div class="scale">' + "".join(
        f'<span>{v:g}</span>' for v in S.DERIVED) + "</div>")
    parts.append("""<div class="box">
<b>字阶（7 档）</b>：12 / 14 / 15 / 20 / 22 / 34 / 44<br>
<b>0.62em 派生值</b>：9.3 = 15×0.62 · 12.4 = 20×0.62 · 21.08 = 34×0.62 · 27.28 = 44×0.62
（<span class="muted">只应出现在金额组件内部</span>）<br><br>
29 屏 1197 个文本元素里，<b>只出现过这 11 个值</b>。
<span class="big">16 / 18 / 24 / 28 / 13 / 11 / 10 一次都没有出现</span> —— 代码里这些全是自创。
</div>""")

    # 汇总
    parts.append("<h2>二、越界汇总与建议映射</h2>")
    parts.append("<table><tr><th>代码现值</th><th>处数</th><th>建议</th>"
                 "<th>理由</th><th>负面影响 / 风险</th></tr>")
    for v in sorted(groups, reverse=True):
        p = PROPOSALS.get(v, {"target": "—", "reason": "—", "risk": "—"})
        parts.append(
            f'<tr><td><span class="pill">{v:g}px</span></td>'
            f'<td>{len(groups[v])}</td><td><b>{md(p["target"])}</b></td>'
            f'<td>{md(p["reason"])}</td><td>{md(p["risk"])}</td></tr>')
    parts.append("</table>")

    # 明细
    parts.append("<h2>三、逐处明细</h2>")
    for v in sorted(groups, reverse=True):
        parts.append(f'<h3><span class="pill">{v:g}px</span> &nbsp;{len(groups[v])} 处</h3>')
        parts.append("<table><tr><th style='width:340px'>位置</th><th>代码</th></tr>")
        for r in sorted(groups[v], key=lambda x: (x["file"], x["line"])):
            parts.append(
                f'<tr><td class="mono">{esc(r["file"])}:{r["line"]}'
                f'<br><span class="muted">{esc(r["kind"])}</span></td>'
                f'<td><code>{esc(r["text"])}</code></td></tr>')
        parts.append("</table>")

    # 非字阶的越界
    heights = [r for r in rows if r["kind"] == "height:分数" and not r["ok"]]
    if heights:
        parts.append("<h2>四、行高比值的待确认项</h2>")
        parts.append("<table><tr><th style='width:340px'>位置</th><th>比值</th><th>代码</th></tr>")
        for r in heights:
            parts.append(
                f'<tr><td class="mono">{esc(r["file"])}:{r["line"]}</td>'
                f'<td><b>{r["value"]:g}</b></td><td><code>{esc(r["text"])}</code></td></tr>')
        parts.append("</table>")
        parts.append("""<div class="box risk">
这两处不是金额档，需要人工确认设计意图：<br>
<code>height: 20/14</code>（1.4286）—— 14px 配 20px 行盒。设计稿 14px 的行盒档位是
19（<code>normal</code>）/ 21（<code>.dv.note</code>）/ 23.1 / 23.8，<b>没有 20</b>。<br>
<code>height: 18/12</code>（1.5）—— 12px 配 18px 行盒。设计稿<b>有</b> 12→18（<code>.foot-note</code>），
这一处<b>合法</b>，属扫描器白名单遗漏。
</div>""")

    parts.append("</div></body></html>")

    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(parts))

    print(f"written: {out}")
    print(f"扫描 {len(rows)} 处，越界 {len(bad)} 处，分组 {len(groups)} 类")
    return 0


if __name__ == "__main__":
    sys.exit(main())
