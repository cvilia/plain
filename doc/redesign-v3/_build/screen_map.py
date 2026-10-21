"""29 屏的落地映射表 + 文案分类规则。

`gen_coding_brief.py`（生成指令文档）与 `check_screen_coverage.py`（门禁）
**共用本文件**，避免两处各写一份映射表、改一处忘另一处。

屏号 / slug 来自 `13-ALL-SCREENS-ASSETS/`（`NN-slug.png`，与 `单独确认.html` 帧序 1:1）。
`target` 一律相对 `plain/`，即 `C:\\Users\\lizhenyu\\WorkBuddy\\Dev\\PlainApp\\plain\\`。
"""
import re

# ── 文案分类 ─────────────────────────────────────────────────────────
# DATA_CLASSES 上的文案属于「样例数据」：同一位置的数字本来就该随真实数据变，
# 门禁不比对。其余一律视为「结构性文案」，必须能在代码里找到。
DATA_CLASSES = {
    # 金额四段式与各类金额
    "amt", "cur", "int", "dec", "pnt", "xl", "s", "pamt", "rw-amt",
    "dn-c1", "dn-dec", "dn-cur", "dn-c2", "expr", "lpct", "lamt", "skv", "cv",
    # 计数 / 备注 / 其它随数据变的
    "cnt", "ricnt", "ml", "val", "kvr", "sval",
    # 设备状态栏（系统画的，不是 App 内容）
    "sb-time", "sb-marks",
}

# 受用户数据影响、只能软比对（命中率作参考，不判失败）
SOFT_CLASSES = {"drow", "tile-n", "sub", "rt", "avt", "lname", "thsw",
                "prowname", "note", "tagx"}

SKIP_PATTERNS = [
    re.compile(r"^\d{4}年\d{1,2}月\d{1,2}日"),                # 2026年9月28日 12:34
    re.compile(r"^\d{4}年\d{1,2}月$"),                         # 2026年9月（页标题，由数据算）
    re.compile(r"^\d{1,2}月\d{1,2}日"),                        # 9月27日 周六
    re.compile(r"^[¥$]"),                                      # ¥1,881
    re.compile(r"^[-+−]?[\d,\.]+(%|倍|天|期|笔|个|条|日)?$"),  # 1,301 / 12.4%
    re.compile(r"^\d{1,2}:\d{2}$"),                            # 14:55
    re.compile(r"^[A-Za-z0-9\-_/\.]{1,24}$"),                  # 型号 / 尾号 / 版本号
]


def is_data(cls, value):
    """样例数据 / 用户数据 / 设备信息 → 门禁不比对。"""
    if set((cls or "").split()) & DATA_CLASSES:
        return True
    return any(p.match(value) for p in SKIP_PATTERNS)


def is_soft(cls):
    return bool(set((cls or "").split()) & SOFT_CLASSES)


# ── 运行时拼接的值 ───────────────────────────────────────────────────
# 设计稿写的是**渲染结果**，代码里写的是**模板 + 数据**，字面量必然搜不到。
# 例：屏 23 的 `餐饮 ¥1,881.44` 由 `'${f.label} ${formatAmountYuan(...)}'`
# 拼出，源码里只有 `'餐饮'` 与 `1881.44` 两处 —— 硬比对会误报成「缺失」。
# 规则：把值拆成「词」与「数值」，**两者都必须在源码里出现**（不要求相邻）
# 才算命中。既不放过真缺口，也不会把拼出来的结果当成没写。
#
# 量词后缀：`gen_screens.py` 的文案是**模板参数**（`month_note="记账月起始：10 日"`），
# 渲染出来量词跟在数值后面 —— `10` 是样例数据，`记账月起始：` 与 ` 日` 才是结构。
# 与 SKIP_PATTERNS 对 `2026年9月` 的处理同源，只是数值不在句尾。故在数值后
# 允许一个量词，否则这类文案会被误报成「缺失」（屏 2 / 屏 7 就栽在这）。
UNIT_SUFFIX = "小时|分钟|天|日|周|月|年|笔|个|条|期|次|倍|人|张|只|份|元|角|分|秒|页|项|级|岁"
COMPOSED_RE = re.compile(
    r"^(?P<words>.+?)\s*(?P<num>[¥$]?\s*[-−+]?\d[\d,]*(?:\.\d+)?)\s*"
    r"(?:(?:%|‰|" + UNIT_SUFFIX + r"))?$"
)
_NUM_JUNK = str.maketrans("", "", "¥$, ")


