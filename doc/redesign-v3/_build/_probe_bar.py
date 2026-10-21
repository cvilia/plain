"""临时探针：量预算页每条进度条的实际渲染宽度 vs 期望百分比。用后即删。"""
import os
import shutil
import subprocess
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

PROBE = """
<script>
window.addEventListener('load', function () {
  var fr = document.querySelector('.frame[data-screen="25"]');
  var out = [];
  document.querySelectorAll('.frame').forEach(function (f) { f.style.display = 'none'; });
  fr.style.display = 'block'; fr.style.transform = 'none'; fr.style.margin = '0';
  var rows = fr.querySelectorAll('.prow');
  rows.forEach(function (rw, i) {
    var name = rw.querySelector('.prowname').textContent.trim();
    var bar = rw.querySelector('.pbar');
    var fill = rw.querySelector('.pbar > i');
    var br = bar.getBoundingClientRect(), fR = fill.getBoundingClientRect();
    var cs = getComputedStyle(fill);
    out.push((i + 1) + '. ' + name
      + ' | bar=' + Math.round(br.width) + 'px'
      + ' fill=' + Math.round(fR.width) + 'px'
      + ' = ' + (fR.width / br.width * 100).toFixed(1) + '%'
      + ' | inline=' + fill.getAttribute('style')
      + ' | css.w=' + cs.width + ' bg=' + cs.backgroundColor);
  });
  document.body.innerHTML = '<pre id="P">' + out.join('\\n') + '</pre>';
});
</script>
"""

src = open(os.path.join(ROOT, "单独确认.html"), encoding="utf-8").read()
html = src.replace("</body>", PROBE + "</body>")
p = os.path.join(ROOT, "._probe_bar.html")
open(p, "w", encoding="utf-8").write(html)
prof = tempfile.mkdtemp()
url = "file:///" + p.replace("\\", "/").lstrip("/")
cmd = [CHROME, "--headless=new", "--disable-gpu", "--no-first-run",
       "--allow-file-access-from-files", "--user-data-dir=" + prof,
       "--virtual-time-budget=3000", "--window-size=1400,900", "--dump-dom", url]
r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
s = r.stdout
i, j = s.find('<pre id="P">'), s.find("</pre>")
print(s[i + 12:j] if i >= 0 else "DUMP:\n" + s[-1200:])
try:
    os.remove(p)
except OSError:
    pass
shutil.rmtree(prof, ignore_errors=True)
