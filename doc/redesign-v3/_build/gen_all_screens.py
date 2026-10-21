"""素记 Plain · redesign-v3 — **全部页面**高保真生成器。

产出：redesign-v3/单独确认.html（单文件，零外部依赖，双击即开）

范围：整个 App 的 **29 屏**（V1.0 十一 + V2.0 八 + V3.0 十），
      与 `03-交互原型.html` 的 SCREENS 表、`14-pages.js` 的 CHIP_GROUPS 三方对齐。
口径：**只出亮态中文**（素白主题）。不切主题 / 不切亮度 / 不切语言。

铁律：
  · 与 07-SCREENS.html **同一套**令牌与组件 —— CSS / sprite / 组件函数直接从
    gen_screens 复用，不复制粘贴，避免两套规格漂移。
  · 新增 21 屏只用现有 84 枚图标，**不新增图标**（`ic_*` 全部在 icons.json 里复核过）。
  · 跨屏同源数据必须对得上（信用卡欠款、投资市值、报表分类金额…），见 DATA 段注释。

运行：python _build/gen_all_screens.py
"""

from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import gen_screens as G  # noqa: E402

# ── 复用：组件片段 / 文案 / 图标表 ─────────────────────────────────
ic = G.ic
amount = G.amount
row = G.row
group = G.group
nav = G.nav
topbar = G.topbar
statusbar = G.statusbar
switch = G.switch
CAT_LABEL = G.CAT_LABEL
ICO = G.ICO
CATREFS = G.CATREFS

ROOT = G.ROOT
ZH = G.ZH            # 已有 8 屏的文案（中文键）
T = lambda k: ZH[k]  # noqa: E731

# ═══════════════════════════════════════════════════════════════════ 新增 CSS
#
# 只加 21 屏真正需要、而 8 屏没用到的组件。**风格必须与既有件同源**：
# 中性面 + 1px 线 + 无氛围装饰；进度条按《05-COMPONENT-SPECS》§24 的规格实现。

EXTRA_CSS = r"""
/* ═══ 全部页面追加件（与 8 屏同源：中性面 + 1px 线，无装饰） ═══ */

/* ── 进度条 Progress Bar（05-COMPONENT-SPECS §24） ──
   轨道 6 / pill / chartTrack；填充 primary，超支 → income(红)；
   超支必须同时出「警告图标 + 已超支文案」，不靠颜色单独表意（C2）。 */
.pbar{height:6px;border-radius:999px;background:var(--chart-track);overflow:hidden}
.pbar > i{display:block;height:100%;border-radius:999px;background:var(--primary)}
.pbar.warn > i{background:var(--warn-ink)}
.pbar.over > i{background:var(--income)}
.prowname{display:flex;align-items:baseline;gap:8px;font-size:calc(15px * var(--tscale));
  font-weight:500;color:var(--ink)}
.prowname .pamt{flex:1;text-align:right;font-size:calc(12px * var(--tscale));font-weight:500;
  color:var(--muted);font-variant-numeric:tabular-nums}
.prowfoot{display:flex;align-items:center;gap:5px;margin-top:7px;
  font-size:calc(12px * var(--tscale));font-weight:600;color:var(--ink-2)}
.prowfoot.warn{color:var(--warn-ink)}
.prowfoot.over{color:var(--income-ink)}
.prow{padding:14px 0}
.prow + .prow{border-top:1px solid var(--line-soft)}
.pbarwrap{margin-top:9px}

/* ── 说明块（功能口径、生效范围、副作用预览） ── */
.notepanel{padding:14px 16px;font-size:calc(12px * var(--tscale));line-height:1.72;
  color:var(--muted)}
.notepanel b{color:var(--ink-2);font-weight:600}
.notepanel .nl{display:block;margin-top:3px}

/* ── 键值行（汇总、口径明细） ── */
.kvr{display:flex;align-items:center;gap:12px;min-height:44px;padding:4px 16px;
  font-size:calc(14px * var(--tscale));color:var(--ink)}
.kvr + .kvr{border-top:1px solid var(--line-soft)}
.kvr > span:first-child{flex:1;min-width:0;white-space:nowrap;overflow:hidden;
  text-overflow:ellipsis}
.kvr > b{font-weight:600;font-variant-numeric:tabular-nums;flex:0 0 auto}

/* ── 数据表（还款计划、交叉分析） ── */
.dtbl{display:grid;gap:0;padding:0 2px}
.dtbl > span{padding:10px 2px;font-size:calc(14px * var(--tscale));color:var(--ink);
  border-bottom:1px solid var(--line-soft);font-variant-numeric:tabular-nums}
.dtbl > span.r{text-align:right}
.dtbl > span.h{font-size:calc(12px * var(--tscale));font-weight:600;color:var(--muted);
  border-bottom-color:var(--line)}
.dtbl > span.mut{color:var(--muted)}
.dtbl.cols4{grid-template-columns:1.15fr 1fr 1fr 1.25fr}
.dtbl.cols4 > span:nth-last-child(-n+4){border-bottom:0}

/* ── 热力矩阵（分类 × 账户） ── */
.heat{display:grid;gap:2px;padding:0 2px}
.heat.cols4{grid-template-columns:64px repeat(3,1fr)}
.heat > span{display:flex;align-items:center;justify-content:center;height:38px;
  border-radius:8px;font-size:calc(12px * var(--tscale));font-variant-numeric:tabular-nums}
.heat > span.hd{justify-content:flex-start;color:var(--muted);font-weight:600;
  padding-left:2px}
.heat > span.hc{color:var(--muted);font-weight:600}
.heat > span.cell{font-weight:600;background:var(--surface-2);color:var(--muted)}
.heat > span.mut{background:transparent;color:var(--faint)}

/* ── 迷你柱（净值走势 / 资金年龄） ── */
.minibars{display:flex;align-items:flex-end;gap:7px;height:92px}
.minibars > i{flex:1;border-radius:4px 4px 0 0;background:var(--bar-fill);opacity:.30;
  display:block}
.minibars > i.on{background:var(--primary);opacity:1}
.mblabels{display:flex;gap:7px;margin-top:7px}
.mblabels > span{flex:1;text-align:center;font-size:calc(12px * var(--tscale));color:var(--muted)}

/* ── 堆叠条（资产构成） ── */
.stack{display:flex;height:10px;border-radius:999px;overflow:hidden;margin:2px 0 12px}
.stack > i{display:block;height:100%}
.lgdot{display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:8px;
  vertical-align:middle}

/* ── 标签 chip（提醒级别、端支持状态） ── */
.tagx{height:22px;padding:0 8px;border-radius:999px;font-size:calc(12px * var(--tscale));
  font-weight:600;display:inline-flex;align-items:center;flex:0 0 auto;
  background:var(--surface-2);color:var(--muted)}
.tagx.ring{background:var(--warn-soft);color:var(--warn-ink)}
.tagx.silent{background:var(--surface-2);color:var(--muted)}
.tagx.done{background:var(--ok-soft);color:var(--ok-ink)}

/* ── 主题行 ── */
.throw{display:flex;align-items:center;gap:12px;min-height:64px;padding:10px 16px}
.throw + .throw{border-top:1px solid var(--line-soft)}
.thsw{display:flex;gap:4px;flex:0 0 auto}
.thsw > i{width:18px;height:18px;border-radius:6px;display:block}
.thtick{color:var(--primary-ink);flex:0 0 auto;display:flex}

/* ── 分段器上方留白（分类管理既有 .segwrap，这里给二级页用） ── */
.segwrap.top{padding-top:4px}

/* ── 空态 ── */
.emptybox{padding:32px 16px;text-align:center;color:var(--muted);
  font-size:calc(14px * var(--tscale));line-height:1.7}

/* ── 规则行（IF / THEN） ── */
.rulerow{display:flex;gap:12px;padding:14px 16px}
.rulerow + .rulerow{border-top:1px solid var(--line-soft)}
.ruleno{width:22px;height:22px;border-radius:7px;flex:0 0 22px;display:flex;
  align-items:center;justify-content:center;font-size:12px;font-weight:600;
  background:var(--primary-tint);color:var(--primary-ink)}
.ruleno.off{background:var(--surface-2);color:var(--muted)}
.rulecond{font-size:calc(12px * var(--tscale));color:var(--muted);line-height:1.6;
  margin-top:3px}
.rulecond code{font-family:inherit;font-weight:600;color:var(--ink-2)}

/* ── 副作用预览 / 结算明细的双列 ── */
.duocol{display:flex;justify-content:space-between;align-items:baseline;gap:12px;
  font-size:calc(14px * var(--tscale));color:var(--ink);min-height:34px;padding:2px 16px}
.duocol + .duocol{border-top:1px solid var(--line-soft)}
.duocol > b{font-weight:600;font-variant-numeric:tabular-nums}

/* ── 开关 · 永不可授予（禁用态） ──
   ⚠️ 禁用**不能只靠 opacity** —— 半透明和「关闭」态长得几乎一样，
      用户会以为只是没打开。必须换底色 + 换滑块色。
      ⚠️ CSS 变量名是短横线（--disabled-bg / --disabled-fg），
         不是 Dart 侧的驼峰（disabledBg / disabledFg）—— 写驼峰会静默回退
         （background 落到 transparent、border-color 落到 currentColor），
         页面照常渲染、无任何报错，只有肉眼能看出「禁用态和关闭态长得一样」。 */
.switch.lock{background:var(--disabled-bg);border-color:var(--disabled-fg)}
.switch.lock .knob{background:var(--disabled-fg);box-shadow:none}

/* ── 屏内首组（不需要 32px 上边距） ── */
.grp0{margin-top:20px}

/* ── 空态图标居中（G.CSS 里 svg{display:block}，需显式 auto） ── */
.emptyic{margin:0 auto;color:var(--faint)}

/* ── 序号圆片（首页卡片自定义的排序位） ── */
.ricnt{width:22px;height:22px;border-radius:7px;flex:0 0 22px;display:flex;
  align-items:center;justify-content:center;font-size:12px;font-weight:600;
  background:var(--surface-2);color:var(--muted)}

/* ── 分组大标题（舞台级，非屏内） ── */
.vergrouph{width:100%;margin:26px 0 -6px;font-size:14px;font-weight:700;letter-spacing:.06em;
  color:#5E5E65;text-transform:uppercase;padding:0 4px}
.vergrouph:first-child{margin-top:0}
"""