def composed_parts(value):
    """「词 + 数值（+ 量词）」形态 → (词, 数值)；拆不出词（即纯数值）时返回 None。"""
    m = COMPOSED_RE.match(value.strip())
    if not m:
        return None
    words = m.group("words").strip(" ·—-—")
    if len(words) < 2:
        return None
    num = m.group("num").translate(_NUM_JUNK).strip("-−+")
    if not num:
        return None
    return words, num


def composed_hit(value, hay_flat):
    """`hay_flat` 必须是**去掉千分位逗号**的全量源码。"""
    p = composed_parts(value)
    if not p:
        return False
    words, num = p
    words = words.replace(",", "")
    return words in hay_flat and num in hay_flat


def screen_texts(sc):
    """把一屏的实测文案分成三堆，各项为 (cls, value, tag)。

    hard = 结构性文案，必须能在代码里找到（门禁硬比对）
    soft = 受用户数据影响，按语义落地即可（只统计）
    data = 样例数据 / 设备信息（不比对）
    """
    hard, soft, data = [], [], []
    for it in sc.get("items", []):
        t = it.get("txt")
        if not t or not t.get("v"):
            continue
        v = t["v"].strip()
        if len(v) < 2:
            continue
        cls = it.get("cls") or ""
        row = (cls, v, it.get("tag") or "")
        if is_data(cls, v):
            data.append(row)
        elif is_soft(cls):
            soft.append(row)
        else:
            hard.append(row)
    dedup = lambda xs: list(dict.fromkeys(xs))
    return dedup(hard), dedup(soft), dedup(data)


