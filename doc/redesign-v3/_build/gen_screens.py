"""素记 Plain · redesign-v3 — 8 屏高保真生成器。

产出：redesign-v3/07-SCREENS.html（单文件，零外部依赖，双击即开）

铁律：
  · CSS 变量全部来自 01-tokens.json 的 resolved / v3Additions —— 页面里没有裸色号
  · 图标全部来自 04-ICON-SYSTEM/svg —— 内联 <symbol> sprite，不混任何其他图标语言
  · 4 个维度可切：主题（素白/青瓷）× 亮度 × 语言 × 字号三档
  · 8 屏可点：底部导航 / FAB / 返回 / 行点击 都能跳

运行：python _build/gen_screens.py
"""

from __future__ import annotations

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
TOK = json.load(open(os.path.join(ROOT, "01-tokens.json"), encoding="utf-8"))
ICONS = json.load(open(os.path.join(ROOT, "04-ICON-SYSTEM", "icons.json"), encoding="utf-8"))

# ═══════════════════════════════════════════════════════════════════ 令牌 → CSS 变量

VAR_MAP = [
    ("bg", "bg"), ("appBg", "app-bg"), ("surface", "surface"), ("surface2", "surface-2"),
    ("ink", "ink"), ("ink2", "ink-2"), ("muted", "muted"), ("faint", "faint"),
    ("line", "line"), ("lineSoft", "line-soft"),
    ("primary", "primary"), ("primaryDeep", "primary-deep"), ("primarySoft", "primary-soft"),
    ("primaryTint", "primary-tint"), ("onPrimary", "on-primary"),
    ("accent", "accent"), ("accentDeep", "accent-deep"), ("accentSoft", "accent-soft"),
    ("onAccent", "on-accent"),
    ("income", "income"), ("incomeSoft", "income-soft"), ("incomeLine", "income-line"),
    ("incomeInk", "income-ink"),
    ("okSoft", "ok-soft"), ("okInk", "ok-ink"), ("warnSoft", "warn-soft"), ("warnInk", "warn-ink"),
    ("dnBg", "dn-bg"), ("dnInk", "dn-ink"),
    ("primaryInk", "primary-ink"), ("accentInk", "accent-ink"),
    ("fabBg", "fab-bg"), ("fabFg", "fab-fg"), ("fabIc", "fab-ic"),
    ("toastBg", "toast-bg"), ("chartTrack", "chart-track"), ("barFill", "bar-fill"),
    ("dash", "dash"),
    ("shadow1", "shadow-1"), ("shadow2", "shadow-2"), ("shadow3", "shadow-3"),
    ("shadowAccent", "shadow-accent"), ("glowPrimary", "glow-primary"),
]
VAR_MAP_V3 = [
    ("lineStrong", "line-strong"), ("lineStrongSoft", "line-strong-soft"),
    ("focusRing", "focus-ring"), ("surfaceInset", "surface-inset"),
    ("disabledFg", "disabled-fg"), ("disabledBg", "disabled-bg"),
    ("overlay", "overlay"), ("skeleton", "skeleton"),
    ("primaryPressed", "primary-pressed"), ("accentPressed", "accent-pressed"),
]

CATS = TOK["invariants"]["category"]
CATREFS = [c["ref"] for c in CATS]


def theme_vars(theme: str, mode: str) -> str:
    combo = f"{theme}.{mode}"
    r = TOK["resolved"][combo]
    e = TOK["v3Additions"][combo]
    out = [f"  --{v}: {r[k]};" for k, v in VAR_MAP]
    out += [f"  --{v}: {e[k]};" for k, v in VAR_MAP_V3]
    out += [f"  --cat-{c['ref']}: {c['base']};" for c in CATS]
    inks = TOK["invariants"]["categoryInk"]["dark" if mode == "dark" else "light"]
    out += [f"  --cat-ink-{ref}: {inks[ref]};" for ref in CATREFS]
    return "\n".join(out)


# ═══════════════════════════════════════════════════════════════════ 图标 sprite

def sprite() -> str:
    """把 04-ICON-SYSTEM/svg/*.svg 内联成一份 <symbol> sprite。

    ⚠️⚠️ 必须把根节点的 fill="none" 搬到 <symbol> 上。
    SVG 的默认 fill 是 **black**，而源文件的 fill="none" 写在**根 <svg> 上**；
    只取内部内容的话这个属性就丢了 —— 结果是**每一枚含闭合路径的图标都被填成实心黑块**
    （盾牌、锁、碗、购物袋全都中招），只有纯开放路径的图标（如导航那几条线）侥幸正常，
    所以肉眼很容易漏掉。这个坑真的踩过一次：资产页的盾牌渲染成了实心黑。
    自检：下面每一枚都断言过源文件带 fill="none"，缺了就报错，不再静默出黑块。"""
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" style="display:none" aria-hidden="true">']
    for rec in ICONS["icons"]:
        raw = open(os.path.join(ROOT, "04-ICON-SYSTEM", rec["file"]), encoding="utf-8").read()
        head = raw.split(">", 1)[0]
        if 'fill="none"' not in head:
            raise SystemExit(
                f'图标 {rec["name"]} 的根 <svg> 缺 fill="none" —— '
                f'内联后会被默认 fill:black 填成实心黑块。'
            )
        inner = raw.split(">", 1)[1].rsplit("</svg>", 1)[0]
        # fill="none" 挂在 symbol 上；个别图标内部自带 fill="currentColor"
        # （如导航行首圆点、钱包扣）会局部覆盖，不受影响。
        parts.append(f'<symbol id="{rec["name"]}" viewBox="0 0 24 24" fill="none">{inner}</symbol>')
    parts.append("</svg>")
    return "".join(parts)


def ic(name: str, size: int = 20, cls: str = "") -> str:
    c = f' class="{cls}"' if cls else ""
    return (f'<svg{c} width="{size}" height="{size}" aria-hidden="true">'
            f'<use href="#{name}"/></svg>')


# ═══════════════════════════════════════════════════════════════════ 文案

ZH = dict(
    brand="素记 Plain",
    balance="本月结余", expense="支出", income_l="收入",
    guide_title="记账，三秒钟的事", guide_sub="本地存储 · 无广告 · 无理财",
    f1="三秒记一笔", f1s="只记数字，不填表格",
    f2="数据只在你手机里", f2s="没有账号，没有服务器",
    f3="十套配色，昼夜两态", f3s="冷底暖点，久看不累",
    cta="开始记账", save="保存", guide_foot="数据全部本地存储 · 卸载前请先备份",
    home_title="2026年9月", month_note="记账月起始：10 日",
    d1="9月28日 周日", d2="9月27日 周六", d3="9月26日 周五",
    r1="餐饮", r1s="午餐 · 公司楼下", r2="交通", r2s="地铁 · 通勤",
    r3="购物", r3s="日用品 · 超市", r4="人情", r4s="生日礼物",
    r5="通讯", r5s="话费充值",
    nav_ledger="流水", nav_report="报表", nav_add="记一笔", nav_assets="资产", nav_me="我的",
    add_title="记一笔", t_expense="支出", t_income="收入", t_transfer="转账",
    t_lend="借出", t_borrow="借入", editing="编辑",
    attr_account="账户", attr_date="日期", attr_note="备注",
    attr_account_v="招行储蓄卡", attr_date_v="今天", attr_note_v="添加备注", cat_more="更多",
    detail_title="账单详情", dv_amount="金额", dv_cat="分类", dv_account="账户",
    dv_date="日期", dv_note="备注", dv_source="来源",
    dv_source_v="手动录入", dv_note_v="公司楼下 · 工作日午餐",
    dv_date_v="2026年9月28日 12:34", edit="编辑", delete="删除这笔账单",
    detail_hint="删除后可在回收站恢复（保留 30 天）",
    rep_title="报表", rep_compare="与上月对比", rep_spend="支出", rep_income="收入",
    rep_net="结余", rep_share="分类占比", rep_trend="每日支出", rep_total="合计",
    rep_count="共 45 笔", vs_last="较上月",
    asset_title="资产", net_worth="净资产", asset_own="资产", asset_debt="负债",
    acc1="招行储蓄卡", acc1s="储蓄卡 ····6217", acc2="微信零钱", acc2s="现金",
    acc3="指数基金", acc3s="投资 · 3 只持仓", acc4="招行信用卡", acc4s="信用卡 · 本期应还",
    hide="隐藏金额",
    cat_title="分类管理", cat_expense="支出", cat_income="收入", cat_new="新建分类",
    n_food="三餐、外卖、堂食", n_fruit="买菜、生鲜、米面粮油", n_shopping="服饰、数码、家居",
    n_daily="洗护、纸品、清洁", n_transport="通勤、打车、加油", n_housing="房租、房贷、水电",
    n_telecom="话费、宽带、会员", n_entertainment="影视、游戏、演出", n_medical="门诊、药品、体检",
    n_study="书籍、课程、考试", n_social="红包、礼物、请客", n_other="未归类的支出",
    cnt="笔",
    me_title="我的", g_book="记账", g_security="安全", g_look="外观", g_data="数据", g_about="关于",
    s_month="月起始日", s_month_v="10 日", s_font="字体大小", s_font_v="标准",
    s_sound="记账确认音效", s_stay="保存后停留在记账页",
    s_lock="应用锁", s_hide="隐藏金额", s_theme="主题", s_theme_v="素白",
    s_mode="外观模式", s_mode_v="跟随系统", s_backup="备份与恢复", s_import="批量导入",
    s_privacy="隐私承诺", s_version="版本", s_version_v="V1.0.0",
    privacy_line="无广告、无外联、无埋点上报", entries="账单",
)