CSS = G.CSS + EXTRA_CSS


# ═══════════════════════════════════════════════════════════════════ 跨屏同源数据
#
# ⚠️ 这些数字在多个屏里出现，必须**一处定义、多处引用**，否则 29 屏拼在一起
#    会被肉眼抓出矛盾（这是上一版被点名的问题之一）。
#
#   首页 hero      支出 5,879.50 / 收入 9,300.00 / 结余 3,420.50
#   报表环形图     餐饮 32% 购物 24% 其他 18% 交通 14% 居住 12%  → 合计 5,879.50
#   资金流向       同 5 类、同金额 → 结余 3,420.50（与首页一致）
#   交叉分析       同 5 类 × 3 账户，行合计 = 5,879.50
#   预算           同 5 类实际值，合计 4,821.19（其余分类未设预算）
#   资产           52,180.30 + 1,240.20 + 38,000.00 − 5,000.00 = 86,420.50
#   投资持仓       20,400 + 11,880 + 5,720 = 38,000.00（与资产页「指数基金」一致）
#   信用卡账单     欠款 5,000.00（与资产页负债一致）
#   净值追踪       9 月 86,420.50（与资产页净资产一致）

TOTAL_EXPENSE = "5,879.50"
TOTAL_INCOME = "9,300.00"
TOTAL_NET = "3,420.50"

# 分类 → (百分比, 金额)；与报表 05-reports 的 DONUT / LEGEND 完全一致
SPLIT = [("food", 32, "1,881.44"), ("shopping", 24, "1,411.08"),
         ("other", 18, "1,058.31"), ("transport", 14, "823.13"),
         ("housing", 12, "705.54")]

CARD_OWE = "5,000.00"      # 信用卡本期应还（资产页负债）
CARD_LIMIT = "20,000.00"
CARD_AVAIL = "15,000.00"
INVEST_MKT = "38,000.00"   # 投资总市值（资产页「指数基金」）
NET_WORTH = "86,420.50"    # 净资产（资产页）


def pct_row(ref, pct, used, limit, note=""):
    """分类预算行：名称 + 金额/预算 → 进度条 → 百分比脚注（§24 规格）。"""
    r = used / limit * 100 if limit else 0
    cls = "over" if r >= 100 else ("warn" if r >= 90 else "")
    foot_cls = cls
    if r >= 100:
        foot = f'{ic("ic_status_warning", 13)}已超支 ¥{used - limit:,.2f}'
    elif r >= 90:
        foot = f'{ic("ic_status_warning", 13)}仅剩 ¥{limit - used:,.2f}，注意节奏'
    else:
        foot = f'剩余 ¥{limit - used:,.2f}（{100 - r:.0f}%）'
    if note:
        foot += f' · {note}'
    return (f'<div class="prow">'
            f'<div class="prowname"><span class="dot8" '
            f'style="background:var(--cat-{ref})"></span>{CAT_LABEL["zh"][ref]}'
            f'<span class="pamt">¥{used:,.2f} / ¥{limit:,.2f}</span></div>'
            f'<div class="pbarwrap"><div class="pbar {cls}">'
            f'<i style="width:{min(r, 100):.1f}%"></i></div></div>'
            f'<div class="prowfoot {foot_cls}">{foot}</div></div>')


def kvr(k, v, tone=""):
    t = f' style="color:var(--{tone})"' if tone else ""
    return f'<div class="kvr"><span>{k}</span><b{t}>{v}</b></div>'


def note(html):
    return f'<div class="panel notepanel">{html}</div>'


def iconrow(icon, title, sub, right="", chevron=False, goto=None):
    """带图标的行（资产页 acc 的同族，用于 21 屏的列表类内容）。"""
    tag = "a" if goto else "div"
    attrs = f' data-goto="{goto}"' if goto else ""
    ch = ic("ic_chevron_right", 16, "chev") if chevron else ""
    subh = f'<span class="sub">{sub}</span>' if sub else ""
    return (f'<{tag} class="row"{attrs}><span class="ricos">{ic(icon, 22)}</span>'
            f'<span class="rcol"><span class="rt">{title}</span>{subh}</span>'
            f'{right}{ch}</{tag}>')


# ═══════════════════════════════════════════════════════════════════ V1.0 补 3 屏

def screen_backup():
    """SP-4-01 备份与恢复 —— 空态 + 备份说明 + 恢复流程。"""
    return f'''<div class="screen">{statusbar()}
{topbar("备份与恢复", right='<button class="textbtn">生成备份</button>')}
<div class="scroll">
  <div class="grp0">{note(
      '备份为<b>整库加密文件</b>，包含全部账单、分类、账户与设置。'
      '通过系统分享保存到网盘或电脑。<span class="nl">'
      '卸载应用会清除本地数据，<b>请提前备份</b>。</span>')}</div>
  <section class="grp"><div class="eyebrow">历史备份</div>
    <div class="panel">
      <div class="emptybox">{ic("ic_storage", 28, "emptyic")}
        <div style="margin-top:10px;color:var(--ink-2);font-weight:500">还没有备份</div>
        <div style="margin-top:3px">点击右上角「生成备份」创建第一份</div></div>
    </div></section>
  <section class="grp"><div class="eyebrow">恢复流程</div>
    <div class="panel">{note(
        '选择备份 → 校验密码与版本 → 预览（笔数 / 时间范围）→ 确认。'
        '<span class="nl">恢复前系统会<b>自动生成一份「恢复前备份」</b>，操作可反悔。</span>')}
    </div></section>
  <div class="scroll-pad"></div>
</div></div>'''


def screen_find():
    """SP-5-01 发现 —— V1.0 聚合 + V2.0 / V3.0 入口 + 路线图。

    ⚠️ 图标分配避开两处雷同：
      · `ic_sort`（上下双向箭头）与 `ic_transfer`（左右双向箭头）是**同一形状旋转 90°** ——
        同屏并列会读成同一件事，故本页完全不用 `ic_sort`。
      · `ic_chart_pie` 只给「分割交易」（一份拆成多块），不与「报表」的 nav 图标混用。
    见《10-CHANGELOG》返工记录。
    """
    v2 = [("ic_transfer", "转账 / 借出 / 借入", "双账户记一笔，显式确认"),
          ("ic_chart_pie", "分割交易", "一笔消费拆到多个分类"),
          ("ic_receipt", "报销中心", "待报销 → 已到账三态"),
          ("ic_card", "信用卡账单", "账单周期、应还、未出账明细"),
          ("ic_bell", "提醒中心", "预算 / 账单 / 周期三类聚合"),
          ("ic_recurring", "自动规则", "IF 条件 → THEN 动作"),
          ("ic_goal", "储蓄目标与基金", "大额支出按月摊存"),
          ("ic_settings", "首页卡片自定义", "选择常驻卡片与顺序")]
    v3 = [("ic_chart_line", "投资持仓", "成本 / 市值 / 浮动盈亏"),
          ("ic_calendar", "贷款摊销", "等额本息 / 等额本金"),
          ("ic_chart_bars", "净值追踪", "净值走势与资产构成"),
          ("ic_arrow_up_right", "资金流向", "钱从哪来、到哪去、剩多少"),
          ("ic_filter", "交叉分析", "分类 × 账户透视"),
          ("ic_status_info", "资金年龄", "花掉的一块钱躺了多少天"),
          ("ic_budget", "预算", "四种方法论任选"),
          ("ic_nav_profile", "家庭与成员", "共享账本与角色权限"),
          ("ic_cloud", "开放接口", "本地 API 与 MCP"),
          ("ic_export", "桌面端与多端", "四端能力矩阵")]
    mks = lambda items: "".join(iconrow(i, n, s, chevron=True) for i, n, s in items)
    return f'''<div class="screen">{statusbar()}
<header class="topbar"><button class="iconbtn" data-back>{ic("ic_back", 22)}</button>
  <h1>发现</h1><div class="tb-right"></div></header>
<div class="scroll">
  <section class="grp0"><div class="eyebrow">常用</div>
    <div class="panel">
      {iconrow("ic_storage", "备份与恢复", "生成加密备份 · 恢复到任意设备", chevron=True)}
      {iconrow("ic_scan", "分类管理", "12 个一级 · 41 个二级 · 自定义图标与备注", chevron=True)}
    </div></section>
  <section class="grp"><div class="eyebrow">V2.0 · 交易精度与主动管家</div>
    <div class="panel">{mks(v2)}</div></section>
  <section class="grp"><div class="eyebrow">V3.0 · 资产完整性与方法论</div>
    <div class="panel">{mks(v3)}</div></section>
  <section class="grp"><div class="eyebrow">版本</div>
    <div class="panel">
      {kvr("当前版本", "V1.0.0")}
      {kvr("已上线", "V1.0 全部功能")}
      {kvr("规划中", "V2.0 · V3.0 · 商业化 V4.0")}
    </div></section>
  <div class="scroll-pad"></div>
</div></div>'''


