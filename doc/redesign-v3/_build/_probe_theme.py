"""探针：从 theme_registry.dart 提取「10 主题 -> tone」绑定与品牌种子色。

用途：核对 redesign-v3/01-tokens.json 的 resolved 是否与代码侧
（theme_registry.dart 的 tone 归属 + 品牌种子）一致。

只读，不写任何文件。
"""
import io
import os
import re
import json

ROOT = os.path.dirname(os.path.abspath(__file__))
REG = os.path.normpath(os.path.join(
    ROOT, "..", "..", "plain", "lib", "app", "theme", "theme_registry.dart"))
TOK = os.path.normpath(os.path.join(ROOT, "..", "01-tokens.json"))

src = io.open(REG, encoding="utf-8").read()
# 取 _specs 表
body = src.split("const Map<ThemeId, ThemeSpec> _specs = {", 1)[1]
body = body.split("\n};", 1)[0]

blocks = re.split(r"\n  ThemeId\.", body)
rows = []
for b in blocks[1:]:
    tid = b.split(":", 1)[0].strip()
    tone = re.search(r"tone:\s*ToneId\.(\w+)", b)
    light_p = re.search(r"p:\s*(0x[0-9A-Fa-f]{8})", b)
    light_a = re.search(r"a:\s*(0x[0-9A-Fa-f]{8})", b)
    rows.append((tid, tone.group(1) if tone else "?", light_p.group(1) if light_p else "?",
                 light_a.group(1) if light_a else "?"))

print("代码侧 theme_registry.dart：")
for t in rows:
    print("  %-12s tone=%-8s primary=%s accent=%s" % t)

tok = json.load(io.open(TOK, encoding="utf-8"))
res = tok["resolved"]
print("\n交付侧 01-tokens.json：")
mismatch = []
for t, tone, p, a in rows:
    k = "%s.light" % t
    v = res.get(k)
    if v is None:
        print("  %-12s 交付缺失 %s" % (t, k))
        mismatch.append(t)
        continue
    dp = v.get("primary", "").upper()
    da = v.get("accent", "").upper()
    dp6 = "#" + dp[1:7] if dp.startswith("#") else dp
    da6 = "#" + da[1:7] if da.startswith("#") else da
    okp = dp6 == p.upper().replace("0X", "#")
    oka = da6 == a.upper().replace("0X", "#")
    flag = "OK " if (okp and oka) else "DIFF"
    if not (okp and oka):
        mismatch.append(t)
    print("  %-12s %s primary=%s(code %s) accent=%s(code %s)"
          % (t, flag, dp6, p, da6, a))

print("\n品牌色不一致主题：", mismatch if mismatch else "无")

# tone 归属：交付侧需在 meta 里记录
meta = tok.get("meta", {})
print("meta keys:", list(meta.keys()))
tt = meta.get("themeTone") or meta.get("theme_tone")
print("交付记录的 theme->tone:", tt)
