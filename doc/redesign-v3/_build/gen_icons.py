"""素记 Plain · redesign-v3 — 图标作图与出图。

⚠️⚠️ 本脚本目前只覆盖 188 枚里的 100 枚 ⚠️⚠️
    04-ICON-SYSTEM/svg 下现有 188 枚、icons.json 记 188 条
    （nav 5 / category 100 / op 27 / status 9 / entry 13 / chart 5 / ui 29）。
    但下面 `ICONS` 里 category 只有 12 枚 —— 另外 88 枚 cat 细分图标是
    `_tmp_gen_cat_icons_*.py` 直接写 SVG + 追加 icons.json 的 category 段生成的。
    直接重跑会：① 删掉全部 ic_*.svg；② 只重建 ICONS 里的 100 枚；
    ③ 重写 icons.json，丢掉那 88 枚 category 条目。

    make 之前先看 `_guard_no_overwrite()`：它会数字符，孤儿图标存在就拒绝运行。
    真要重跑：先把那 88 枚补进 ICONS，或显式 `--force`（自担风险）。

不产出的东西：文档（ICON-SPEC.md 手写）。
产出的东西：
  redesign-v3/04-ICON-SYSTEM/svg/ic_*.svg    每枚一个源文件
  redesign-v3/04-ICON-SYSTEM/icons.json      name / file / category / codepoint / tags
  redesign-v3/_build/sprite.html + sheet.png 自检贴图（用完可删）

作图语言（全部图标无例外）：
  画布 24×24 · 内容盒 [2, 22]（20 单位）· 描边 1.75 居中 · round cap/join
  fill=none · 颜色 currentColor · 点状元素用 r=1.5 / r=1.6 实心圆
  圆角矩形统一用 <rect rx>，不用手写贝塞尔弧 —— 曲率一致才不会「一套语言」变「一锅拼盘」
"""

from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
SVG_DIR = os.path.join(ROOT, "04-ICON-SYSTEM", "svg")

GRID = 24
STROKE = 1.75

# ─────────────────────────────────────────────────────────────── 元素助手

def p(d: str) -> str:
    return f'<path d="{d}"/>'


def r(x, y, w, h, rx) -> str:
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}"/>'


def c(cx, cy, rr) -> str:
    return f'<circle cx="{cx}" cy="{cy}" r="{rr}"/>'


def dot(cx, cy, rr=1.5) -> str:
    """实心点：分类色圆点、省略号、关节。"""
    return f'<circle cx="{cx}" cy="{cy}" r="{rr}" fill="currentColor" stroke="none"/>'


# ─────────────────────────────────────────────────────────────── 图标定义
# (name, category, codepoint_offset, tags, [elements])