THEMES10 = [
    ("qingci", "青瓷", "清爽 · 青绿 × 蜜桃"),
    ("dianlan", "靛蓝", "沉稳 · 深蓝 × 琥珀"),
    ("zhuqing", "竹青", "素雅 · 草绿 × 藤紫"),
    ("haiyan", "海盐", "深邃 · 青蓝 × 珊瑚"),
    ("ouhe", "藕荷", "柔美 · 藕紫 × 沙金"),
    ("taoyao", "桃夭", "浪漫 · 桃粉 × 青碧"),
    ("feiying", "绯樱", "古朴 · 绯红 × 松绿"),
    ("xinghuang", "杏黄", "温暖 · 杏黄 × 湖蓝"),
    ("doulv", "豆绿", "清新 · 豆绿 × 藤紫"),
    ("subai", "素白", "极简 · 炭黑 × 橘红"),
]


def screen_theme():
    """SP-5-02 主题 —— 外观模式 + 10 套主题（当前 = 素白）。

    色卡走 `--th-<id>-p / -a` 变量，**页面里不出现裸色号**（铁律）。
    """
    rows = []
    for tid, name, tag in THEMES10:
        on = tid == "subai"
        tick = ic("ic_check", 18, "thick") if on else ""
        rows.append(
            f'<div class="throw">'
            f'<span class="thsw"><i style="background:var(--th-{tid}-p)"></i>'
            f'<i style="background:var(--th-{tid}-a)"></i></span>'
            f'<span class="rcol"><span class="rt">{name}</span>'
            f'<span class="sub">{tag}</span></span>'
            f'<span class="thtick">{tick}</span></div>')
    return f'''<div class="screen">{statusbar()}
{topbar("主题")}
<div class="segwrap top"><div class="seg">
  <button class="segi on">跟随系统</button>
  <button class="segi">浅色</button>
  <button class="segi">深色</button>
</div></div>
<div class="scroll"><div class="panel">{"".join(rows)}</div>
  <div class="grp"><div class="panel notepanel">
    10 套主题<b>全部免费</b>，每套含浅色 / 深色两态，切换即时生效、无需重启。
    <span class="nl">    主题只改外观：分类色板与收入 / 支出语义色<b>跨主题固定</b>；
    主题属本机偏好，多端同步时不覆盖其他设备。</span></div></div>
  <div class="scroll-pad"></div></div></div>'''


# ═══════════════════════════════════════════════════════════════════ V2.0 八屏

def screen_addplus():
    """SP-1-04 转账 / 借出 / 借入 —— 双账户显式确认（G-6），不计入收支（G-2）。"""
    modes = [("转账", True), ("借出", False), ("借入", False)]
    tabs = "".join(f'<button class="ttab{" on" if on else ""}">{n}</button>'
                   for n, on in modes)
    return f'''<div class="screen">{statusbar()}
{topbar("转账", right='<button class="textbtn">保存</button>')}
<div class="ttabs">{tabs}</div>
<div class="amount-block">
  <div class="expr">转入基金定投</div>
  <div class="amt-line">{amount("1,000.00", "input")}</div>
</div>
<div class="addbody">
  <div class="panel">
    {iconrow("ic_arrow_up_right", "转出账户", "",
             '<span class="sval">招行储蓄卡 ····6217</span>', chevron=True)}
    {iconrow("ic_arrow_down_left", "转入账户", "",
             '<span class="sval">指数基金 · 定投</span>', chevron=True)}
    {iconrow("ic_calendar", "日期", "", '<span class="sval">今天</span>', chevron=True)}
    {iconrow("ic_note", "备注", "", '<span class="sval">选填</span>', chevron=True)}
  </div>
  <div class="grp"><div class="eyebrow">保存后的影响</div>
    <div class="panel">
      <div class="duocol"><span>转出账户</span><b style="color:var(--income-ink)">−¥1,000.00</b></div>
      <div class="duocol"><span>转入账户</span><b style="color:var(--ink)">+¥1,000.00</b></div>
      <div class="duocol"><span>净资产</span><b>不变</b></div>
      <div class="duocol"><span>收支与预算</span><b>不计入</b></div>
    </div></div>
  <div class="grp"><div class="panel notepanel">
    涉及<b>两个账户</b>的记账不走「点分类即保存」，需要显式确认（G-6）。
    <span class="nl">转账只是钱换了地方 —— 计入收支会让你的「支出」凭空翻倍（G-2）。</span>
  </div></div>
</div>
<div class="keypad" style="grid-template-columns:1fr">
  <button class="key ok">确认转账</button>
</div>
<div class="safearea"></div></div>'''


def screen_split():
    """SP-1-05 分割交易 —— 父单金额 = Σ子项，不等不允许保存。"""
    parts = [("food", "餐饮 · 午餐", "工作餐", "68.00"),
             ("social", "人情 · 请客", "招待同事", "100.00")]
    rows = "".join(
        f'<div class="row"><span class="dot6" style="background:var(--cat-{ref})"></span>'
        f'<span class="rcol"><span class="rt">{name}</span>'
        f'<span class="sub">{sub}</span></span>'
        f'<span class="rw-amt">{amount(a, "s")}</span></div>' for ref, name, sub, a in parts)
    return f'''<div class="screen">{statusbar()}
{topbar("分割这笔账单", right='<button class="textbtn">完成</button>')}
<div class="scroll">
  <section class="grp0"><div class="panel" style="padding:16px">
    <div class="duocol" style="padding:0;min-height:30px;border:0">
      <span style="color:var(--muted)">账单原始金额</span><b>¥168.00</b></div>
    <div class="duocol" style="padding:0;min-height:30px;border:0">
      <span style="color:var(--muted)">已分配</span>
      <b style="color:var(--ok-ink)">¥168.00</b></div>
    <div class="pbarwrap"><div class="pbar"><i style="width:100%"></i></div></div>
    <div class="prowfoot" style="color:var(--ok-ink);margin-top:8px">
      {ic("ic_status_success", 13)}已对平，可以保存</div>
  </div></section>
  <section class="grp"><div class="eyebrow">子项（2）</div>
    <div class="panel">{rows}
      <div class="row"><span class="ricos">{ic("ic_plus", 20)}</span>
        <span class="rcol"><span class="rt" style="color:var(--primary-ink)">再分一项</span></span></div>
    </div></section>
  <div class="grp"><div class="panel notepanel">
    父子结构：父单不被删除，子项独立统计。父单金额<b>恒等于 Σ 子项金额</b>。
    <span class="nl">报表中各子项按自己的分类计数，父单<b>分类置空</b>、不参与分类统计
    （避免双算）；父单只计入账户余额一次。</span></div></div>
  <div class="scroll-pad"></div>
</div></div>'''


def screen_claim():
    """SP-1-06 报销中心 —— 待报销 / 已提交 / 已到账三态。"""
    def item(date, cat, sub, amt):
        return (f'<div class="duocol" style="padding:0 16px;min-height:38px">'
                f'<span style="color:var(--muted)">{date}　{cat}</span>'
                f'<b>{amount(amt, "s")}</b></div>')
    return f'''<div class="screen">{statusbar()}
{topbar("报销中心")}
<div class="scroll">
  <section class="hero" style="padding-top:6px">
    <div class="hairline"></div>
    <div class="hero-label">待收回金额</div>
    <div class="hero-amt">{amount("1,528.00", "xl")}</div>
    <div class="hero-split">
      <div class="hs"><span class="hs-l">待报销</span><span class="hs-v">1 笔</span></div>
      <div class="hs"><span class="hs-l">已提交</span><span class="hs-v">1 笔</span></div>
    </div>
    <div class="hairline"></div>
  </section>
  <section class="grp"><div class="eyebrow">待报销 · 1 笔</div>
    <div class="panel">{item("09-26", "交通 · 客户拜访打车", "", "328.00")}</div></section>
  <section class="grp"><div class="eyebrow">已提交 · 1 笔</div>
    <div class="panel">{item("09-22", "餐饮 · 团队聚餐垫付", "", "1,200.00")}</div></section>
  <section class="grp"><div class="eyebrow">已到账 · 1 笔</div>
    <div class="panel">{item("09-15", "居住 · 出差酒店", "", "560.00")}</div></section>
  <div class="grp"><div class="panel notepanel">
    报销到账时系统自动生成一笔等额收入并<b>冲销原支出</b> —— 净效果为 0，
    不会把报销算成额外收入。
    <span class="nl">支出统计中该笔<b>始终保留</b>（体现真实消费），
    到账收入标记为「报销回款」，不计入收入口径。</span></div></div>
  <div class="scroll-pad"></div>
</div></div>'''


