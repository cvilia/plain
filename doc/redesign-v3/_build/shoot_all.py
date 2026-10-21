"""给「单独确认.html」的全部 29 帧逐屏出图（亮态中文）。

⚠️ 临时 HTML 必须写在 redesign-v3/ 根目录 —— @font-face 用的是相对路径
   `12-FONTS/…`，写到系统临时目录会 404，截出来的是回退字体（踩过）。
⚠️ 页面自带 `@media (max-width:520px){.frame{transform:scale(.82)}}`，
   无头视口 390 会命中 → 每张图下缘多一条空白、内容只占 82%。必须 !important 抵消。
"""
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
OUT = os.path.join(ROOT, "13-ALL-SCREENS-ASSETS")
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

SLUG = ["guide", "ledger", "add", "detail", "categories", "assets", "reports", "backup",
        "find", "theme", "settings",
        "addplus", "split", "claim", "cardbill", "remind", "rule", "goal", "homecards",
        "invest", "loan", "networth", "sankey", "cross", "age", "budget", "family",
        "api", "desk"]

INJECT = """
<style>
html,body{background:#FFFFFF !important}
.toolbar,.vergrouph{display:none !important}
.stage{display:block !important;padding:0 !important;gap:0 !important;
  justify-content:flex-start !important}
.frame{display:none !important;transform:none !important;margin:0 !important}
.frame[data-shot]{display:block !important}
.frame .flabel{display:none !important}
</style>
"""


def main():
    only = sys.argv[1:]
    src = open(os.path.join(ROOT, "单独确认.html"), encoding="utf-8").read()
    os.makedirs(OUT, exist_ok=True)
    tmp = os.path.join(ROOT, "._shoot_all.html")

    n = 0
    for i, slug in enumerate(SLUG):
        if only and slug not in only:
            continue
        html = src.replace("</head>", INJECT + "</head>")
        html = html.replace(f'<section class="frame" data-screen="{i}">',
                            f'<section class="frame" data-screen="{i}" data-shot>')
        open(tmp, "w", encoding="utf-8").write(html)
        prof = tempfile.mkdtemp()
        out = os.path.join(OUT, f"{i + 1:02d}-{slug}.png")
        url = "file:///" + tmp.replace("\\", "/").lstrip("/")
        cmd = [CHROME, "--headless=new", "--disable-gpu", "--no-first-run",
               "--hide-scrollbars", "--allow-file-access-from-files",
               "--user-data-dir=" + prof, "--force-device-scale-factor=2",
               "--virtual-time-budget=3500", "--window-size=390,844",
               f"--screenshot={out}", url]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        ok = os.path.exists(out)
        n += 1
        print(f'{"OK " if ok else "FAIL"} {os.path.basename(out)} '
              f'{os.path.getsize(out) if ok else 0}')
        shutil.rmtree(prof, ignore_errors=True)
    try:
        os.remove(tmp)
    except OSError:
        pass
    print("total", n)


if __name__ == "__main__":
    sys.exit(main())