ICONS: list[tuple[str, str, list[str], list[str]]] = [
    # ══════════════ 导航 5 ══════════════
    ("ic_nav_ledger", "nav", ["ledger", "list", "transactions", "流水", "账单"],
     [p("M8.75 6.5h10.75"), p("M8.75 12h10.75"), p("M8.75 17.5h10.75"),
      dot(5.25, 6.5, 1.4), dot(5.25, 12, 1.4), dot(5.25, 17.5, 1.4)]),

    ("ic_nav_report", "nav", ["report", "chart", "pie", "报表", "图表"],
     [p("M12 3.5A8.5 8.5 0 0 1 20.5 12A8.5 8.5 0 0 1 12 20.5A8.5 8.5 0 0 1 3.5 12"),
      p("M12 12 12 3.5"), p("M12 12 20.5 12")]),

    ("ic_nav_add", "nav", ["add", "new", "plus", "记一笔", "记帐"],
     [p("M12 5.25v13.5"), p("M5.25 12h13.5")]),

    ("ic_nav_assets", "nav", ["assets", "wallet", "balance", "资产", "钱包"],
     [r(3.75, 7.25, 16.5, 11.5, 3),
      p("M6.75 7.25V6.4a1.75 1.75 0 0 1 1.75-1.75h7a1.75 1.75 0 0 1 1.75 1.75v.85"),
      dot(16.5, 13, 1.35)]),

    ("ic_nav_profile", "nav", ["profile", "me", "user", "我的", "设置"],
     [c(12, 8.25, 3.5), p("M5.5 19.5a6.5 6.5 0 0 1 13 0")]),

    # ══════════════ 分类 12 ══════════════
    ("ic_cat_food", "category", ["food", "meal", "restaurant", "餐饮", "吃"],
     [p("M3.5 11.75A8.5 8.5 0 0 0 20.5 11.75Z"),
      p("M9.6 9V6.25"), p("M14.4 9V6.25")]),

    ("ic_cat_grocery", "category", ["grocery", "fruit", "market", "食材", "买菜"],
     [p("M12 8.75c1.5-1.3 3.95-1.6 5.55-.2 1.9 1.7 1.9 5-.1 8.1-1.2 1.85-2.85 3.25-4.35 3.25-.5 0-.8-.15-1.1-.3"
        "-.35-.15-.65-.3-1-.3s-.65.15-1 .3c-.3.15-.6.3-1.1.3-1.5 0-3.15-1.4-4.35-3.25-2-3.1-2-6.4-.1-8.1 1.6-1.4 4.05-1.1 5.55.2z"),
      p("M12 8.75V6.1"),
      p("M12 6.1c1.55-.4 2.55-1.45 2.85-2.85-1.55.1-2.6 1.05-2.85 2.85z")]),

    ("ic_cat_shopping", "category", ["shopping", "bag", "buy", "购物", "买"],
     [p("M5.5 8.25h13l-1.05 10.5a2.25 2.25 0 0 1-2.24 2.05H8.79a2.25 2.25 0 0 1-2.24-2.05z"),
      p("M9.25 8.25V6.5a2.75 2.75 0 0 1 5.5 0v1.75")]),

    ("ic_cat_daily", "category", ["daily", "household", "bottle", "日用", "生活"],
     [r(10.25, 3.25, 3.5, 2.25, 0.9),
      p("M10.25 5.5 8.5 8.25"), p("M13.75 5.5 15.5 8.25"),
      r(7.5, 8.25, 9, 12, 2.5)]),

    ("ic_cat_transport", "category", ["transport", "bus", "car", "交通", "出行"],
     [r(5, 4, 14, 13, 3), p("M5 10.5h14"),
      dot(8.5, 19.25, 1.35), dot(15.5, 19.25, 1.35)]),

    ("ic_cat_housing", "category", ["housing", "rent", "home", "居住", "房租"],
     [p("M3.5 11.25 12 4l8.5 7.25"),
      p("M5.75 10.75V18.5a1.75 1.75 0 0 0 1.75 1.75h9a1.75 1.75 0 0 0 1.75-1.75v-7.75"),
      p("M10.25 20.25v-4a1.75 1.75 0 0 1 3.5 0v4")]),

    ("ic_cat_telecom", "category", ["telecom", "signal", "phone", "通讯", "话费"],
     [p("M6.75 20.25V15.5"), p("M12 20.25V10.75"), p("M17.25 20.25V6")]),

    ("ic_cat_entertainment", "category", ["fun", "music", "headphone", "娱乐", "玩"],
     [p("M5 15.25V12a7 7 0 0 1 14 0v3.25"),
      r(3.25, 13.75, 3.5, 6.25, 1.75), r(17.25, 13.75, 3.5, 6.25, 1.75)]),

    ("ic_cat_medical", "category", ["medical", "health", "医疗", "看病"],
     [c(12, 12, 8.5), p("M12 8.25v7.5"), p("M8.25 12h7.5")]),

    ("ic_cat_study", "category", ["study", "book", "learn", "学习", "教育"],
     [p("M12 7.25v11.5"),
      p("M12 7.25C10.4 5.9 8.4 5.25 5.75 5.25a1.5 1.5 0 0 0-1.5 1.5v9.5a1.5 1.5 0 0 0 1.5 1.5c2.65 0 4.65.65 6.25 2"),
      p("M12 7.25c1.6-1.35 3.6-2 6.25-2a1.5 1.5 0 0 1 1.5 1.5v9.5a1.5 1.5 0 0 1-1.5 1.5c-2.65 0-4.65.65-6.25 2")]),

    ("ic_cat_social", "category", ["social", "gift", "present", "人情", "礼物"],
     [r(3, 6.25, 18, 3.75, 1.75), r(4.5, 10, 15, 10.25, 2), p("M12 6.25v14")]),

    ("ic_cat_other", "category", ["other", "misc", "grid", "其他", "杂项"],
     [r(4.25, 4.25, 6, 6, 1.75), r(13.75, 4.25, 6, 6, 1.75),
      r(4.25, 13.75, 6, 6, 1.75), r(13.75, 13.75, 6, 6, 1.75)]),

    # ══════════════ 操作 19 ══════════════
    ("ic_back", "op", ["back", "arrow-left", "返回"],
     [p("M19 12H5.5"), p("M11.25 5.75 5 12l6.25 6.25")]),

    ("ic_chevron_right", "op", ["chevron", "next", "右"],
     [p("M9.5 5.75 15.75 12 9.5 18.25")]),

    ("ic_chevron_left", "op", ["chevron", "prev", "左"],
     [p("M14.5 5.75 8.25 12 14.5 18.25")]),

    ("ic_chevron_down", "op", ["chevron", "expand", "下"],
     [p("M5.75 9.5 12 15.75 18.25 9.5")]),

    ("ic_close", "op", ["close", "x", "dismiss", "关闭"],
     [p("M6 6 18 18"), p("M18 6 6 18")]),

    ("ic_search", "op", ["search", "find", "搜索", "查找"],
     [c(10.75, 10.75, 6.25), p("M15.4 15.4 20 20")]),

    ("ic_filter", "op", ["filter", "funnel", "筛选"],
     [p("M4.25 5.75h15.5l-6 7.25v5.25l-3.5 2.25v-7.5z")]),

    ("ic_edit", "op", ["edit", "pencil", "write", "编辑", "修改"],
     [p("M16.5 3.75 20.25 7.5 8.25 19.5l-4.5 1 1-4.5z"), p("M14.25 6 18 9.75")]),

    ("ic_delete", "op", ["delete", "trash", "remove", "删除"],
     [p("M3.75 6.5h16.5"),
      p("M9.25 6.5V4.75a1.5 1.5 0 0 1 1.5-1.5h2.5a1.5 1.5 0 0 1 1.5 1.5V6.5"),
      p("M6 6.5 6.95 19.4a1.75 1.75 0 0 0 1.75 1.6h6.6a1.75 1.75 0 0 0 1.75-1.6L18 6.5"),
      p("M10.25 10.25v6.75"), p("M13.75 10.25v6.75")]),

    ("ic_check", "op", ["check", "done", "ok", "确认"],
     [p("M4.75 12.5 9.5 17.25 19.25 6.75")]),

    ("ic_plus", "op", ["plus", "add", "加"],
     [p("M12 5.5v13"), p("M5.5 12h13")]),

    ("ic_minus", "op", ["minus", "subtract", "减"],
     [p("M5.5 12h13")]),

    ("ic_more", "op", ["more", "ellipsis", "menu", "更多"],
     [dot(6.25, 12, 1.6), dot(12, 12, 1.6), dot(17.75, 12, 1.6)]),

    ("ic_more_vertical", "op", ["more", "ellipsis", "kebab", "更多"],
     [dot(12, 6.25, 1.6), dot(12, 12, 1.6), dot(12, 17.75, 1.6)]),

    ("ic_share", "op", ["share", "nodes", "分享"],
     [c(6, 6.75, 2.25), c(6, 17.25, 2.25), c(17.75, 12, 2.25),
      p("M7.9 7.8 15.7 11.1"), p("M7.9 16.2 15.7 12.9")]),

    ("ic_undo", "op", ["undo", "revert", "撤销"],
     [p("M20.25 17.75v-2.5a5.25 5.25 0 0 0-5.25-5.25H5.75"),
      p("M9.5 5.75 5.5 10l4 4.25")]),

    ("ic_sort", "op", ["sort", "order", "排序"],
     [p("M7.5 4.75v14.5"), p("M4.25 16 7.5 19.25 10.75 16"),
      p("M16.5 19.25V4.75"), p("M13.25 8 16.5 4.75 19.75 8")]),

    ("ic_drag_handle", "op", ["drag", "handle", "reorder", "拖动"],
     [p("M6.5 9.5h11"), p("M6.5 14.5h11")]),

    ("ic_scan", "op", ["scan", "qr", "扫描"],
     [p("M3.75 8.75V5.5a1.75 1.75 0 0 1 1.75-1.75h3.25"),
      p("M20.25 8.75V5.5a1.75 1.75 0 0 0-1.75-1.75h-3.25"),
      p("M3.75 15.25v3.25a1.75 1.75 0 0 0 1.75 1.75h3.25"),
      p("M20.25 15.25v3.25a1.75 1.75 0 0 1-1.75 1.75h-3.25"),
      p("M3.75 12h16.5")]),

    # ══════════════ 状态 8 ══════════════
    ("ic_status_success", "status", ["success", "ok", "check", "成功"],
     [c(12, 12, 8.5), p("M8.25 12.25 10.75 14.75 15.75 9.5")]),

    ("ic_status_error", "status", ["error", "fail", "失败"],
     [c(12, 12, 8.5), p("M9.5 9.5 14.5 14.5"), p("M14.5 9.5 9.5 14.5")]),

    ("ic_status_warning", "status", ["warning", "alert", "警告"],
     [p("M10.6 4.4 2.9 17.75a1.6 1.6 0 0 0 1.4 2.4h15.4a1.6 1.6 0 0 0 1.4-2.4L13.4 4.4a1.6 1.6 0 0 0-2.8 0z"),
      p("M12 9.75v3.75"), dot(12, 17, 1.05)]),

    ("ic_status_info", "status", ["info", "about", "信息"],
     [c(12, 12, 8.5), p("M12 11.25v5"), dot(12, 8.25, 1.05)]),

    ("ic_lock", "status", ["lock", "secure", "锁"],
     [r(4.75, 10.25, 14.5, 10, 2.5), p("M8.25 10.25V7.75a3.75 3.75 0 0 1 7.5 0v2.5")]),

    ("ic_offline", "status", ["offline", "no-network", "离线"],
     [p("M6.75 17.5h10.5a3.75 3.75 0 0 0 .4-7.5 5.5 5.5 0 0 0-10.6-1.2 4.4 4.4 0 0 0-.3 8.7z"),
      p("M4.5 4.5 19.5 19.5")]),

    ("ic_empty", "status", ["empty", "inbox", "tray", "空态"],
     [r(3, 6.5, 18, 11, 2.75),
      p("M3 12.5h4.75l1.25 2.25h6l1.25-2.25H21")]),

    ("ic_loading", "status", ["loading", "spinner", "加载"],
     [p("M12 3.75a8.25 8.25 0 1 0 8.25 8.25")]),

    # ══════════════ 记账 12 ══════════════
    ("ic_calendar", "entry", ["calendar", "date", "日历", "日期"],
     [r(3.75, 5.25, 16.5, 15, 2.75), p("M3.75 10h16.5"),
      p("M8.25 3.5v3.5"), p("M15.75 3.5v3.5"), dot(8.5, 14.25, 1.35)]),

    ("ic_account", "entry", ["account", "card", "bank", "账户", "银行卡"],
     [r(3.25, 5.75, 17.5, 12.5, 2.75), p("M3.25 10.25h17.5"), p("M6.75 14.75h3.5")]),

    ("ic_note", "entry", ["note", "memo", "text", "备注"],
     [r(4.75, 3.75, 14.5, 16.5, 2.5),
      p("M8.25 8.75h7.5"), p("M8.25 12.5h7.5"), p("M8.25 16.25h4.25")]),

    ("ic_amount", "entry", ["amount", "money", "yuan", "金额"],
     [p("M8.25 5.5 12 11.25 15.75 5.5"), p("M12 11.25v7.25"),
      p("M8.75 13.5h6.5"), p("M8.75 16.25h6.5")]),

    ("ic_transfer", "entry", ["transfer", "swap", "转账"],
     [p("M4.25 8.75h13.5"), p("M14.25 5.25 17.75 8.75l-3.5 3.5"),
      p("M19.75 15.25H6.25"), p("M9.75 11.75 6.25 15.25l3.5 3.5")]),

    ("ic_budget", "entry", ["budget", "target", "limit", "预算"],
     [c(12, 12, 8.25), c(12, 12, 3.5)]),

    ("ic_recurring", "entry", ["recurring", "repeat", "cycle", "周期"],
     [p("M4.75 12a7.25 7.25 0 0 1 12.15-5.35"), p("M17.25 3.5v3.75h-3.75"),
      p("M19.25 12a7.25 7.25 0 0 1-12.15 5.35"), p("M6.75 20.5v-3.75h3.75")]),

    ("ic_export", "entry", ["export", "upload", "导出"],
     [p("M12 15.25V4"), p("M8.25 7.5 12 3.75l3.75 3.75"),
      p("M4.5 13.5v4.5a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2v-4.5")]),

    ("ic_import", "entry", ["import", "download", "导入"],
     [p("M12 3.75V15"), p("M8.25 11.5 12 15.25l3.75-3.75"),
      p("M4.5 13.5v4.5a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2v-4.5")]),

    ("ic_attachment", "entry", ["attachment", "clip", "附件"],
     [p("M19.75 10.5 10.9 19.35a5 5 0 0 1-7.07-7.07l8.6-8.6a3.35 3.35 0 0 1 4.74 4.74l-8.6 8.6a1.7 1.7 0 0 1-2.4-2.4l7.6-7.6")]),

    ("ic_goal", "entry", ["goal", "flag", "saving", "目标"],
     [p("M6 20.5V4.25"), p("M6 4.75h11.5l-2.25 3.75 2.25 3.75H6")]),

    ("ic_receipt", "entry", ["receipt", "bill", "invoice", "报销", "票据"],
     [p("M5.75 3.75h12.5v16.5l-2.5-1.75-2.5 1.75-2.5-1.75-2.5 1.75-2.5-1.75z"),
      p("M9.25 8.5h5.5"), p("M9.25 12.25h5.5")]),

    # ══════════════ 图表 5 ══════════════
    ("ic_chart_pie", "chart", ["pie", "donut", "占比"],
     [p("M12 3.5a8.5 8.5 0 1 0 8.5 8.5h-8.5z")]),

    ("ic_chart_bars", "chart", ["bars", "column", "柱状"],
     [p("M6.75 20.25V12"), p("M12 20.25V5.75"), p("M17.25 20.25V15.5")]),

    ("ic_chart_line", "chart", ["line", "trend", "折线"],
     [p("M3.75 18.5 9 12l4 3.5 7.25-8.25")]),

    ("ic_trend_up", "chart", ["up", "increase", "涨"],
     [p("M4 16.5 9.5 11l3.5 3.5L20 8"), p("M14.75 8H20v5.25")]),

    ("ic_trend_down", "chart", ["down", "decrease", "跌"],
     [p("M4 8 9.5 13.5l3.5-3.5L20 16.5"), p("M14.75 16.5H20V11.25")]),

    # ══════════════ 通用 23 ══════════════
    ("ic_settings", "ui", ["settings", "preferences", "sliders", "设置"],
     [p("M3.75 8.5h16.5"), p("M3.75 15.5h16.5"), c(9, 8.5, 2.25), c(15.5, 15.5, 2.25)]),

    ("ic_bell", "ui", ["bell", "notification", "reminder", "提醒"],
     [p("M5.75 16.75 7 14.25V10.5a5 5 0 0 1 10 0v3.75l1.25 2.5z"),
      p("M10.25 19.75a2.25 2.25 0 0 0 3.5 0")]),

    ("ic_moon", "ui", ["moon", "dark", "夜"],
     [p("M20.25 14.75A8.75 8.75 0 0 1 9.25 3.75a8.75 8.75 0 1 0 11 11z")]),

    ("ic_sun", "ui", ["sun", "light", "日"],
     [c(12, 12, 4.25), p("M12 2.75v2.5"), p("M12 18.75v2.5"),
      p("M2.75 12h2.5"), p("M18.75 12h2.5"),
      p("M5.45 5.45 7.2 7.2"), p("M16.8 16.8l1.75 1.75"),
      p("M18.55 5.45 16.8 7.2"), p("M7.2 16.8 5.45 18.55")]),

    ("ic_palette", "ui", ["palette", "theme", "color", "swatch", "主题", "配色"],
     [c(12, 12, 8.5), p("M3.5 12h17"), p("M12 3.5v17")]),

    ("ic_font", "ui", ["font", "text-size", "字号"],
     [p("M3.5 19.25 8 5.25l4.5 14"), p("M5.1 15h5.8"),
      p("M16.25 19.25v-6.5a2.75 2.75 0 0 1 5.5 0v6.5"), p("M16.25 15.5h5.5")]),

    ("ic_volume", "ui", ["volume", "sound", "音效"],
     [p("M11 5.25 6.75 8.75H3.5v6.5h3.25L11 18.75z"),
      p("M14.75 9.25a4 4 0 0 1 0 5.5"), p("M17.5 6.5a8 8 0 0 1 0 11")]),

    ("ic_qr", "ui", ["qr", "code", "二维码"],
     [p("M3.75 8.25V5.5a1.75 1.75 0 0 1 1.75-1.75h2.75"),
      p("M20.25 8.25V5.5a1.75 1.75 0 0 0-1.75-1.75h-2.75"),
      p("M3.75 15.75v2.75a1.75 1.75 0 0 0 1.75 1.75h2.75"),
      r(6.75, 6.75, 3.5, 3.5, 1), r(13.75, 6.75, 3.5, 3.5, 1),
      r(6.75, 13.75, 3.5, 3.5, 1), p("M13.75 17.5h4"), p("M17.5 13.75v4")]),

    ("ic_copy", "ui", ["copy", "duplicate", "复制"],
     [r(8.25, 8.25, 12, 12, 2.5), p("M15.75 8.25V6.25a2.5 2.5 0 0 0-2.5-2.5H6.25a2.5 2.5 0 0 0-2.5 2.5v7a2.5 2.5 0 0 0 2.5 2.5h2")]),

    ("ic_star", "ui", ["star", "favorite", "收藏"],
     [p("M12 3.75 14.6 9.05 20.5 9.9l-4.25 4.15 1 5.85L12 17.15l-5.25 2.75 1-5.85L3.5 9.9l5.9-.85z")]),

    ("ic_tag", "ui", ["tag", "label", "标签"],
     [p("M11.75 3.75H5.5A1.75 1.75 0 0 0 3.75 5.5v6.25L13.5 21.5l7.25-7.25z"),
      dot(7.75, 7.75, 1.4)]),

    ("ic_shield", "ui", ["shield", "privacy", "secure", "隐私"],
     [p("M12 3.5 4.75 6.5v5.25c0 4.4 2.9 7.45 7.25 8.75 4.35-1.3 7.25-4.35 7.25-8.75V6.5z")]),

    ("ic_fingerprint", "ui", ["fingerprint", "biometric", "指纹"],
     [p("M12 3.75a8.25 8.25 0 0 1 8.25 8.25"),
      p("M3.75 12A8.25 8.25 0 0 1 12 3.75"),
      p("M6.75 14.5a5.25 5.25 0 0 1 10.5-2.5"),
      p("M12 20.25c-2.6 0-4.85-1.6-5.75-3.9"),
      p("M14.25 20.1a8.25 8.25 0 0 0 2.9-2.35")]),

    ("ic_storage", "ui", ["storage", "database", "存储"],
     [p("M4.25 6.5c0-1.5 3.5-2.75 7.75-2.75s7.75 1.25 7.75 2.75"),
      p("M4.25 6.5v11c0 1.5 3.5 2.75 7.75 2.75s7.75-1.25 7.75-2.75v-11"),
      p("M4.25 12c0 1.5 3.5 2.75 7.75 2.75s7.75-1.25 7.75-2.75")]),

    ("ic_image", "ui", ["image", "photo", "图片"],
     [r(3.75, 4.75, 16.5, 14.5, 2.5),
      p("M3.75 15.75 8.5 11l4.25 4.25 2.5-2.5 5.25 5.25"),
      dot(8.75, 9.25, 1.4)]),

    ("ic_camera", "ui", ["camera", "photo", "拍照"],
     [p("M4 8.75h3l1.5-2.5h7l1.5 2.5h3a1.75 1.75 0 0 1 1.75 1.75v7A1.75 1.75 0 0 1 20 19.25H4a1.75 1.75 0 0 1-1.75-1.75v-7A1.75 1.75 0 0 1 4 8.75z"),
      c(12, 13.5, 3.25)]),

    ("ic_eye", "ui", ["eye", "show", "visible", "显示"],
     [p("M2.75 12S6.25 6.25 12 6.25 21.25 12 21.25 12 17.75 17.75 12 17.75 2.75 12 2.75 12z"),
      c(12, 12, 3.25)]),

    ("ic_eye_off", "ui", ["eye-off", "hide", "hidden", "隐藏"],
     [p("M9.75 6.6A8.6 8.6 0 0 1 12 6.25c5.75 0 9.25 5.75 9.25 5.75a17 17 0 0 1-3.1 3.6"),
      p("M6.35 8.4A17 17 0 0 0 2.75 12s3.5 5.75 9.25 5.75c1.15 0 2.2-.2 3.15-.55"),
      p("M10.1 10.1a2.7 2.7 0 0 0 3.8 3.8"), p("M4.5 4.5 19.5 19.5")]),

    ("ic_cloud", "ui", ["cloud", "sync", "backup", "云同步"],
     [p("M6.75 17.75h10.5a3.75 3.75 0 0 0 .4-7.5 5.5 5.5 0 0 0-10.6-1.2 4.4 4.4 0 0 0-.3 8.7z")]),

    ("ic_wallet", "ui", ["wallet", "balance", "钱包", "余额"],
     [r(3.75, 7.25, 16.5, 11.5, 3), p("M3.75 11.25h16.5"), dot(16.5, 14.75, 1.35)]),

    ("ic_card", "ui", ["card", "credit", "银行卡"],
     [r(3.25, 6.25, 17.5, 11.5, 2.5), p("M3.25 10.25h17.5"), p("M6.5 14.25h4")]),

    ("ic_arrow_up_right", "ui", ["arrow", "up-right", "out"],
     [p("M6.75 17.25 17.25 6.75"), p("M8.75 6.75h8.5v8.5")]),

    ("ic_arrow_down_left", "ui", ["arrow", "down-left", "in"],
     [p("M17.25 6.75 6.75 17.25"), p("M15.25 17.25h-8.5v-8.5")]),

    # ══════════════ 增补 16 · 码位 0xE055–0xE064 ══════════════
    # 出处：G 类图标替换时发现 15 项语义在 v3 集里无对应造型（原先只能拿近似造型顶替）。
    # 依《04》§2「增补规则」：新图标只能追加末尾，不得插入中间 —— 故码位自 0xE055 连续接续，
    # 上述分组顺序（op/category/…）在文件里不重排，避免移动既有 84 枚的码位。
    # 几何基准：与既有 84 枚同一套语言（24 网格 / 描边 1.75 / round cap / currentColor）；
    # 造型与 Lucide 同源（v3 的 eye/camera/storage/fingerprint 亦然），圆角与半径按《04》§1.1 收口。

    ("ic_chevron_up", "op", ["chevron", "collapse", "expand-less", "向上", "收起"],
     [p("M5.75 14.5 12 8.25 18.25 14.5")]),

    ("ic_circle_plus", "op", ["add", "plus", "circle", "新增", "添加"],
     [c(12, 12, 8.5), p("M12 8.25v7.5"), p("M8.25 12h7.5")]),

    ("ic_circle_minus", "op", ["remove", "minus", "circle", "移除", "删除"],
     [c(12, 12, 8.5), p("M8.25 12h7.5")]),

    ("ic_play", "op", ["play", "run", "start", "执行", "开始"],
     [p("M8.25 5.25 18.75 12 8.25 18.75z")]),

    ("ic_list_check", "op", ["list", "check", "todo", "核对", "勾选"],
     [p("M3.75 7.25 5.75 9.25 9.75 5.25"), p("M13 7.25h7.75"),
      p("M13 12.25h7.75"),
      p("M3.75 17.25 5.75 19.25 9.75 15.25"), p("M13 17.25h7.75")]),

    ("ic_merge", "op", ["merge", "combine", "consolidate", "合并"],
     [p("M6.75 4.5 12 9.75"), p("M17.25 4.5 12 9.75"), p("M12 9.75v9.75"),
      p("M9.75 17.25 12 19.5 14.25 17.25")]),

    # 文件夹外框自绘而非照抄 Lucide 原值：Lucide 的 folder 占满 [2,22]，
    # 比既有 84 枚（多在 [3,21]）明显大一圈 —— 收口到 [3.25,20.75] × [4.75,19.25]，
    # 圆角 2 与 ic_note(rx 2.5)/ic_calendar(rx 2.75) 同族。
    ("ic_folder_plus", "op", ["folder", "new", "create", "新建文件夹"],
     [p("M3.25 19.25V6.75a2 2 0 0 1 2-2h2.85a2 2 0 0 1 1.66.89l.48.72a2 2 0 0 0 1.66.89h6.85a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5.25a2 2 0 0 1-2-2z"),
      p("M12 10v4.5"), p("M9.75 12.25h4.5")]),

    ("ic_folder_move", "op", ["folder", "move", "移动文件夹"],
     [p("M3.25 19.25V6.75a2 2 0 0 1 2-2h2.85a2 2 0 0 1 1.66.89l.48.72a2 2 0 0 0 1.66.89h6.85a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5.25a2 2 0 0 1-2-2z"),
      p("M9.25 12.5h6.5"), p("M12.75 9.75 15.5 12.5l-2.75 2.75")]),

    ("ic_history", "entry", ["history", "log", "recent", "历史", "操作日志"],
     [p("M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"),
      p("M3 3v5h5"), p("M12 7v5l4 2")]),

    ("ic_mood", "status", ["mood", "smile", "happy", "正向", "情绪"],
     [c(12, 12, 8.5), p("M7.75 13.75a6 6 0 0 0 8.5 0"),
      dot(9, 9.25, 1.05), dot(15, 9.25, 1.05)]),

    ("ic_gift", "ui", ["gift", "present", "reward", "礼物", "奖励"],
     [r(3, 8, 18, 4, 1), p("M12 8v13"),
      p("M19 12v7a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-7"),
      p("M7.5 8a2.5 2.5 0 0 1 0-5A4.8 8 0 0 1 12 8a4.8 8 0 0 1 4.5-5 2.5 2.5 0 0 1 0 5")]),

    ("ic_trophy", "ui", ["trophy", "award", "win", "成就", "奖杯"],
     [p("M7.5 3.75h9v5.5a4.5 4.5 0 0 1-9 0z"),
      p("M7.5 5.25H6a2.25 2.25 0 0 0 0 4.5h1.5"),
      p("M16.5 5.25H18a2.25 2.25 0 0 1 0 4.5h-1.5"),
      p("M12 13.75v5"), p("M8.75 18.75h6.5")]),

    ("ic_flame", "ui", ["flame", "fire", "streak", "连续", "火苗"],
     [p("M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z")]),

    ("ic_celebration", "ui", ["celebration", "party", "achievement", "庆祝", "达成"],
     [p("M4.25 19.75 10.25 8.25 15.75 13.75z"), p("M14.5 6.75 16.25 5"),
      dot(18.25, 4.75, 1.05), dot(19.75, 9, 1.05)]),

    ("ic_cloud_upload", "ui", ["cloud", "upload", "backup", "上传", "备份"],
     [p("M6.75 17.75h10.5a3.75 3.75 0 0 0 .4-7.5 5.5 5.5 0 0 0-10.6-1.2 4.4 4.4 0 0 0-.3 8.7z"),
      p("M12 15.5v-4.5"), p("M9.75 13.25 12 11l2.25 2.25")]),

    ("ic_cloud_download", "ui", ["cloud", "download", "restore", "下载", "恢复"],
     [p("M6.75 17.75h10.5a3.75 3.75 0 0 0 .4-7.5 5.5 5.5 0 0 0-10.6-1.2 4.4 4.4 0 0 0-.3 8.7z"),
      p("M12 10.5v4.5"), p("M9.75 12.75 12 15l2.25-2.25")]),
]

