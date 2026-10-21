"""临时探针：遍历「单独确认.html」的全部 29 帧，量测 844 高度预算与滚动溢出。

判据：
  · 每帧 .screen 的直接子元素高度合计必须 == 844（差额即被 overflow:hidden 切掉的内容）
  · .scroll / .addbody 的 scrollHeight > clientHeight 是**预期**的（内容可滚）
  · 但不允许 scrollHeight == 0 或有元素高 0（说明 flex 被压塌）

⚠️ 与 单独确认.html 同目录，否则 @font-face 404、量到的是回退字体。
用后即删。
"""
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

PROBE = """
<script>
window.addEventListener('load', function () {
  var out = [];
  document.querySelectorAll('.frame').forEach(function (fr, idx) {
    var scr = fr.querySelector('.screen');
    var lab = fr.querySelector('.flabel').textContent.trim();
    var sr = scr.getBoundingClientRect();
    var total = 0, zero = [], over = [];
    Array.prototype.forEach.call(scr.children, function (c) {
      var r = c.getBoundingClientRect();
      total += r.height;
      if (r.height < 1 && c.className.indexOf('statusbar') < 0) zero.push(c.className);
    });
    var sc = scr.querySelector('.scroll') || scr.querySelector('.addbody');
    var scinfo = '-';
    if (sc) {
      var h = Math.round(sc.getBoundingClientRect().height);
      var sh = sc.scrollHeight;
      scinfo = h + '/' + sh + (sh - h > 0 ? ' (+' + (sh - h) + ')' : '');
    }
    out.push([String(idx + 1).padStart(2, '0'),
              lab,
              Math.round(total) + '/844' + (Math.abs(total - 844) > 1.5 ? ' <<<' : ''),
              scinfo,
              zero.length ? 'ZERO:' + zero.join(',') : ''].join(' | '));
  });
  document.body.innerHTML = '<pre id="P">' + out.join('\\n') + '</pre>';
});
</script>
"""


def main():
    src = open(os.path.join(ROOT, "单独确认.html"), encoding="utf-8").read()
    html = src.replace("</body>", PROBE + "</body>")
    p = os.path.join(ROOT, "._probe_all.html")
    open(p, "w", encoding="utf-8").write(html)
    prof = tempfile.mkdtemp()
    url = "file:///" + p.replace("\\", "/").lstrip("/")
    cmd = [CHROME, "--headless=new", "--disable-gpu", "--no-first-run",
           "--allow-file-access-from-files", "--user-data-dir=" + prof,
           "--virtual-time-budget=4000", "--window-size=1400,900", "--dump-dom", url]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    s = r.stdout
    i, j = s.find('<pre id="P">'), s.find("</pre>")
    print(s[i + 12:j] if i >= 0 else "DUMP tail:\n" + s[-1500:])
    try:
        os.remove(p)
    except OSError:
        pass
    shutil.rmtree(prof, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
