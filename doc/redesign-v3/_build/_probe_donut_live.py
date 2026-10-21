"""探针：在真浏览器里量环形图中心金额的实际渲染宽度（不靠推算）。

问：`.dn-c1` 的 bbox 宽是否 <= 环内孔直径？
内孔直径 = 2 * (r - stroke/2)（从 SVG 属性实地读取，不写死）。

用后即删临时 HTML。只读。
"""
import os
import shutil
import subprocess
import tempfile

import shoot

PROBE = """
<script>
window.addEventListener('load', function () {
  var out = [];
  var t = document.querySelector('.dn-c1');
  var segs = document.querySelectorAll('.donut .dn-seg');
  var r = parseFloat(segs[0].getAttribute('r'));
  var sw = parseFloat(getComputedStyle(document.querySelector('.donut g')).strokeWidth);
  var hole = 2 * (r - sw / 2);
  var b = t.getBBox();
  out.push('r=' + r + '  stroke=' + sw + '  内孔直径=' + hole.toFixed(2));
  out.push('.dn-c1 font-size = ' + getComputedStyle(t).fontSize);
  var cur = t.querySelector('.dn-cur');
  out.push('.dn-cur font-size = ' + (cur ? getComputedStyle(cur).fontSize : ''));
  out.push('bbox = x:' + b.x.toFixed(2) + ' w:' + b.width.toFixed(2)
           + ' h:' + b.height.toFixed(2));
  out.push('左右各余 = ' + ((hole - b.width) / 2).toFixed(2) + 'px');
  out.push('判定 = ' + (b.width <= hole - 4 ? 'PASS' : 'FAIL 溢出 ' + (b.width - hole).toFixed(2)));
  out.push('center x = ' + (b.x + b.width / 2).toFixed(2) + ' （环心 68.0）');
  out.push('TOTAL bbox = ' + JSON.stringify(
    (function () { var c = document.querySelector('.dn-c2').getBBox();
       return {x: +c.x.toFixed(2), y: +c.y.toFixed(2),
               w: +c.width.toFixed(2), h: +c.height.toFixed(2)}; })()));
  document.body.innerHTML = '<pre id="P">' + out.join('\\n') + '</pre>';
});
</script>
"""


def main():
    src = open(shoot.SRC, encoding="utf-8").read()
    html = shoot.build_variant(src, theme="subai", mode="dark", lang="zh",
                               screen="reports")
    html = html.replace("</body>", PROBE + "</body>")
    p = os.path.join(shoot.ROOT, "._probe_donut.html")
    open(p, "w", encoding="utf-8").write(html)
    prof = tempfile.mkdtemp()
    url = "file:///" + p.replace("\\", "/").lstrip("/")
    cmd = [shoot.CHROME, "--headless=new", "--disable-gpu", "--no-first-run",
           "--allow-file-access-from-files", "--user-data-dir=" + prof,
           "--virtual-time-budget=4000", "--window-size=730,1200", "--dump-dom", url]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=90)
    s = r.stdout
    i, j = s.find('<pre id="P">'), s.find("</pre>")
    print(s[i + 12:j] if i >= 0 else "DUMP tail:\n" + s[-1500:])
    try:
        os.remove(p)
    except OSError:
        pass
    shutil.rmtree(prof, ignore_errors=True)


main()
