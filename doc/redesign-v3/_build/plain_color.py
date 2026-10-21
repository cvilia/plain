"""素记 Plain · redesign-v3 — 颜色数学（与 color_math.dart 位对齐的独立第二实现）。

为什么要有这个文件：01-tokens.json 的 20 组 resolved 不是手填的，是复算出来的。
只要色值走脚本，就不会出现「文档写一套、代码跑出来另一套」。

约定：内部一律用 ARGB int（0xAARRGGBB），与 Dart 侧完全一致；
只在输出到 tokens.json 时转成 CSS `#RRGGBBAA`。

⚠️ mix 是 **sRGB 分量线性插值**，不是线性光插值 —— 必须和浏览器 / Flutter 的
source-over 合成逐位一致，否则门禁验的不是真正渲染出来的颜色。
"""

from __future__ import annotations

BLACK = 0xFF000000
WHITE = 0xFFFFFFFF


# ─────────────────────────────────────────────────────────────── 解析 / 输出


def hx(s) -> int:
    """'#RRGGBB' / '#RRGGBBAA' / '0xAARRGGBB' / int → ARGB int。"""
    if isinstance(s, int):
        return s
    t = s.replace("#", "")
    if t.lower().startswith("0x"):
        t = t[2:]
    if len(t) == 6:
        t = "FF" + t
    return int(t, 16)


def css(argb: int) -> str:
    """ARGB int → CSS `#RRGGBBAA`（字母序与 Dart 相反，这是最容易踩的一脚）。"""
    a = (argb >> 24) & 0xFF
    r = (argb >> 16) & 0xFF
    g = (argb >> 8) & 0xFF
    b = argb & 0xFF
    return "#%02X%02X%02X%02X" % (r, g, b, a)


def dart(argb: int) -> str:
    return "0x%08X" % argb


def _rgb(argb: int):
    return (argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF


def alpha_of(argb: int) -> float:
    return ((argb >> 24) & 0xFF) / 255.0


def opaque(argb: int) -> int:
    return 0xFF000000 | (argb & 0xFFFFFF)


# ─────────────────────────────────────────────────────────────── WCAG


def _lin(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lum(argb: int) -> float:
    r, g, b = _rgb(argb)
    return 0.2126 * _lin(r / 255) + 0.7152 * _lin(g / 255) + 0.0722 * _lin(b / 255)


def contrast(a: int, b: int) -> float:
    la, lb = lum(a), lum(b)
    hi, lo = (la, lb) if la > lb else (lb, la)
    return (hi + 0.05) / (lo + 0.05)


def mix(a: int, b: int, t: float) -> int:
    t = max(0.0, min(1.0, t))
    ar, ag, ab = _rgb(a)
    br, bg, bb = _rgb(b)
    r = round(ar * (1 - t) + br * t)
    g = round(ag * (1 - t) + bg * t)
    bl = round(ab * (1 - t) + bb * t)
    return 0xFF000000 | (r << 16) | (g << 8) | bl


def composite(fg: int, alpha: float, bg: int) -> int:
    """fg 以 alpha 叠在 bg 上 → 不透明结果。"""
    return mix(bg, opaque(fg), alpha)


# ─────────────────────────────────────────────────────────────── 派生规则（§4.6）


def ink_for(fg: int, bg: int, target: float) -> int:
    """① inkFor：在 [fg] 附近找对 [bg] ≥ target 的颜色。方向由黑白端点决定。"""
    if contrast(fg, bg) >= target:
        return fg
    to_black = contrast(BLACK, bg) > contrast(WHITE, bg)
    endpoint = BLACK if to_black else WHITE
    t = 0.05
    while t <= 1.0 + 1e-9:
        c = mix(fg, endpoint, t)
        if contrast(c, bg) >= target:
            return c
        t += 0.05
    return endpoint


def pick_on(bg: int, deep: int, target: float) -> int:
    """② pickOn：实心块上的前景。先试主题墨 → 白 → inkFor(white)。"""
    if contrast(deep, bg) >= target:
        return deep
    if contrast(WHITE, bg) >= target:
        return WHITE
    return ink_for(WHITE, bg, target)


def accent_sheen(accent: int, on_accent: int) -> int:
    """③ accentSheen：渐变高光端点。"""
    toward = BLACK if on_accent == WHITE else WHITE
    return mix(accent, toward, 0.12)


def pressed_fill(c: int, on_c: int, amount: float = 0.10) -> int:
    """实心控件的「按下」填充。

    ⚠️ 不能用 primaryDeep / accentDeep 当按下底 —— 当标签是近黑时，底色再压暗
    会把对比度吃穿（实测最差 2.65:1）。正确做法是**底色朝标签色的反方向位移**，
    按下同时对比度不降反升。与 accentSheen 同一套规则，只是位移量更小。
    """
    toward = WHITE if lum(on_c) < 0.5 else BLACK
    return mix(c, toward, amount)


def hero_safe(c: int) -> int:
    """④ heroSafe：压暗使白字 ≥ 4.6:1。"""
    target = 4.6
    if contrast(WHITE, c) >= target:
        return c
    t = 0.05
    while t <= 1.0 + 1e-9:
        d = mix(c, BLACK, t)
        if contrast(WHITE, d) >= target:
            return d
        t += 0.05
    return BLACK


def ink_for_layers(fg: int, backgrounds, target: float) -> int:
    """①′ inkForLayers：对 backgrounds 中**每一个**底都 ≥ target。"""
    if not backgrounds:
        return fg

    def ok(c):
        return all(contrast(c, bg) >= target for bg in backgrounds)

    if ok(fg):
        return fg
    hardest = min(backgrounds, key=lambda bg: contrast(fg, bg))
    to_black = contrast(BLACK, hardest) > contrast(WHITE, hardest)
    primary_end = BLACK if to_black else WHITE
    fallback_end = WHITE if to_black else BLACK
    for endpoint in (primary_end, fallback_end):
        t = 0.05
        while t <= 1.0 + 1e-9:
            c = mix(fg, endpoint, t)
            if ok(c):
                return c
            t += 0.05
        if ok(endpoint):
            return endpoint
    return primary_end


# ─────────────────────────────────────────────────────────────── 自检

if __name__ == "__main__":
    samples = [
        (hx("#14B8A6"), hx("#FFFFFF")),
        (hx("#FB923C"), hx("#FFFFFF")),
        (hx("#1F2D28"), hx("#F1F5F3")),
    ]
    for fg, bg in samples:
        print(css(fg), css(bg), round(contrast(fg, bg), 3))
    print("onAccent/素白 =", css(pick_on(hx("#FB923C"), hx("#111113"), 4.5)))
    print("heroSafe/青瓷 =", css(hero_safe(hx("#2DD4BF"))))
