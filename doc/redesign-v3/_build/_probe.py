"""临时探针 v2：量测「活动帧」内各区块真实高度，用于核对 844 高度预算。用后即删。"""
import sys, os, tempfile, subprocess, shutil

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shoot

PROBE = """
<script>
window.addEventListener('load', function () {
  var fr = document.querySelector('.frame.active');
  var scr = fr.querySelector('.screen');
  var out = [];
  out.push('screen rect = ' + JSON.stringify(scr.getBoundingClientRect()));
  var total = 0;
  Array.prototype.forEach.call(scr.children, function (c) {
    var r = c.getBoundingClientRect(), cs = getComputedStyle(c);
    total += r.height;
    out.push(pad(c.className, 24) + ' h=' + Math.round(r.height)
             + ' scrollH=' + c.scrollHeight + ' flex=' + cs.flex
             + ' y=' + Math.round(r.top - scr.getBoundingClientRect().top));
  });
  out.push('--- 子项高度合计 = ' + Math.round(total) + ' / 844');
  var sc = scr.querySelector('.scroll');
  if (sc) out.push('scroll 区 height=' + Math.round(sc.getBoundingClientRect().height)
                   + ' scrollHeight=' + sc.scrollHeight
                   + ' 溢出=' + (sc.scrollHeight - Math.round(sc.getBoundingClientRect().height)));
  document.body.innerHTML = '<pre id="P">' + out.join('\\n') + '</pre>';
});
function pad(s, n) { while (s.length < n) s += ' '; return s; }
</script>
"""


def run(screen, theme="subai", mode="light", lang="zh"):
    src = open(shoot.SRC, encoding="utf-8").read()
    html = shoot.build_variant(src, theme=theme, mode=mode, lang=lang, screen=screen)
    html = html.replace("</body>", PROBE + "</body>")
    # 必须与 07-SCREENS.html 同目录，否则 @font-face 相对路径 404、量到的是回退字体
    p = os.path.join(shoot.ROOT, "._probe.html")
    open(p, "w", encoding="utf-8").write(html)
    prof = tempfile.mkdtemp()
    url = "file:///" + p.replace("\\", "/").lstrip("/")
    cmd = [shoot.CHROME, "--headless=new", "--disable-gpu", "--no-first-run",
           "--allow-file-access-from-files", "--user-data-dir=" + prof,
           "--virtual-time-budget=3000", "--window-size=390,844", "--dump-dom", url]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=90)
    s = r.stdout
    i, j = s.find('<pre id="P">'), s.find("</pre>")
    print("=" * 70)
    print("SCREEN =", screen, mode, lang)
    print("=" * 70)
    print(s[i + 12:j] if i >= 0 else "DUMP tail:\n" + s[-1000:])
    try:
        os.remove(p)
    except OSError:
        pass
    shutil.rmtree(prof, ignore_errors=True)


for sc in sys.argv[1:] or ["add"]:
    run(sc)