def screen_cardbill():
    """SP-2-02 信用卡账单 —— 欠款余额为唯一权威可写量，可用额度派生只读。"""
    tx = [("09-26", "餐饮 · 外卖", "86.50"), ("09-24", "购物 · 数码配件", "399.00"),
          ("09-21", "餐饮 · 团队聚餐", "1,200.00"), ("09-18", "交通 · 打车", "46.00"),
          ("09-12", "其他 · 订阅服务", "168.00")]
    rows = "".join(f'<div class="duocol" style="min-height:40px">'
                   f'<span style="color:var(--muted)">{d}　{n}</span>'
                   f'<b>{amount(a, "s")}</b></div>' for d, n, a in tx)
    used = 5000 / 20000 * 100
    return f'''<div class="screen">{statusbar()}
{topbar("信用卡账单")}
<div class="scroll">
  <section class="hero" style="padding-top:6px">
    <div class="hairline"></div>
    <div class="hero-label">本期应还 · 还款日 10月8日</div>
    <div class="hero-amt">{amount("5,000.00", "xl")}</div>
    <div class="hero-split">
      <div class="hs"><span class="hs-l">最低还款</span>
        <span class="hs-v">{amount("500.00", "s")}</span></div>
      <div class="hs"><span class="hs-l">可用额度</span>
        <span class="hs-v">{amount("15,000.00", "s")}</span></div>
      <div class="hs"><span class="hs-l">已用</span><span class="hs-v">25.0%</span></div>
    </div>
    <div class="hairline"></div>
  </section>
  <section class="grp"><div class="eyebrow">账户参数</div>
    <div class="panel" style="padding:6px 0">
      {kvr("账单日", "每月 25 日")}
      {kvr("还款日", "次月 8 日")}
      {kvr("总额度", "¥20,000.00")}
      {kvr("循环利息", "无（全额还款）")}
      <div style="padding:12px 16px">
        <div class="pbar warn"><i style="width:{used:.1f}%"></i></div>
        <div class="prowfoot" style="color:var(--muted);margin-top:8px">
          已用 25.0%，额度使用健康</div>
      </div>
    </div></section>
  <section class="grp"><div class="eyebrow">本期未出账消费 · ¥1,899.50</div>
    <div class="panel">{rows}</div></section>
  <div class="grp"><div class="panel notepanel">
    <b>双数模型：</b>「欠款余额」是可写的唯一权威量；「可用额度」由总额度派生，<b>只读</b>。
    <span class="nl">本期应还 ¥5,000.00 与未出账 ¥1,899.50 是两个口径：
    前者是上一账单周期的结算结果，后者是本期新增。</span>
    <span class="nl">信用卡消费<b>计入支出统计</b>（钱确实花了）；
    还信用卡<b>不计入收支</b>（只减少欠款）。</span></div></div>
  <div class="scroll-pad"></div>
</div></div>'''


def screen_remind():
    """SP-5-04 提醒中心 —— 三类聚合，分级通知（G-3）。"""
    # ⚠️ 第一项必须是**合法 CSS 变量名**。早先这里放的是「预算 / 账单 / 周期」，
    #    拼出 `var(--预算)` —— 变量不存在 → background 回退到初始值 transparent，
    #    每张卡左侧的色点**完全不显示**，而且不报错。
    items = [("warn-ink", "本月餐饮预算已用 87%", "剩余 ¥130.00，按当前速度将在 5 天后超支", "响铃", "ring"),
             ("warn-ink", "本月总支出已达 90%", "较上月同期多花 12%", "静默", "silent"),
             ("income-ink", "招行信用卡 10月8日还款", "本期应还 ¥5,000.00，还有 10 天", "响铃", "ring"),
             ("primary", "房租 ¥4,500.00 待确认", "今天是每月 1 日，检测到周期记账规则命中", "响铃", "ring"),
             ("primary", "指数基金定投将于 10月15日扣款", "¥1,000.00，从招行储蓄卡扣除", "静默", "silent")]
    cards = "".join(
        f'<div class="panel" style="margin-bottom:12px;padding:14px 16px">'
        f'<div style="display:flex;align-items:flex-start;gap:10px">'
        f'<span class="dot8" style="background:var(--{kind});margin-top:6px"></span>'
        f'<span class="rcol"><span class="rt" style="white-space:normal">{title}</span>'
        f'<span class="sub" style="white-space:normal;line-height:1.6">{desc}</span></span>'
        f'<span class="tagx {lvcls}">{lv}</span></div>'
        f'<div style="display:flex;gap:8px;margin-top:12px;padding-left:18px">'
        f'<button class="btn2" style="height:34px;min-width:72px;font-size:calc(14px * var(--tscale))">稍后</button>'
        f'<button class="btn2" style="height:34px;min-width:72px;font-size:calc(14px * var(--tscale));'
        f'border-color:var(--primary-ink);color:var(--primary-ink)">知道了</button>'
        f'</div></div>'
        for kind, title, desc, lv, lvcls in items)
    return f'''<div class="screen">{statusbar()}
{topbar("提醒中心", right='<button class="textbtn">设置</button>')}
<div class="segwrap top"><div class="seg">
  <button class="segi on">全部</button><button class="segi">预算</button>
  <button class="segi">账单</button><button class="segi">周期</button>
</div></div>
<div class="scroll">{cards}
  <div class="panel notepanel">
    分级通知（G-3）：<b>静默</b>只进提醒中心、不响铃；<b>响铃</b>同时走系统通知。
    <span class="nl">预算 90% 静默、100% 响铃 —— 但两者都<b>不阻挡你继续记账</b>。</span>
  </div>
  <div class="scroll-pad"></div></div></div>'''


def screen_rule():
    """SP-5-05 自动规则 —— IF 条件 → THEN 动作，命中可回溯。"""
    rules = [("星巴克自动归类", True,
              "商户 包含 <code>星巴克</code>",
              "分类 → 餐饮 · 饮料　账户 → 招行信用卡", 12),
             ("地铁通勤归类", True,
              "商户 包含 <code>地铁</code> 且 金额 <code>≤ 20</code>",
              "分类 → 交通 · 公交地铁", 34),
             ("大额支出标记", True,
              "金额 <code>≥ 500</code>",
              "打标签 <code>#大额</code>　备注追加提醒", 6),
             ("工资自动入账", True,
              "金额 <code>= 15,000</code> 且 类型 收入",
              "分类 → 其他 · 工资　账户 → 招行储蓄", 1),
             ("晚间消费提醒", False,
              "时间 在 <code>23:00–05:00</code>",
              "打标签 <code>#深夜</code>（仅标记不通知）", 3)]
    rows = "".join(
        f'<div class="rulerow"><span class="ruleno{" off" if not on else ""}">{i + 1}</span>'
        f'<span class="rcol"><span class="rt" style="white-space:normal">{name}</span>'
        f'<span class="rulecond">IF　{cond}</span>'
        f'<span class="rulecond">THEN　{act}</span>'
        f'<span class="rulecond" style="color:var(--faint)">已命中 {hit} 次</span></span>'
        f'{switch(on)}</div>' for i, (name, on, cond, act, hit) in enumerate(rules))
    return f'''<div class="screen">{statusbar()}
{topbar("自动规则", right='<button class="textbtn">新建</button>')}
<div class="scroll">
  <section class="grp0"><div class="panel notepanel">
    规则 = <b>条件（IF）</b> + <b>动作（THEN）</b>。一条账单可在保存时命中多条规则，
    按优先级顺序执行，后者可覆盖前者。
    <span class="nl">每次命中都会记入「规则执行日志」，可查看、可撤销。</span>
  </div></section>
  <section class="grp"><div class="eyebrow">规则 · 5 条</div>
    <div class="panel">{rows}</div></section>
  <div class="grp"><div class="panel notepanel">
    执行阶段：<b>保存前</b>（可改写分类 / 账户） / <b>保存后</b>（只做标记与通知）。
    <span class="nl">改动仅作用于规则生效之后的新账单，<b>不回改历史</b>。</span>
  </div></div>
  <div class="scroll-pad"></div>
</div></div>'''


def screen_goal():
    """SP-5-06 储蓄目标与基金 —— 沉淀基金 + 储蓄目标。"""
    funds = [("ic_export", "年度旅行", 7400, 12000, 1000),
             ("ic_wallet", "换手机", 1800, 6000, 500),
             ("ic_shield", "保险费（年金）", 3600, 4800, 400),
             ("ic_status_success", "应急储备", 12500, 30000, 2500)]
    rows = ""
    for i, (ico, name, saved, target, monthly) in enumerate(funds):
        p = saved / target * 100
        cls = "over" if p >= 100 else ("warn" if p >= 90 else "")
        rows += (f'<div class="prow">'
                 f'<div class="prowname">{ic(ico, 18)}'
                 f'<span style="margin-left:8px">{name}</span>'
                 f'<span class="pamt">¥{saved:,}.00 / ¥{target:,}.00</span></div>'
                 f'<div class="pbarwrap"><div class="pbar {cls}">'
                 f'<i style="width:{min(p, 100):.0f}%"></i></div></div>'
                 f'<div class="prowfoot" style="color:var(--muted)">'
                 f'{p:.0f}% · 还差 ¥{target - saved:,}.00'
                 f'<span style="margin-left:auto">月存 ¥{monthly:,}.00</span></div></div>')

    total_saved, total_target = 25300, 52800
    return f'''<div class="screen">{statusbar()}
{topbar("储蓄目标与基金", right='<button class="textbtn">新建</button>')}
<div class="scroll">
  <section class="hero" style="padding-top:6px">
    <div class="hairline"></div>
    <div class="hero-label">目标已存 / 目标总额</div>
    <div class="hero-amt">{amount("25,300.00", "xl")}</div>
    <div class="hero-split">
      <div class="hs"><span class="hs-l">总进度</span>
        <span class="hs-v">{(total_saved / total_target * 100):.1f}%</span></div>
      <div class="hs"><span class="hs-l">月需存入</span>
        <span class="hs-v">{amount("4,400.00", "s")}</span></div>
    </div>
    <div class="hairline"></div>
  </section>
  <section class="grp"><div class="eyebrow">目标 · 4 个</div>
    <div class="panel" style="padding:0 16px">{rows}</div></section>
  <div class="grp"><div class="panel notepanel">
    <b>沉淀基金</b>把「一年一次的大额支出」拆成月存（保险费、旅行、年检），
    避免某个月突然被击穿。
    <span class="nl">目标里的钱<b>从「安全可花」基数中扣除</b> —— 否则你会以为自己很有钱。</span>
  </div></div>
  <div class="scroll-pad"></div>
</div></div>'''