EN = dict(
    brand="Plain",
    balance="Balance this month", expense="Spent", income_l="Received",
    guide_title="Log it in three seconds.", guide_sub="Local only · No ads · No investing",
    f1="Three-second entry", f1s="Just the number, no forms",
    f2="Data stays on your phone", f2s="No account, no server",
    f3="Ten palettes, day and night", f3s="Cool base, warm accents",
    cta="Start tracking", save="Save", guide_foot="Stored locally · Back up before uninstalling",
    home_title="Sep 2026", month_note="Month starts on day 10",
    d1="Sun, Sep 28", d2="Sat, Sep 27", d3="Fri, Sep 26",
    r1="Dining", r1s="Lunch · Near the office", r2="Transport", r2s="Metro · Commute",
    r3="Shopping", r3s="Household · Supermarket", r4="Social", r4s="Birthday gift",
    r5="Telecom", r5s="Phone bill top-up",
    nav_ledger="Ledger", nav_report="Reports", nav_add="Add", nav_assets="Assets", nav_me="Me",
    add_title="Add expense", t_expense="Expense", t_income="Income", t_transfer="Transfer",
    t_lend="Lend", t_borrow="Borrow", editing="Edit",
    attr_account="Account", attr_date="Date", attr_note="Note",
    attr_account_v="CMB Savings", attr_date_v="Today", attr_note_v="Add note", cat_more="More",
    detail_title="Entry detail", dv_amount="Amount", dv_cat="Category", dv_account="Account",
    dv_date="Date", dv_note="Note", dv_source="Source",
    dv_source_v="Manual entry", dv_note_v="Near the office · Weekday lunch",
    dv_date_v="Sep 28, 2026 12:34", edit="Edit", delete="Delete this entry",
    detail_hint="Restorable from Trash (30 days)",
    rep_title="Reports", rep_compare="Compared with last month", rep_spend="Spent",
    rep_income="Received", rep_net="Net", rep_share="By category", rep_trend="Daily spending",
    rep_total="Total", rep_count="45 entries", vs_last="vs last month",
    asset_title="Assets", net_worth="Net worth", asset_own="Assets", asset_debt="Debts",
    acc1="CMB Savings", acc1s="Savings ····6217", acc2="WeChat Balance", acc2s="Cash",
    acc3="Index Funds", acc3s="Investing · 3 holdings", acc4="CMB Credit Card",
    acc4s="Credit · due this cycle", hide="Hide amounts",
    cat_title="Categories", cat_expense="Expense", cat_income="Income", cat_new="New category",
    n_food="Meals, takeout, dine-in", n_fruit="Groceries, fresh food, staples",
    n_shopping="Clothing, gadgets, home", n_daily="Personal care, paper goods",
    n_transport="Commute, taxi, fuel", n_housing="Rent, mortgage, utilities",
    n_telecom="Phone, broadband, plans", n_entertainment="Movies, games, shows",
    n_medical="Clinic, pharmacy, checkup", n_study="Books, courses, exams",
    n_social="Gifts, red packets, treats", n_other="Uncategorised spending",
    cnt="entries",
    me_title="Me", g_book="Tracking", g_security="Security", g_look="Appearance",
    g_data="Data", g_about="About",
    s_month="Month starts on", s_month_v="Day 10", s_font="Text size", s_font_v="Standard",
    s_sound="Confirmation sound", s_stay="Stay on entry page after saving",
    s_lock="App lock", s_hide="Hide amounts", s_theme="Theme", s_theme_v="Plain White",
    s_mode="Appearance", s_mode_v="Follow system", s_backup="Backup & restore",
    s_import="Bulk import", s_privacy="Privacy promise", s_version="Version",
    s_version_v="V1.0.0", privacy_line="No ads, no network, no tracking", entries="entries",
)

CAT_LABEL = {
    "zh": {c["ref"]: c["name"] for c in CATS},
    "en": {"food": "Dining", "fruit": "Groceries", "shopping": "Shopping", "daily": "Household",
           "transport": "Transport", "housing": "Housing", "telecom": "Telecom",
           "entertainment": "Fun", "medical": "Health", "study": "Learning",
           "social": "Social", "other": "Other"},
}
CAT_ICON = {c["ref"]: c["iconRef"] for c in CATS}
ICO = {"food": "ic_cat_food", "fruit": "ic_cat_grocery", "shopping": "ic_cat_shopping",
       "daily": "ic_cat_daily", "transport": "ic_cat_transport", "housing": "ic_cat_housing",
       "telecom": "ic_cat_telecom", "entertainment": "ic_cat_entertainment",
       "medical": "ic_cat_medical", "study": "ic_cat_study", "social": "ic_cat_social",
       "other": "ic_cat_other"}


def TXT(lang):
    return ZH if lang == "zh" else EN


# ═══════════════════════════════════════════════════════════════════ 组件片段

def amount(value, size_cls="xl", sign="", tone="ink"):
    neg = value.startswith("-")
    v = value.lstrip("-+")
    ints, dec = (v.split(".") + ["00"])[:2]
    pre = "−" if neg else sign
    return (f'<span class="amt {size_cls} tone-{tone}">'
            f'<span class="cur">¥</span>{pre}'
            f'<span class="int">{ints}</span><span class="pnt">.</span>'
            f'<span class="dec">{dec}</span></span>')


def row(dot_ref, title, sub, right, right_tone="ink", goto=None, chevron=False):
    tag = "a" if goto else "div"
    attrs = f' data-goto="{goto}"' if goto else ""
    dot = (f'<span class="dot6" style="background:var(--cat-{dot_ref})"></span>'
           if dot_ref else '<span class="dot6 dot6-none"></span>')
    ch = ic("ic_chevron_right", 16, "chev") if chevron else ""
    subhtml = f'<span class="sub">{sub}</span>' if sub else ""
    return (f'<{tag} class="row"{attrs}>{dot}'
            f'<span class="rcol"><span class="rt">{title}</span>{subhtml}</span>'
            f'<span class="rw-amt tone-{right_tone}">{right}</span>{ch}</{tag}>')


def group(title, body):
    head = f'<div class="eyebrow">{title}</div>' if title else ""
    return f'<section class="grp">{head}<div class="panel">{body}</div></section>'


def nav(lang, active):
    t = TXT(lang)
    out = []
    for key, icon, label in [("ledger", "ic_nav_ledger", t["nav_ledger"]),
                             ("reports", "ic_nav_report", t["nav_report"])]:
        on = " on" if key == active else ""
        out.append(f'<a class="navitem{on}" data-goto="{key}">{ic(icon, 22)}'
                   f'<span class="navlab">{label}</span></a>')
    out.append('<a class="navitem navcenter" data-goto="add">'
               f'<span class="navfab">{ic("ic_nav_add", 22)}</span></a>')
    for key, icon, label in [("assets", "ic_nav_assets", t["nav_assets"]),
                             # ⚠️ 曾写成 ic_nav_me —— icons.json 里没有这个名字
                             #    （正确名是 ic_nav_profile），于是底部导航「我的」的
                             #    <use href="#ic_nav_me"> 匹配不到 symbol，图标位置
                             #    一直是一块空白，而不会报任何错。
                             ("settings", "ic_nav_profile", t["nav_me"])]:
        on = " on" if key == active else ""
        out.append(f'<a class="navitem{on}" data-goto="{key}">{ic(icon, 22)}'
                   f'<span class="navlab">{label}</span></a>')
    return f'<nav class="nav">{"".join(out)}</nav>'


def topbar(title, left_icon="ic_back", right="", left_goto="", h1_class=""):
    lg = f' data-goto="{left_goto}"' if left_goto else " data-back"
    return (f'<header class="topbar"><button class="iconbtn"{lg}>{ic(left_icon, 22)}</button>'
            f'<h1 class="{h1_class}">{title}</h1><div class="tb-right">{right}</div></header>')


