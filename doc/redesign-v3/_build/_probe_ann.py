"""标注版装载自检：在真浏览器里跑一遍，确认客户端 JS 把 29 屏 / 全量规格行都建出来了。"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
HTML = os.path.join(ROOT, "单独确认-标注版.html")
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

PROBE = r"""
<script>
window.__err = [];
window.addEventListener('error', function (e) { window.__err.push(String(e.message)); });
window.addEventListener('load', function () {
  setTimeout(function () {
    var out = [];
    out.push('JS_ERRORS=' + (window.__err.length ? window.__err.join(' | ') : 'none'));
    out.push('specs=' + document.querySelectorAll('.spec').length);
    out.push('rows=' + document.querySelectorAll('.spec tr[data-i]').length);
    out.push('boxes=' + document.querySelectorAll('.ovl .ov').length);
    out.push('badges=' + document.querySelectorAll('.ovl .bd').length);
    out.push('dimlines=' + document.querySelectorAll('.ovl .dim').length);
    // 跳屏控件是 <select id="jump">，不是按钮 —— 旧选择器 [data-jump] 恒为 0，已换掉
    out.push('jumpopts=' + document.querySelectorAll('#jump option').length);
    out.push('kindbtns=' + document.querySelectorAll('#bar button[data-kind]').length);
    out.push('togbtns=' + document.querySelectorAll('#bar button[data-tog]').length);
    var f = document.querySelector('.spec .frame');
    var s = f ? f.querySelector('.screen') : null;
    out.push('frame=' + (f ? Math.round(f.getBoundingClientRect().width) + 'x' +
                                  Math.round(f.getBoundingClientRect().height) : '-'));
    out.push('screen=' + (s ? Math.round(s.getBoundingClientRect().width) + 'x' +
                                   Math.round(s.getBoundingClientRect().height) : '-'));
    // 抽查：第 1 屏第 22 号元素在画布上的框，与规格表里写的数值是否一致
    var ov = document.querySelectorAll('.spec')[0].querySelector('.ov[data-i="2"]');
    out.push('sample_ov2=' + (ov ? ov.style.left + ',' + ov.style.top + ' ' +
                                     ov.style.width + 'x' + ov.style.height : '-'));
    var tr = document.querySelectorAll('.spec')[0].querySelector('tr[data-i="2"]');
    out.push('sample_tr2=' + (tr ? Array.prototype.slice.call(tr.children, 2, 4)
                                     .map(function (td) { return td.textContent.trim(); })
                                     .join(' | ') : '-'));
    // 字号越界的现场复核：扫全部 tr 的「文字」列里出现的 px 值
    var fs = {};
    document.querySelectorAll('.spec tr[data-i]').forEach(function (tr) {
      var t = tr.children[6] ? tr.children[6].textContent : '';
      (t.match(/([0-9.]+)px/g) || []).forEach(function (v) { fs[v] = (fs[v] || 0) + 1; });
    });
    out.push('fontsizes=' + JSON.stringify(fs));

    // 逐屏核对（用渲染器挂出来的 window.PLAIN_SPEC 独立比对，不是自己比自己）：
    //   ① 首屏内的每一项都应有且仅有一个叠加框，且框的 inline 几何 == 规格里的 x/y/w/h
    //   ② 横向必须收在 0..W 内、顶边不得为负（这两类是硬错，必须为 0）
    //   ③ 纵向「下缘越过 852」单独统计 —— 那是滚动内容的自然溢出（.frame 会裁掉），
    //      不算错，但数量要报出来别被当成漏项。
    var bad = [], outX = [], clipBelow = 0, nOn = 0;
    var PS = window.PLAIN_SPEC;
    if (!PS) { out.push('perScreen=NO PLAIN_SPEC'); }
    else {
      PS.screens.forEach(function (s, si) {
        var sec = document.querySelector('.spec[id="s' + s.no + '"]');
        if (!sec) { bad.push('s' + s.no + ' 缺 section'); return; }
        var ovs = {};
        sec.querySelectorAll('.ovl .ov').forEach(function (o) { ovs[o.getAttribute('data-i')] = o; });
        var nb = 0;
        s.items.forEach(function (it) {
          if (it.below) { nb++; return; }
          nOn++;
          var o = ovs[String(it.i)];
          if (!o) { bad.push('s' + s.no + ' 缺框 #' + it.i); return; }
          var e = o.style;
          var got = [e.left, e.top, e.width, e.height];
          var want = [it.x + 'px', it.y + 'px', it.w + 'px', Math.max(it.h, 1) + 'px'];
          if (got.join(',') !== want.join(','))
            bad.push('s' + s.no + ' #' + it.i + ' ' + got.join(',') + ' != ' + want.join(','));
          if (it.x < -0.5 || it.y < -0.5 || it.x + it.w > PS.w + .5)
            outX.push('s' + s.no + ' #' + it.i + ' @' + it.x + ',' + it.y + ' ' + it.w + 'x' + it.h);
          if (it.y + it.h > PS.h + .5) clipBelow++;
        });
        if (nb !== s.items.length - Object.keys(ovs).length)
          bad.push('s' + s.no + ' below 计数不符');
      });
      out.push('onCanvasItems=' + nOn);
      out.push('perScreen=' + (bad.length ? bad.slice(0, 8).join(' | ') : 'ok'));
      out.push('clipBelowFold=' + clipBelow + '（滚动内容自然溢出，非错）');
      out.push('outOfBounds=' + (outX.length ? outX.slice(0, 12).join(' | ') : 'none'));
    }

    // 圆角越界现场复核：列序是 #(0) 元素(1) 位置(2) 尺寸(3) 圆角(4) 填充边框(5) 文字(6) 间距(7)
    // ⚠️ radOf() 会把 px 后缀剥掉再写进单元格，所以这里只能收「原文本」做枚举，
    //    不能再拿 /([0-9.]+)px/ 去抽 —— 那样恒为空（踩过一次）。
    var rs = {};
    document.querySelectorAll('.spec tr[data-i]').forEach(function (tr) {
      var t = tr.children[4] ? tr.children[4].textContent.trim() : '';
      if (!t) t = '（无圆角）';
      rs[t] = (rs[t] || 0) + 1;
    });
    out.push('radii=' + JSON.stringify(rs));

    // 分割线：应等于全站 .hairline 数量，且高恒为 1pt
    var hl = document.querySelectorAll('.screen .hairline');
    var hh = {};
    hl.forEach(function (h) {
      var r = h.getBoundingClientRect();
      var k = Math.round(r.height) + 'x' + (Math.round(r.width) % 2 ? 'odd' : 'even');
      hh[k] = (hh[k] || 0) + 1;
    });
    out.push('hairlines=' + hl.length + ' ' + JSON.stringify(hh));

    // 回归项：描边框不得画到机身外。
    // ⚠️ 不能用 .ov 的 getBoundingClientRect 去比机身矩形 —— overflow:hidden 只裁「绘制」，
    //    布局盒仍是全尺寸，这么量永远是「越界」的（踩过一次）。
    //    真正的不变式是：每个 .ov 都必须处在一个与机身等大、且 overflow:hidden 的 .ovclip 里。
    var clipBad = [], clipN = 0, noClip = 0, cutN = 0;
    document.querySelectorAll('.spec').forEach(function (sec) {
      var f = sec.querySelector('.frame');
      var fr = f.getBoundingClientRect();
      var cl = sec.querySelector('.ovl > .ovclip');
      if (!cl || getComputedStyle(cl).overflow !== 'hidden') {
        var n0 = sec.querySelectorAll('.ovl .ov').length;
        if (n0) clipBad.push(sec.id + ' 无裁切层(' + n0 + ' 框)');
        return;
      }
      var cr = cl.getBoundingClientRect();
      if (Math.abs(cr.width - fr.width) > 1 || Math.abs(cr.height - fr.height) > 1)
        clipBad.push(sec.id + ' 裁切层 ≠ 机身');
      // 每个框从外往里数，第一个 position:absolute 的定位祖先必须是 .ovclip 或 .ovl，
      // 且 .ovclip 必须是它的祖先（不能落回 .frame）
      sec.querySelectorAll('.ovl .ov').forEach(function (o) {
        clipN++;
        if (!cl.contains(o)) { noClip++; clipBad.push(sec.id + '#' + o.getAttribute('data-i')); }
      });
      cutN += sec.querySelectorAll('.ovl .cut').length;
    });
    out.push('ovclip=' + (clipBad.length ? clipBad.slice(0, 8).join(' | ') : 'ok') +
             ' 框数=' + clipN + ' 未裁=' + noClip);
    out.push('cutmarks=' + cutN + '（应 == clipBelowFold）');
    document.body.innerHTML = '<pre id="P">' + out.join('\n') + '</pre>';
  }, 1200);
});
</script>
"""


def main():
    src = open(HTML, encoding="utf-8").read()
    html = src.replace("</body>", PROBE + "</body>")
    tmp = os.path.join(ROOT, "._probe_ann.html")
    open(tmp, "w", encoding="utf-8").write(html)
    prof = tempfile.mkdtemp()
    url = "file:///" + tmp.replace("\\", "/").lstrip("/")
    cmd = [CHROME, "--headless=new", "--disable-gpu", "--no-first-run",
           "--allow-file-access-from-files", "--user-data-dir=" + prof,
           "--virtual-time-budget=9000", "--window-size=1600,1200", "--dump-dom", url]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=240)
    shutil.rmtree(prof, ignore_errors=True)
    try:
        os.remove(tmp)
    except OSError:
        pass
    s = r.stdout
    i = s.find('<pre id="P">')
    if i < 0:
        print("自检失败，DOM 尾部：\n", s[-1200:])
        return 1
    j = s.find("</pre>", i)
    txt = s[i + 12:j].replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
    print(txt)
    bad = re.search(r"JS_ERRORS=(?!none)", txt)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
