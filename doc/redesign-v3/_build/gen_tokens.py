"""素记 Plain · redesign-v3 — 令牌生成器。

产出：redesign-v3/01-tokens.json
  · resolved  10 主题 × 2 明暗 = 20 组，字段名与 AppTokens 逐字一致（53 个）
  · 复现 plain/tool/theme_contrast_check.dart 的 41 项 × 20 组合门禁
  · 追加 v3 新增检查（焦点环 / 控件描边 / 禁用态 / 分类 ink 宿主 / 面板层次）
  · 任何一项不达标 → 非零退出，不许出交付物

运行：python _build/gen_tokens.py
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from plain_color import (  # noqa: E402
    BLACK, WHITE, accent_sheen, alpha_of, composite, contrast, css, hx,
    hero_safe, ink_for, ink_for_layers, mix, opaque, pick_on, pressed_fill,
)

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "01-tokens.json"))

# ══════════════════════════════════════════════════════════════════════════
# 1 · 中性层（重做）
#
# 上一版的病根：三个 tone 都偏暖（bg #F3F3F1 的 B 通道比 R 低 2），叠上米色卡片
# 就是「米黄叠米黄」。v3 把三个 tone 全部拉回**近真白**，只保留 ≤2 个 RGB 单位的
# 冷/暖偏向作为主题区分——不足以形成「米黄」，但足以让 10 套皮肤有细微性格差。
#
# 亮态：bg → appBg → surface → surface2 四层靠**明度**递进（不靠描边）。
# 暗态：bg 最深 → surface2 最浅，逐级提亮；非纯黑（最深 #121214，不是 #000）。
# ══════════════════════════════════════════════════════════════════════════

TONES = {
    # cool：品牌冷绿家族（青瓷/靛蓝/竹青/海盐/藕荷/桃夭/绯樱）
    "cool": {
        "light": dict(bg="#F4F6F6", appBg="#FAFBFB", surface="#FFFFFF", surface2="#F5F7F7",
                      ink="#0E1413", ink2="#36403E", muted="#5B6765", faint="#808C8A",
                      line="#E3E8E7", lineSoft="#EDF1F0"),
        "dark": dict(bg="#101413", appBg="#181D1C", surface="#202625", surface2="#293130",
                     ink="#E8EDEA", ink2="#BEC8C4", muted="#8E9895", faint="#6F7975",
                     line="#2F3634", lineSoft="#272E2C"),
    },
    # neutral：零色偏冷中性（素白 —— 默认皮肤）
    "neutral": {
        "light": dict(bg="#F5F5F6", appBg="#FBFBFC", surface="#FFFFFF", surface2="#F6F6F8",
                      ink="#101012", ink2="#38383D", muted="#5E5E65", faint="#838389",
                      line="#E4E4E8", lineSoft="#EFEFF2"),
        "dark": dict(bg="#121214", appBg="#1A1A1D", surface="#222225", surface2="#2B2B2F",
                     ink="#ECECEE", ink2="#C2C2C7", muted="#93939B", faint="#74747C",
                     line="#33333A", lineSoft="#2B2B32"),
    },
    # sand：≤2 单位的暖偏（杏黄/豆绿）。**不是米黄**：bg 的 R−B = 3。
    "sand": {
        "light": dict(bg="#F7F6F4", appBg="#FCFBF9", surface="#FFFFFF", surface2="#F7F6F3",
                      ink="#121110", ink2="#3A3835", muted="#615D58", faint="#85807A",
                      line="#E6E4DF", lineSoft="#F0EEE9"),
        "dark": dict(bg="#131211", appBg="#1B1A18", surface="#232220", surface2="#2C2B28",
                     ink="#EDECE9", ink2="#C6C2BD", muted="#96928C", faint="#77726B",
                     line="#35332F", lineSoft="#2D2B28"),
    },
}

TONE_ALPHA = {
    "soft": {"light": 0.12, "dark": 0.20},
    "tint": {"light": 0.07, "dark": 0.13},
    "asoft": {"light": 0.12, "dark": 0.22},
}

# ══════════════════════════════════════════════════════════════════════════
# 2 · 品牌层（10 主题 × 2 明暗）
#
# p / pd / a / ad 为**产品冻结值**（02-PRD STORY-5.2「色值以 theme_registry 为准」，
# 旧名迁移表与商店描述都绑定这 10 组色相）—— 本轮不改色相，只改派生。
# hero / frame 保留冻结值：门禁要求 hero×白字 ≥ 4.6，v3 不使用该令牌。
# ══════════════════════════════════════════════════════════════════════════

B = dict  # 简写

THEMES = [
    # id, 名称, tone, light(p,pd,a,ad,hero0,hero1,heroD0,heroD1,frame), dark(...)
    ("qingci", "青瓷", "cool",
     ("14B8A6", "0D9488", "FF6B6B", "F43F5E", "0F766E", "2DD4BF", "134E4A", "115E59", "115E59"),
     ("5EEAD4", "2DD4BF", "FB7185", "F43F5E", "115E59", "14B8A6", "042F2E", "115E59", "115E59")),
    ("dianlan", "靛蓝", "cool",
     ("3B82F6", "2563EB", "F59E0B", "D97706", "1D4ED8", "60A5FA", "1E3A5F", "1D4ED8", "1E3A5F"),
     ("93C5FD", "60A5FA", "FBBF24", "F59E0B", "1E3A8A", "3B82F6", "0B1B3A", "1E3A8A", "1E3A8A")),
    ("zhuqing", "竹青", "cool",
     ("4ADE80", "22C55E", "A78BFA", "8B5CF6", "15803D", "86EFAC", "14532D", "166534", "14532D"),
     ("86EFAC", "4ADE80", "C4B5FD", "A78BFA", "166534", "22C55E", "052E16", "166534", "166534")),
    ("haiyan", "海盐", "cool",
     ("06B6D4", "0891B2", "FB7185", "E11D48", "0E7490", "22D3EE", "164E63", "155E75", "164E63"),
     ("67E8F9", "22D3EE", "FDA4AF", "FB7185", "155E75", "06B6D4", "083344", "155E75", "155E75")),
    ("ouhe", "藕荷", "cool",
     ("A78BFA", "8B5CF6", "FBBF24", "F59E0B", "6D28D9", "C4B5FD", "4C1D95", "5B21B6", "4C1D95"),
     ("C4B5FD", "A78BFA", "FDE68A", "FBBF24", "5B21B6", "8B5CF6", "2E1065", "5B21B6", "5B21B6")),
    ("taoyao", "桃夭", "cool",
     ("F472B6", "EC4899", "2DD4BF", "14B8A6", "BE185D", "FB7185", "831843", "9D174D", "831843"),
     ("F9A8D4", "F472B6", "5EEAD4", "2DD4BF", "9D174D", "EC4899", "500724", "9D174D", "9D174D")),
    ("feiying", "绯樱", "cool",
     ("EF4444", "DC2626", "10B981", "059669", "B91C1C", "F87171", "7F1D1D", "991B1B", "7F1D1D"),
     ("FCA5A5", "F87171", "6EE7B7", "34D399", "991B1B", "EF4444", "450A0A", "991B1B", "991B1B")),
    ("xinghuang", "杏黄", "sand",
     ("F59E0B", "D97706", "38BDF8", "0284C7", "B45309", "FBBF24", "78350F", "92400E", "78350F"),
     ("FCD34D", "FBBF24", "7DD3FC", "38BDF8", "92400E", "F59E0B", "451A03", "92400E", "92400E")),
    ("doulv", "豆绿", "sand",
     ("84CC16", "65A30D", "C084FC", "A855F7", "4D7C0F", "BEF264", "365314", "3F6212", "365314"),
     ("D9F99D", "BEF264", "E9D5FF", "C084FC", "3F6212", "84CC16", "1A2E05", "3F6212", "3F6212")),
    ("subai", "素白", "neutral",
     ("3F3F46", "27272A", "FB923C", "F97316", "27272A", "71717A", "18181B", "27272A", "27272A"),
     ("D4D4D8", "A1A1AA", "FDBA74", "FB923C", "3F3F46", "71717A", "09090B", "27272A", "27272A")),
]

# ══════════════════════════════════════════════════════════════════════════
# 3 · 恒等层（INV-1：跨主题恒等，只随明暗变）
# ══════════════════════════════════════════════════════════════════════════

CATEGORY = [
    ("food", "餐饮", "FF6B6B", "basket-food", ["meal", "restaurant", "food", "餐饮", "吃"]),
    ("fruit", "食材", "4ADE80", "basket-grocery", ["grocery", "market", "食材", "买菜"]),
    ("shopping", "购物", "F472B6", "bag", ["shopping", "bag", "购物", "买"]),
    ("daily", "日用", "A78BFA", "bottle", ["daily", "household", "日用", "生活"]),
    ("transport", "交通", "38BDF8", "bus", ["transport", "bus", "交通", "出行"]),
    ("housing", "居住", "FDBA74", "house", ["housing", "rent", "居住", "房租"]),
    ("telecom", "通讯", "2DD4BF", "phone", ["telecom", "phone", "通讯", "话费"]),
    ("entertainment", "娱乐", "E879F9", "game", ["fun", "entertainment", "娱乐", "玩"]),
    ("medical", "医疗", "F87171", "cross", ["medical", "health", "医疗", "看病"]),
    ("study", "学习", "60A5FA", "book", ["study", "book", "学习", "教育"]),
    ("social", "人情", "C084FC", "gift", ["social", "gift", "人情", "礼物"]),
    ("other", "其他", "94A3B8", "dots", ["other", "misc", "其他", "杂项"]),
]

SEM_LIGHT = dict(income="DC2626", incomeSoft="FFF1F2", incomeLine="FECDD3",
                 okSoft="ECFDF5", okBase="059669",
                 warnSoft="FDF3E3", warnInk="7A4E14",
                 dnBg="ECFDF5", dnBase="059669")
SEM_DARK = dict(income="FDA4AF", incomeSoft="#3A0B16"[1:], incomeLine="7F1D2D",
                okSoft="052E22", okBase="6EE7B7",
                warnSoft="3A2E1A", warnInk="E8B96A",
                dnBg="052E22", dnBase="6EE7B7")

# shadow 三档：亮态冷黑，暗态降权（面重于影）
SHADOW_ALPHA = {"light": (0.06, 0.10, 0.16), "dark": (0.26, 0.34, 0.46)}
GLOW_ALPHA = {"light": 0.06, "dark": 0.08}
SHADOW_BRAND_ALPHA = {"light": 0.10, "dark": 0.16}

ADDITIONS = [
    dict(name="lineStrong", kind="color",
         why="控件描边（输入框/次按钮）需要 ≥3:1 的可见边界；line 是 1.2:1 的发丝线，二者不能混用"),
    dict(name="focusRing", kind="color",
         why="键盘/读屏焦点必须可见（WCAG 2.4.11）。取 primaryInk 值，2px 描边 + 2px 偏移"),
    dict(name="surfaceInset", kind="color",
         why="键帽/内嵌槽（数字键盘、分段控件轨道）需要比 surface2 再退一档的底"),
    dict(name="disabledFg", kind="color", why="禁用态文字色，与 faint 分离（faint 仍用于图标占位）"),
    dict(name="disabledBg", kind="color", why="禁用态填充底"),
    dict(name="overlay", kind="color", why="模态遮罩，亮暗不同 alpha（亮 32% / 暗 56%）"),
    dict(name="skeleton", kind="color", why="骨架屏底色，语义上不等于 lineSoft"),
    dict(name="lineStrongSoft", kind="color", why="选中态描边（低一档），介于 line 与 lineStrong 之间"),
    dict(name="primaryPressed", kind="color",
         why="实心主按钮按下底。**不能复用 primaryDeep** —— 标签为近黑时压暗底色会把对比度吃穿（最差 2.65:1）。"),
    dict(name="accentPressed", kind="color", why="实心强调按钮（FAB / 保存）按下底，同上"),
]

# 令牌使用禁令：写了就不会有人用错
TOKEN_BANS = [
    "primaryDeep / accentDeep 禁止作为承载文字的填充底（它们只用于描边、图形、装饰）。"
    "按下态一律用 v3Additions.primaryPressed / accentPressed。",
    "heroGrad0/1 / heroDarkGrad0/1 在 v3 全产品不使用 —— 结余区改为纯排印 + 发丝线。"
    "保留值只是为了让 41 项门禁的 hero×白字 4 项继续成立。",
    "glowPrimary / glowAccent 只允许用作「暗态面板 1px 内高光」或「焦点环外圈」，"
    "禁止作为模糊光晕 / 背景光斑（上一版首页结余卡角上的柔光就是这样来的）。",
    "chartTrack 是装饰性轨道，不承担信息（必须同时有数字标签）；因此不按 3:1 图形阈值验。",
    "categoryColorMap 的 12 基色只用于：环形图扇区、列表行 6px 圆点、选中分类格描边。"
    "禁止用于按钮底、正文文字。",
]

# ══════════════════════════════════════════════════════════════════════════
# 4b · 非颜色令牌
# ══════════════════════════════════════════════════════════════════════════

TYPE = {
    "families": {
        "num": {"stack": ["Inter", "MiSans"], "features": ["tnum"], "license": "Inter: SIL OFL 1.1"},
        "ui": {"stack": ["Inter", "MiSans", "PingFang SC", "HarmonyOS Sans SC", "Noto Sans CJK SC"],
               "license": "Inter: OFL 1.1；MiSans: 小米官方免费商用（本站本地打包，禁 CDN）"},
    },
    # 8 级封闭字阶：4 数字 + 4 文排。不再新增。
    "scale": {
        "amount-input": dict(size=44, weight=600, lhZh=1.12, lhEn=1.12, tracking=-0.030, family="num",
                             role="记一笔输入金额"),
        "amount-xl": dict(size=34, weight=700, lhZh=1.16, lhEn=1.16, tracking=-0.020, family="num",
                          role="首页结余 / 账单详情主金额"),
        "amount-l": dict(size=22, weight=600, lhZh=1.24, lhEn=1.24, tracking=-0.015, family="num",
                         role="卡片主数字 / 账户余额 / 报表合计"),
        "amount-s": dict(size=15, weight=600, lhZh=1.34, lhEn=1.34, tracking=-0.010, family="num",
                         role="列表行金额"),
        "title": dict(size=20, weight=600, lhZh=1.40, lhEn=1.30, tracking=0.0, family="ui",
                      role="页面标题 / 弹层标题"),
        "heading": dict(size=15, weight=500, lhZh=1.55, lhEn=1.40, tracking=0.0, family="ui",
                        role="区块标题 / 列表主文"),
        "body": dict(size=14, weight=400, lhZh=1.65, lhEn=1.45, tracking=0.0, family="ui",
                     role="正文"),
        "caption": dict(size=12, weight=500, lhZh=1.55, lhEn=1.45, tracking=0.010, family="ui",
                        role="次要信息 / 标签 / 时间戳"),
    },
    "modifiers": {
        "eyebrow": dict(base="caption", weight=600, tracking=0.080,
                        usage="分组小标题（大写感）；英文自动 uppercase"),
    },
    "sizesTiers": {"standard": 1.00, "large": 1.12, "xlarge": 1.26},
    "rules": [
        "金额一律 tabular-nums（Inter tnum）。中文用 MiSans 时同样开 tnum。",
        "金额小数位：≥amount-l 一档小数用 0.62× 字号 + muted 色；currency 符号 0.62× 字号 + muted 色。",
        "行高按语言切换：zh 用 lhZh，en 用 lhEn。同一个 token 两套值，不许取中。",
        "字号三档对字号列做**离散乘法后四舍五入到整数**，不动行高比与字重。",
    ],
}

SPACE = {
    "base": 4,
    "scale": {"s1": 4, "s2": 8, "s3": 12, "s4": 16, "s5": 20, "s6": 24, "s7": 32, "s8": 40, "s9": 48, "s10": 64},
    "semantic": {
        "pagePadH": {"compact": 16, "medium": 24, "expanded": 32},
        "pagePadTop": 12, "sectionGap": 32, "groupGap": 20, "rowGap": 8,
        "cardPad": {"compact": 16, "expanded": 20}, "inlineGap": 8,
    },
    "rule": "组间留白 ≥ 组内间距。同一屏只允许出现 3 个不同间距值。",
}

RADIUS = {
    "r1": 8,    # chip / 标签 / 小图标底
    "r2": 12,   # 按钮 / 输入框 / 分段控件 / 键帽
    "r3": 16,   # 面板 / 卡片 / 列表组
    "r4": 24,   # 底部抽屉 / 模态
    "pill": 999,
    "rule": "全局 4 档 + 全圆。不许出现第 5 个圆角值。",
}

STROKE = {"hairline": 1, "control": 1, "strong": 1.5, "focus": 2, "rule": "描边走 token 色，不许写半透明黑。"}

ELEVATION = {
    "levels": {
        "e0": dict(shadow="none", use="平铺内容、列表行、分组面板"),
        "e1": dict(shadow="shadow1", dx=0, dy=1, blur=2, use="卡片、按钮静置"),
        "e2": dict(shadow="shadow2", dx=0, dy=4, blur=14, use="悬浮按钮、下拉、粘性头"),
        "e3": dict(shadow="shadow3", dx=0, dy=18, blur=44, use="模态、抽屉、Toast"),
    },
    "rules": [
        "亮态阴影是**冷黑**（0,0,0），不是暖黑；暗态阴影降权（0.26/0.34/0.46），靠面色分层。",
        "e0 与 e1 之间的边界用 1px line，不用阴影加大来区分。",
        "暗态面板另加 1px glowPrimary 内高光（顶部），替代亮态的阴影表达。",
    ],
}

MOTION = {
    "duration": {"press": 100, "fast": 150, "base": 300, "slow": 480, "ambient": 600},
    "curve": {
        "out": "cubic-bezier(0.16, 1, 0.30, 1)",
        "spring": "cubic-bezier(0.34, 1.56, 0.64, 1)",
        "io": "cubic-bezier(0.40, 0, 0.20, 1)",
    },
    "press": {"scale": 0.97, "iconScale": 0.93, "duration": 100, "curve": "spring", "fillShift": "primaryPressed"},
    "reducedMotion": {"duration": 100, "transform": "none", "keep": ["opacity"]},
}

SIZES = {
    "touch": {"min": 44, "preferred": 48, "hitSlopRule": "视觉尺寸 < 44 时，用透明热区补到 44×44（不许缩小点击区）"},
    "icon": {"inline": 16, "control": 20, "nav": 22, "grid": 24, "empty": 40, "hero": 56},
    "control": {
        "btnLg": 52, "btnMd": 44, "btnSm": 34, "input": 48,
        "rowSingle": 60, "rowDouble": 72, "navBar": 56, "tabBar": 60,
        "fab": 56, "keypadKey": 62, "keypadGap": 6, "categoryTile": 68,
        "switchW": 48, "switchH": 28, "segH": 36, "chipH": 28,
        "sheetHandle": 4, "backBtn": 40,
    },
}



# ══════════════════════════════════════════════════════════════════════════
# 4 · 单组合解析
# ══════════════════════════════════════════════════════════════════════════

def resolve(theme_id, name, tone_id, brand_light, brand_dark, is_dark):
    tone = {k: hx(v) for k, v in TONES[tone_id]["dark" if is_dark else "light"].items()}
    br = brand_dark if is_dark else brand_light
    p, pd, a, ad = (hx(br[i]) for i in range(4))
    hero = [hero_safe(hx(br[i])) for i in (4, 5, 6, 7)]
    frame = hx(br[8])

    key = "dark" if is_dark else "light"
    sa, ta, asa = (TONE_ALPHA[k][key] for k in ("soft", "tint", "asoft"))

    hosts = [tone["surface"], tone["surface2"], tone["bg"], tone["appBg"]]
    p_soft_hosts = [composite(p, sa, h) for h in hosts]
    p_tint_hosts = [composite(p, ta, h) for h in hosts]
    a_soft_hosts = [composite(a, asa, h) for h in hosts]

    t = {}  # AppTokens 字段
    # ── Neutral 10 ──
    for f in ("bg", "appBg", "surface", "surface2", "ink", "ink2", "muted", "faint", "line", "lineSoft"):
        t[f] = tone[f]

    # ── Brand primary 4 ──
    t["primary"] = p
    t["primaryDeep"] = pd
    t["primarySoft"] = (round(sa * 255) << 24) | (p & 0xFFFFFF)
    t["primaryTint"] = (round(ta * 255) << 24) | (p & 0xFFFFFF)

    # ── Brand accent 4 ──
    t["accent"] = a
    t["accentDeep"] = ad
    t["accentSoft"] = (round(asa * 255) << 24) | (a & 0xFFFFFF)
    on_accent = pick_on(a, tone["ink"], 4.5)
    t["accentGrad"] = f"linear-gradient(180deg, {css(accent_sheen(a, on_accent))} 0%, {css(a)} 100%)"

    # ── Derived 4 ──
    t["onPrimary"] = pick_on(p, tone["ink"], 4.5)
    t["onAccent"] = on_accent
    t["primaryInk"] = ink_for_layers(p, p_soft_hosts + p_tint_hosts + [tone["surface"], tone["bg"]], 4.5)
    t["accentInk"] = ink_for_layers(a, a_soft_hosts + [tone["surface"], tone["bg"]], 4.5)

    # ── Income 4 ──
    sem = {k: hx(v) for k, v in (SEM_DARK if is_dark else SEM_LIGHT).items()}
    t["income"] = sem["income"]
    t["incomeSoft"] = sem["incomeSoft"]
    t["incomeLine"] = sem["incomeLine"]
    t["incomeInk"] = ink_for_layers(sem["income"],
                                    [sem["incomeSoft"], tone["surface"], tone["bg"], tone["appBg"]], 4.5)

    # ── Status 6 ──
    t["okSoft"] = sem["okSoft"]
    t["okInk"] = ink_for_layers(sem["okBase"], [sem["okSoft"], tone["surface"], tone["bg"], tone["appBg"]], 4.5)
    t["warnSoft"] = sem["warnSoft"]
    t["warnInk"] = ink_for_layers(sem["warnInk"], [sem["warnSoft"], tone["surface"], tone["bg"]], 4.5)
    t["dnBg"] = sem["dnBg"]
    t["dnInk"] = ink_for_layers(sem["dnBase"], [sem["dnBg"], tone["surface"], tone["bg"], tone["appBg"]], 4.5)

    # ── Atmosphere 7（hero* 冻结保留，v3 不使用；heroCard 归中，防误用米黄）──
    t["heroGrad0"], t["heroGrad1"] = hero[0], hero[1]
    t["heroDarkGrad0"], t["heroDarkGrad1"] = hero[2], hero[3]
    t["frame"] = frame
    t["heroCard0"] = tone["surface"]
    t["heroCard1"] = tone["surface2"]

    # ── FAB 3 ──
    t["fabBg"] = a
    t["fabFg"] = t["onAccent"]
    t["fabIc"] = t["onAccent"]

    # ── Charts 3 ──
    t["chartTrack"] = mix(tone["surface2"], tone["faint"], 0.45)
    t["barFill"] = ink_for_layers(p, [tone["surface"], tone["appBg"], tone["bg"]], 3.0)
    t["dash"] = mix(tone["line"], tone["muted"], 0.42)

    # ── Glow / Shadow 8 ──
    ga = GLOW_ALPHA[key]
    ba = SHADOW_BRAND_ALPHA[key]
    t["glowPrimary"] = (round(ga * 255) << 24) | (p & 0xFFFFFF)
    t["glowAccent"] = (round(ga * 255) << 24) | (a & 0xFFFFFF)
    t["shadowPrimary"] = (round(ba * 255) << 24) | (p & 0xFFFFFF)
    t["shadowAccent"] = (round(ba * 255) << 24) | (a & 0xFFFFFF)
    t["toastBg"] = tone["ink"] if not is_dark else mix(tone["surface"], WHITE, 0.10)
    s1, s2, s3 = SHADOW_ALPHA[key]
    t["shadow1"] = (round(s1 * 255) << 24) | (BLACK & 0xFFFFFF)
    t["shadow2"] = (round(s2 * 255) << 24) | (BLACK & 0xFFFFFF)
    t["shadow3"] = (round(s3 * 255) << 24) | (BLACK & 0xFFFFFF)

    # ── v3 增补（不进 AppTokens，写入 meta.additions）──
    extra = {
        "lineStrong": ink_for_layers(tone["line"], [tone["surface"], tone["appBg"], tone["bg"]], 3.0),
        "focusRing": t["primaryInk"],
        "surfaceInset": (mix(tone["surface"], tone["bg"], 0.55) if not is_dark
                         else mix(tone["surface"], BLACK, 0.22)),
        "disabledFg": mix(tone["surface"], tone["faint"], 0.55 if not is_dark else 0.7),
        "disabledBg": mix(tone["surface"], tone["bg"], 0.7 if not is_dark else 0.35),
        "overlay": (round(0.32 * 255) << 24) | (BLACK & 0xFFFFFF) if not is_dark
                   else (round(0.56 * 255) << 24) | (BLACK & 0xFFFFFF),
        "skeleton": mix(tone["surface"], tone["bg"], 0.85 if not is_dark else 0.5),
        "lineStrongSoft": ink_for(mix(tone["line"], tone["ink2"], 0.35) if not is_dark
                                  else mix(tone["line"], tone["ink2"], 0.55), tone["surface"], 2.0),
        "primaryPressed": pressed_fill(p, t["onPrimary"]),
        "accentPressed": pressed_fill(a, on_accent),
    }
    ctx = dict(
        tone_id=tone_id, tone=tone, p=p, a=a, p_soft_hosts=p_soft_hosts,
        p_tint_hosts=p_tint_hosts, a_soft_hosts=a_soft_hosts, on_accent=on_accent,
    )
    return t, extra, ctx


# ══════════════════════════════════════════════════════════════════════════
# 5 · 门禁（41 项复现 + v3 追加）
# ══════════════════════════════════════════════════════════════════════════

class Gate:
    def __init__(self):
        self.passed = 0
        self.failed = []
        self.rows = []

    def check(self, tag, name, fg, bg, target, group):
        r = contrast(fg, bg)
        ok = r >= target
        self.rows.append(dict(combo=tag, item=name, ratio=round(r, 3),
                              target=target, group=group, pass_=ok))
        if ok:
            self.passed += 1
        else:
            self.failed.append(f"FAIL {tag} {name}: {r:.2f} < {target}")

    def report(self):
        return dict(passed=self.passed, failed=len(self.failed),
                    total=self.passed + len(self.failed), failures=self.failed)


def run_gate(t, extra, ctx, is_dark, tag):
    g = Gate()
    tone = ctx["tone"]
    p, a = ctx["p"], ctx["a"]
    hosts = [tone["surface"], tone["surface2"], tone["bg"], tone["appBg"]]

    # ── 复现 theme_contrast_check.dart 的 41 项 ──
    g.check(tag, "ink×bg", tone["ink"], tone["bg"], 4.5, "legacy41")
    g.check(tag, "ink×surface", tone["ink"], tone["surface"], 4.5, "legacy41")
    g.check(tag, "ink2×bg", tone["ink2"], tone["bg"], 4.5, "legacy41")
    g.check(tag, "ink2×surface", tone["ink2"], tone["surface"], 4.5, "legacy41")
    g.check(tag, "muted×bg", tone["muted"], tone["bg"], 4.5, "legacy41")
    g.check(tag, "muted×surface", tone["muted"], tone["surface"], 4.5, "legacy41")
    for i, hst in enumerate(hosts):
        g.check(tag, f"primaryInk×pSoft@{css(hst)}", t["primaryInk"], ctx["p_soft_hosts"][i], 4.5, "legacy41")
        g.check(tag, f"primaryInk×pTint@{css(hst)}", t["primaryInk"], ctx["p_tint_hosts"][i], 4.5, "legacy41")
    g.check(tag, "primaryInk×bg", t["primaryInk"], tone["bg"], 4.5, "legacy41")
    g.check(tag, "primaryInk×surface", t["primaryInk"], tone["surface"], 4.5, "legacy41")
    for i, hst in enumerate(hosts):
        g.check(tag, f"accentInk×aSoft@{css(hst)}", t["accentInk"], ctx["a_soft_hosts"][i], 4.5, "legacy41")
    g.check(tag, "accentInk×bg", t["accentInk"], tone["bg"], 4.5, "legacy41")
    g.check(tag, "accentInk×surface", t["accentInk"], tone["surface"], 4.5, "legacy41")
    g.check(tag, "income×surface", t["income"], tone["surface"], 4.5, "legacy41")
    g.check(tag, "onPrimary×primary", t["onPrimary"], p, 4.5, "legacy41")
    g.check(tag, "onAccent×accent", t["onAccent"], a, 4.5, "legacy41")
    sheen = accent_sheen(a, t["onAccent"])
    g.check(tag, "sheen×onAccent", t["onAccent"], sheen, 4.5, "legacy41")
    g.check(tag, "accent×onAccent", t["onAccent"], a, 4.5, "legacy41")
    for i, nm in enumerate(("hero0", "hero1", "heroD0", "heroD1")):
        g.check(tag, f"{nm}×white", WHITE, t[["heroGrad0", "heroGrad1", "heroDarkGrad0", "heroDarkGrad1"][i]], 4.6, "legacy41")
    g.check(tag, "okInk×okSoft", t["okInk"], t["okSoft"], 4.5, "legacy41")
    g.check(tag, "okInk×surface", t["okInk"], tone["surface"], 4.5, "legacy41")
    g.check(tag, "warnInk×warnSoft", t["warnInk"], t["warnSoft"], 4.5, "legacy41")
    g.check(tag, "dnInk×dnBg", t["dnInk"], t["dnBg"], 4.5, "legacy41")
    g.check(tag, "dnInk×surface", t["dnInk"], tone["surface"], 4.5, "legacy41")
    g.check(tag, "incomeInk×incomeSoft", t["incomeInk"], t["incomeSoft"], 4.5, "legacy41")
    g.check(tag, "incomeInk×surface", t["incomeInk"], tone["surface"], 4.5, "legacy41")
    g.check(tag, "ink×appBg", tone["ink"], tone["appBg"], 4.5, "legacy41")
    g.check(tag, "ink2×appBg", tone["ink2"], tone["appBg"], 4.5, "legacy41")
    g.check(tag, "muted×appBg", tone["muted"], tone["appBg"], 4.5, "legacy41")

    # ── v3 追加 ──
    g.check(tag, "faint×surface(图形)", tone["faint"], tone["surface"], 3.0, "v3-graphics")
    g.check(tag, "faint×appBg(图形)", tone["faint"], tone["appBg"], 3.0, "v3-graphics")
    g.check(tag, "ink2×surface2(图标)", tone["ink2"], tone["surface2"], 3.0, "v3-graphics")
    g.check(tag, "focusRing×surface", extra["focusRing"], tone["surface"], 3.0, "v3-focus")
    g.check(tag, "focusRing×bg", extra["focusRing"], tone["bg"], 3.0, "v3-focus")
    g.check(tag, "lineStrong×surface", extra["lineStrong"], tone["surface"], 3.0, "v3-border")
    g.check(tag, "lineStrong×appBg", extra["lineStrong"], tone["appBg"], 3.0, "v3-border")
    g.check(tag, "barFill×surface(图形)", t["barFill"], tone["surface"], 3.0, "v3-graphics")
    g.check(tag, "barFill×appBg(图形)", t["barFill"], tone["appBg"], 3.0, "v3-graphics")
    g.check(tag, "onPrimary×primaryPressed", t["onPrimary"], extra["primaryPressed"], 4.5, "v3-states")
    g.check(tag, "onAccent×accentPressed", t["onAccent"], extra["accentPressed"], 4.5, "v3-states")
    g.check(tag, "toastFg×toastBg", tone["ink"] if is_dark else tone["surface"], t["toastBg"], 4.5, "v3-toast")
    # 面板层次：靠明度分层，逐级至少 2% 反差（与 1px line 双保险，避免「面糊成一片」）
    pairs = [("surface2", "surface"), ("surface", "appBg"), ("appBg", "bg")]
    for a_n, b_n in pairs:
        r = contrast(tone[a_n], tone[b_n])
        ok = r >= 1.02
        g.rows.append(dict(combo=tag, item=f"layerstep {a_n}>{b_n}", ratio=round(r, 3),
                           target=1.02, group="v3-layering", pass_=ok))
        if ok:
            g.passed += 1
        else:
            g.failed.append(f"FAIL {tag} layerstep {a_n}>{b_n}: {r:.3f} < 1.02")
    return g


# ══════════════════════════════════════════════════════════════════════════
# 6 · main
# ══════════════════════════════════════════════════════════════════════════

def main():
    resolved = {}
    extras = {}
    combos_meta = {}
    all_rows = []
    failures = []
    passed = 0

    for tid, name, tone_id, bl, bd in THEMES:
        for is_dark in (False, True):
            key = "dark" if is_dark else "light"
            t, extra, ctx = resolve(tid, name, tone_id, bl, bd, is_dark)
            combo = f"{tid}.{key}"
            resolved[combo] = {k: (v if k == "accentGrad" else css(v)) for k, v in t.items()}
            extras[combo] = {k: css(v) for k, v in extra.items()}
            combos_meta[combo] = dict(theme=tid, themeName=name, brightness=key, tone=tone_id)
            g = run_gate(t, extra, ctx, is_dark, f"{name}/{key}")
            all_rows += g.rows
            failures += g.failed
            passed += g.passed

    # 分类 ink（12 × 2）：对全部宿主 ≥4.5
    cat_ink = {"light": {}, "dark": {}}
    for cref, cname, chex, _icon, _tags in CATEGORY:
        base = hx(chex)
        for key in ("light", "dark"):
            tone = {k: hx(v) for k, v in TONES["neutral"][key].items()}
            soft = composite(base, TONE_ALPHA["soft"][key], tone["surface"])
            v = ink_for_layers(base, [tone["surface"], tone["bg"], tone["appBg"], soft], 4.5)
            cat_ink[key][cref] = css(v)
            for host, hn in ((tone["surface"], "surface"), (soft, "soft")):
                r = contrast(v, host)
                ok = r >= 4.5
                if ok:
                    passed += 1
                else:
                    failures.append(f"FAIL categoryInk {cname}/{key}/{hn}: {r:.2f}")

    # INV-1：分类基色唯一数 = 12
    if len({c[2] for c in CATEGORY}) != 12:
        failures.append("INV-1 violated: 分类基色必须 12 个唯一值")
    if len(set(SEM_LIGHT.values())) < 5:
        failures.append("INV-1 violated: 语义色亮态值异常")

    gate = dict(
        legacy41_per_combo=41,
        v3_extra_per_combo=len([r for r in all_rows if r["combo"] == "青瓷/light" and r["group"].startswith("v3")]),
        total=passed + len(failures),
        passed=passed,
        failed=len(failures),
        min_ratio=min(r["ratio"] for r in all_rows),
        failures=failures[:60],
    )

    doc = {
        "version": "3.0",
        "generatedBy": "_build/gen_tokens.py（可复算；不要手改本文件）",
        "meta": {
            "product": "素记 / Plain",
            "direction": "Quiet Ledger · 安静的账本",
            "appTokensFields": 53,
            "combos": 20,
            "colorEncoding": "CSS #RRGGBBAA。Dart 侧须转 0xAARRGGBB —— 字节序相反。",
            "alphaPolicy": {
                "primarySoft": TONE_ALPHA["soft"],
                "primaryTint": TONE_ALPHA["tint"],
                "accentSoft": TONE_ALPHA["asoft"],
                "note": "品牌淡彩层保留 alpha（不是预混色），由绘制时与宿主合成；结构色一律不透明。",
            },
            "additions": ADDITIONS,
            "deprecated": [
                "heroGrad0/1 与 heroDarkGrad0/1：v3 不使用（结余区改为纯排印 + 发丝线，去掉了渐变面板）。"
                "保留冻结值仅为让 41 项门禁中的 hero×白字 4 项继续成立。",
                "heroCard0/1：已归中为 surface / surface2，防止有人沿用旧的米黄值 #FFFCF4 把暖底带回来。",
            ],
        },
        "tones": {k: {bk: {kk: css(hx(vv)) for kk, vv in bv.items()} for bk, bv in kv.items()}
                  for k, kv in TONES.items()},
        "themes": {tid: dict(name=name, tone=tone_id, main=css(hx(bl[0])), mainDark=css(hx(bd[0])),
                             accent=css(hx(bl[2])), accentDark=css(hx(bd[2])))
                   for tid, name, tone_id, bl, bd in THEMES},
        "type": TYPE,
        "space": SPACE,
        "radius": RADIUS,
        "stroke": STROKE,
        "elevation": ELEVATION,
        "motion": MOTION,
        "sizes": SIZES,
        "bans": TOKEN_BANS,
        "invariants": {
            "category": [dict(ref=c[0], name=c[1], base=css(hx(c[2])), iconRef=c[3], tags=c[4])
                         for c in CATEGORY],
            "categoryInk": cat_ink,
            "semantic": {
                "light": {k: css(hx(v)) for k, v in SEM_LIGHT.items()},
                "dark": {k: css(hx(v)) for k, v in SEM_DARK.items()},
                "redIsIncome": "红=进账，绿=下跌/节省（中文金融习惯，与欧美相反）",
            },
        },
        "combos": combos_meta,
        "resolved": resolved,
        "v3Additions": extras,
        "gates": gate,
    }
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump(doc, fh, ensure_ascii=False, indent=1)

    print(f"resolved combos : {len(resolved)}")
    print(f"AppTokens fields: {len(next(iter(resolved.values())))}")
    print(f"gate            : {passed} passed / {len(failures)} failed / {passed + len(failures)} total")
    print(f"gate min ratio  : {min(r['ratio'] for r in all_rows):.3f}")
    if failures:
        print("\n".join(failures[:60]))
        return 1
    print("ALL GREEN ✓")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