def statusbar():
    bars = "".join(f'<rect x="{i*5}" y="{9-v}" width="3" height="{v}" rx="1" fill="currentColor"/>'
                   for i, v in enumerate([4, 6, 9, 12]))
    return ('<div class="statusbar"><span class="sb-time">14:55</span>'
            f'<span class="sb-marks"><svg width="18" height="12" aria-hidden="true">{bars}</svg>'
            '<svg width="18" height="12" aria-hidden="true">'
            '<rect x="0.5" y="1.5" width="14" height="9" rx="3" fill="none" stroke="currentColor" opacity=".45"/>'
            '<rect x="2.5" y="3.5" width="9" height="5" rx="1.5" fill="currentColor"/></svg>'
            '</span></div>')


def switch(on):
    return f'<span class="switch{" on" if on else ""}"><span class="knob"></span></span>'


# ═══════════════════════════════════════════════════════════════════ 8 屏

def screen_guide(lang):
    t = TXT(lang)
    feats = [("ic_nav_add", t["f1"], t["f1s"]), ("ic_lock", t["f2"], t["f2s"]),
             ("ic_palette", t["f3"], t["f3s"])]
    rows = "".join(f'<div class="feat">{ic(i, 22)}<span class="fcol"><span class="ft">{a}</span>'
                   f'<span class="fs">{b}</span></span></div>' for i, a, b in feats)
    return f'''<div class="screen page-guide">{statusbar()}
<div class="guide-top"><span class="wordmark">{t["brand"]}</span></div>
<h2 class="guide-h">{t["guide_title"]}</h2>
<p class="guide-p">{t["guide_sub"]}</p>
<div class="guide-hero">
  <div class="hairline"></div>
  <div class="hero-label">{t["balance"]}</div>
  <div class="hero-amt">{amount("12,480.00", "xl")}</div>
  <div class="hairline"></div>
</div>
<div class="featlist">{rows}</div>
<div class="guide-foot">
  <button class="btn primary" data-goto="ledger">{t["cta"]}</button>
  <p class="foot-note">{t["guide_foot"]}</p>
</div></div>'''


def screen_home(lang):
    t = TXT(lang)
    return f'''<div class="screen">{statusbar()}
<header class="topbar">
  <button class="iconbtn" data-goto="reports">{ic("ic_calendar", 20)}</button>
  <h1>{t["home_title"]}</h1>
  <div class="tb-right">
    <button class="iconbtn">{ic("ic_search", 20)}</button>
    <button class="iconbtn">{ic("ic_more", 20)}</button>
  </div>
</header>
<div class="scroll">
  <section class="hero">
    <div class="hairline"></div>
    <div class="hero-label">{t["balance"]}</div>
    <div class="hero-amt">{amount("3,420.50", "xl")}</div>
    <div class="hero-split">
      <div class="hs"><span class="hs-l">{t["expense"]}</span>
        <span class="hs-v">{amount("5,879.50", "s")}</span></div>
      <div class="hs"><span class="hs-l">{t["income_l"]}</span>
        <span class="hs-v">{amount("9,300.00", "s", sign="+", tone="income")}</span></div>
    </div>
    <div class="hairline"></div>
    <div class="month-note">{ic("ic_calendar", 13)}<span>{t["month_note"]}</span></div>
  </section>
  {group(t["d1"], row("food", t["r1"], t["r1s"], "32.00", goto="detail")
         + row("transport", t["r2"], t["r2s"], "4.00", goto="detail"))}
  {group(t["d2"], row("shopping", t["r3"], t["r3s"], "128.60", goto="detail")
         + row("social", t["r4"], t["r4s"], "300.00", goto="detail"))}
  {group(t["d3"], row("telecom", t["r5"], t["r5s"], "50.00", goto="detail"))}
  <div class="scroll-pad"></div>
</div>
{nav(lang, "ledger")}
</div>'''


def screen_add(lang):
    t = TXT(lang)
    tabs = "".join(f'<button class="ttab{" on" if on else ""}">{t[k]}</button>'
                   for k, on in [("t_expense", True), ("t_income", False), ("t_transfer", False),
                                 ("t_lend", False), ("t_borrow", False)])
    # 12 个一级分类全部平铺 = 3 行 × 4 列，正好填满，不留空格子。
    # 用分类图标（cat-ink 色）而不是圆点 —— 选择器是图标唯一真正该出场的地方：
    # 圆点适合「已记完的流水行」（安静、次要），选择器需要可扫读的图形。
    order = ["food", "fruit", "transport", "shopping", "daily", "housing", "telecom",
             "entertainment", "medical", "study", "social", "other"]
    tiles = "".join(
        f'<button class="tile{" on" if ref == "food" else ""}">'
        f'<span style="color:var(--cat-ink-{ref});display:flex">{ic(ICO[ref], 23)}</span>'
        f'<span class="tile-n">{CAT_LABEL[lang][ref]}</span></button>' for ref in order)

    keys = []
    for k in ["1", "2", "3"]:
        keys.append(f'<button class="key">{k}</button>')
    keys.append(f'<button class="key op">{ic("ic_back", 22)}</button>')
    for k in ["4", "5", "6"]:
        keys.append(f'<button class="key">{k}</button>')
    keys.append(f'<button class="key op">{ic("ic_close", 19)}</button>')
    for k in ["7", "8", "9"]:
        keys.append(f'<button class="key">{k}</button>')
    keys.append('<span class="key blank"></span>')
    keys.append('<button class="key">.</button>')
    keys.append('<button class="key">0</button>')
    keys.append(f'<button class="key ok">{t["save"]}</button>')

    return f'''<div class="screen">{statusbar()}
{topbar(t["add_title"], left_icon="ic_close")}
<div class="ttabs">{tabs}</div>
<div class="amount-block">
  <div class="expr">25<span class="caret"></span></div>
  <div class="amt-line">{amount("25.00", "input")}</div>
</div>
<div class="addbody">
  <div class="catgrid">{tiles}</div>
  <div class="attrchips">
    <button class="chip">{ic("ic_account", 16)}{t["attr_account_v"]}</button>
    <button class="chip">{ic("ic_calendar", 16)}{t["attr_date_v"]}</button>
    <button class="chip ph">{ic("ic_note", 16)}{t["attr_note_v"]}</button>
  </div>
</div>
<div class="keypad">{"".join(keys)}</div>
<div class="safearea"></div>
</div>'''


def screen_detail(lang):
    t = TXT(lang)
    rows = "".join([
        f'<div class="drow"><span class="dk">{t["dv_cat"]}</span>'
        f'<span class="dv"><span class="dot6" style="background:var(--cat-food)"></span>'
        f'{CAT_LABEL[lang]["food"]}</span></div>',
        f'<div class="drow"><span class="dk">{t["dv_account"]}</span>'
        f'<span class="dv">{t["attr_account_v"]}</span></div>',
        f'<div class="drow"><span class="dk">{t["dv_date"]}</span>'
        f'<span class="dv">{t["dv_date_v"]}</span></div>',
        f'<div class="drow"><span class="dk">{t["dv_note"]}</span>'
        f'<span class="dv note">{t["dv_note_v"]}</span></div>',
        f'<div class="drow"><span class="dk">{t["dv_source"]}</span>'
        f'<span class="dv">{t["dv_source_v"]}</span></div>',
    ])
    return f'''<div class="screen">{statusbar()}
{topbar(t["detail_title"], right=f'<button class="textbtn">{t["edit"]}</button>')}
<div class="scroll">
  <section class="detail-hero">
    <div class="hero-label">{t["dv_amount"]}</div>
    <div class="hero-amt">{amount("32.00", "xl")}</div>
    <div class="dh-meta"><span class="dot6" style="background:var(--cat-food)"></span>
      <span>{CAT_LABEL[lang]["food"]}</span><span class="sep">·</span>
      <span>{t["attr_account_v"]}</span></div>
  </section>
  <div class="panel detail-panel">{rows}</div>
  <div class="danger-zone">
    <button class="btn2 danger">{ic("ic_delete", 18)}<span>{t["delete"]}</span></button>
    <p class="foot-note">{t["detail_hint"]}</p>
  </div>
</div></div>'''


DONUT = [("food", 32.0), ("shopping", 24.0), ("other", 18.0), ("transport", 14.0),
         ("housing", 12.0)]
LEGEND = [("food", 32.0, "1,881.44"), ("shopping", 24.0, "1,411.08"),
          ("other", 18.0, "1,058.31"), ("transport", 14.0, "823.13"),
          ("housing", 12.0, "705.54")]
BARS = [0.42, 0.30, 0.61, 0.24, 0.55, 0.78, 0.36, 0.20, 0.48, 0.66, 0.29, 0.90,
        0.52, 0.34]


