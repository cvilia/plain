"""素记 Plain · redesign-v3 — 高保真截图器（无头 Chrome）

产出：redesign-v3/09-SCREENS-ASSETS/*.png

做法：
  · 不另写一份 HTML。直接复用 07-SCREENS.html，只做字符串级改造：
      - 预设 <body> 的 data-theme / data-mode / data-lang / data-size
      - 单屏模式：data-view="single" + 给目标 frame 加 active
      - 注入一段「shot 模式」CSS：去掉工具条与舞台边距，让 390×844 一帧对齐到 (0,0)
  · 这样截图与交付 HTML 永远同源，不会出现「截图很美、HTML 不是那样」。

运行：python _build/shoot.py
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
SRC = os.path.join(ROOT, "07-SCREENS.html")
OUT = os.path.join(ROOT, "09-SCREENS-ASSETS")

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

SHOT_CSS_SINGLE = """
html,body{background:#FFFFFF!important;padding:0!important;margin:0!important}
body .toolbar{display:none!important}
body .stage{padding:0!important;gap:0!important;display:block!important;
  justify-content:flex-start!important;flex-wrap:nowrap!important}
body .flabel{display:none!important}
/* ⚠️ 必须抵消交付页面里的响应式兜底：
     @media (max-width:520px){.frame{transform:scale(.82);margin-bottom:-152px}}
   无头视口宽度会落到 520 以下，若不抵消，一帧会被缩到 320×692，
   截图下缘出现 152px 空白（实测踩过）。这里用 !important 压回去，
   页面本身那条规则不动 —— 它在真机窄屏下是正确行为。 */
body .frame{position:relative!important;width:390px!important;height:844px!important;
  margin:0!important;transform:none!important}
"""

SHOT_CSS_GRID = """
body{padding:0!important}
body .toolbar{display:none!important}
"""


def build_variant(html: str, *, theme, mode, lang, size="standard", screen=None) -> str:
    """返回一份只用于截图的 HTML 文本。

    screen 有值 → 单屏模式（data-view=single + 目标帧 active），输出恰好一帧。
    screen 为 None → 网格模式，保留全部帧与帧标签，只隐藏脚手架工具条。
    """

    # ── 1. body 属性
    i = html.index("<body")
    j = html.index(">", i)
    body_tag = html[i:j]
    body_tag = _set_attr(body_tag, "data-theme", theme)
    body_tag = _set_attr(body_tag, "data-mode", mode)
    body_tag = _set_attr(body_tag, "data-lang", lang)
    if screen:
        body_tag = _set_attr(body_tag, "data-size", size)
        body_tag = _set_attr(body_tag, "data-view", "single")
    html = html[:i] + body_tag + html[j:]

    # ── 2. 只显示目标帧
    if screen:
        needle = '<section class="frame" data-screen="%s" data-lang="%s">' % (screen, lang)
        if needle not in html:
            raise SystemExit("找不到帧：" + needle)
        html = html.replace(needle, needle.replace('class="frame"', 'class="frame active"'), 1)

    # ── 3. shot CSS 注入（放在 </style> 之前，优先级靠后）
    k = html.rindex("</style>")
    css = SHOT_CSS_SINGLE if screen else SHOT_CSS_GRID
    return html[:k] + css + html[k:]


def _set_attr(tag: str, name: str, val: str) -> str:
    import re

    if re.search(r'%s="[^"]*"' % name, tag):
        return re.sub(r'%s="[^"]*"' % name, '%s="%s"' % (name, val), tag)
    return tag + ' %s="%s"' % (name, val)


def chrome_shot(html_path: str, out_png: str, w: int, h: int, scale: int) -> None:
    profile = tempfile.mkdtemp(prefix="plainshot_")
    url = "file:///" + html_path.replace("\\", "/").lstrip("/")
    cmd = [
        CHROME,
        "--headless=new",
        "--disable-gpu",
        "--hide-scrollbars",
        "--no-first-run",
        "--no-default-browser-check",
        "--allow-file-access-from-files",
        "--font-render-hinting=none",
        "--force-device-scale-factor=%d" % scale,
        "--user-data-dir=" + profile,
        "--virtual-time-budget=4000",
        "--window-size=%d,%d" % (w, h),
        "--screenshot=" + out_png,
        url,
    ]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    shutil.rmtree(profile, ignore_errors=True)
    if not os.path.exists(out_png):
        print("!! 截图失败", out_png)
        print((r.stderr or "")[-1200:])
        raise SystemExit(1)


def autocrop(path: str) -> None:
    """把舞台四周的空白裁掉（背景是纯 #FFFFFF）。"""
    try:
        from PIL import Image
    except ImportError:
        return
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    bg = (255, 255, 255)

    def row_empty(y):
        for x in range(0, w, 3):
            if px[x, y] != bg:
                return False
        return True

    def col_empty(x):
        for y in range(0, h, 3):
            if px[x, y] != bg:
                return False
        return True

    top = 0
    while top < h - 1 and row_empty(top):
        top += 1
    bot = h - 1
    while bot > top and row_empty(bot):
        bot -= 1
    left = 0
    while left < w - 1 and col_empty(left):
        left += 1
    right = w - 1
    while right > left and col_empty(right):
        right -= 1
    if (left, top, right, bot) == (0, 0, w - 1, h - 1):
        return
    im.crop((left, top, right + 1, bot + 1)).save(path)


def main() -> int:
    src = open(SRC, encoding="utf-8").read()
    os.makedirs(OUT, exist_ok=True)
    # ⚠️ 临时 HTML 必须与 07-SCREENS.html 同目录，不能写进子目录或系统临时目录。
    #    页面里的 @font-face 用相对路径（12-FONTS/ 与 ../plain/assets/fonts/misans/），
    #    换到别的目录就全部 404 → 字体静默回退，截图看着「差不多」但根本不是 MiSans。
    #    （实测过一次：document.fonts 全部 status=error，数字宽度其实是回退字体的。）
    tmp = ROOT
    shot_files = []

    jobs = []

    # ── 可选过滤：`python shoot.py reports ledger` 只重出名字含这些子串的图。
    #    改一屏时不必等全部 38 张（全量约 5~6 分钟）。
    _filters = [a for a in sys.argv[1:] if not a.startswith("-")]

    def _keep(name: str) -> bool:
        return not _filters or any(f in name for f in _filters)

    # ── A. 四张主力屏 × 亮暗 × 中英（16 张）
    key = ["ledger", "add", "reports", "settings"]
    for sc in key:
        for mode in ("light", "dark"):
            for lang in ("zh", "en"):
                jobs.append(
                    dict(
                        name="%s--%s-%s" % (sc, mode, lang),
                        screen=sc, theme="subai", mode=mode, lang=lang,
                        w=390, h=844, scale=2, crop=False,
                    )
                )

    # ── B. 其余四屏：亮中必出 + 亮英 / 暗中 / 暗英（补齐暗态与中英覆盖）
    #    这四屏里藏着最易在暗态与英文下出问题的位置：
    #    详情页的危险按钮描边、分类管理的多行英文、资产页的正负号 —— 都值得有图。
    for sc in ("guide", "detail", "assets", "categories"):
        jobs.append(
            dict(name="%s--light-zh" % sc, screen=sc, theme="subai",
                 mode="light", lang="zh", w=390, h=844, scale=2, crop=False)
        )
        extra = [("light", "en"), ("dark", "zh"), ("dark", "en")]
        for mode, lang in extra:
            jobs.append(
                dict(name="%s--%s-%s" % (sc, mode, lang), screen=sc, theme="subai",
                     mode=mode, lang=lang, w=390, h=844, scale=2, crop=False)
            )

    # ── C. 第二主题（青瓷）证明 10 主题可跑：首页 亮/暗
    for mode in ("light", "dark"):
        jobs.append(
            dict(name="ledger--qingci-%s-zh" % mode, screen="ledger", theme="qingci",
                 mode=mode, lang="zh", w=390, h=844, scale=2, crop=False)
        )

    # ── D. 总览：8 屏网格（4 行 × 2 列）。亮暗 × 中英 各一份 = 4 张
    #    画布高度：4×844 + 3×34(gap) + 2×34(padding) = 3546，再留 24 给首行帧标签
    for mode in ("light", "dark"):
        for lang in ("zh", "en"):
            jobs.append(
                dict(name="overview-%s-%s" % (mode, lang), screen=None, theme="subai",
                     mode=mode, lang=lang, w=880, h=3620, scale=1, crop=True)
            )

    n = 0
    jobs = [j for j in jobs if _keep(j["name"])]
    if _filters:
        print("过滤 %s → %d 张" % (_filters, len(jobs)))
    try:
        for job in jobs:
            html = build_variant(
                src, theme=job["theme"], mode=job["mode"], lang=job["lang"],
                screen=job["screen"],
            )
            p = os.path.join(tmp, "._shot_%s.html" % job["name"])
            open(p, "w", encoding="utf-8").write(html)
            shot_files.append(p)
            out = os.path.join(OUT, job["name"] + ".png")
            chrome_shot(p, out, job["w"], job["h"], job["scale"])
            if job["crop"]:
                autocrop(out)
            n += 1
            print("  [%2d/%d] %s" % (n, len(jobs), job["name"] + ".png"))
    finally:
        for f in shot_files:
            try:
                os.remove(f)
            except OSError:
                pass

    print("\n完成：%d 张 → %s" % (n, OUT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
