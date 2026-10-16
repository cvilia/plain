# -*- coding: utf-8 -*-
"""生成《图标替换清单》：Material Icons → v3 `PlainIconData` 的映射与复核清单。

数据源三处：
  ① `MAP`  —— 本轮实际执行的替换表（手工维护，已全部落到精确造型，无存疑项）；
  ② `plain/lib` —— 扫描 v3 常量的真实引用文件数（判断哪些图标在用）；
  ③ `redesign-v3/04-ICON-SYSTEM/icons.json` —— v3 全集 100 枚 + 分组。

用法：
    python plain/tool/report_icon_map.py [--out 路径.html]

产出默认写到 `PlainApp/图标替换清单.html`。
"""

import argparse
import html
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PLAIN = os.path.dirname(HERE)          # plain/
ROOT = os.path.dirname(PLAIN)          # PlainApp/
LIB = os.path.join(PLAIN, "lib")
ICONS_JSON = os.path.join(
    ROOT, "redesign-v3", "04-ICON-SYSTEM", "icons.json")

# (Material Icons 名, v3 常量, 原处数, 备注)
# 2026-10-14：原 15 处「语义近似」已随补画的 16 枚图标换成精确造型，存疑清零。
# 位置：action_log_page / entry_input_page / achievements_page / recurring_page /
#      reconcile_mode_page / emotion_feedback_card / category_manage_page /
#      sync_page / safe_to_spend_card。
MAP = [
    ("add", "plus", 8, ""),
    ("chevron_right", "chevronRight", 7, ""),
    ("calendar_today_outlined", "calendar", 3, ""),
    ("delete_outline", "delete", 3, ""),
    ("receipt_long_outlined", "receipt", 3, ""),
    ("search", "search", 3, ""),
    ("account_balance_wallet_outlined", "wallet", 2, ""),
    ("chevron_left", "chevronLeft", 2, ""),
    ("lock_outline", "lock", 2, ""),
    ("pie_chart_outline", "chartPie", 2, ""),
    ("savings_outlined", "goal", 2, "品牌标/我的页同一只存钱罐"),
    ("trending_up_outlined", "trendUp", 2, ""),
    ("visibility_outlined", "eye", 2, ""),
    ("visibility_off_outlined", "eyeOff", 2, ""),
    ("account_balance_wallet", "wallet", 1, ""),
    ("add_circle_outline", "circlePlus", 1, "action_log：「insert」操作"),
    ("add_photo_alternate_outlined", "image", 1, ""),
    ("arrow_back", "back", 1, ""),
    ("arrow_back_ios_new", "back", 1, ""),
    ("card_giftcard", "gift", 1, "achievements：权益券"),
    ("category_outlined", "catOther", 1, "原为未知 ref 的回退，改落到「其他」"),
    ("celebration_outlined", "celebration", 1, "emotion_feedback：达成目标"),
    ("check", "check", 1, ""),
    ("clear", "close", 1, ""),
    ("close", "close", 1, ""),
    ("cloud_download_outlined", "cloudDownload", 1, "sync：从云端恢复"),
    ("cloud_upload_outlined", "cloudUpload", 1, "sync：上传备份到云端"),
    ("create_new_folder_outlined", "folderPlus", 1, "category_manage：新建一级分类"),
    ("credit_card", "card", 1, ""),
    ("credit_card_outlined", "card", 1, ""),
    ("delete_forever_outlined", "delete", 1, ""),
    ("download", "export", 1, ""),
    ("drag_handle", "dragHandle", 1, ""),
    ("drive_file_move_outline", "folderMove", 1, "category_manage：移动分类到目标"),
    ("edit_outlined", "edit", 1, ""),
    ("emoji_events", "trophy", 1, "achievements：已解锁徽章"),
    ("event_repeat_outlined", "recurring", 1, ""),
    ("expand_less", "chevronUp", 1, "safe_to_spend：展开态，已去掉 RotatedBox 变通"),
    ("expand_more", "chevronDown", 1, ""),
    ("fingerprint", "fingerprint", 1, ""),
    ("history", "history", 1, "action_log：空态"),
    ("local_fire_department", "flame", 1, "achievements：连续记账"),
    ("merge_type", "merge", 1, "category_manage：合并到目标分类"),
    ("more_horiz", "more", 1, ""),
    ("more_vert", "moreVertical", 1, ""),
    ("payments_outlined", "amount", 1, ""),
    ("pie_chart", "chartPie", 1, ""),
    ("play_arrow", "play", 1, "recurring：立即执行到期规则"),
    ("playlist_add_check_outlined", "listCheck", 1, "reconcile_mode：空态"),
    ("receipt_long", "receipt", 1, ""),
    ("remove_circle_outline", "circleMinus", 2, "action_log：「delete」操作 + entry_input「不指定账户」"),
    ("restore", "undo", 1, ""),
    ("search_off_outlined", "empty", 1, ""),
    ("sentiment_satisfied_alt_outlined", "mood", 1, "emotion_feedback：正向情绪"),
    ("settings", "settings", 1, ""),
    ("settings_outlined", "settings", 1, ""),
    ("shield_outlined", "shield", 1, ""),
    ("subdirectory_arrow_right", "chevronRight", 1, ""),
    ("trending_down", "trendDown", 1, ""),
    ("trending_up", "trendUp", 1, ""),
    ("undo", "undo", 1, ""),
    ("visibility", "eye", 1, ""),
    ("visibility_off", "eyeOff", 1, ""),
    ("wb_sunny_outlined", "sun", 1, ""),
    ("PlainIcons.back（旧字体库）", "back", 1, "`plain_back_button.dart`，零引用死代码（旧库已删）"),
    ("call_split", "（删除参数）", 1, "`_DetailRow.icon` 声明了但从未渲染"),
]