def donut_amount(v, avail=87.0):
    """环形图中心金额：四段式 + 「放不下就降档」。

    内孔 91px（r=52 / stroke=13 / 画布 136），左右各留 2px → 可用 **87.0**。
    数字按 tnum 宽度 594/1000 计；实测阈值表见 _probe_donut.py。
      18px <= ¥86,420.50      (83.70)
      16px <= ¥999,999.99     (83.90)
      14px <= ¥9,999,999.99   (85.80)
      12px <= ¥99,999,999.99  (80.60，金额上限 Money.maxCents)
    再长就只能缩写 —— 见《10-CHANGELOG》待拍板 T-9。
    """
    TAB, CUR, COM, PNT = 0.594, 0.610, 0.288, 0.277
    ints, dec = (v.split(".") + [""])[:2]

    def w(size):
        small = size * 0.62
        x = CUR * small
        x += sum(1 for c in ints if c.isdigit()) * TAB * size
        x += ints.count(",") * COM * size
        if dec:
            x += PNT * size + len(dec) * TAB * small
        return x

    size = next((s for s in (18, 16, 14, 12) if w(s) <= avail), 12)
    return (f'<tspan class="dn-cur">¥</tspan>{ints}'
            f'<tspan class="dn-pnt">.</tspan>'
            f'<tspan class="dn-dec">{dec}</tspan>', size)


def donut_svg():
    R, C, SW = 52.0, 68.0, 13.0   # 内孔 = (52 - 13/2) * 2 = 91px
    circ = 2 * 3.141592653589793 * R
    off, segs = 0.0, []
    for ref, pct in DONUT:
        segs.append(f'<circle class="dn-seg" cx="{C}" cy="{C}" r="{R}" '
                    f'style="stroke:var(--cat-{ref});stroke-dasharray:{circ*pct/100:.2f} '
                    f'{circ:.2f};stroke-dashoffset:{-off:.2f}"/>')
        off += circ * pct / 100
    inner, cs = donut_amount("5,879.50")
    return (f'<svg class="donut" width="136" height="136" viewBox="0 0 136 136">'
            f'<g fill="none" stroke-width="{SW:.0f}" stroke-linecap="butt">'
            f'{"".join(segs)}</g>'
            f'<text class="dn-c1" x="{C}" y="{C-4}" text-anchor="middle" '
            f'style="font-size:{cs}px">{inner}</text>'
            f'<text class="dn-c2" x="{C}" y="{C+16}" text-anchor="middle">TOTAL</text>'
            f'</svg>')


def bars_svg():
    w, gap = 14, 6
    total = len(BARS) * w + (len(BARS) - 1) * gap
    out = []
    for i, h in enumerate(BARS):
        x = i * (w + gap)
        bh = 8 + h * 52
        out.append(f'<rect x="{x}" y="{66-bh:.1f}" width="{w}" height="{bh:.1f}" rx="3" '
                   f'style="fill:var(--bar-fill);opacity:{0.35 + h*0.65:.2f}"/>')
    return (f'<svg class="bars" viewBox="0 0 {total} 72" preserveAspectRatio="none" '
            f'width="100%" height="72"><line x1="0" y1="66.5" x2="{total}" y2="66.5" '
            f'style="stroke:var(--line)"/>{"".join(out)}</svg>')


def screen_reports(lang):
    t = TXT(lang)
    legend = "".join(
        f'<div class="lrow"><span class="dot8" style="background:var(--cat-{ref})"></span>'
        f'<span class="lname">{CAT_LABEL[lang][ref]}</span>'
        f'<span class="lpct">{pct:.0f}%</span>'
        f'<span class="lamt">{amount(amt, "s")}</span></div>' for ref, pct, amt in LEGEND)
    # 涨跌色一律走「涨红跌绿」，与行标签语义无关 —— 方向由箭头图标承担。
    # 支出↗ / 收入↗ 都取红，结余↘ 取绿。三行统一，避免同一屏出现两套色彩逻辑。
    cmp_rows = "".join([
        f'<div class="crow"><span class="ck">{t["rep_spend"]}</span>'
        f'<span class="cv">{amount("5,879.50", "s")}</span>'
        f'<span class="cd tone-up">{ic("ic_trend_up", 14)}12.4%</span></div>',
        f'<div class="crow"><span class="ck">{t["rep_income"]}</span>'
        f'<span class="cv tone-income">{amount("9,300.00", "s", sign="+", tone="income")}</span>'
        f'<span class="cd tone-up">{ic("ic_trend_up", 14)}8.1%</span></div>',
        f'<div class="crow"><span class="ck">{t["rep_net"]}</span>'
        f'<span class="cv">{amount("3,420.50", "s")}</span>'
        f'<span class="cd tone-dn">{ic("ic_trend_down", 14)}6.2%</span></div>',
    ])
    return f'''<div class="screen">{statusbar()}
<header class="topbar">
  <button class="iconbtn" data-goto="ledger">{ic("ic_calendar", 20)}</button>
  <h1>{t["rep_title"]}</h1>
  <div class="tb-right">
    <button class="iconbtn">{ic("ic_filter", 20)}</button>
    <button class="iconbtn">{ic("ic_more", 20)}</button>
  </div>
</header>
<div class="scroll">
  <div class="month-note tight">{ic("ic_calendar", 13)}<span>{t["month_note"]}</span>
    <span class="dot-sep">·</span><span>{t["rep_count"]}</span></div>
  <div class="panel cmppanel">
    <div class="eyebrow">{t["rep_compare"]}</div>
    {cmp_rows}
  </div>
  <div class="panel chartpanel">
    <div class="eyebrow">{t["rep_share"]}</div>
    <div class="donut-wrap">{donut_svg()}</div>
    <div class="legend">{legend}</div>
  </div>
  <div class="panel chartpanel">
    <div class="eyebrow">{t["rep_trend"]}</div>
    {bars_svg()}
  </div>
  <div class="scroll-pad"></div>
</div>
{nav(lang, "reports")}
</div>'''


def screen_assets(lang):
    t = TXT(lang)
    def acc(icon, name, sub, money, tone="ink"):
        return (f'<div class="row"><span class="ricos">{ic(icon, 22)}</span>'
                f'<span class="rcol"><span class="rt">{name}</span>'
                f'<span class="sub">{sub}</span></span>'
                f'<span class="rw-amt tone-{tone}">{money}</span>'
                f'{ic("ic_chevron_right", 16, "chev")}</div>')
    return f'''<div class="screen">{statusbar()}
<header class="topbar">
  <button class="iconbtn ghost">{ic("ic_shield", 20)}</button>
  <h1>{t["asset_title"]}</h1>
  <div class="tb-right"><button class="iconbtn">{ic("ic_eye_off", 20)}</button></div>
</header>
<div class="scroll">
  <section class="hero">
    <div class="hairline"></div>
    <div class="hero-label">{t["net_worth"]}</div>
    <div class="hero-amt">{amount("86,420.50", "xl")}</div>
    <div class="hairline"></div>
  </section>
  {group(t["asset_own"],
         acc("ic_card", t["acc1"], t["acc1s"], amount("52,180.30", "s"))
         + acc("ic_wallet", t["acc2"], t["acc2s"], amount("1,240.20", "s"))
         + acc("ic_chart_line", t["acc3"], t["acc3s"], amount("38,000.00", "s")))}
  {group(t["asset_debt"],
         acc("ic_receipt", t["acc4"], t["acc4s"], amount("-5,000.00", "s")))}
  <div class="scroll-pad"></div>
</div>
{nav(lang, "assets")}
</div>'''


def screen_categories(lang):
    t = TXT(lang)
    note_key = {"food": "n_food", "fruit": "n_fruit", "shopping": "n_shopping",
                "daily": "n_daily", "transport": "n_transport", "housing": "n_housing",
                "telecom": "n_telecom", "entertainment": "n_entertainment",
                "medical": "n_medical", "study": "n_study", "social": "n_social",
                "other": "n_other"}
    counts = {"food": 128, "fruit": 46, "shopping": 33, "daily": 61, "transport": 88,
              "housing": 6, "telecom": 4, "entertainment": 12, "medical": 3,
              "study": 7, "social": 9, "other": 2}
    body = "".join(
        f'<div class="crow2"><span class="cicon" style="color:var(--cat-ink-{ref})">'
        f'{ic(ICO[ref], 24)}</span>'
        f'<span class="rcol"><span class="rt">{CAT_LABEL[lang][ref]}</span>'
        f'<span class="sub">{t[note_key[ref]]}</span></span>'
        f'<span class="cnt">{counts[ref]} {t["cnt"]}</span>'
        f'{ic("ic_drag_handle", 18, "drag")}</div>' for ref in CATREFS)
    return f'''<div class="screen">{statusbar()}
<header class="topbar">
  <button class="iconbtn" data-back>{ic("ic_back", 22)}</button>
  <h1>{t["cat_title"]}</h1>
  <div class="tb-right"><button class="iconbtn">{ic("ic_plus", 20)}</button></div>
</header>
<div class="segwrap"><div class="seg">
  <button class="segi on">{t["cat_expense"]}</button>
  <button class="segi">{t["cat_income"]}</button>
</div></div>
<div class="scroll"><div class="panel catpanel">{body}</div>
  <div class="scroll-pad"></div></div>
<div class="footbar"><button class="btn2 wide">{ic("ic_plus", 18)}<span>{t["cat_new"]}</span></button>
<div class="safearea"></div></div>
</div>'''