# ── 29 屏映射表 ──────────────────────────────────────────────────────
# 状态：aligned = 上一轮 8 屏批次已按设计改过
#       rework  = 有 V1.0 旧页，需按新设计改造
#       new     = 目前没有任何页面，要新建
#       shell   = 不新建页面，改既有的壳 / 布局 / 组件
SCREENS = [
    (1, "guide", "SP-0-01 首次启动与权限引导", "aligned",
     "lib/features/settings/onboarding_page.dart",
     "品牌字标 → 三条卖点 → 主按钮 的三段式引导"),
    (2, "ledger", "SP-0-02 首页流水", "aligned",
     "lib/features/ledger/presentation/flow_list_page.dart",
     "hero 结余区 + 按日分组的流水 + 底部导航"),
    (3, "add", "SP-1-01 记账输入页", "aligned",
     "lib/features/ledger/presentation/entry_input_page.dart",
     "金额区 + 属性 chip + 分类格 + 数字键盘"),
    (4, "detail", "SP-1-02 账单详情", "aligned",
     "lib/features/ledger/presentation/entry_detail_page.dart",
     "金额 hero + 明细行 + 危险区"),
    (5, "categories", "SP-1-03 分类管理", "aligned",
     "lib/features/settings/category_manage_page.dart",
     "支出/收入 分段 + 分类行（图标 + 名称 + 笔数 + 拖拽柄）+ 新建分类"),
    (6, "assets", "SP-2-01 账户管理", "aligned",
     "lib/features/accounts/accounts_page.dart",
     "净值 hero + 账户分组面板"),
    (7, "reports", "SP-3-01 报表页", "aligned",
     "lib/features/reports/reports_page.dart",
     "结余卡 + 环形图 + 分类图例 + 日趋势柱 + 月对比"),
    (8, "backup", "SP-4-01 备份与恢复", "rework",
     "lib/features/settings/backup_page.dart",
     "说明面板 + 两个动作按钮 + 空态"),
    (9, "find", "SP-5-01 发现", "new",
     "lib/features/discover/discover_page.dart",
     "★ 新页：按能力分组的全功能入口目录（我那里被搬走的入口都在这）"),
    (10, "theme", "SP-5-02 主题", "rework",
     "lib/features/settings/theme_page.dart",
     "分段（浅色/深色/跟随系统）+ 10 主题色卡网格 + 说明面板"),
    (11, "settings", "SP-5-03 我的（设置）", "aligned",
     "lib/features/settings/settings_page.dart",
     "★ 精简：数据组只留「备份与恢复 / 批量导入」，其余 11 项搬到发现页"),
    (12, "addplus", "SP-1-04 转账 / 借出 / 借入", "rework",
     "lib/features/ledger/presentation/entry_input_page.dart",
     "在记账页加「转账/借出/借入」三态：双账户选择 + 保存后影响说明"),
    (13, "split", "SP-1-05 分割交易编辑器", "new",
     "lib/features/ledger/presentation/split_editor_page.dart",
     "★ 新页：一笔记账拆到多个分类，带已分配进度与「已对平」判定"),
    (14, "claim", "SP-1-06 报销中心", "rework",
     "lib/features/settings/reimburse_center_page.dart",
     "hero 待收回金额 + 待报销/已提交 两个分组"),
    (15, "cardbill", "SP-2-02 信用卡账单详情", "rework",
     "lib/features/accounts/credit_reconcile_page.dart",
     "hero 本期应还 + 账户参数键值表 + 进度条 + 风险说明"),
    (16, "remind", "SP-5-04 提醒中心", "rework",
     "lib/features/settings/reminders_page.dart",
     "分段（全部/预算/账单/周期）+ 带色点与静音标记的提醒行"),
    (17, "rule", "SP-5-05 自动规则", "rework",
     "lib/features/settings/automation_rules_page.dart",
     "规则列表（序号 + 条件→动作 + 开关）+ 优先级说明面板"),
    (18, "goal", "SP-5-06 储蓄目标与基金", "rework",
     "lib/features/settings/savings_goals_page.dart",
     "hero 总进度 + 目标进度行（名称/金额/进度条/月需存入）"),
    (19, "homecards", "SP-5-07 首页卡片自定义", "rework",
     "lib/features/settings/home_layout_page.dart",
     "可选卡片行（开关 + 计数）+ 至少 1 张 / 最多 4 张 的约束文案"),
    (20, "invest", "SP-2-04 投资持仓", "new",
     "lib/features/assets/investment_page.dart",
     "★ 新页：持仓总市值/总成本/浮动盈亏 hero + 持仓行 + 涨跌色"),
    (21, "loan", "SP-2-05 贷款摊销", "new",
     "lib/features/assets/loan_page.dart",
     "★ 新页：贷款参数键值表 + 四列摊销表 + 进度条"),
    (22, "networth", "SP-2-06 净值追踪与资产估值", "new",
     "lib/features/assets/net_worth_page.dart",
     "★ 新页：当前净值 hero + 迷你柱状趋势 + 资产负债表"),
    (23, "sankey", "SP-3-03 资金流向（Sankey）", "new",
     "lib/features/reports/sankey_page.dart",
     "★ 新页：收入→支出→结余三列桑基图 + 分类标签"),
    (24, "cross", "SP-3-04 交叉分析", "new",
     "lib/features/reports/cross_analysis_page.dart",
     "★ 新页：切维度 + 分类×账户 热力表"),
    (25, "age", "SP-3-05 资金年龄", "new",
     "lib/features/reports/money_age_page.dart",
     "★ 新页：平均停留天数 hero + 近 6 月迷你柱 + 分档说明"),
    (26, "budget", "SP-5-09 预算（四种方法论）", "rework",
     "lib/features/settings/budget_page.dart",
     "分段切换 4 种方法论 + 预算进度行 + 超支警示"),
    (27, "family", "SP-5-10 家庭与成员", "new",
     "lib/features/family/family_page.dart",
     "★ 新页：成员行（头像 + 角色 + 开关）+ 邀请 + 共享账本说明"),
    (28, "api", "SP-5-11 开放接口（API / MCP）", "new",
     "lib/features/settings/api_page.dart",
     "★ 新页：总开关 + 逐项权限行 + 风险说明面板"),
    (29, "desk", "SP-6-01 桌面端与多端", "new",
     "lib/features/settings/platform_page.dart",
     "★ 新页：四端能力矩阵（含「已支持 / V3.0」标签）+ 已规划能力清单"),
]

# 既有壳与组件（不占屏号，但必须一起改）
SHELL = [
    ("lib/features/ledger/presentation/home_shell.dart",
     "底部导航：4 个页签 + 中央 navfab（44×44 / r12）"),
    ("lib/design_system/plain_ui.dart",
     "组件层：补 PlainTopBar / PlainPrimaryButton / PlainDangerButton / PlainSeg"),
    ("lib/app/theme/app_colors.dart",
     "★ 补 38 个令牌桥接（现在只桥了 26/63，v3 新增的 10 个一个都没有）"),
    ("lib/app/l10n/app_strings.dart",
     "文案表：设计里的结构性文案统一进这里，别散落在各页字符串里"),
]


def by_no(no):
    for s in SCREENS:
        if s[0] == no:
            return s
    raise KeyError(no)