# ══════════════════════════════════════════════════════════════════════════
# 产出
# ══════════════════════════════════════════════════════════════════════════

CAT_LABEL = {"nav": "导航", "category": "分类", "op": "操作", "status": "状态",
             "entry": "记账", "chart": "图表", "ui": "通用"}


def svg_doc(elements, size=24, title="icon", stroke=STROKE):
    body = "\n  ".join(elements)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
        f'viewBox="0 0 {GRID} {GRID}" fill="none" role="img" aria-label="{title}">\n'
        f'  <g stroke="currentColor" stroke-width="{stroke}" stroke-linecap="round" '
        f'stroke-linejoin="round">\n  {body}\n  </g>\n</svg>\n'
    )


def _guard_no_overwrite() -> None:
    """安全闸：svg 目录里有 ICONS 之外的图标时拒绝运行。

    这道闸是给「重跑一次把 88 枚 cat 图标冲掉」这种事兜底的 —— 光靠注释
    挡不住手快。要真跑就 `--force`，或者先把孤儿图标补进 ICONS。
    """
    if not os.path.isdir(SVG_DIR):
        return
    have = {
        n[len("ic_"):-len(".svg")]
        for n in os.listdir(SVG_DIR)
        if n.startswith("ic_") and n.endswith(".svg")
    }
    defined = {name[len("ic_"):] if name.startswith("ic_") else name for name, *_ in ICONS}
    orphans = sorted(have - defined)
    if not orphans or "--force" in sys.argv:
        return
    print(f"[abort] svg 目录有 {len(orphans)} 枚图标不在 ICONS 里，重跑会删掉它们：")
    for n in orphans[:12]:
        print(f"         - ic_{n}.svg")
    if len(orphans) > 12:
        print(f"         ... 共 {len(orphans)} 枚")
    print("        这些是 _tmp_gen_cat_icons_*.py 写的。先补进 ICONS，或加 --force。")
    sys.exit(2)