def screen_settings(lang):
    t = TXT(lang)
    def srow(label, value=None, sw=None, chev=True, icon=None):
        left = ic(icon, 20, "sicon") if icon else ""
        mid = (f'<span class="rcol"><span class="rt">{label}</span></span>')
        right = ""
        if sw is not None:
            right = switch(sw)
        elif value:
            right = f'<span class="sval">{value}</span>'
            if chev:
                right += ic("ic_chevron_right", 16, "chev")
        elif chev:
            right = ic("ic_chevron_right", 16, "chev")
        return f'<div class="row srow">{left}{mid}{right}</div>'

    return f'''<div class="screen">{statusbar()}
<header class="topbar"><button class="iconbtn ghost">{ic("ic_nav_profile", 20)}</button>
  <h1>{t["me_title"]}</h1><div class="tb-right"></div></header>
<div class="scroll">
  <div class="privacy-strip">{ic("ic_shield", 18)}
    <span class="pcol"><span class="pt">{t["s_privacy"]}</span>
    <span class="ps">{t["privacy_line"]}</span></span></div>
  {group(t["g_book"],
         srow(t["s_month"], t["s_month_v"])
         + srow(t["s_font"], t["s_font_v"])
         + srow(t["s_sound"], sw=False)
         + srow(t["s_stay"], sw=True))}
  {group(t["g_security"],
         srow(t["s_lock"], sw=False) + srow(t["s_hide"], sw=False))}
  {group(t["g_look"],
         srow(t["s_theme"], t["s_theme_v"]) + srow(t["s_mode"], t["s_mode_v"]))}
  {group(t["g_data"],
         srow(t["s_backup"], icon="ic_cloud") + srow(t["s_import"], icon="ic_import"))}
  {group(t["g_about"],
         srow(t["s_privacy"], icon="ic_shield")
         + srow(t["s_version"], t["s_version_v"]))}
  <div class="scroll-pad"></div>
</div>
{nav(lang, "settings")}
</div>'''


SCREENS = [
    ("guide", "引导", "Onboarding", screen_guide),
    ("ledger", "首页流水", "Home", screen_home),
    ("add", "记一笔", "Add", screen_add),
    ("detail", "账单详情", "Detail", screen_detail),
    ("reports", "报表", "Reports", screen_reports),
    ("assets", "资产", "Assets", screen_assets),
    ("categories", "分类管理", "Categories", screen_categories),
    ("settings", "我的/设置", "Me", screen_settings),
]

# ═══════════════════════════════════════════════════════════════════ CSS