SCAN_SKIP = {"design_system/plain_icons_v3.dart",
             "design_system/category_icon_v3.dart"}

HEAD = """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>素记 · 图标替换清单</title>
<style>
:root{--ink:#101012;--ink2:#5E5E65;--ink3:#8A8A92;--line:#E4E4E8;--bg:#FBFBFC;
--warn:#B4410E;--warnbg:#FFF6F0;--ok:#0F7A5A;--code:#F4F4F6;--okbg:#F1FAF6}
*{box-sizing:border-box}
body{margin:0;padding:40px 32px 80px;background:var(--bg);color:var(--ink);
font:14px/1.6 "MiSans","PingFang SC",system-ui,sans-serif;-webkit-font-smoothing:antialiased}
.wrap{max-width:1080px;margin:0 auto}
h1{font-size:26px;font-weight:600;margin:0 0 6px;letter-spacing:-.01em}
.sub{color:var(--ink2);margin:0 0 32px;font-size:13px}
h2{font-size:16px;font-weight:600;margin:36px 0 12px}
table{width:100%;border-collapse:collapse;background:#fff;border:1px solid var(--line);
border-radius:10px;overflow:hidden}
th,td{text-align:left;padding:7px 10px;border-bottom:1px solid var(--line);
vertical-align:top;font-size:13px}
th{background:#F6F6F8;font-weight:600;color:var(--ink2);white-space:nowrap}
tr:last-child td{border-bottom:none}
code{background:var(--code);padding:1px 5px;border-radius:4px;font-size:12px;
font-family:ui-monospace,Consolas,monospace}
.mono{font-family:ui-monospace,Consolas,monospace;font-size:12px}
.big{font-size:20px;font-weight:600}
.pill{display:inline-block;padding:1px 8px;border-radius:99px;font-size:12px;
background:var(--warnbg);color:var(--warn);font-weight:600}
.pill.ok{background:var(--okbg);color:var(--ok)}
.box{background:#fff;border:1px solid var(--line);border-radius:10px;
padding:14px 16px;margin:12px 0}
.stats{display:flex;gap:12px;flex-wrap:wrap;margin:0 0 8px}
.stat{background:#fff;border:1px solid var(--line);border-radius:10px;
padding:12px 16px;min-width:150px}
.stat b{display:block;font-size:22px;font-weight:600;line-height:1.25}
.stat span{color:var(--ink2);font-size:12px}
.chips{display:flex;gap:4px;flex-wrap:wrap}
.chips code{background:#fff;border:1px solid var(--line)}
.muted{color:var(--ink3)}
</style></head><body><div class="wrap">
"""


def esc(s):
    return html.escape(str(s))


def scan_usage():
    """v3 常量 -> 引用它的文件集合（排除声明文件与分类映射表）。"""
    pat = re.compile(r"\bPlainIconData\.(\w+)")
    use = {}
    for base, dirs, files in os.walk(LIB):
        dirs[:] = [d for d in dirs if d != "generated"]
        for fn in sorted(files):
            if not fn.endswith(".dart"):
                continue
            p = os.path.join(base, fn)
            rel = os.path.relpath(p, LIB).replace(os.sep, "/")
            if rel in SCAN_SKIP:
                continue
            src = open(p, encoding="utf-8").read()
            for m in pat.finditer(src):
                use.setdefault(m.group(1), set()).add(rel)
    return use


def load_icon_set():
    if not os.path.exists(ICONS_JSON):
        return []
    d = json.load(open(ICONS_JSON, encoding="utf-8"))
    return d.get("icons", [])


