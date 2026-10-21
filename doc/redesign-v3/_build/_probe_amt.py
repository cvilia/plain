"""临时探针：量金额四段式各段的 computed color。用后即删。"""
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
  var out = [];
  var st = document.querySelector('.stage');
  var cs = getComputedStyle(st);
  out.push('--muted      = ' + cs.getPropertyValue('--muted').trim());
  out.push('--accent     = ' + cs.getPropertyValue('--accent').trim());
  out.push('--ink        = ' + cs.getPropertyValue('--ink').trim());
  out.push('--primary    = ' + cs.getPropertyValue('--primary').trim());
  out.push('--income-ink = ' + cs.getPropertyValue('--income-ink').trim());
  out.push('');
  var fr = document.querySelector('.frame[data-screen="2"]');
  var amt = fr.querySelector('.amt');
  out.push('amt computed color = ' + getComputedStyle(amt).color);
  ['.cur', '.int', '.pnt', '.dec'].forEach(function (sel) {
    var el = fr.querySelector('.amt ' + sel);
    if (!el) { out.push(sel + ' -> (无此段)'); return; }
    var c = getComputedStyle(el);
    out.push(sel + ' -> color=' + c.color + '  font-size=' + c.fontSize
             + '  matched="' + Array.prototype.slice.call(document.styleSheets).length + '"');
  });
  // 找出到底哪条规则命中 .cur
  var el2 = fr.querySelector('.amt .cur');
  var hits = [];
  Array.prototype.forEach.call(document.styleSheets, function (sh) {
    var rules; try { rules = sh.cssRules; } catch (e) { return; }
    Array.prototype.forEach.call(rules, function (r) {
      if (r.selectorText && /\\.amt \\.cur|^\\.cur/.test(r.selectorText)) {
        hits.push(r.selectorText + ' { ' + r.style.cssText + ' }');
      }
    });
  });
  out.push('');
  out.push('命中 .cur 的规则:');
  hits.forEach(function (h) { out.push('  ' + h); });
  document.body.innerHTML = '<pre id="P">' + out.join('\\n') + '</pre>';
});
</script>
"""

src = open(os.path.join(ROOT, "单独确认.html"), encoding="utf-8").read()
html = src.replace("</body>", PROBE + "</body>")
p = os.path.join(ROOT, "._probe_amt.html")
open(p, "w", encoding="utf-8").write(html)
prof = tempfile.mkdtemp()
url = "file:///" + p.replace("\\", "/").lstrip("/")
cmd = [CHROME, "--headless=new", "--disable-gpu", "--no-first-run",
       "--allow-file-access-from-files", "--user-data-dir=" + prof,
       "--virtual-time-budget=3000", "--window-size=1400,900", "--dump-dom", url]
r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
s = r.stdout
i, j = s.find('<pre id="P">'), s.find("</pre>")
print(s[i + 12:j] if i >= 0 else "DUMP:\n" + s[-1500:])
try:
    os.remove(p)
except OSError:
    pass
shutil.rmtree(prof, ignore_errors=True)