CSS = r"""
/* ── 字体：交付自带优先（12-FONTS/），仓库路径兜底 ──
   本机与仓库均无 Inter；MiSans 是仓库内唯一真实存在、免费可商用、且带 tnum 的字体。
   双 src 列表：第一个 404 时浏览器自动降级到第二个（已实测 Chrome 行为）。        */
@font-face{font-family:"MiSans";font-style:normal;font-weight:400;font-display:swap;
  src:url("12-FONTS/MiSans-Regular.ttf") format("truetype"),
      url("../plain/assets/fonts/misans/MiSans-Regular.ttf") format("truetype")}
@font-face{font-family:"MiSans";font-style:normal;font-weight:500;font-display:swap;
  src:url("12-FONTS/MiSans-Medium.ttf") format("truetype"),
      url("../plain/assets/fonts/misans/MiSans-Medium.ttf") format("truetype")}
@font-face{font-family:"MiSans";font-style:normal;font-weight:600;font-display:swap;
  src:url("12-FONTS/MiSans-Semibold.ttf") format("truetype"),
      url("../plain/assets/fonts/misans/MiSans-Semibold.ttf") format("truetype")}
@font-face{font-family:"MiSans";font-style:normal;font-weight:700;font-display:swap;
  src:url("12-FONTS/MiSans-Bold.ttf") format("truetype"),
      url("../plain/assets/fonts/misans/MiSans-Bold.ttf") format("truetype")}

*{box-sizing:border-box;margin:0;padding:0;-webkit-font-smoothing:antialiased}
html,body{background:#E9E9EC;color:#121214;
  font-family:"MiSans",Inter,"Segoe UI",system-ui,-apple-system,"HarmonyOS Sans SC","PingFang SC","Microsoft YaHei",sans-serif;
  /* 账本类应用：全站数字走等宽数字。tnum 只作用于 0-9 与相关标点，不影响中文。
     MiSans 的 tnum 已实测存在（GSUB: pnum + tnum，开后数字统一 594/1000）。 */
  font-variant-numeric:tabular-nums;font-feature-settings:"tnum" 1}
body{padding:0 0 72px}
button{font:inherit;color:inherit;background:none;border:0;cursor:pointer}
a{text-decoration:none;color:inherit;cursor:pointer}
svg{display:block}

/* ── 顶部工具条（不参与设计系统，纯脚手架） ── */
.toolbar{position:sticky;top:0;z-index:50;display:flex;flex-wrap:wrap;gap:18px;align-items:center;
  padding:14px 22px;background:#FFFFFF;border-bottom:1px solid #D8D8DE;box-shadow:0 1px 3px rgba(0,0,0,.05)}
.tb-brand{font-weight:700;font-size:15px;letter-spacing:.01em}
.tb-brand small{font-weight:500;color:#5E5E65;margin-left:8px;font-size:12px}
.tb-group{display:flex;align-items:center;gap:6px}
.tb-lab{font-size:11px;font-weight:600;letter-spacing:.06em;text-transform:uppercase;color:#7A7A82}
.seg2{display:inline-flex;background:#F0F0F3;border-radius:9px;padding:2px}
.seg2 button{padding:5px 11px;border-radius:7px;font-size:12.5px;font-weight:600;color:#5E5E65}
.seg2 button.on{background:#FFFFFF;color:#121214;box-shadow:0 1px 2px rgba(0,0,0,.10)}
.screenpicker{display:flex;flex-wrap:wrap;gap:6px}
.screenpicker button{padding:5px 10px;border-radius:7px;font-size:12.5px;font-weight:600;
  background:#F0F0F3;color:#5E5E65}
.screenpicker button.on{background:#121214;color:#fff}

/* ── 舞台 ── */
.stage{display:flex;flex-wrap:wrap;gap:34px;justify-content:center;padding:34px 22px;
  --tscale:1}
body[data-view="single"] .frame:not(.active){display:none}
body[data-view="single"] .stage{justify-content:center}

/* ── 手机壳 ── */
.frame{position:relative;width:390px;height:844px;flex:0 0 auto}
.frame .bezel{position:absolute;inset:0;border-radius:46px;background:var(--surface);
  border:1px solid var(--line);box-shadow:0 18px 44px var(--shadow-3);overflow:hidden}
.frame .flabel{position:absolute;top:-24px;left:2px;font-size:11.5px;font-weight:700;
  letter-spacing:.05em;color:#5E5E65;text-transform:uppercase}
.screen{position:absolute;inset:0;display:flex;flex-direction:column;overflow:hidden;
  background:var(--app-bg);color:var(--ink)}

/* ── 状态栏 ── */
.statusbar{height:47px;flex:0 0 47px;display:flex;align-items:flex-end;justify-content:space-between;
  padding:0 22px 6px;color:var(--ink);font-size:14.5px;font-weight:600;letter-spacing:.01em}
.sb-marks{display:flex;gap:6px;align-items:center;color:var(--ink)}

/* ── 顶栏 ── */
.topbar{height:56px;flex:0 0 56px;display:flex;align-items:center;gap:4px;padding:0 8px;
  background:var(--app-bg)}
.topbar h1{flex:1;text-align:center;font-size:calc(20px * var(--tscale));font-weight:600;
  letter-spacing:0;color:var(--ink);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;
  padding:0 4px}
.tb-right{display:flex;align-items:center;gap:2px;min-width:40px;justify-content:flex-end}
.iconbtn{width:44px;height:44px;border-radius:12px;display:flex;align-items:center;justify-content:center;
  color:var(--ink-2);flex:0 0 auto;background:none}
.iconbtn:active{background:var(--surface-inset);transform:scale(.93)}
.iconbtn.ghost{color:var(--ink-2)}
.textbtn{height:34px;padding:0 10px;border-radius:12px;font-size:calc(15px * var(--tscale));
  font-weight:500;color:var(--primary-ink);display:flex;align-items:center}
.textbtn:active{background:var(--primary-tint)}

/* ── 滚动区 ── */
.scroll{flex:1;overflow-y:auto;overflow-x:hidden;padding:0 16px}
.scroll::-webkit-scrollbar{width:0}
.scroll-pad{height:24px}
.hairline{height:1px;background:var(--line);margin:0}
.eyebrow{font-size:calc(12px * var(--tscale));font-weight:600;letter-spacing:.08em;
  text-transform:uppercase;color:var(--muted);margin:0 0 8px 2px}

/* ── 金额（四段式） ── */
.amt{display:inline-flex;align-items:baseline;font-variant-numeric:tabular-nums;
  font-feature-settings:"tnum" 1;letter-spacing:-.02em;color:var(--ink)}
.amt .cur{font-size:.62em;color:var(--muted);margin-right:.06em;font-weight:600}
.amt .pnt,.amt .int{font-size:1em}
.amt .dec{font-size:.62em;color:var(--muted);font-weight:600}
.amt.xl{font-size:calc(34px * var(--tscale));font-weight:700;line-height:1.16}
.amt.l{font-size:calc(22px * var(--tscale));font-weight:600;line-height:1.24}
.amt.s{font-size:calc(15px * var(--tscale));font-weight:600;line-height:1.34;letter-spacing:-.01em}
.amt.input{font-size:calc(44px * var(--tscale));font-weight:600;line-height:1.12;letter-spacing:-.03em}
.amt.s .dec{font-size:1em;color:inherit}
.tone-income{color:var(--income)}
.tone-income .int,.tone-income .pnt{color:var(--income)}
.tone-income .cur,.tone-income .dec{color:var(--income);opacity:.7}
/* 涨红跌绿：中国股市/记账惯例，涨=红、跌=绿。方向另由箭头图标承担。 */
.tone-up{color:var(--income-ink)}
.tone-dn{color:var(--dn-ink)}
.tone-muted{color:var(--muted)}

/* ── Hero 区（无卡片、无渐变、无光晕） ── */
.hero{padding:14px 0 0}
.hero .hairline{margin:0}
.hero-label{font-size:calc(12px * var(--tscale));font-weight:600;letter-spacing:.08em;
  text-transform:uppercase;color:var(--muted);margin:16px 0 8px 2px}
.hero-amt{font-size:calc(34px * var(--tscale));margin:0 0 16px 0}
.hero-split{display:flex;gap:28px;padding:0 0 16px}
.hs{display:flex;flex-direction:column;gap:3px}
.hs-l{font-size:calc(12px * var(--tscale));font-weight:600;letter-spacing:.04em;color:var(--muted)}
.month-note{display:flex;align-items:center;gap:6px;padding:12px 0 0 2px;
  font-size:calc(12px * var(--tscale));font-weight:500;color:var(--muted)}
.month-note.tight{padding:14px 2px 12px}
.month-note svg{color:var(--faint)}
.dot-sep{color:var(--faint);margin:0 2px}

/* ── 分组面板 ── */
.grp{margin-top:32px}
.panel{border-radius:16px;background:var(--surface);border:1px solid var(--line);overflow:hidden}

/* ── 列表行 ── */
.row{display:flex;align-items:center;gap:10px;min-height:60px;padding:9px 16px;color:inherit}
.row + .row{border-top:1px solid var(--line-soft);margin-top:0}
.row:active{background:var(--surface-inset)}
/* ⚠️ 这里必须是独立类，不能写成 `.row .rcol`。
   早先写成 `.row .rcol` 时，分类管理页（用 .crow2 而不是 .row）拿不到
   flex-direction:column，结果「餐饮」和它的别名挤成一行
   「餐饮三餐、外卖、堂食」——看起来像忘了加分隔符，其实是作用域没命中。 */
.rcol{flex:1;display:flex;flex-direction:column;align-items:flex-start;gap:2px;min-width:0}
.rcol .rt{font-size:calc(15px * var(--tscale));font-weight:500;color:var(--ink);
  white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:100%}
.rcol .sub{font-size:calc(12px * var(--tscale));font-weight:500;color:var(--muted);
  white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:100%}
.rw-amt{font-variant-numeric:tabular-nums;font-size:calc(15px * var(--tscale));font-weight:600;
  letter-spacing:-.01em;flex:0 0 auto}
.dot6{width:6px;height:6px;border-radius:50%;flex:0 0 6px}
.dot6-none{background:transparent}
.dot8{width:8px;height:8px;border-radius:50%;flex:0 0 8px}
.chev{color:var(--faint);flex:0 0 auto}
.ricos{width:26px;height:22px;display:flex;align-items:center;color:var(--ink-2);flex:0 0 auto}
.sicon{color:var(--ink-2);flex:0 0 auto;width:20px}
.srow .rcol{margin-left:2px}
.sval{font-size:calc(14px * var(--tscale));font-weight:500;color:var(--muted);margin-right:2px}
.crow2{display:flex;align-items:center;gap:12px;min-height:72px;padding:12px 16px}
.crow2 + .crow2{border-top:1px solid var(--line-soft)}
.cicon{flex:0 0 24px;display:flex;align-items:center;justify-content:center}
.cnt{font-size:calc(12px * var(--tscale));font-weight:500;color:var(--muted);flex:0 0 auto}
.drag{color:var(--faint);flex:0 0 auto}

/* ── 底部导航 ── */
.nav{height:60px;flex:0 0 60px;display:flex;border-top:1px solid var(--line);background:var(--app-bg);
  padding-bottom:env(safe-area-inset-bottom)}
.navitem{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;
  color:var(--muted)}
.navitem.on{color:var(--primary-ink)}
.navitem:active svg{transform:scale(.93)}
.navlab{font-size:calc(12px * var(--tscale));font-weight:500;white-space:nowrap}
.navcenter{justify-content:center}
.navfab{width:44px;height:44px;border-radius:14px;background:var(--accent);color:var(--fab-ic);
  display:flex;align-items:center;justify-content:center;box-shadow:0 2px 8px var(--shadow-accent)}
.navcenter:active .navfab{background:var(--accent-pressed);transform:scale(.94)}

/* ── 按钮 ── */
.btn{height:52px;border-radius:12px;display:flex;align-items:center;justify-content:center;gap:8px;
  font-size:calc(15px * var(--tscale));font-weight:600;padding:0 20px;min-width:88px}
.btn.primary{background:var(--primary);color:var(--on-primary);box-shadow:0 1px 2px var(--shadow-1)}
.btn.primary:active{background:var(--primary-pressed);transform:scale(.97)}
.btn2{height:44px;border-radius:12px;display:flex;align-items:center;justify-content:center;gap:8px;
  font-size:calc(15px * var(--tscale));font-weight:500;padding:0 16px;
  border:1px solid var(--line-strong);color:var(--ink);background:none}
.btn2:active{background:var(--surface-inset);transform:scale(.97)}
/* 危险按钮：整颗走危险色，不能只是图标红、文字黑。
   删除是不可逆操作，按钮本身必须读起来「危险」。 */
.btn2.danger{border-color:var(--income-line);color:var(--income-ink)}
.btn2.danger svg{color:var(--income-ink)}
.btn2.wide{width:100%}
.foot-note{font-size:calc(12px * var(--tscale));color:var(--muted);text-align:center;line-height:1.5}

/* ── 引导页 ── */
.page-guide{padding:0 24px;background:var(--app-bg)}
.guide-top{padding:22px 0 0}
.wordmark{font-size:calc(15px * var(--tscale));font-weight:700;letter-spacing:.06em;color:var(--ink)}
.guide-hero{margin:26px 0 0}
.guide-hero .hairline{margin:0}
.guide-hero .hero-amt{margin:18px 0 18px}
.guide-h{font-size:calc(20px * var(--tscale));font-weight:600;line-height:1.4;margin:30px 0 8px 2px;
  color:var(--ink)}
.guide-p{font-size:calc(14px * var(--tscale));line-height:1.65;color:var(--muted);margin:0 0 4px 2px}
.featlist{margin:28px 0 0}
.feat{display:flex;gap:14px;align-items:flex-start;padding:14px 0;border-top:1px solid var(--line-soft)}
.feat svg{color:var(--ink-2);margin-top:1px;flex:0 0 auto}
.fcol{display:flex;flex-direction:column;gap:3px}
.ft{font-size:calc(15px * var(--tscale));font-weight:500;color:var(--ink)}
.fs{font-size:calc(12px * var(--tscale));font-weight:500;color:var(--muted)}
.guide-foot{margin:auto 0 0;padding:0 0 34px;display:flex;flex-direction:column;gap:14px}

/* ── 记一笔 ── */
.ttabs{display:flex;gap:4px;padding:0 12px 6px;overflow-x:auto;flex:0 0 auto}
.ttabs::-webkit-scrollbar{display:none}
/* 右缘渐隐：英文 5 个 Tab 放不下时必须能滚（已实测）。
   没有这个提示，被切一半的 "Borrow" 看起来像渲染错误而不是「还有内容」。
   中文场景下右侧本来就是空的，遮罩作用在空白上，无副作用。 */
.ttabs{-webkit-mask-image:linear-gradient(90deg,#000 calc(100% - 28px),transparent);
  mask-image:linear-gradient(90deg,#000 calc(100% - 28px),transparent)}
.ttab{height:44px;padding:0 14px;border-radius:12px;font-size:calc(14px * var(--tscale));
  font-weight:500;color:var(--muted);white-space:nowrap;flex:0 0 auto;
  display:inline-flex;align-items:center}
.ttab.on{color:var(--ink);font-weight:600;background:var(--primary-tint);
  box-shadow:inset 0 0 0 1px var(--primary-ink)}
.amount-block{padding:2px 16px 10px;display:flex;flex-direction:column;align-items:flex-end;
  flex:0 0 auto}
/* 记一笔的中段（分类格 + 属性行）——唯一可滚区，键盘永远贴底。
   这样在「特大字号 × 英文」下也只是这一区滚动，不会把键盘顶出屏幕。 */
.addbody{flex:1 1 auto;min-height:0;overflow-y:auto;overflow-x:hidden}
.chip{position:relative;height:40px;padding:0 12px;border-radius:999px;
  border:1px solid var(--line);background:var(--surface);display:inline-flex;align-items:center;
  gap:6px;font-size:calc(12px * var(--tscale));font-weight:600;color:var(--ink-2);
  white-space:nowrap;flex:0 0 auto}
.chip svg{color:var(--muted);flex:0 0 auto}
.chip.ph{border-style:dashed;color:var(--muted);font-weight:500}
.chip::after{content:"";position:absolute;left:0;top:50%;transform:translateY(-50%);
  width:100%;height:44px}
.attrchips{display:flex;flex-wrap:wrap;gap:8px;padding:2px 16px 10px}
.expr{font-size:calc(14px * var(--tscale));font-weight:500;color:var(--muted);
  font-variant-numeric:tabular-nums;display:flex;align-items:center;height:20px}
.caret{display:inline-block;width:2px;height:15px;background:var(--primary);margin-left:3px;
  vertical-align:-2px}
.amt-line{margin-top:4px}
.catgrid{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;padding:10px 16px;flex:0 0 auto}
.tile{height:62px;border-radius:12px;display:flex;flex-direction:column;align-items:center;
  justify-content:center;gap:6px;background:none;border:1.5px solid transparent;padding:0 2px}
.tile-n{font-size:calc(12px * var(--tscale));font-weight:500;color:var(--ink-2);
  white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:100%}
.tile.on{background:var(--primary-tint);border-color:var(--primary-ink)}
.tile.on .tile-n{color:var(--primary-ink);font-weight:600}
.tile:active{background:var(--surface-inset);transform:scale(.96)}
.tile.more svg{color:var(--muted)}
.keypad{flex:0 0 auto;display:grid;grid-template-columns:repeat(4,1fr);gap:6px;padding:8px 12px 10px}
.key{height:62px;border-radius:12px;background:var(--surface-2);border:1px solid var(--line);
  box-shadow:0 1px 2px var(--shadow-1);font-size:calc(22px * var(--tscale));font-weight:500;
  color:var(--ink);display:flex;align-items:center;justify-content:center;
  font-variant-numeric:tabular-nums}
.key:active{background:var(--primary-tint);transform:scale(.96)}
.key.op{color:var(--ink-2)}
.key.blank{background:none;border:0;box-shadow:none}
.key.ok{grid-column:span 2;background:var(--accent);border-color:var(--accent);
  color:var(--on-accent);font-size:calc(15px * var(--tscale));font-weight:600;
  box-shadow:0 2px 8px var(--shadow-accent)}
.key.ok:active{background:var(--accent-pressed)}
.safearea{height:34px;flex:0 0 34px}

/* ── 详情 ── */
.detail-hero{padding:22px 0 26px;text-align:center}
.detail-hero .hero-label{margin:0 0 10px}
.dh-amt{display:flex;justify-content:center}
.dh-meta{display:flex;align-items:center;justify-content:center;gap:8px;margin-top:14px;
  font-size:calc(12px * var(--tscale));font-weight:500;color:var(--muted)}
.dh-meta .sep{color:var(--faint)}
.detail-panel{margin:0}
.drow{display:flex;align-items:center;gap:16px;min-height:56px;padding:10px 16px}
.drow + .drow{border-top:1px solid var(--line-soft)}
.dk{font-size:calc(14px * var(--tscale));font-weight:400;color:var(--muted);flex:0 0 76px}
.dv{flex:1;display:flex;align-items:center;gap:8px;justify-content:flex-end;text-align:right;
  font-size:calc(15px * var(--tscale));font-weight:500;color:var(--ink)}
.dv.note{font-size:calc(14px * var(--tscale));font-weight:400;color:var(--ink-2);line-height:1.5}
.danger-zone{margin:32px 0 0;display:flex;flex-direction:column;gap:10px}
.danger-zone .btn2{width:100%}

/* ── 报表 ── */
.cmppanel{margin-top:4px;padding:18px 16px 10px}
.cmppanel .eyebrow{margin-left:0}
.crow{display:flex;align-items:center;height:44px;gap:12px}
.crow + .crow{border-top:1px solid var(--line-soft)}
.ck{flex:1;font-size:calc(15px * var(--tscale));font-weight:500;color:var(--ink)}
.cv{flex:0 0 auto}
.cd{display:flex;align-items:center;gap:3px;flex:0 0 76px;justify-content:flex-end;
  font-size:calc(12px * var(--tscale));font-weight:600}
.chartpanel{margin-top:12px;padding:18px 16px 16px}
.chartpanel .eyebrow{margin-left:0}
.donut-wrap{display:flex;justify-content:center;padding:4px 0 14px}
.dn-c1{font-size:18px;font-weight:600;fill:var(--ink);font-variant-numeric:tabular-nums}
.dn-c1 .dn-cur,.dn-c1 .dn-dec{font-size:.62em;fill:var(--muted)}
.dn-c2{font-size:8.5px;font-weight:600;letter-spacing:.1em;fill:var(--muted)}
.legend{display:flex;flex-direction:column}
.lrow{display:flex;align-items:center;height:40px;gap:0}
.lname{flex:1;font-size:calc(14px * var(--tscale));color:var(--ink);margin-left:12px;
  white-space:nowrap;overflow:hidden;text-overflow:ellipsis;padding-right:8px}
.lpct{flex:0 0 48px;text-align:right;font-size:calc(15px * var(--tscale));font-weight:600;
  color:var(--ink-2);font-variant-numeric:tabular-nums}
.lamt{flex:0 0 92px;text-align:right;font-size:calc(15px * var(--tscale));font-weight:600;
  color:var(--ink);font-variant-numeric:tabular-nums}
.bars{display:block;margin-top:6px}

/* ── 分类管理 ── */
.segwrap{padding:0 16px 12px;flex:0 0 auto}
.seg{display:flex;background:var(--surface-inset);border-radius:12px;padding:3px;height:36px}
.segi{flex:1;border-radius:9px;font-size:calc(14px * var(--tscale));font-weight:500;
  color:var(--muted)}
.segi.on{background:var(--surface);color:var(--ink);font-weight:600;
  box-shadow:0 1px 2px var(--shadow-1)}
.catpanel{margin-top:0}
.footbar{padding:10px 16px 0;flex:0 0 auto;background:var(--app-bg);
  border-top:1px solid var(--line)}

/* ── 设置 ── */
.privacy-strip{display:flex;gap:12px;align-items:center;margin-top:4px;padding:14px 16px;
  border-radius:16px;background:var(--ok-soft);color:var(--ok-ink)}
.privacy-strip svg{color:var(--ok-ink);flex:0 0 auto}
.pcol{display:flex;flex-direction:column;gap:2px}
.pt{font-size:calc(14px * var(--tscale));font-weight:600}
.ps{font-size:calc(12px * var(--tscale));font-weight:500;opacity:.9}

/* ── 开关 ── */
.switch{width:48px;height:28px;border-radius:999px;background:var(--line);border:1px solid var(--line);
  position:relative;flex:0 0 48px;display:inline-block}
.switch .knob{position:absolute;top:2px;left:2px;width:22px;height:22px;border-radius:50%;
  background:var(--surface);box-shadow:0 1px 2px var(--shadow-1);transition:transform .15s cubic-bezier(.4,0,.2,1)}
.switch.on{background:var(--primary);border-color:var(--primary)}
.switch.on .knob{transform:translateX(20px)}

/* ── 触控命中区补足 ──────────────────────────────────────────────
   规则：视觉尺寸允许小于 44，但「命中区」必须 ≥ 44×44。
   做法：用 ::after 撑一层透明覆盖层，不改变视觉与布局。
   仅对视觉尺寸 < 44 的可点元素使用；≥44 的元素（.key 62 / .navitem 60 /
   .row 60 / .drow 56 / .attrrow 44 / .crow 44 / .navfab 44 / .tile 68）
   本身已合规，不加。                                                */
.textbtn,.segi,.switch{position:relative}
.textbtn::after,.segi::after,.switch::after{
  content:"";position:absolute;left:0;top:50%;transform:translateY(-50%);
  width:100%;height:44px;pointer-events:auto}
.switch::after{left:50%;transform:translate(-50%,-50%);width:44px}

/* ── 响应式：窄屏时缩放整个舞台 ── */
@media (max-width:520px){
  .frame{transform:scale(.82);transform-origin:top center;margin-bottom:-152px}
}
"""

