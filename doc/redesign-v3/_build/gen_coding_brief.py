"""生成《编码指令-29屏UI对齐.md》—— 喂给另一个编码 Agent 的分批执行指令。

**为什么要有这个脚本**：29 屏的「必现控件 / 必现文案」共 445 条结构性文案，
手工抄进指令文档必然漏、且设计一改就两边不一致。所以 §2 的逐屏清单
**全部从 `spec.json` 机读生成**，文档头标明生成时间与重生成命令。

产出：`PlainApp/编码指令-29屏UI对齐.md`

用法：python gen_coding_brief.py
"""
import json
import os
import datetime

import screen_map as SM


HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
PROJ = os.path.normpath(os.path.join(ROOT, ".."))
PLAIN_ROOT = os.path.join(PROJ, "plain")
OUT = os.path.join(PROJ, "编码指令-29屏UI对齐.md")
SPEC_JSON = os.path.join(HERE, "spec.json")

# 控件中文名（与 gen_annotated.LABEL 同口径，只列本案会用到的）
LBL = {
    "topbar": "顶栏", "h1": "页面标题", "tb-right": "顶栏·右侧操作", "iconbtn": "图标按钮",
    "statusbar": "状态栏", "scroll": "滚动内容区", "hero": "首屏区",
    "hero-label": "首屏区·标签", "hero-amt": "首屏区·主金额", "hero-split": "首屏区·分栏",
    "hs-l": "分栏小项·标签", "hs-v": "分栏小项·值", "eyebrow": "分组小标题",
    "panel": "面板", "notepanel": "说明面板", "chartpanel": "图表面板",
    "cmppanel": "对比面板", "row": "列表行", "rcol": "行·文字列", "rt": "行·标题",
    "ricos": "行·图标位", "sub": "行·副标题", "sval": "行·右侧值", "chev": "右箭头",
    "hairline": "分割线", "nav": "底部导航", "navitem": "导航项", "navlab": "导航项文字",
    "navfab": "导航·中央按钮", "switch": "开关", "knob": "开关滑块",
    "seg": "分段控件", "segi": "分段项", "segwrap": "分段容器", "ttabs": "类型页签组",
    "ttab": "类型页签", "btn": "主按钮", "btn2": "次要按钮", "textbtn": "文字按钮",
    "pbar": "进度条", "pbarwrap": "进度条容器", "prow": "进度行", "prowname": "进度行·名称",
    "pamt": "进度行·金额", "prowfoot": "进度行·脚注", "crow2": "对比行",
    "duocol": "双列容器", "cicon": "行·图标", "cnt": "计数", "ricnt": "计数徽标",
    "drag": "拖拽柄", "kvr": "键值行", "avt": "成员头像", "tagx": "标签",
    "thsw": "主题色卡", "thtick": "主题色卡·勾选", "tile": "分类格", "tile-n": "分类格名称",
    "catgrid": "分类格网格", "keypad": "数字键盘", "key": "键盘键", "ok": "OK 键",
    "attrchips": "属性 chip 组", "chip": "chip", "amount-block": "金额区",
    "donut": "环形图", "donut-wrap": "环形图容器", "legend": "图例", "lrow": "图例行",
    "lname": "图例·名称", "lpct": "图例·占比", "lamt": "图例·金额",
    "bars": "柱状图", "minibars": "迷你柱图", "sankey": "桑基图",
    "skc": "桑基·列标题", "skl": "桑基·分类标签", "skv": "桑基·金额",
    "heat": "热力表", "cell": "单元格", "cols4": "四列容器", "dtbl": "数据表",
    "prow": "进度行", "emptybox": "空态框", "emptyic": "空态图形",
    "qrcode": "二维码", "ntab": "导航页签", "duocol": "双列容器",
    "nl": "说明文字", "fs": "卖点·副句", "ft": "卖点·主句",
    "guide-h": "引导·主标题", "guide-p": "引导·副标题", "wordmark": "字标",
    "foot-note": "脚注", "sknote": "桑基·说明", "hc": "热力单元格",
    "hd": "热力表·表头", "heatfoot": "热力表·脚注", "mblabels": "迷你柱·月份",
    "skg": "桑基·结余标签", "lgdot": "图例色点", "dot8": "色点 8", "dot6": "色点 6",
    "ps": "隐私条·副句", "pt": "隐私条·主句", "sicon": "设置行·图标",
    "srow": "设置行", "grouplabel": "分组标签", "expr": "表达式",
}