def camel(stem):
    """`ic_nav_ledger` → `navLedger`；`ic_back` → `back`。组前缀保留。"""
    parts = stem.split("_")[1:]          # 去掉 ic
    return parts[0] + "".join(w.capitalize() for w in parts[1:])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out")
    args = ap.parse_args()

    use = scan_usage()
    icons = load_icon_set()

    total_pts = sum(c for _, _, c, _ in MAP)
    uniq = len({m for m, _, _, _ in MAP})
    doubt = [(m, v, c, n) for m, v, c, n in MAP if n.startswith("!")]
    used = sorted(use.items(), key=lambda kv: (-len(kv[1]), kv[0]))
    unused = [i for i in icons if camel(i["name"]) not in use]

    P = [HEAD]
    P.append("<h1>素记 · 图标替换清单</h1>")
    P.append(
        f'<p class="sub">源：<code>plain/tool/report_icon_map.py</code>'
        f' · 图标唯一源：<code>redesign-v3/04-ICON-SYSTEM/</code>（{len(icons)} 枚，'
        f'24 网格 / 描边 1.75 / <code>currentColor</code>）'
        f' · 渲染路线：<code>flutter_svg</code> 吃 <code>assets/icons/*.svg</code></p>')

    P.append('<div class="stats">')
    P.append(f'<div class="stat"><b>{total_pts}</b><span>替换的 Material 图标使用点</span></div>')
    P.append(f'<div class="stat"><b>{uniq}</b><span>涉及的 Material 图标种类</span></div>')
    P.append(f'<div class="stat"><b>{len(used)}</b><span>业务代码里在用的 v3 图标</span></div>')
    P.append(f'<div class="stat"><b>{len(icons)}</b><span>v3 图标全集</span></div>')
    P.append('<div class="stat"><b>0</b><span>存疑映射</span></div>')
    P.append('<div class="stat"><b>0</b><span>业务代码残留的 <code>Icons.</code></span></div>')
    P.append("</div>")

    P.append('<div class="box"><b>结论</b><ul>'
             '<li>业务代码里 <code>Icons.</code> 已清零；唯一残留是 '
             '<code>app/layout_shell.dart</code>（零引用死代码，用户明令保留不删）。</li>'
             '<li>旧 323 枚 <code>PlainIcons</code> 字体库、<code>assets/fonts/plain_icons/</code> '
             '与 <code>lib/design_system/plain_icons.dart</code> <b>已删除</b>，'
             '<code>pubspec.yaml</code> 的字体声明同步移除。</li>'
             '<li>原先 15 处<b>语义近似</b>的映射（库里无对应造型）已按《04》规则'
             '<b>在码位末尾补画 16 枚精确图标</b>（<code>0xE055</code>–<code>0xE064</code>），'
             '全部换成精确造型，<b>存疑清零</b>。</li>'
             '<li>图标走 <code>flutter_svg</code>：<code>PlainIcon</code> 直接吃 '
             '<code>assets/icons/ic_*.svg</code>，不做 path 预解析。</li>'
             '</ul></div>')

    # ── 一、映射表 ──
    P.append("<h2>一、映射表</h2>")
    P.append("<table><tr><th>Material Icons</th><th>v3 PlainIconData</th>"
             "<th>处数</th><th>说明</th></tr>")
    for m, v, c, note in MAP:
        if note.startswith("!"):
            badge = '<span class="pill">存疑</span> '
            note = note[1:]
        elif m.startswith("PlainIcons") or v.startswith("（"):
            badge = '<span class="pill ok">清理</span> '
        else:
            badge = ""
        P.append(
            f'<tr><td class="mono">{esc(m)}</td>'
            f'<td class="mono">{esc(v)}</td>'
            f'<td>{c}</td><td>{badge}{esc(note) or "<span class=\'muted\'>语义直接对应</span>"}</td></tr>')
    P.append("</table>")

    # ── 二、v3 图标使用分布 ──
    P.append("<h2>二、v3 图标使用分布</h2>")
    P.append(f'<p class="sub">扫 <code>plain/lib</code>（排除声明文件与分类映射表），'
             f'共 {len(used)} 枚被引用。</p>')
    P.append("<table><tr><th>v3 常量</th><th>引用文件数</th><th>引用位置</th></tr>")
    for k, files in used:
        fl = ", ".join(sorted(files))
        P.append(f'<tr><td class="mono">PlainIconData.{esc(k)}</td>'
                 f'<td>{len(files)}</td>'
                 f'<td class="mono muted" style="font-size:11px">{esc(fl)}</td></tr>')
    P.append("</table>")

    if unused:
        P.append("<h3>未使用（预留）</h3>")
        P.append('<div class="chips">')
        for i in unused:
            P.append(f'<code>{esc(i["name"])}</code> ')
        P.append("</div>")
        P.append(f'<p class="sub">{len(unused)} 枚。其中分类 12 枚由 '
                 f'<code>category_icon_v3.dart</code> 的映射表覆盖（不计入上方引用统计）；'
                 f'其余为 v3 全集里尚未落地的造型。</p>')

    # ── 三、存疑清单 ──
    if doubt:
        P.append("<h2>三、待拍板：语义近似的映射</h2>")
        P.append('<p class="sub">下列 Material 图标的语义在 v3 图标集里<b>没有对应造型</b>，'
                 '已选语义最近的替代。若要精确，需按《04》补画并追加到码位末尾。</p>')
        P.append("<table><tr><th>Material</th><th>暂用</th><th>缺什么</th></tr>")
        for m, v, c, note in doubt:
            P.append(f'<tr><td class="mono">{esc(m)}</td>'
                     f'<td class="mono">{esc(v)}</td>'
                     f'<td>{esc(note[1:])}</td></tr>')
        P.append("</table>")

    # ── 四、基础设施改动 ──
    P.append("<h2>四、基础设施改动</h2>")
    P.append('<table><tr><th>文件</th><th>改动</th></tr>'
             '<tr><td class="mono">design_system/plain_icons_v3.dart</td>'
             '<td>改为<b>生成物</b>（<code>plain/tool/gen_icons_abs.py</code>）：'
             '<code>PlainIconData</code> 100 枚常量 + <code>byName</code>；'
             '<code>PlainIcon.size</code> 由 <code>double = 24</code> 改为 '
             '<code>double?</code>，缺省时跟随 <code>IconTheme.of(context).size</code>'
             ' —— 与 <code>Icon</code> 语义对齐，避免 <code>IconButton(iconSize:)</code> '
             '语境下尺寸从 18 悄悄跳回 24。</td></tr>'
             '<tr><td class="mono">design_system/plain_icons.dart</td>'
             '<td><b>已删除</b>（旧 323 枚字体图标，零外部引用）。</td></tr>'
             '<tr><td class="mono">assets/fonts/plain_icons/</td>'
             '<td><b>已删除</b>（<code>PlainIcons.ttf</code> 78KB + 目录），'
             '<code>pubspec.yaml</code> 的 <code>PlainIcons</code> family 声明同步移除。</td></tr>'
             '<tr><td class="mono">design_system/app_empty_state.dart</td>'
             '<td><code>icon</code> 由 <code>IconData</code> 改为 '
             '<code>PlainIconData</code>（7 处调用点同步）。</td></tr>'
             '<tr><td class="mono">design_system/plain_ui.dart</td>'
             '<td><code>_TopBarIconBtn.icon</code> 字段删除（双轨收敛为单轨）；'
             '<code>PlainDangerButton.icon</code>／<code>PlainPrimaryButton.icon</code> '
             '由 <code>IconData?</code> 改为 <code>PlainIconData?</code>。</td></tr>'
             '<tr><td class="mono">design_system/category_icons.dart</td>'
             '<td>删除 <code>iconForCategory()</code>（旧库唯一出口），'
             '移除 <code>plain_icons.dart</code> 依赖；只保留 ref 清单 '
             '<code>kAllCategoryIconRefs</code>。</td></tr>'
             '<tr><td class="mono">design_system/plain_back_button.dart</td>'
             '<td>切到 v3 <code>PlainIconData.back</code>（该文件全库零引用）。</td></tr>'
             '<tr><td class="mono">features/ledger/presentation/entry_detail_page.dart</td>'
             '<td><code>_DetailRow.icon</code> 删除 —— 声明了但 build 里从未渲染。</td></tr>'
             '<tr><td class="mono">tool/gen_icons_abs.py</td>'
             '<td><b>重写</b>为路线 B 生成器（原先会产 <code>IconOp</code> + '
             '<code>CustomPaint</code>、<code>size</code> 写死 24，跑一次就把 '
             '<code>plain_icons_v3.dart</code> 整覆盖）。</td></tr>'
             '<tr><td class="mono">tool/gen_plain_icons_v3.py</td>'
             '<td><b>降级为废弃存根</b>（执行即报错退出，不写盘）。</td></tr>'
             '<tr><td class="mono">test/ui_resource_gate_test.dart</td>'
             '<td>针对旧 <code>PlainIcons</code> 字体的 4 项断言整体重写为 v3 口径'
             '（资产路径 / byName 对应 / 12 一级 ref 映射 / 未知 ref 回落）。</td></tr>'
             '</table>')

    P.append("</div></body></html>")

    out = args.out or os.path.join(ROOT, "图标替换清单.html")
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(P))
    print(f"written: {out}")
    print(f"  map={uniq} kinds / {total_pts} points, doubt={len(doubt)}, "
          f"v3 used={len(used)}, unused={len(unused)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