# ═══════════════════════════════════════════════════════════════════ 组装

JS = r"""
(function () {
  var body = document.body;
  var tpl = {};
  document.querySelectorAll('.frame').forEach(function (f) {
    tpl[f.dataset.screen] = f.querySelector('.screen').innerHTML;
  });

  function setScreen(frame, id) {
    if (!tpl[id]) return;
    frame.dataset.screen = id;
    frame.querySelector('.screen').innerHTML = tpl[id];
    frame.querySelector('.screen').scrollTop = 0;
  }

  // 记录每个 frame 的来路，支持返回
  var stack = new WeakMap();

  document.addEventListener('click', function (e) {
    var frame = e.target.closest('.frame');
    if (!frame) return;
    var go = e.target.closest('[data-goto]');
    var back = e.target.closest('[data-back]');
    if (go) {
      e.preventDefault();
      var from = frame.dataset.screen, to = go.dataset.goto;
      if (from === to) return;
      stack.set(frame, (stack.get(frame) || []).concat([from]));
      setScreen(frame, to);
      if (body.dataset.view === 'single') syncPicker(to);
      return;
    }
    if (back) {
      e.preventDefault();
      var st = stack.get(frame) || [];
      var prev = st.pop() || 'ledger';
      stack.set(frame, st);
      setScreen(frame, prev);
      if (body.dataset.view === 'single') syncPicker(prev);
    }
  });

  function syncPicker(id) {
    document.querySelectorAll('.screenpicker button').forEach(function (b) {
      b.classList.toggle('on', b.dataset.screen === id);
    });
  }

  // 工具条
  document.querySelectorAll('[data-set]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var key = btn.dataset.set, val = btn.dataset.val;
      body.dataset[key] = val;
      btn.parentNode.querySelectorAll('button').forEach(function (b) {
        b.classList.toggle('on', b === btn);
      });
      if (key === 'size') applySize(val);
      if (key === 'view' && val === 'single') {
        var active = document.querySelector('.frame.active') || document.querySelector('.frame');
        document.querySelectorAll('.frame').forEach(function (f) { f.classList.remove('active'); });
        active.classList.add('active');
        syncPicker(active.dataset.screen);
      }
    });
  });

  // 字号三档：字号列四舍五入到整数（不动行高与字重）
  var BASE = {title: 20, heading: 15, body: 14, caption: 12,
              'amount-input': 44, 'amount-xl': 34, 'amount-l': 22, 'amount-s': 15,
              'key': 22};
  function applySize(tier) {
    var k = tier === 'large' ? 1.12 : (tier === 'xlarge' ? 1.26 : 1.0);
    var map = {
      '--fs-title': Math.round(BASE.title * k),
      '--fs-heading': Math.round(BASE.heading * k),
      '--fs-body': Math.round(BASE.body * k),
      '--fs-caption': Math.round(BASE.caption * k)
    };
    Object.keys(map).forEach(function (n) {
      document.querySelectorAll('.stage').forEach(function (s) {
        s.style.setProperty(n, map[n] + 'px');
      });
    });
    // 舞台整体缩放因子：以下所有 calc() 都乘它
    document.querySelectorAll('.stage').forEach(function (s) { s.style.setProperty('--tscale', k); });
  }

  document.querySelectorAll('.screenpicker button').forEach(function (b) {
    b.addEventListener('click', function () {
      var first = document.querySelector('.frame');
      setScreen(first, b.dataset.screen);
      document.querySelectorAll('.frame').forEach(function (f) { f.classList.remove('active'); });
      first.classList.add('active');
      syncPicker(b.dataset.screen);
    });
  });

  applySize('standard');

  // 单屏模式下点击缩略图同步
  document.querySelectorAll('.frame').forEach(function (f, i) {
    f.addEventListener('click', function () {
      document.querySelectorAll('.frame').forEach(function (x) { x.classList.remove('active'); });
      f.classList.add('active');
    });
  });
})();
"""