def human(cls, tag=None):
    """class 串 → 中文说明。没有收录的 class 直接给 class 名（研发本来就认它）；
    连 class 都没有的，用标签名兜底，别让清单里出现「（无 class）」这种没信息量的行。"""
    parts = [c for c in (cls or "").split()
             if c and c not in ("on", "lock", "done", "silent", "wide",
                                "tight", "thick", "throw", "stack", "s")]
    if parts:
        return " · ".join(LBL.get(c, c) for c in parts)
    return {"span": "行内文本", "div": "块", "b": "加粗", "i": "斜体",
            "svg": "图标", "h1": "页面标题", "h2": "小标题", "p": "段落",
            }.get(tag or "", tag or "文本")


def main():
    with open(SPEC_JSON, encoding="utf-8") as fh:
        spec = json.load(fh)

    # ── 收集逐屏数据 ──────────────────────────────────────────────
    # 屏 → 所属批次（屏 6/7 会同时属于 B1 壳 与 B3/B4 内容）
    in_batch = {}
    import check_screen_coverage as C
    for bk, (nos, _d) in C.BATCHES.items():
        for n in nos:
            in_batch.setdefault(n, []).append(bk)

    per = {}
    for sc in spec:
        no = sc["no"]
        _, slug, title, status, target, note = SM.by_no(no)
        hard, soft, data = SM.screen_texts(sc)
        # 必现控件：有中文名的、出现次数靠前的
        cnt = {}
        for it in sc["items"]:
            for c in (it.get("cls") or "").split():
                if c in LBL:
                    cnt[c] = cnt.get(c, 0) + 1
        per[no] = {
            "slug": slug, "title": title, "status": status,
            "target": target, "note": note,
            "items": len(sc["items"]),
            "hard": hard, "soft": soft, "data": data,
            "batches": in_batch.get(no, []),
            "widgets": sorted(cnt.items(), key=lambda x: -x[1]),
        }

    STATUS = {"aligned": "已对齐过一轮", "rework": "有旧页，需改造",
              "new": "**无页面，要新建**", "shell": "改既有壳"}

    # ── §2 逐屏附录（按屏号排序，一屏一份，标注它落在哪几批）────────
    app = []
    for no in sorted(per):
        r = per[no]
        bs = " → ".join(r["batches"]) or "—"
        app.append(f"\n#### 屏 {no} · `{r['slug']}` · {r['title']}  \n")
        app.append(f"- **所属批次**：**{bs}**　**状态**：{STATUS[r['status']]}　"
                   f"**设计元素**：{r['items']} 个　**必现结构性文案**：{len(r['hard'])} 条\n")
        app.append(f"- **目标文件**：`{r['target']}`\n")
        app.append(f"- **任务**：{r['note']}\n")
        ws = [w for w, _ in r["widgets"]][:16]
        if ws:
            app.append(f"- **必须用到的控件**：{human(' '.join(ws))}\n")
        app.append("- **必须出现的文案**（逐条核对，缺一条即不通过）：\n")
        for cls, v, tag in r["hard"]:
            app.append(f"  - `[{human(cls, tag)}]` {v}\n")
        if r["soft"]:
            app.append("- 参考文案（受用户数据影响，按语义落地即可，不硬比）："
                       f"{'、'.join(v for _, v, _t in r['soft'][:12])}"
                       f"{' …' if len(r['soft']) > 12 else ''}\n")
    appendix = "".join(app)

    # ── 装配 ─────────────────────────────────────────────────────
    # ── §0 里的证据数字：现算，不写死（否则设计/代码一变，文档就在说谎）──
    import check_screen_coverage as C
    spec_all = C.load_spec()
    lib = C.load_lib()
    stats = [C.check_screen(n, spec_all, lib) for n in range(1, len(spec_all) + 1)]
    cov_hit = sum(s["hardInLib"] for s in stats)
    cov_tot = sum(s["hard"] for s in stats)
    cov_pct = 100 * cov_hit / max(cov_tot, 1)
    n_bad = sum(1 for s in stats if s["missLib"])
    n_new = sum(1 for s in stats if s["status"] == "new")
    vio = {name: tot for name, _why, tot, _per in C.scan_violations(lib, None)}
    tok_dart = C.re.findall(r"this\.([A-Za-z0-9_]+)",
                            lib.get("lib/app/theme/tokens.dart", ""))
    n_tok = len(tok_dart)
    pairs = C.re.findall(r"(\w+):\s*t\.(\w+)",
                         lib.get("lib/app/theme/app_colors.dart", ""))
    n_bridge = len(set(b for _a, b in pairs))
    n_missing_tok = len(set(tok_dart) - set(b for _a, b in pairs))

    # 测试基线：静态数一下 test()/testWidgets() 的处数。
    # ⚠️ HANDOFF.md 里写的「128 tests」是过时数字，别照抄。
    n_tests = 0
    tdir = os.path.join(PLAIN_ROOT, "test")
    for root, dirs, files in os.walk(tdir):
        for f in files:
            if f.endswith("_test.dart"):
                s = open(os.path.join(root, f), encoding="utf-8", errors="ignore").read()
                n_tests += len(C.re.findall(r"\btestWidgets?\s*\(", s))
                n_tests += len(C.re.findall(r"^\s*test\s*\(", s, C.re.M))

    now = datetime.date.today().isoformat()
    n_hard = sum(len(per[n]["hard"]) for n in per)
    n_items = sum(per[n]["items"] for n in per)

    doc = DOC_HEAD.format(
        date=now, n_screens=len(per), n_items=n_items, n_hard=n_hard,
        cov_hit=cov_hit, cov_pct=cov_pct, n_bad=n_bad, n_new=n_new,
        v_appbar=vio.get("AppBar(", 0), v_listtile=vio.get("ListTile", 0),
        v_card=vio.get("Card(", 0), v_icons=vio.get("Icons.*", 0),
        v_colors=vio.get("Colors.*", 0),
        n_tok=n_tok, n_bridge=n_bridge, n_missing_tok=n_missing_tok,
        n_tests=n_tests,
    )
    doc += BATCH_TABLE
    doc += TASKS
    doc += "### 2.2 逐屏清单（机读生成，勿手改）\n\n"
    doc += (f"> 本节由 `redesign-v3/_build/gen_coding_brief.py` 从 `redesign-v3/_build/spec.json` 生成，"
            f"共 {len(per)} 屏 / {n_hard} 条必现结构性文案，**按屏号排序**。\n"
            f"> 屏 6 / 屏 7 同属两批（B1 做壳与顶栏、B3/B4 做内容），"
            f"清单只有一份，按批次先后各做一遍。\n"
            f"> 设计一改就重跑生成器，**不要在本文件里手改清单**。\n")
    doc += appendix
    doc += "\n---\n\n"
    # ACCEPTANCE 里有 {n_tests} 占位 —— 单独 format，别直接拼
    doc += ACCEPTANCE.format(n_tests=n_tests)
    doc += ANTIPATTERNS
    doc += RHYTHM

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(doc)
    print("written:", OUT, os.path.getsize(OUT) // 1024, "KB")
    print("screens=%d  items=%d  必现结构性文案=%d" % (len(per), n_items, n_hard))


BATCH_LIST = []


def _init_batches():
    """批次顺序与屏号取自 check_screen_coverage.BATCHES —— 单一事实源。

    （保留这个钩子是因为 §2.1 的批次表与 §2.2 的「所属批次」都依赖它；
    目前 §2.1 的文字表是手写的，改批次时两处都要动。）
    """
    import check_screen_coverage as C
    global BATCH_LIST
    BATCH_LIST = [(k, [], v[1], v[0]) for k, v in C.BATCHES.items()]


DOC_HEAD = """# 编码指令 · 29 屏 UI 对齐（素记 Plain）

| 文档属性 | 内容 |
| --- | --- |
| 文档版本 | v1.0 |
| 文档状态 | 可执行（分批喂给编码 Agent） |
| 生成日期 | {date} |
| 适用范围 | `C:\\Users\\lizhenyu\\WorkBuddy\\Dev\\PlainApp\\plain` |
| 上游输入 | `redesign-v3/单独确认-标注版.html`（29 屏 × {n_items} 元素）、`redesign-v3/01-tokens.json`、`redesign-v3/05-COMPONENT-SPECS.md` |
| 读者 | 编码 Agent（Flutter 侧） |
| 生成方式 | §2.2 逐屏清单由 `redesign-v3/_build/gen_coding_brief.py` 从实测数据 `spec.json` 生成 |

> **本文件不是设计稿，是执行指令。** 所有数值（位置 / 尺寸 / 圆角 / 颜色 / 间距）
> **一律现场打开 `redesign-v3/单独确认-标注版.html` 查第 N 屏的规格表**，
> 本文件**不转述任何数值** —— 2000+ 个数值经转述必丢精度，且改完无法判断对错。

---

## §0 为什么不能"一句话交给 AI"

把 29 屏原型截图 + 一句「照着做」交给编码 Agent，产出**必然**是"差很多、缺东少西"。
这不是模型能力问题，是信息结构问题。以下 5 种失败模式在**本工程已经实测发生过**：

| # | 失败模式 | 本工程的实测代价 |
| --- | --- | --- |
| F1 | **漏文案**：原型上的分组小标题、说明句、"已支持" 标签被当成装饰忽略 | 29 屏 **{n_hard} 条**结构性文案，代码里只有 **{cov_hit} 条（{cov_pct:.1f}%）** |
| F2 | **漏页面**：没有对应文件的屏，Agent 会以为"已经做过了" | 29 屏里 **{n_bad} 屏**未达标；其中 **{n_new} 屏目前无任何页面** |
| F3 | **抄邻居的写法**：Agent 参照同目录现有页面，把 Material 组件照搬过来 | 现存 `AppBar` × {v_appbar}、`ListTile` × {v_listtile}、`Card` × {v_card}、`Icons.*` × {v_icons}、`Colors.*` × {v_colors} —— 全是设计明令换掉的写法 |
| F4 | **自己发明令牌**：页面要描边 / 焦点环 / 禁用态时找不到令牌，就地硬编码 | `AppTokens` 有 **{n_tok}** 个字段，但 widget 真正读的 `AppColors` **只桥接了 {n_bridge} 个**，**{n_missing_tok} 个没暴露**（v3 新增的 10 个一个都没有） |
| F5 | **改错地方**：Agent 会去动已经做对的东西（预置分类、schema、门禁） | 设计原型的分类二级名是**示例值**（`三餐/外卖/堂食`），与代码预置清单（`早餐/午餐/晚餐…`）**不同**，误改会动到已定稿的 41 个二级分类 |

**结论**：必须给 ①绝对路径 ②不许重写的清单 ③可执行验收。下面就是这三样。

---

## §1 常驻上下文包（每一轮对话开头整段粘贴）

```text
【工程】Flutter 记账 App「素记 / Plain」
【代码根】C:\\Users\\lizhenyu\\WorkBuddy\\Dev\\PlainApp\\plain
【设计真值】C:\\Users\\lizhenyu\\WorkBuddy\\Dev\\PlainApp\\redesign-v3\\
  · 单独确认-标注版.html  ← 29 屏逐元素规格（iPhone 16 · 393×852）。要看某屏数值就开它。
  · 01-tokens.json        ← 颜色/字阶/间距/圆角/动效/投影的真值
  · 05-COMPONENT-SPECS.md ← 25 节控件解剖与状态表
  · 06-INTERACTION.md     ← 时长曲线、按压反馈、转场、手势、降级
  · 04-ICON-SYSTEM/       ← 84 枚图标（svg/ + icons.json）
  · 08-SCREENS-SPEC/      ← ⚠️ 只有 8 屏，其余 21 屏的规格只在「标注版.html」里
【逐屏执行指令】C:\\Users\\lizhenyu\\WorkBuddy\\Dev\\PlainApp\\编码指令-29屏UI对齐.md
【覆盖门禁】python redesign-v3/_build/check_screen_coverage.py --batch B?

【已定稿、禁止重写】
· 数据层：sqlite3 + 手写 DDL，kSchemaVersion = 3，8 张表，15 个索引（全 partial）
· 金额：int64 分，禁 double；Money.maxCents = 9999999999
· 主题：AppColors 是 ThemeExtension，widget 一律用 context.colors
· 刷新：写侧 ref.invalidateData.bumpXxx()，读侧 watch 对应 versionProvider
· 令牌真值：lib/app/theme/tokens.dart（63 字段，已含 v3 的 10 个新字段）
· 预置分类：lib/data/seed/preset_categories.dart（支出 12 一级 + 41 二级）
             —— 设计原型上的分类名是示例值，不要去改它
· 图标：唯一源 redesign-v3/04-ICON-SYSTEM/svg/ → assets/icons/ic_*.svg（flutter_svg 运行时加载）
         绑定 lib/design_system/plain_icons_v3.dart 是生成物（plain/tool/gen_icons_abs.py）
         —— 旧 PlainIcons 字体与 lib/design_system/plain_icons.dart 已删除，不要再引用
· 已有组件：PlainEyebrow / PlainPanel / PlainRow / PlainTypeTab / PlainSwitch /
             PlainPrimaryButton / PlainDangerButton / CategoryDot（lib/design_system/plain_ui.dart）

【硬约束】
· 中文交流；不要跑 flutter build / 发布，测试可以跑
· 不降级依赖；不新增第三方 UI 库（图表自己画，见 §4 A7）
· 含中文的文件用 Write / Edit 改，禁止 PowerShell 批量替换
· 断点常量只在 lib/app/breakpoints.dart
· FAB 必须带 heroTag
· 金额文本必须带 FontFeature.tabularFigures()

【本工程 AI 必栽的 8 个坑（先读再动手）】
1. AppColors 只桥接了 {n_bridge}/{n_tok} 个令牌（{n_missing_tok} 个没暴露）—— 要描边/焦点环/
   禁用态/遮罩时 **先去 app_colors.dart 补桥接**，不要就地硬编码色值。
2. AGENTS.md 里"常驻 Widget 必须调 watchBrandTheme"**已过时**，
   该机制已换成 AppColors ThemeExtension，代码里 watchBrandTheme 的调用点是 0。
3. 同目录现有页面大量使用 Material AppBar / ListTile / Card / Icons.*，
   **不要参照它们**；参照 lib/design_system/plain_ui.dart。
4. design_system/plain_ui.dart 目前只被 settings_page.dart 用过。
   要用组件时先看这个文件，而不是复制 settings_page 的内联写法。
5. tokens.shadow1/2/3 是**纯黑旧值**，设计要的是**暖黑** rgba(48,41,30,·)
   → 一律用 lib/app/theme/shadows.dart 的 AppShadows.level1/2/3(isDark)。
6. 颜色字节序相反：设计 JSON 是 #RRGGBBAA，Dart 是 0xAARRGGBB。
   #3F3F461F → Color(0x1F3F3F46)。别写正则一把梭，会丢掉透明度。
7. AppColors.border 对应设计的 --line（不是 --line-strong）；
   AppColors.divider 对应设计的 --line-soft。别按名字猜。
8. 说明面板（.notepanel）里的长句是**内容**不是装饰，
   漏掉就是"缺东少西"的主要形态。门禁会逐条核对。

【验收（每轮结束必须贴原始输出，不要只说"已完成"）】
cd C:\\Users\\lizhenyu\\WorkBuddy\\Dev\\PlainApp\\plain
set "PROGRAMFILES(X86)=C:\\Program Files (x86)"
C:\\Users\\lizhenyu\\flutter\\bin\\flutter.bat test
C:\\Users\\lizhenyu\\flutter\\bin\\dart.bat analyze lib test
python ..\\redesign-v3\\_build\\check_screen_coverage.py --batch <本轮批次>
```

---

## §2 任务清单

"""

BATCH_TABLE = """### 2.1 批次总览

| 批次 | 内容 | 屏号 | 为什么必须一起交付 |
| --- | --- | --- | --- |
| **B0** | 令牌桥接 + 组件层 + 违规清零 | — | 不先做，后面每屏都会各自发明轮子，风格永远统一不了 |
| **B1** | 壳与顶栏 | 2 / 6 / 7 / 11 | 4 个一级页共用底部导航与顶栏，改一个不改另一个会跳版 |
| **B2** | 记账链路 | 3 / 4 / 5 / 12 / 13 | 输入页是「转账三态」与「分割编辑器」的宿主，拆开会编译不过 |
| **B3** | 资产链路 | 6 / 15 / 20 / 21 / 22 | 共用净值/持仓的取数与格式，一起做才好抽公共件 |
| **B4** | 报表链路 | 7 / 23 / 24 / 25 / 26 | 共用环形图/柱图/进度条的绘图基元 |
| **B5** | 管家链路 | 9 / 14 / 16 / 17 / 18 / 19 | ★ 发现页是新 IA 的入口，与它列出的 5 个页面同时上线 |
| **B6** | 数据与设置 | 1 / 8 / 10 / 27 / 28 / 29 | 收尾，含引导页与多端信息页 |

> 一次喂 **一个批次**（不超过 6 屏）。一次给超过 5 个任务，漏改率显著上升。

---

"""

TASKS = r"""### B0 · 地基（不可拆，必须最先交付）

| 项 | 内容 |
| --- | --- |
| **锚点** | `lib/app/theme/app_colors.dart`　`lib/design_system/plain_ui.dart` |
| **任务** | 1. 给 `AppColors` 补桥接 `AppTokens` 里**尚未暴露的 38 个字段**：`lineStrong` `lineStrongSoft` `focusRing` `surfaceInset` `disabledFg` `disabledBg` `overlay` `skeleton` `primaryPressed` `accentPressed` `frame` `fabIc` `toastBg` `primaryTint` `primaryInk` `onAccent` `accentSoft` `accentDeep` `accentInk` `incomeSoft` `incomeLine` `incomeInk` `okSoft` `okInk` `warnSoft` `warnInk` `dnBg` `shadow1/2/3` `shadowAccent` `shadowPrimary` `glowPrimary` `glowAccent` `heroCard0/1` `heroGrad0/1` `heroDarkGrad0/1` `accentGrad`<br>2. `plain_ui.dart` 补三个组件：`PlainTopBar`（56 高 / 返回 34 圆 / 标题 20·600 / 右侧操作）、`PlainSeg`（分段控件，36 高 / 命中区 44 / 选中项 r8）、`PlainTag`（标签，供 `已支持 / 规划中 / V3.0` 用）<br>3. 违规清零（见 §3 表） |
| **约束** | 补字段只能**追加**，不得改现有 26 个的语义（`border` = 设计 `--line`、`divider` = 设计 `--line-soft` 保持不动）。`accentGrad` 是 `Gradient` 不是 `Color`，不要按色值解析。`fabIc` **不能**直接取 `accent` —— 10 个主题 10/10 对比度不达标，必须走 `inkFor(accent, fabBg, 3.0)` |
| **验收** | `flutter test` 全绿；`dart analyze lib test` 无 issue；`python redesign-v3/_build/check_screen_coverage.py --violations` 的 `AppBar/ListTile/Card/ElevatedButton/OutlinedButton/SnackBar/Colors.*` **计数为 0**（`Icons.*` 允许在 `lib/design_system/` 内保留，页面层为 0） |
| **禁止** | 不要顺手改 `lib/app/theme/theme_registry.dart` 的色值；不要动 `lib/app/theme/tokens.dart` 的字段顺序；不要为了让门禁通过而放宽判定 |

### B1 · 壳与顶栏（屏 2 / 6 / 7 / 11）

| 项 | 内容 |
| --- | --- |
| **锚点** | `lib/features/ledger/presentation/home_shell.dart`、`flow_list_page.dart`、`lib/features/reports/reports_page.dart`、`lib/features/accounts/accounts_page.dart`、`lib/features/settings/settings_page.dart` |
| **任务** | 把 4 个一级页的 Material `AppBar` 全部换成 `PlainTopBar`；底部导航按设计（4 页签 + 中央 44×44 `PlainTopBar` 无关的 FAB，r12）；首页流水改为 `hero 结余区 + 按日分组 + 行内 6px 分类圆点` |
| **约束** | 顶栏标题 20/600；导航项文字 12；FAB 必须带 `heroTag` |
| **验收** | `--batch B1` 结构性文案覆盖 100%；4 屏的实际高度预算 = 852（含状态栏 47 + 顶栏 56 + 导航） |
| **禁止** | 不要改导航的 4 个页签名称与顺序（流水 / 报表 / 资产 / 我的）；不要给面板加 elevation |

### B2 · 记账链路（屏 3 / 4 / 5 / 12 / 13）

| 项 | 内容 |
| --- | --- |
| **锚点** | `lib/features/ledger/presentation/entry_input_page.dart`（1165 行）、`entry_detail_page.dart`、`lib/features/settings/category_manage_page.dart`、**新建** `lib/features/ledger/presentation/split_editor_page.dart` |
| **任务** | ① 记账页补「转账 / 借出 / 借入」三态（双账户选择 + 「保存后的影响」说明面板 + 双向金额）；② 新建分割交易编辑器（父单原始金额 + 子项列表 + 已分配进度 + 「已对平，可以保存」判定）；③ 分类管理对齐设计（分段 支出/收入、行内图标 24 + 名称 15/500 + 笔数 12、拖拽柄、底部「新建分类」） |
| **约束** | 硬口径不可动：OK 才保存（点分类只预选）；键盘只有 数字/小数点/退格/C/OK；分割的父单不被删除、子项独立统计 |
| **验收** | `--batch B2` 覆盖 100%；键盘高度与分类格网格不溢出屏幕（设计值见标注版第 3 屏）；`lib/domain/usecases/split_usecases.dart` 的既有测试全绿 |
| **禁止** | 不要把 `categories.note`（分类备注）和 `transactions.note`（账单备注）共用字段或组件；不要改 `preset_categories.dart` 的名称 |

### B3 · 资产链路（屏 6 / 15 / 20 / 21 / 22）

| 项 | 内容 |
| --- | --- |
| **锚点** | `lib/features/accounts/accounts_page.dart`、`credit_reconcile_page.dart`、**新建** `lib/features/assets/{investment_page,loan_page,net_worth_page}.dart` |
| **任务** | 三张新页：投资持仓（总市值/总成本/浮动盈亏 hero + 持仓行 + 涨跌色）、贷款摊销（参数键值表 + 四列摊销表 + 进度条）、净值追踪（当前净值 hero + 迷你柱趋势 + 资产负债表）；信用卡账单页改造为 hero + 账户参数 + 进度条 + 风险说明 |
| **约束** | 涨跌配色按中国习惯（**涨红跌绿**）；金额一律 `int64` 分；`Money.maxCents = 9999999999` 的显示宽度要按标注版的档位规则降档，**不许截断** |
| **验收** | `--batch B3` 覆盖 100%；四列摊销表在 393 宽下不横向溢出 |
| **禁止** | 不要引入图表库；不要新建账户/负债相关的数据表（用既有 `accounts`） |

### B4 · 报表链路（屏 7 / 23 / 24 / 25 / 26）

| 项 | 内容 |
| --- | --- |
| **锚点** | `lib/features/reports/reports_page.dart`、`lib/design_system/donut_chart.dart`、**新建** `lib/features/reports/{sankey_page,cross_analysis_page,money_age_page}.dart`、`lib/features/settings/budget_page.dart` |
| **任务** | 三张新图页：桑基（收入→支出→结余 三列 + 标签）、交叉分析（切维度 + 分类×账户 热力表）、资金年龄（平均停留天数 hero + 近 6 月迷你柱 + 分档说明）；报表页与预算页对齐设计（分段切换 4 种方法论、进度行、超支警示） |
| **约束** | 环形图中心金额的降档规则（T-9）：档位 `20 → 15 → 14 → 12`，**向下取到放得下的一档，绝不截断**；可用宽 358 |
| **验收** | `--batch B4` 覆盖 100%；环形图中心在 `¥99,999,999.99` 下不压环 |
| **禁止** | 不要用 `CustomPainter` 之外的方式画桑基（会引入依赖）；不要把 12 个分类基色用在文字或按钮底 |

### B5 · 管家链路（屏 9 / 14 / 16 / 17 / 18 / 19）★

| 项 | 内容 |
| --- | --- |
| **锚点** | **新建** `lib/features/discover/discover_page.dart`；`lib/features/settings/{reimburse_center,reminders,automation_rules,savings_goals,home_layout}_page.dart` |
| **任务** | ★ **发现页是本轮 IA 变更的核心**：它按 `常用 / V1.0 / V2.0 / V3.0 / V4.0` 分组，把原来堆在「我的」里的 11 个入口收编过来（每行：图标 24 + 标题 15/500 + 一行说明 12 + 右箭头）。**同一批必须把「我的」页的数据组精简到只剩「备份与恢复 / 批量导入」**，否则两个入口并存。另外 5 张页面对齐设计 |
| **约束** | 发现的每一行都带一句说明文案 —— 这是设计的骨架，不是装饰（门禁逐条比对）；「我的」页分组顺序：记账 / 安全 / 外观 / 数据 / 关于 |
| **验收** | `--batch B5` 覆盖 100%；发现页每一行的 `onTap` 指向真实存在的页面（不许留空回调）；从「我的」到被搬走的 11 个入口**仍有且仅有一条路径** |
| **禁止** | 不要在「我的」里保留被搬走的条目；不要给发现页的行加前置淡彩底板 |

### B6 · 数据与设置（屏 1 / 8 / 10 / 27 / 28 / 29）

| 项 | 内容 |
| --- | --- |
| **锚点** | `lib/features/settings/{onboarding_page,backup_page,theme_page}.dart`、**新建** `lib/features/family/family_page.dart`、`lib/features/settings/{api_page,platform_page}.dart` |
| **任务** | 引导页对齐三段式；备份页（说明面板 + 两个动作 + 空态）；主题页（分段 3 态 + 10 主题色卡 r8 网格 + 说明面板）；家庭与成员（成员行 + 邀请 + 共享账本边界说明）；开放接口（总开关 + 逐项权限 + 风险说明）；多端信息页（四端能力矩阵 + 已支持/规划中 标签） |
| **约束** | 家庭页必须写清「共享账本」与「记账伙伴」是两套边界（G-5），不共用；开放接口必须写明「默认关闭」「只在监听、不经过服务器」 |
| **验收** | `--batch B6` 覆盖 100%；彩蛋/说明类长句逐条在页面上可见 |
| **禁止** | 不要真的实现网络监听（本轮只做界面与开关状态持久化）；不要改备份文件格式 `.sujibak` |

---

"""

ACCEPTANCE = r"""## §3 交付验收总表

每轮结束**必须贴原始输出**，不接受"已完成"这种口头结论。

| # | 命令 | 期望输出 |
| --- | --- | --- |
| A1 | `flutter test` | `All tests passed!`，且用例总数 **不得低于 {n_tests}**（改动前先数一遍；下降即视为改坏了）。⚠️ `HANDOFF.md` 里写的「128 tests」是过时数字，别照抄 |
| A2 | `dart analyze lib test` | `No issues found!` |
| A3 | `python redesign-v3/_build/check_screen_coverage.py --batch <本轮>` | 表格里本轮屏**全部 ✓**；末尾 `结构性文案覆盖：N/N = 100.0%  未达标屏数：0/N`；exit 0 |
| A4 | `python redesign-v3/_build/check_screen_coverage.py --violations` | `AppBar / ListTile / Card / ElevatedButton / OutlinedButton / SnackBar / Colors.*` **全部 0 处** |
| A5 | `dart format --output=none --set-exit-if-changed lib` | 无输出，exit 0 |
| A6 | 打开 `redesign-v3/单独确认-标注版.html` 第 N 屏 | 与实现稿并排比：**控件个数、控件顺序、文案一字不差**；差异只允许出现在"数值"（因为数值以你的实现为最终），不允许出现在"有什么/没有什么" |
| A7 | 新增/改动文件清单 | 逐个 `git status --short` 列出，不许出现未声明的文件 |

**结构性断言（比功能测试更重要）**

- **A3 是最硬的一条**：它把"设计里有的东西"变成 exit code。功能测试全绿但 A3 不达标，
  就是典型的"页面能跑、但缺东少西"。
- **A6 的比法**：不要比像素，比**清单**。逐行读标注版的规格表，问"这一行在我页面上吗"。
  设计元素 172 个的 `发现` 页最容易漏。

---

"""

ANTIPATTERNS = r"""## §4 反面清单（每条都付过代价）

| # | 禁止 | 代价（本工程实际发生） |
| --- | --- | --- |
| N1 | **不要转述设计数值**（"大约 16 的间距""青绿色"） | 数值必须现场查标注版。上一版交付因把 HSL 插值当成 sRGB 合成算法，**整个令牌文件重写** |
| N2 | **不要参照同目录现有页面写新页面** | 现存 `AppBar` × 27 / `ListTile` × 22 / `Card` × 31 / `Icons.*` × 127 —— 照抄就是把这些错误复制到新页 |
| N3 | **不要在页面里硬编码颜色** | `Colors.*` 现有 15 处；设计有 10 主题 × 亮暗 20 组，硬编码等于只在默认主题下正确 |
| N4 | **不要去改 `lib/data/seed/preset_categories.dart` 的分类名** | 设计原型的 `三餐/外卖/堂食` 是**示例值**；代码的 `早餐/午餐/晚餐/夜宵/零食/饮料` 是上一轮产品定稿，改了会让老用户重装后分类全变 |
| N5 | **不要宽泛地"顺手优化"不相关代码** | 一次超出范围的"重构"会引入无法审计的变更。改哪个文件、为什么，要在交付说明里写明 |
| N6 | **不要为了让门禁通过而下调阈值 / 注释掉断言** | 门禁是这一轮唯一能挡住"缺东少西"的东西。它红了就补页面，不要改它 |
| N7 | **不要新增第三方 UI / 图表库** | 桑基、热力、迷你柱、环形图**都自己画**。引入依赖会破坏四端一致性，且与"本地优先、包体积可控"的产品线冲突 |
| N8 | **不要把「设计里没有的东西」加进去** | 现有「我的」页比设计多了「其它」组（情绪反馈 / 消费周报）与 11 个数据入口 —— 这些是本轮要**减掉**的，不是参考 |
| N9 | **不要改数据层**（schema / 索引 / 迁移 / 金额单位） | `kSchemaVersion = 3`、8 张表、15 个 partial 索引已定稿。UI 对齐不需要任何 schema 变更 |
| N10 | **不要用 `AlertDialog` / `SnackBar` / `showModalBottomSheet` 的默认外观** | 设计有 `.dialog` / `.toast`；默认外观与本设计语言（r24 / 暖黑投影 / 无 elevation）冲突 |
| N11 | **不要漏掉"说明面板"里的长句** | 这是"缺东少西"最常见的一类：页面结构对了，但少了那句把规则讲清楚的文案。门禁逐条比对 |
| N12 | **不要在「我的」和数据层之间做"兼容性保留"** | 被搬到发现页的 11 个入口，在「我的」里**必须删掉**，只留一条路径 |

---

"""

RHYTHM = r"""## §5 建议的对话节奏

**分 7 轮，一轮一个批次。** 每轮按下面四步走，不要跳跃：

1. **先贴 §1 常驻上下文包**（整段），再贴本轮批次指令。
2. 让 Agent **先只读不写**：读 §2.2 里本轮各屏的清单 + 打开标注版对应屏，
   回一份**"我打算怎么做"的清单**（每屏：目标文件 / 会改哪些部件 / 会新建哪些文件）。
   —— 这一步能提前拦住"改错地方"和"漏屏"。
3. 确认后让 Agent 动手。**要求它每完成一屏就贴 `--batch B?` 的门禁输出**，
   不要攒到最后一起贴（攒到最后等于没法定位是哪一屏漏的）。
4. 本轮结束时贴 **A1–A5 的原始输出**。A3 未 100% 就不要进入下一批。

**每轮交付说明必须包含**（缺一不可）：

```text
本轮批次：B?
新增文件：<绝对路径 1>、<绝对路径 2> …
改动文件：<绝对路径>（改了什么）
未完成项：<有就写，没有写"无">  ← 写"无"之前请先跑 A3
门禁原始输出：
  A1 flutter test        → <粘贴>
  A2 dart analyze        → <粘贴>
  A3 check_screen_coverage --batch B? → <粘贴>
  A4 --violations        → <粘贴>
```

**特别提醒 B0 与 B5**

- **B0 是最容易被跳过的一批**。Agent 会觉得"先做页面更实在"。但 B0 不做，
  后面 6 批会各自发明描边色、各自画顶栏，最后风格依然是散的 —— 那就白做一轮。
- **B5 是本轮真正的产品变更**（新增「发现」页 + 精简「我的」）。
  它不是"补一个页面"，是信息架构调整，**必须一次交付完**，否则会出现同一入口两条路径。

**如果只能先做一批**：做 **B0 + B2**（地基 + 记账链路）。
记账链路是日活最高的路径，且它自身就包含"转账三态"和"分割编辑器"两个新页面的宿主改造。
"""


if __name__ == "__main__":
    _init_batches()
    main()
