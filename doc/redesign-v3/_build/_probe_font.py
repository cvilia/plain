"""临时探针 v3：验证 MiSans 是否真的加载（而非回退到 Segoe UI）。用后即删。"""
import sys, os, tempfile, subprocess, shutil

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shoot

PROBE = """
<script>
window.addEventListener('load', function () {
  var out = [];
  out.push('document.fonts.check(16px MiSans) = ' + document.fonts.check('16px "MiSans"'));
  out.push('document.fonts.check(16px MiSans, 600) = ' + document.fonts.check('600 16px "MiSans"'));
  var loaded = [];
  document.fonts.forEach(function (f) { loaded.push(f.family + '/' + f.weight + '/' + f.status); });
  out.push('已注册 @font-face: ' + JSON.stringify(loaded));
  function w(fam, txt, weight, feat) {
    var s = document.createElement('span');
    s.style.cssText = 'position:absolute;white-space:pre;font-size:44px;font-weight:' + weight +
      ';font-family:' + fam + (feat ? ';font-variant-numeric:tabular-nums' : '');
    s.textContent = txt;
    document.body.appendChild(s);
    var r = s.getBoundingClientRect().width;
    document.body.removeChild(s);
    return Math.round(r * 100) / 100;
  }
  var T = '99,999,999.99';
  out.push('44px MiSans  600 tabular  "' + T + '" = ' + w('"MiSans"', T, 600, 1));
  out.push('44px MiSans  600 比例      "' + T + '" = ' + w('"MiSans"', T, 600, 0));
  out.push('44px Segoe   600 tabular  "' + T + '" = ' + w('"Segoe UI"', T, 600, 1));
  out.push('44px 雅黑     600 tabular  "' + T + '" = ' + w('"Microsoft YaHei"', T, 600, 1));
  out.push('--- 中文字宽（应等于 MiSans 的 1000/1000 全角）---');
  out.push('44px MiSans  400 "记账" = ' + w('"MiSans"', '记账', 400, 0) + '  （期望 88）');
  out.push('44px Segoe   400 "记账" = ' + w('"Segoe UI"', '记账', 400, 0));
  out.push('--- 单价校验：MiSans tabular 单数字宽应 = 44*0.594 = 26.14 ---');
  out.push('44px MiSans 400 "0" tabular = ' + w('"MiSans"', '0', 400, 1) + ' / 比例 = ' + w('"MiSans"', '0', 400, 0));
  out.push('44px MiSans 400 "1" tabular = ' + w('"MiSans"', '1', 400, 1) + ' / 比例 = ' + w('"MiSans"', '1', 400, 0));
  document.body.innerHTML = '<pre id="P">' + out.join('\\n') + '</pre>';
});
</script>
"""


def main():
    src = open(shoot.SRC, encoding="utf-8").read()
    html = shoot.build_variant(src, theme="subai", mode="light", lang="zh", screen="ledger")
    html = html.replace("</body>", PROBE + "</body>")
    # 必须与 07-SCREENS.html 同目录，否则 @font-face 的相对路径 404
    p = os.path.join(shoot.ROOT, "._probe_font.html")
    open(p, "w", encoding="utf-8").write(html)
    prof = tempfile.mkdtemp()
    url = "file:///" + p.replace("\\", "/").lstrip("/")
    cmd = [shoot.CHROME, "--headless=new", "--disable-gpu", "--no-first-run",
           "--allow-file-access-from-files", "--user-data-dir=" + prof,
           "--virtual-time-budget=4000", "--window-size=730,900", "--dump-dom", url]
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