def toolbar_block():
    themes = [("subai", "素白"), ("qingci", "青瓷")]
    modes = [("light", "亮"), ("dark", "暗")]
    langs = [("zh", "中文"), ("en", "EN")]
    sizes = [("standard", "标准"), ("large", "大"), ("xlarge", "特大")]
    views = [("grid", "全部 8 屏"), ("single", "单屏")]

    def seg(key, items, default):
        b = "".join(f'<button data-set="{key}" data-val="{v}"'
                    f'{" class=\"on\"" if v == default else ""}>{lab}</button>'
                    for v, lab in items)
        return f'<div class="seg2">{b}</div>'

    picker = "".join(f'<button data-screen="{sid}">{zh}</button>' for sid, zh, _, _ in SCREENS)
    return (f'<div class="toolbar">'
            f'<div class="tb-brand">素记 Plain · redesign-v3<small>Quiet Ledger</small></div>'
            f'<div class="tb-group"><span class="tb-lab">主题</span>{seg("theme", themes, "subai")}</div>'
            f'<div class="tb-group"><span class="tb-lab">亮度</span>{seg("mode", modes, "light")}</div>'
            f'<div class="tb-group"><span class="tb-lab">语言</span>{seg("lang", langs, "zh")}</div>'
            f'<div class="tb-group"><span class="tb-lab">字号</span>{seg("size", sizes, "standard")}</div>'
            f'<div class="tb-group"><span class="tb-lab">视图</span>{seg("view", views, "grid")}</div>'
            f'<div class="tb-group"><span class="tb-lab">跳屏</span>'
            f'<div class="screenpicker">{picker}</div></div>'
            f'</div>')


def build():
    theme_css = []
    for theme in ("subai", "qingci"):
        for mode in ("light", "dark"):
            theme_css.append(f'body[data-theme="{theme}"][data-mode="{mode}"] .stage{{\n'
                             f'{theme_vars(theme, mode)}\n}}')
    # 默认（未设 data 属性时）
    body_cls_vars = theme_vars("subai", "light")

    for lang in ("zh", "en"):
        parts = []
        for sid, zh, en, fn in SCREENS:
            parts.append(f'<section class="frame" data-screen="{sid}" data-lang="{lang}">'
                         f'<div class="flabel">{zh} / {en}</div>'
                         f'<div class="bezelless">{fn(lang)}</div></section>')
        globals()[f"FRAMES_{lang}"] = "".join(parts)

    html = f"""<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>素记 Plain · redesign-v3 · 8 屏高保真</title>
<style>
{CSS}
/* ── 主题 × 亮度 → 变量（值全部来自 01-tokens.json，页面里没有裸色号） ── */
body{{{'  ' if False else ''}}}
{chr(10).join(theme_css)}
/* 语言切换：先全隐藏，再只显示与 body[data-lang] 匹配的那一半。
   ⚠️ 早先写成「默认隐藏 zh 帧」是错的 —— 那样 en 帧永远不会被隐藏，
      网格模式下中英会同时出现（16 帧而不是 8 帧）。 */
.frame[data-lang]{{display:none}}
body[data-lang="zh"] .frame[data-lang="zh"]{{display:block}}
body[data-lang="en"] .frame[data-lang="en"]{{display:block}}
body[data-view="single"] .frame{{display:none !important}}
body[data-view="single"] .frame.active{{display:block !important}}
</style></head>
<body data-theme="subai" data-mode="light" data-lang="zh" data-size="standard" data-view="grid">
{sprite()}
{toolbar_block()}
<div class="stage">
{FRAMES_zh}
{FRAMES_en}
</div>
<script>{JS}</script>
</body></html>
"""
    out = os.path.join(ROOT, "07-SCREENS.html")
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(html)
    print("written:", out, len(html), "bytes")
    print("screens:", len(SCREENS), "frames:", len(SCREENS) * 2)
    return 0


if __name__ == "__main__":
    raise SystemExit(build())