def screen_card():
    """SP-5-07 首页卡片自定义 —— 至少 1 张、最多 4 张，长按拖动排序。"""
    cards = [("记账月结余", "收入 / 支出 / 结余三数值", True),
             ("预算进度", "本月预算总进度条", True),
             ("安全可花", "扣除预留后的日均可支配", True),
             ("目标进度", "最近一个储蓄目标的进度", False),
             ("净值", "净资产与较上月变化", False),
             ("近 7 天热力图", "按日消费强度色块", False)]
    rows = "".join(
        f'<div class="row" style="min-height:64px">'
        f'<span class="ricnt">{i + 1}</span>'
        f'<span class="rcol"><span class="rt">{n}</span><span class="sub">{d}</span></span>'
        f'{switch(on)}</div>' for i, (n, d, on) in enumerate(cards))
    return f'''<div class="screen">{statusbar()}
{topbar("首页卡片自定义")}
<div class="scroll">
  <section class="grp0"><div class="panel notepanel">
    勾选要常驻首页的卡片。<b>至少保留 1 张、最多 4 张</b>，长按可拖动排序。
  </div></section>
  <section class="grp"><div class="eyebrow">可选卡片 · 已选 3 / 4</div>
    <div class="panel">{rows}</div></section>
  <div class="grp"><div class="panel notepanel">
    首页卡片顺序与开关属<b>本机偏好</b>，多端同步时不覆盖其他设备。
  </div></div>
  <div class="scroll-pad"></div>
</div></div>'''


# ═══════════════════════════════════════════════════════════════════ V3.0 十屏

def screen_invest():
    """SP-2-04 投资持仓 —— 成本 / 份额 / 市值 / 浮动盈亏。

    ⚠️ 市值合计 38,000.00 必须等于资产页的「指数基金」—— 跨屏同源量。
    """
    holds = [("沪深300指数基金", "110020", "6,841.78", "3.274", 17000, 22400),
             ("纳指ETF", "513100", "1,170.95", "8.950", 9600, 10480),
             ("货币基金", "000198", "5,120.00", "1.000", 5000, 5120)]
    rows = ""
    for name, code, shs, nav, cost, mkt in holds:
        gain = mkt - cost
        r = gain / cost * 100
        tone = "income" if gain >= 0 else "dn"
        rows += (f'<div class="prow">'
                 f'<div class="prowname"><span class="rt">{name}</span>'
                 f'<span class="pamt">{code}</span></div>'
                 f'<div class="prowfoot" style="color:var(--muted);font-weight:500">'
                 f'持有 {shs} 份 · 净值 {nav}</div>'
                 f'<div class="duocol" style="padding:0;border:0;min-height:30px;margin-top:6px">'
                 f'<span style="color:var(--muted)">市值</span>'
                 f'<span><b>{amount(f"{mkt:,}.00", "s")}</b>'
                 f'<span class="tone-{tone}" style="margin-left:10px;font-size:calc(12px * var(--tscale));'
                 f'font-weight:600;font-variant-numeric:tabular-nums">'
                 f'{"+" if gain >= 0 else ""}{gain:,}.00（{"+" if r >= 0 else ""}{r:.2f}%）</span></span>'
                 f'</div></div>')
    return f'''<div class="screen">{statusbar()}
{topbar("投资持仓", right='<button class="textbtn">刷新</button>')}
<div class="scroll">
  <section class="hero" style="padding-top:6px">
    <div class="hairline"></div>
    <div class="hero-label">持仓总市值</div>
    <div class="hero-amt">{amount("38,000.00", "xl")}</div>
    <div class="hero-split">
      <div class="hs"><span class="hs-l">总成本</span>
        <span class="hs-v">{amount("31,600.00", "s")}</span></div>
      <div class="hs"><span class="hs-l">浮动盈亏</span>
        <span class="hs-v tone-up">{amount("6,400.00", "s", sign="+")}</span></div>
      <div class="hs"><span class="hs-l">收益率</span>
        <span class="hs-v tone-up">+20.25%</span></div>
    </div>
    <div class="hairline"></div>
  </section>
  <section class="grp"><div class="eyebrow">持仓 · 3 只</div>
    <div class="panel" style="padding:0 16px">{rows}</div></section>
  <div class="grp"><div class="panel notepanel">
    持仓成本为手工录入或买入时自动记账；<b>市值需要行情源</b> ——
    数据源选型是 V3.0 前的开放问题（免费源 / 用户手填 / 手动刷新三选一或多轨）。
    <span class="nl">在你选定之前，市值可按「最近一次手动估值」冻结显示。</span>
  </div></div>
  <div class="scroll-pad"></div>
</div></div>'''


def screen_loan():
    """SP-2-05 贷款摊销 —— 等额本息 / 等额本金 + 逐期本息拆分。"""
    sch = [(25, 1956.89, 272.24, 73142.41), (26, 1963.99, 265.14, 71178.42),
           (27, 1971.11, 258.02, 69207.31), (28, 1978.25, 250.88, 67229.06),
           (29, 1985.42, 243.71, 65243.64), (30, 1992.62, 236.51, 63251.02)]
    rows = ""
    for i, pri, itr, bal in sch:
        rows += (f'<span class="mut">第 {i} 期</span>'
                 f'<span class="r" style="font-weight:600">{pri:,.2f}</span>'
                 f'<span class="r mut">{itr:,.2f}</span>'
                 f'<span class="r">{bal:,.2f}</span>')
    return f'''<div class="screen">{statusbar()}
{topbar("贷款摊销")}
<div class="scroll">
  <section class="hero" style="padding-top:6px">
    <div class="hairline"></div>
    <div class="hero-label">剩余本金</div>
    <div class="hero-amt">{amount("75,099.30", "xl")}</div>
    <div class="hero-split">
      <div class="hs"><span class="hs-l">月供</span>
        <span class="hs-v">{amount("2,229.13", "s")}</span></div>
      <div class="hs"><span class="hs-l">已还</span><span class="hs-v">24 / 60 期</span></div>
      <div class="hs"><span class="hs-l">利率</span><span class="hs-v">4.35%</span></div>
    </div>
    <div class="hairline"></div>
  </section>
  <section class="grp"><div class="eyebrow">贷款参数</div>
    <div class="panel" style="padding:6px 0">
      {kvr("还款方式", "等额本息")}
      {kvr("贷款总额", "¥120,000.00")}
      {kvr("利息总额", "¥13,747.80")}
      {kvr("已还利息", "¥8,598.40")}
      <div style="padding:12px 16px">
        <div class="pbar"><i style="width:40.0%"></i></div>
        <div class="prowfoot" style="color:var(--muted);margin-top:8px">
          还款进度 40.0%（24 / 60 期）</div>
      </div>
    </div></section>
  <section class="grp"><div class="eyebrow">未来 6 期还款计划</div>
    <div class="panel" style="padding:8px 14px 6px">
      <div class="dtbl cols4">
        <span class="h">期次</span><span class="h r">本金</span>
        <span class="h r">利息</span><span class="h r">剩余余额</span>
        {rows}
      </div>
    </div></section>
  <div class="grp"><div class="panel notepanel">
    每期还款自动生成一条「还款」账单：<b>利息计入支出</b>，本金只减少负债、
    <b>不计入支出</b>（G-2）。
    <span class="nl">这样你看到的是「这个月真的花了多少利息」，
    而不是「我把本金挪了个地方也算花掉」。</span></div></div>
  <div class="scroll-pad"></div>
</div></div>'''


def screen_networth():
    """SP-2-06 净值追踪 —— 净值走势 + 资产构成 + 手动估值。

    ⚠️ 9 月净值 86,420.50 与资产页净资产同源。
    """
    hist = [("4月", 78300), ("5月", 79850), ("6月", 81400),
            ("7月", 83100), ("8月", 84700), ("9月", 86420.50)]
    mx = max(v for _, v in hist)
    bars = "".join(
        f'<i class="{"on" if i == len(hist) - 1 else ""}" '
        f'style="height:{v / mx * 100:.1f}%"></i>' for i, (_, v) in enumerate(hist))
    labels = "".join(f'<span>{m}</span>' for m, _ in hist)
    return f'''<div class="screen">{statusbar()}
{topbar("净值追踪")}
<div class="scroll">
  <section class="hero" style="padding-top:6px">
    <div class="hairline"></div>
    <div class="hero-label">当前净值（资产 − 负债）</div>
    <div class="hero-amt">{amount("86,420.50", "xl")}</div>
    <div class="hero-split">
      <div class="hs"><span class="hs-l">较上月</span>
        <span class="hs-v tone-up">{amount("1,720.50", "s", sign="+")}</span></div>
      <div class="hs"><span class="hs-l">环比</span><span class="hs-v tone-up">+2.03%</span></div>
    </div>
    <div class="hairline"></div>
  </section>
  <section class="grp"><div class="eyebrow">净值走势 · 近 6 个月</div>
    <div class="panel" style="padding:18px 16px 14px">
      <div class="minibars">{bars}</div>
      <div class="mblabels">{labels}</div>
    </div></section>
  <section class="grp"><div class="eyebrow">资产构成</div>
    <div class="panel" style="padding:16px">
      <div class="stack">
        <i style="width:58.4%;background:var(--cat-food)"></i>
        <i style="width:41.6%;background:var(--cat-fruit)"></i>
      </div>
      <div class="duocol" style="padding:0;border:0;min-height:34px">
        <span><span class="lgdot" style="background:var(--cat-food)"></span>现金与储蓄</span>
        <b>¥53,420.50 · 58.4%</b></div>
      <div class="duocol" style="padding:0;border:0;min-height:34px">
        <span><span class="lgdot" style="background:var(--cat-fruit)"></span>投资市值</span>
        <b>¥38,000.00 · 41.6%</b></div>
      <div class="duocol" style="padding:0;border:0;min-height:34px">
        <span><span class="lgdot" style="background:var(--faint)"></span>负债</span>
        <b>−¥5,000.00</b></div>
    </div></section>
  <div class="grp"><div class="panel notepanel">
    净值 = Σ资产 − Σ负债，与资产页<b>同一口径</b>（现金类账户）。
    <span class="nl">房 / 车等非现金资产靠<b>手动估值与折旧</b>录入，
    每 3 / 6 / 12 个月提醒你更新一次。</span>
    <span class="nl">净值曲线仅在估值口径一致时可比 —— 换了口径，图上会留一个标注点。</span>
  </div></div>
  <div class="scroll-pad"></div>
</div></div>'''