def main():
    _guard_no_overwrite()
    os.makedirs(SVG_DIR, exist_ok=True)
    # 清掉上一轮残留（只删 ic_*.svg，不动别的）
    for n in os.listdir(SVG_DIR):
        if n.startswith("ic_") and n.endswith(".svg"):
            os.remove(os.path.join(SVG_DIR, n))

    records = []
    cp = 0xE001
    for name, cat, tags, elements in ICONS:
        fn = f"{name}.svg"
        with open(os.path.join(SVG_DIR, fn), "w", encoding="utf-8") as fh:
            fh.write(svg_doc(elements, title=name))
        records.append(dict(name=name, file=f"svg/{fn}", category=cat,
                            categoryLabel=CAT_LABEL[cat], codepoint=f"0x{cp:04X}",
                            tags=tags))
        cp += 1

    doc = {
        "version": "3.0",
        "grid": GRID,
        "stroke": STROKE,
        "strokeLinecap": "round",
        "strokeLinejoin": "round",
        "fill": "none",
        "color": "currentColor",
        "contentBox": [2, 22],
        "paintedExtent": [1.125, 22.875],
        "codepointStart": "0xE001",
        "codepointRule": "自 0xE001 起连续分配。本轮为**全新一套造型**，与旧 PlainIcons 无继承关系，"
                         "码位仅作新字体/映射表用，不承诺与旧字体一致。",
        "count": len(records),
        "byCategory": {k: sum(1 for r in records if r["category"] == k) for k in CAT_LABEL},
        "icons": records,
    }
    with open(os.path.join(ROOT, "04-ICON-SYSTEM", "icons.json"), "w", encoding="utf-8") as fh:
        json.dump(doc, fh, ensure_ascii=False, indent=1)

    # 自检贴图
    cells = []
    for name, cat, tags, elements in ICONS:
        cells.append(
            f'<div class="cell"><div class="ico">{svg_doc(elements, 48, name)}</div>'
            f'<div class="nm">{name}</div></div>'
        )
    sheet = (
        f'<!doctype html><html><head><meta charset="utf-8"><title>icon sheet</title><style>\n'
        f'body{{margin:0;background:#fff;font:11px/1.4 Inter,system-ui,sans-serif;color:#101012}}\n'
        f'.grid{{display:grid;grid-template-columns:repeat(12,1fr);gap:6px;padding:14px}}\n'
        f'.cell{{display:flex;flex-direction:column;align-items:center;gap:4px;'
        f'border:1px solid #E4E4E8;border-radius:10px;padding:8px 4px;color:#101012}}\n'
        f'.ico{{color:#101012;display:flex}}\n'
        f'.nm{{font-size:9px;color:#5E5E65;text-align:center;word-break:break-all}}\n'
        f'</style></head><body><div class="grid">{"".join(cells)}</div></body></html>'
    )
    with open(os.path.join(HERE, "sprite.html"), "w", encoding="utf-8") as fh:
        fh.write(sheet)

    print(f"icons: {len(records)}")
    print("by category:", doc["byCategory"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
