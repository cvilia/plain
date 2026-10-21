"""给标注版截图（人工复核版面用）。

两个坑，都绕开了：

1. **不用 `window.scrollTo`** —— 无头下时机不可靠（实测截出 10 KB 空白图）。
   改成「只让目标那屏显示」，版面位置确定，不依赖滚动。

2. **不用 CSS `nth-of-type` 选卡片** —— `.doc` 的子元素里 `.hero-doc` 和 `.card`
   都是 `div`，`nth-of-type` 会把两者混在一起数，偏移量靠不住。
   改成在 `</body>` 前注入一段**同步**脚本直接 `style.display='none'`：
   `RENDER_JS` 是同步建 `.spec` 的，所以脚本跑的时候 DOM 已就绪，
   既不用 `setTimeout` 也就没有和 `--screenshot` 抢时机的问题。

用法：
    python _shoot_ann.py                      # 全部
    python _shoot_ann.py 07-screen05 08-screen09   # 只重出指定几张
"""
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
HTML = os.path.join(ROOT, "单独确认-标注版.html")
OUTDIR = os.path.join(ROOT, "14-SPEC-ASSETS")
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

# 文档头的 5 张卡片（0 基）：0 规范一致性 / 1 11项修正 / 2 结论+字号圆角表 /
# 3 色值令牌 / 4 怎么读
# 每张：(名字, 视口宽, 视口高, 显示卡片下标, hero 是否显示, 只显第 N 屏[1 基, 0=不显屏])
SHOTS = [
    ("01-overview", 1520, 1000, [0], True, 0),
    ("02-audit", 1520, 2100, [1, 2, 3, 4], True, 0),
    ("03-screen01", 1520, 1400, [], False, 1),
    ("04-screen03", 1520, 1400, [], False, 3),
    ("05-screen07", 1520, 1400, [], False, 7),
    ("06-screen23", 1520, 1400, [], False, 23),
    # 下缘越界最严重的两屏 —— 用来复核 .ovclip 裁切与 ▾ 标记
    ("07-screen05", 1520, 1400, [], False, 5),
    ("08-screen09", 1520, 1400, [], False, 9),
]

# 同步隐藏脚本：跑在 </body> 前，此时 .spec 已由 RENDER_JS 建好
HIDE = """<script>
(function () {
  var showCards = %s, showHero = %s, showSpec = %d;
  Array.prototype.forEach.call(document.querySelectorAll('.doc > .card'),
    function (c, i) { if (showCards.indexOf(i) < 0) c.style.display = 'none'; });
  var hd = document.querySelector('.hero-doc');
  if (hd) hd.style.display = showHero ? '' : 'none';
  Array.prototype.forEach.call(document.querySelectorAll('.spec'),
    function (s, i) { if (i + 1 !== showSpec) s.style.display = 'none'; });
})();
</script>"""


def main():
    want = sys.argv[1:]
    os.makedirs(OUTDIR, exist_ok=True)
    src = open(HTML, encoding="utf-8").read()
    for name, w, h, cards, hero, nth in SHOTS:
        if want and name not in want:
            continue
        js = HIDE % ("[" + ",".join(str(c) for c in cards) + "]",
                     "true" if hero else "false", nth)
        tmp = os.path.join(ROOT, "._shoot_ann.html")
        open(tmp, "w", encoding="utf-8").write(src.replace("</body>", js + "</body>"))
        prof = tempfile.mkdtemp()
        out = os.path.join(OUTDIR, name + ".png")
        url = "file:///" + tmp.replace("\\", "/").lstrip("/")
        cmd = [CHROME, "--headless=new", "--disable-gpu", "--no-first-run",
               "--hide-scrollbars", "--allow-file-access-from-files",
               "--user-data-dir=" + prof, "--force-device-scale-factor=1",
               "--virtual-time-budget=7000",
               f"--window-size={w},{h}", f"--screenshot={out}", url]
        subprocess.run(cmd, capture_output=True, text=True, timeout=180)
        ok = os.path.exists(out)
        print(f'{"OK " if ok else "FAIL"} {name}.png {os.path.getsize(out) if ok else 0}')
        shutil.rmtree(prof, ignore_errors=True)
        try:
            os.remove(tmp)
        except OSError:
            pass


if __name__ == "__main__":
    sys.exit(main())