def screen_sankey():
    """SP-3-03 资金流向 —— 收入 → 各分类 → 结余。

    ⚠️ 5 类金额与报表环形图、首页 hero 完全同源，结余 3,420.50 = 首页结余。
    """
    inc = 9300.00
    H, TOP, INX, INW, OUTX, OUTW = 190.0, 18.0, 14.0, 14.0, 168.0, 14.0
    flows = [("food", "餐饮", 1881.44), ("shopping", "购物", 1411.08),
             ("other", "其他", 1058.31), ("transport", "交通", 823.13),
             ("housing", "居住", 705.54)]
    # ⚠️ 分类 ref 是 `fruit`（食材），不是 `grocery`。写成 var(--cat-grocery) 时
    #    该变量不存在 → `fill` 回退到**初始值 black**，收入条会渲染成一根黑柱，
    #    而不会报任何错。凡是引用分类色都必须用 01-tokens.json 里的 ref 原文。
    # ⚠️ fill 一律写在 style 里（`style="fill:var(--x)"`），属性形式对 var() 的解析
    #    各引擎不完全一致；style 形式与 donut 的做法一致。
    bands = labels = ""
    y = TOP
    for i, (ref, name, v) in enumerate(flows):
        h = v / inc * H
        y0, y1 = y, y + h
        y = y1
        my = (y0 + y1) / 2
        # 标签在 H 内均匀分布，底部留 30px 给「结余」一行 —— 否则最后一条
        # 分类标签会与结余标签叠在一起（实测差 6px）。
        ly = TOP + 16 + i * ((H - 40) / (len(flows) - 1))
        bands += (f'<path d="M{INX + INW} {y0 + 1.5} C 92 {y0 + 1.5}, 118 {my}, {OUTX} {my - 3.5} '
                  f'L {OUTX} {my + 3.5} C 118 {my + 3.5}, 92 {y1 - 1.5}, {INX + INW} {y1 - 1.5} Z" '
                  f'style="fill:var(--cat-{ref})" opacity=".32"/>'
                  f'<rect x="{OUTX}" y="{my - 3.5}" width="{OUTW}" height="7" rx="3" '
                  f'style="fill:var(--cat-{ref})"/>'
                  f'<path d="M{OUTX + OUTW} {my} L {OUTX + OUTW + 8} {ly}" '
                  f'stroke="currentColor" stroke-width="1" fill="none" opacity=".25"/>')
        labels += (f'<text x="{OUTX + OUTW + 12}" y="{ly + 3.5}" font-size="10.5" '
                   f'class="skl">{name} ¥{v:,.2f}</text>')
    left = inc - sum(v for _, _, v in flows)
    yl = TOP + H
    # ⚠️ 结余（36.8%）是**最大的一股流**，必须同样有色带 —— 早先只画了右侧小方块，
    #    左侧柱子的下 37% 变成一段「凭空截断」的空白，桑基图结构是残的。
    #    这里从收入柱剩余区间 (y_after → TOP+H) 补一条流到结余块。
    y_after = TOP + sum(v / inc * H for _, _, v in flows)
    left_band = (
        f'<path d="M{INX + INW} {y_after + 1.5} C 92 {y_after + 1.5}, 118 {yl}, {OUTX} {yl - 3.5} '
        f'L {OUTX} {yl + 3.5} C 118 {yl}, 92 {TOP + H - 1.5}, {INX + INW} {TOP + H - 1.5} Z" '
        f'style="fill:var(--ok-ink)" opacity=".28"/>')
    return f'''<div class="screen">{statusbar()}
{topbar("资金流向", right='<button class="textbtn">导出</button>')}
<div class="scroll">
  <section class="grp0"><div class="panel chartpanel">
    <div class="eyebrow">收入 → 支出 → 结余</div>
    <div class="sknote">2026年9月 · 记账月 9/1–9/30</div>
    <svg class="sankey" viewBox="0 0 330 254" preserveAspectRatio="xMidYMid meet">
      <rect x="{INX}" y="{TOP}" width="{INW}" height="{H}" rx="4"
        style="fill:var(--primary)"/>
      <text x="{INX}" y="{TOP - 6}" font-size="10" class="skc">收入</text>
      {bands}{left_band}{labels}
      <text x="{INX}" y="{TOP + H + 17}" font-size="12.5" font-weight="600" class="skv">¥9,300.00</text>
      <rect x="{OUTX}" y="{yl - 3.5}" width="{OUTW}" height="7" rx="3"
        style="fill:var(--ok-ink)"/>
      <text x="{OUTX + OUTW + 12}" y="{yl + 3.5}" font-size="10.5" class="skg">结余 ¥{left:,.2f}</text>
    </svg>
  </div></section>
  <section class="grp"><div class="eyebrow">收支汇总</div>
    <div class="panel" style="padding:6px 0">
      {kvr("总收入", f"¥{inc:,.2f}")}
      {kvr("总支出", f"¥{sum(v for _, _, v in flows):,.2f}")}
      {kvr("净结余", f"¥{left:,.2f}", "ok-ink")}
      {kvr("储蓄率", f"{left / inc * 100:.1f}%")}
    </div></section>
  <div class="grp"><div class="panel notepanel">
    桑基图回答的是「钱从哪来、流到哪去、最后剩多少」—— 比环形图更适合看结构，
    环形图更适合看占比。
    <span class="nl">色带宽度 = 金额，点任一色带可下钻至该分类的二级明细。</span>
  </div></div>
  <div class="scroll-pad"></div>
</div></div>'''


def screen_cross():
    """SP-3-04 交叉分析 —— 分类 × 账户透视。

    ⚠️ 行合计 = 报表 5 类金额；列合计 303.13 + 3,174.93 + 2,401.44 = 5,879.50。
    """
    cats = [("food", "餐饮", [180.00, 400.00, 1301.44]),
            ("shopping", "购物", [0, 311.08, 1100.00]),
            ("other", "其他", [0, 1058.31, 0]),
            ("transport", "交通", [123.13, 700.00, 0]),
            ("housing", "居住", [0, 705.54, 0])]
    accs = ["现金", "储蓄卡", "信用卡"]
    mx = max(v for _, _, row in cats for v in row)
    body = ('<span class="hd"></span>' + "".join(f'<span class="hc">{a}</span>' for a in accs))
    for ref, name, vals in cats:
        cells = ""
        for v in vals:
            if v == 0:
                cells += '<span class="cell mut">·</span>'
            else:
                alpha = v / mx * 0.62 + 0.10
                fg = "#FFFFFF" if alpha > 0.46 else "var(--ink-2)"
                cells += (f'<span class="cell" style="background:rgba(63,63,70,{alpha:.2f});'
                          f'color:{fg}">{v:,.0f}</span>')
        body += (f'<span class="hd"><span class="dot8" style="background:var(--cat-{ref})">'
                 f'</span>{name}</span>{cells}')
    return f'''<div class="screen">{statusbar()}
{topbar("交叉分析", right='<button class="textbtn">切维度</button>')}
<div class="scroll">
  <section class="grp0"><div class="panel" style="padding:16px">
    <div class="eyebrow" style="margin-left:0">分类 × 账户（9 月支出）</div>
    <div class="heat cols4">{body}</div>
    <div class="heatfoot">数值为金额（元）。颜色越深金额越大；「·」表示该分类在该账户上无消费。</div>
  </div></section>
  <section class="grp"><div class="eyebrow">读出来的结论</div>
    <div class="panel" style="padding:6px 0">
      {kvr("居住 · 全部走储蓄卡", "¥705.54")}
      {kvr("购物 · 全部走信用卡", "¥1,411.08")}
      {kvr("餐饮 · 过半刷信用卡", "¥1,301.44")}
      {kvr("交通 · 以储蓄卡为主", "¥700.00")}
      {kvr("现金合计（小额零星）", "¥303.13")}
      {kvr("信用卡合计", "¥2,401.44")}
    </div></section>
  <div class="grp"><div class="panel notepanel">
    交叉分析的价值在于「<b>发现异常组合</b>」—— 比如某个账户的某类支出突然变成主力，
    往往意味着你的支付习惯在悄悄改变。
  </div></div>
  <div class="scroll-pad"></div>
</div></div>'''


def screen_age():
    """SP-3-05 资金年龄 —— FIFO 口径，只读体检指标。"""
    hist = [("4月", 18), ("5月", 21), ("6月", 24), ("7月", 27), ("8月", 31), ("9月", 34)]
    mx = max(v for _, v in hist)
    bars = "".join(f'<i class="{"on" if i == len(hist) - 1 else ""}" '
                   f'style="height:{v / mx * 100:.1f}%"></i>' for i, (_, v) in enumerate(hist))
    labels = "".join(f'<span>{m}</span>' for m, _ in hist)
    return f'''<div class="screen">{statusbar()}
{topbar("资金年龄")}
<div class="scroll">
  <section class="hero" style="padding-top:6px">
    <div class="hairline"></div>
    <div class="hero-label">花掉的一块钱平均停留天数</div>
    <div class="hero-amt"><span class="amt xl"><span class="int">34</span><span class="dec" style="font-size:.5em">　天</span></span></div>
    <div class="hero-split">
      <div class="hs"><span class="hs-l">较上月</span><span class="hs-v">+3 天</span></div>
      <div class="hs"><span class="hs-l">近 6 月趋势</span><span class="hs-v">持续上升</span></div>
    </div>
    <div class="hairline"></div>
  </section>
  <section class="grp"><div class="eyebrow">近 6 个月</div>
    <div class="panel" style="padding:18px 16px 14px">
      <div class="minibars">{bars}</div>
      <div class="mblabels">{labels}</div>
    </div></section>
  <section class="grp"><div class="eyebrow">这个数字在说什么</div>
    <div class="panel" style="padding:6px 0">
      {kvr("≥ 30 天 · 有缓冲", "健康")}
      {kvr("15–30 天 · 收支同月", "正常")}
      {kvr("&lt; 15 天 · 月光警报", "偏低")}
      <div class="duocol" style="border-top:1px solid var(--line);min-height:44px">
        <span style="font-weight:600">当前判定</span>
        <b style="color:var(--ok-ink)">健康 · 有缓冲</b></div>
    </div></section>
  <div class="grp"><div class="panel notepanel">
    计算口径：<b>FIFO（先进先出）</b>。每笔支出都从最早的收入里扣，
    扣到哪一天的余额就记多少天，最后取加权平均。
    <span class="nl">这是一种「体检指标」，不参与任何记账流程，<b>只读不写</b>。</span>
  </div></div>
  <div class="scroll-pad"></div>
</div></div>'''


def screen_budget():
    """SP-5-09 预算 —— 四种方法论；进度条三级着色（§24）。

    ⚠️ 实际支出取自报表同源 5 类的金额（交通超支 / 购物接近阈值）。
    """
    methods = ["分类限额", "信封预算", "零基预算", "50-30-20"]
    segs = "".join(f'<button class="segi{" on" if i == 0 else ""}">{m}</button>'
                   for i, m in enumerate(methods))
    plan = [("housing", 4600, 705.54), ("food", 3000, 1881.44),
            ("shopping", 1500, 1411.08), ("transport", 600, 823.13),
            ("entertainment", 300, 0.0)]
    tot_l = sum(l for _, l, _ in plan)
    tot_u = sum(u for _, _, u in plan)
    p = tot_u / tot_l * 100
    rows = "".join(pct_row(r, 0, u, l) for r, l, u in plan)
    return f'''<div class="screen">{statusbar()}
{topbar("预算", right='<button class="textbtn">新建</button>')}
<div class="segwrap top"><div class="seg">{segs}</div></div>
<div class="scroll">
  <section class="grp0"><div class="hero" style="padding-top:2px">
    <div class="hairline"></div>
    <div class="hero-label">本月预算已用</div>
    <div class="hero-amt">{p:.1f}<span style="font-size:.52em;font-weight:600">%</span></div>
    <div class="hero-split">
      <div class="hs"><span class="hs-l">已花</span>
        <span class="hs-v">{amount(f"{tot_u:,.2f}", "s")}</span></div>
      <div class="hs"><span class="hs-l">预算</span>
        <span class="hs-v">{amount(f"{tot_l:,.2f}", "s")}</span></div>
      <div class="hs"><span class="hs-l">剩余</span>
        <span class="hs-v">{amount(f"{tot_l - tot_u:,.2f}", "s")}</span></div>
    </div>
    <div class="hairline"></div>
  </div></section>
  <section class="grp"><div class="eyebrow">分类限额 · 5 类</div>
    <div class="panel" style="padding:0 16px">{rows}</div></section>
  <div class="grp"><div class="panel notepanel">
    <b>四套方法论：</b>信封（每类一个信封，花完即止） / 零基（收入全部预先分配，余额为 0）
    / 50-30-20（必要 50 · 想要 30 · 储蓄 20） / 分类限额（最轻量）。
    <span class="nl">进度条三级着色与「是否响铃通知」绑定（G-3）：
    <b>90% 静默提醒、100% 响铃通知</b>，但两者都不阻挡你继续记账。</span>
  </div></div>
  <div class="scroll-pad"></div>
</div></div>'''


def screen_family():
    """SP-5-10 家庭与成员 —— 共享账本、三种角色（G-5 与记账伙伴不共用）。

    ⚠️ 成员头像是**图标**，不是姓名首字 —— 硬禁令里「禁汉字图标」。
       用「我 / 配 / 孩」当头像看似是头像惯例，但在本项目的规则下与
       「拿汉字当图标」无法区分，直接规避。色块 + 图标同样能区分成员。
    """
    members = [("我（李振宇）", "所有者", "primary", "—", "ic_nav_profile"),
               ("配偶", "成员", "cat-social", "¥4,282.00", "ic_nav_profile"),
               ("孩子", "只读", "warn-ink", "—", "ic_eye")]
    rows = "".join(
        f'<div class="row" style="min-height:64px">'
        f'<span class="avt" style="background:var(--{c});color:var(--on-primary)">'
        f'{ic(i, 17)}</span>'
        f'<span class="rcol"><span class="rt">{n}</span>'
        f'<span class="sub">{role}{" · 本月支出 " + sp if sp != "—" else ""}</span></span>'
        f'<span class="sval" style="color:var(--primary-ink)">管理</span></div>'
        for n, role, c, sp, i in members)
    return f'''<div class="screen">{statusbar()}
{topbar("家庭与成员", right='<button class="textbtn">邀请</button>')}
<div class="scroll">
  <section class="grp0"><div class="panel notepanel">
    共享账本：多人共同记同一本账，数据实时互见。
    <b>与「记账伙伴」不同</b> —— 伙伴只是别人帮你记，不共享你的账本（G-5，两套边界不共用）。
  </div></section>
  <section class="grp"><div class="eyebrow">账本</div>
    <div class="panel">
      <div class="row"><span class="rcol"><span class="rt">家庭共享账本</span>
        <span class="sub">3 名成员 · 本月共同记账 47 笔</span></span>{switch(True)}</div>
      <div class="row"><span class="rcol"><span class="rt">成员消费可见性</span>
        <span class="sub">所有成员可见全部账单</span></span>
        {ic("ic_chevron_right", 16, "chev")}</div>
    </div></section>
  <section class="grp"><div class="eyebrow">成员与权限 · 3 人</div>
    <div class="panel">{rows}</div></section>
  <div class="grp"><div class="panel notepanel">
    三种角色：<b>所有者</b>（可增删成员、改权限、删除账本） / <b>成员</b>（可记账、可改自己的账）
    / <b>只读</b>（只能看）。
    <span class="nl">成员看到的分类与主题仍是<b>各自本机偏好</b>，不会被账本同步覆盖。</span>
  </div></div>
  <div class="scroll-pad"></div>
</div></div>'''


def screen_api():
    """SP-5-11 开放接口 —— 默认关闭，最小必要权限。"""
    def ar(icon, title, sub, on=False, disabled=False):
        sw = ('<span class="switch lock"><span class="knob"></span></span>'
              if disabled else switch(on))
        subh = f'<span class="sub">{sub}</span>' if sub else ""
        return (f'<div class="row"><span class="ricos">{ic(icon, 20)}</span>'
                f'<span class="rcol"><span class="rt">{title}</span>{subh}</span>{sw}</div>')
    return f'''<div class="screen">{statusbar()}
{topbar("开放接口")}
<div class="scroll">
  <section class="grp0"><div class="panel notepanel">
    <b>默认关闭。</b>开放接口会让外部程序读写你的账本，
    请只在明确需要时开启，并逐项限定权限范围。
  </div></section>
  <section class="grp"><div class="eyebrow">接口</div>
    <div class="panel">
      {ar("ic_cloud", "本地 REST API", "仅监听 127.0.0.1，不暴露到局域网")}
      {ar("ic_share", "MCP 服务（给 LLM 用）", "供 Claude / Cursor 等客户端读取账本")}
      <div class="row"><span class="ricos">{ic("ic_qr", 20)}</span>
        <span class="rcol"><span class="rt">访问令牌</span>
        <span class="sub">一次生成、可随时吊销</span></span>
        <span class="sval" style="color:var(--primary-ink)">复制</span></div>
    </div></section>
  <section class="grp"><div class="eyebrow">权限范围（最小必要）· 接口开启后生效</div>
    <div class="panel">
      {ar("ic_eye", "读取账单与分类", "", True)}
      {ar("ic_budget", "读取预算与目标", "", True)}
      {ar("ic_edit", "写入账单", "建议保持关闭，写入走导入更安全")}
      {ar("ic_delete", "删除数据", "默认永不可授予", False, True)}
    </div></section>
  <div class="grp"><div class="panel notepanel">
    接口只在<b>本机回环地址</b>监听，不经过任何服务器 ——
    你的账本不会因为「开放」而离开这台设备。
    <span class="nl">MCP 侧默认<b>只读</b>，写入需要单独勾选并二次确认。</span>
  </div></div>
  <div class="scroll-pad"></div>
</div></div>'''


def screen_desk():
    """SP-6-01 桌面端与多端 —— 四端能力矩阵。"""
    ends = [("手机（iOS / Android）", "已支持", "3 秒记账 · 点分类即保存", True),
            ("平板（iPad / Android Pad）", "已支持", "双栏布局 · 侧栏常驻 · 手写备注", True),
            ("桌面（Windows / macOS）", "V3.0", "全键盘操作 · 批量录入 · 报表打印", False),
            ("Web（浏览器）", "V3.0", "免安装查看与导出 · 只读为主", False)]
    rows = ""
    for name, state, desc, ok in ends:
        rows += (f'<div class="row" style="min-height:68px">'
                 f'<span class="ricos" style="color:var(--{"ok-ink" if ok else "muted"})">'
                 f'{ic("ic_status_success" if ok else "ic_status_info", 22)}</span>'
                 f'<span class="rcol"><span class="rt">{name}</span>'
                 f'<span class="sub">{desc}</span></span>'
                 f'<span class="tagx {"done" if ok else "silent"}">{state}</span></div>')
    return f'''<div class="screen">{statusbar()}
{topbar("桌面端与多端")}
<div class="scroll">
  <section class="grp0"><div class="panel notepanel">
    Flutter 工程结构<b>已含 macos / web / windows 目录</b> ——
    四端不是「将来重做」，而是「逐步点亮」。
    <span class="nl">这决定了桌面端的边际成本远低于重写。</span>
  </div></section>
  <section class="grp"><div class="eyebrow">四端能力矩阵</div>
    <div class="panel">{rows}</div></section>
  <section class="grp"><div class="eyebrow">桌面端差异化能力（V3.0）</div>
    <div class="panel" style="padding:6px 0">
      {kvr("全键盘录账（Tab 跳转 / Enter 保存）", "规划")}
      {kvr("CSV / Excel 批量导入与去重", "规划")}
      {kvr("报表导出 PDF 并打印", "规划")}
      {kvr("多账本同开（侧栏切换）", "规划")}
    </div></section>
  <div class="grp"><div class="panel notepanel">
    桌面端与 Web 端的<b>先后顺序是开放问题</b>：Web 先行可以覆盖「临时在别人电脑上查账」，
    macOS 先行则贴近重度用户。
    <span class="nl">建议在 V2.0 云同步落地后按真实用量决定。</span>
  </div></div>
  <div class="scroll-pad"></div>
</div></div>'''


# ═══════════════════════════════════════════════════════════════════ 29 屏清单
#
# 与 03 的 SCREENS 表（SP 编号 / 名称）一一对应；分组与 14-pages.js 的
# CHIP_GROUPS 一致。前 8 屏直接复用 gen_screens 的实现（保证与 07-SCREENS.html
# 像素一致），其余 21 屏为本文件新增。

SCREENS = [
    # ── V1.0 基线 ──
    ("SP-0-01 首次启动与权限引导", lambda: G.screen_guide("zh")),
    ("SP-0-02 首页流水", lambda: G.screen_home("zh")),
    ("SP-1-01 记账输入页", lambda: G.screen_add("zh")),
    ("SP-1-02 账单详情", lambda: G.screen_detail("zh")),
    ("SP-1-03 分类管理", lambda: G.screen_categories("zh")),
    ("SP-2-01 账户管理", lambda: G.screen_assets("zh")),
    ("SP-3-01 报表页", lambda: G.screen_reports("zh")),
    ("SP-4-01 备份与恢复", screen_backup),
    ("SP-5-01 发现", screen_find),
    ("SP-5-02 主题", screen_theme),
    ("SP-5-03 我的（设置）", lambda: G.screen_settings("zh")),
    # ── V2.0 交易精度与主动管家 ──
    ("SP-1-04 转账 / 借出 / 借入", screen_addplus),
    ("SP-1-05 分割交易编辑器", screen_split),
    ("SP-1-06 报销中心", screen_claim),
    ("SP-2-02 信用卡账单详情", screen_cardbill),
    ("SP-5-04 提醒中心", screen_remind),
    ("SP-5-05 自动规则", screen_rule),
    ("SP-5-06 储蓄目标与基金", screen_goal),
    ("SP-5-07 首页卡片自定义", screen_card),
    # ── V3.0 资产完整性与方法论 ──
    ("SP-2-04 投资持仓", screen_invest),
    ("SP-2-05 贷款摊销", screen_loan),
    ("SP-2-06 净值追踪与资产估值", screen_networth),
    ("SP-3-03 资金流向（Sankey）", screen_sankey),
    ("SP-3-04 交叉分析", screen_cross),
    ("SP-3-05 资金年龄", screen_age),
    ("SP-5-09 预算（四种方法论）", screen_budget),
    ("SP-5-10 家庭与成员", screen_family),
    ("SP-5-11 开放接口（API / MCP）", screen_api),
    ("SP-6-01 桌面端与多端", screen_desk),
]

GROUPS = [
    ("V1.0 基线 · 11 屏", 0, 11),
    ("V2.0 交易精度与主动管家 · 8 屏", 11, 19),
    ("V3.0 资产完整性与方法论 · 10 屏", 19, 29),
]

# ── 21 屏新增用到的屏内小件 ──
SANK_STYLE = """
/* 桑基图 */
.sankey{display:block;width:100%;height:auto;margin-top:2px}
.skl{fill:var(--ink)}
.skc{fill:var(--ink-2)}
.skv{fill:var(--ink)}
.skg{fill:var(--ok-ink)}
.sknote{font-size:calc(12px * var(--tscale));font-weight:500;color:var(--muted);
  margin:-4px 0 10px}
/* 热力表脚注 */
.heatfoot{margin-top:10px;font-size:calc(12px * var(--tscale));color:var(--muted);
  line-height:1.6}
/* 头像圆片 */
.avt{width:30px;height:30px;border-radius:10px;flex:0 0 30px;display:flex;
  align-items:center;justify-content:center;font-size:14px;font-weight:600}
"""


def build():
    body_cls = 'data-theme="subai" data-mode="light"'
    theme_css = G.theme_vars("subai", "light")
    # 主题页的 10 组色卡：值来自 01-tokens.json 的 resolved（各主题 light 档），
    # 以变量形式注入，页面侧只写 var(--th-xxx-p) —— 保证交付物里没有裸色号。
    swatch = "\n".join(
        f"  --th-{tid}-p: {G.TOK['resolved'][f'{tid}.light']['primary']};\n"
        f"  --th-{tid}-a: {G.TOK['resolved'][f'{tid}.light']['accent']};"
        for tid, _, _ in THEMES10)

    parts = []
    for label, a, b in GROUPS:
        parts.append(f'<h2 class="vergrouph">{label}</h2>')
        for i in range(a, b):
            title, fn = SCREENS[i]
            parts.append(f'<section class="frame" data-screen="{i}">'
                         f'<div class="flabel">{title}</div>'
                         f'<div class="bezelless">{fn()}</div></section>')
    frames = "".join(parts)

    html = f"""<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>素记 Plain · 全部页面高保真 · 亮态中文</title>
<style>
{CSS}
{SANK_STYLE}
/* ── 单一配色：素白 · 亮态（值全部来自 01-tokens.json，页面里没有裸色号） ── */
.stage{{
{theme_css}
{swatch}
}}
</style></head>
<body {body_cls}>
{G.sprite()}
<div class="toolbar">
  <div class="tb-brand">素记 Plain · 全部页面<small>Quiet Ledger · 亮态中文 · 29 屏</small></div>
  <div class="tb-group"><span class="tb-lab">跳屏</span>
    <div class="screenpicker">
      <button data-jump="0">引导</button><button data-jump="1">流水</button>
      <button data-jump="2">记一笔</button><button data-jump="3">详情</button>
      <button data-jump="4">分类</button><button data-jump="5">资产</button>
      <button data-jump="6">报表</button><button data-jump="7">备份</button>
      <button data-jump="8">发现</button><button data-jump="9">主题</button>
      <button data-jump="10">我的</button><button data-jump="11">转账</button>
      <button data-jump="12">分割</button><button data-jump="13">报销</button>
      <button data-jump="14">信用卡</button><button data-jump="15">提醒</button>
      <button data-jump="16">规则</button><button data-jump="17">目标</button>
      <button data-jump="18">首页卡片</button><button data-jump="19">投资</button>
      <button data-jump="20">贷款</button><button data-jump="21">净值</button>
      <button data-jump="22">资金流向</button><button data-jump="23">交叉分析</button>
      <button data-jump="24">资金年龄</button><button data-jump="25">预算</button>
      <button data-jump="26">家庭</button><button data-jump="27">开放接口</button>
      <button data-jump="28">桌面端</button>
    </div></div>
</div>
<div class="stage">
{frames}
</div>
<script>
(function () {{
  document.querySelectorAll('.screenpicker button').forEach(function (b) {{
    b.addEventListener('click', function () {{
      var f = document.querySelector('.frame[data-screen="' + b.dataset.jump + '"]');
      if (f) f.scrollIntoView({{ behavior: 'smooth', block: 'start' }});
      document.querySelectorAll('.screenpicker button').forEach(function (x) {{
        x.classList.toggle('on', x === b);
      }});
    }});
  }});
}})();
</script>
</body></html>
"""
    errs = guard(html)
    if errs:
        print("!! 自检未通过，已拒绝写盘：")
        for e in errs:
            print("   -", e)
        return 1
    out = os.path.join(ROOT, "单独确认.html")
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(html)
    print("written:", out, len(html), "bytes")
    print("screens:", len(SCREENS))
    print("guard: ok")
    return 0


def guard(html):
    """静默失败自检 —— 这两类错误浏览器都不会报错，只会渲染成透明/空白。

    ① var(--x) 引用了不存在的变量：fill 回退 black、background 回退 transparent。
       本文件已经栽过两次（--cat-grocery 实为 fruit；--disabledBg 实为 --disabled-bg）。
    ② <use href="#x"> 指向不存在的 <symbol>：整枚图标渲染为空白。
       （本文件栽过一次：ic_nav_me 实为 ic_nav_profile。）
    """
    import re

    errs = []
    defined = set(re.findall(r"(--[A-Za-z0-9_-]+)\s*:", html))
    used = set(re.findall(r"var\(\s*(--[A-Za-z0-9_-]+)", html))
    for v in sorted(used - defined):
        errs.append(f"var() 引用了未定义的变量: {v}")

    symbols = set(re.findall(r'<symbol[^>]*id="([^"]+)"', html))
    for u in sorted(set(re.findall(r'<use[^>]*href="#([^"]+)"', html)) - symbols):
        errs.append(f"<use> 指向不存在的 <symbol>: {u}")
    return errs


if __name__ == "__main__":
    raise SystemExit(build())
