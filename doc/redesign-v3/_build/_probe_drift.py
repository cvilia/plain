"""探针：量化「redesign-v3 令牌」相对「plain/ 代码实况」的漂移。

回答三个问题：
  Q1 53 个字段名是否与 tokens.dart 一致？（只读，不判断值）
  Q2 10 主题的品牌种子色（primary/accent 等）是否与 theme_registry.dart 一致？
  Q3 tone 分组（cool/warm/neutral）是否与代码一致？中性层被改了多少？

只读，不写任何文件。
"""
import io
import os
import re
import json
import collections

ROOT = os.path.dirname(os.path.abspath(__file__))
THEME = os.path.normpath(os.path.join(ROOT, "..", "..", "plain", "lib", "app", "theme"))
TOK = os.path.normpath(os.path.join(ROOT, "..", "01-tokens.json"))

tok = json.load(io.open(TOK, encoding="utf-8"))
res = tok["resolved"]


def hexpair(s):
    """#RRGGBBAA -> (r,g,b)"""
    return int(s[1:3], 16), int(s[3:5], 16), int(s[5:7], 16)


# ── Q1 字段名 ────────────────────────────────────────────────────────────────
src = io.open(os.path.join(THEME, "tokens.dart"), encoding="utf-8").read()
dart_fields = sorted(set(re.findall(r"\bthis\.([A-Za-z][A-Za-z0-9_]*)\b", src)))
json_fields = sorted(res["subai.light"].keys())
print("Q1 字段名")
print("   dart %d / json %d" % (len(dart_fields), len(json_fields)))
only_d = sorted(set(dart_fields) - set(json_fields))
only_j = sorted(set(json_fields) - set(dart_fields))
print("   dart 有 json 无:", only_d or "[]")
print("   json 有 dart 无:", only_j or "[]")

# ── Q2 品牌种子 ──────────────────────────────────────────────────────────────
reg = io.open(os.path.join(THEME, "theme_registry.dart"), encoding="utf-8").read()
spec_body = reg.split("const Map<ThemeId, ThemeSpec> _specs = {", 1)[1].split("\n};", 1)[0]
seeds = {}
for b in re.split(r"\n  ThemeId\.", spec_body)[1:]:
    tid = b.split(":", 1)[0].strip()
    tone = re.search(r"tone:\s*ToneId\.(\w+)", b)
    light, dark = b.split("dark: BrandPalette(", 1)
    dl = re.search(r"p:\s*0x[0-9A-Fa-f]{2}([0-9A-Fa-f]{6})", light)
    al = re.search(r"a:\s*0x[0-9A-Fa-f]{2}([0-9A-Fa-f]{6})", light)
    dd = re.search(r"p:\s*0x[0-9A-Fa-f]{2}([0-9A-Fa-f]{6})", dark)
    ad = re.search(r"a:\s*0x[0-9A-Fa-f]{2}([0-9A-Fa-f]{6})", dark)
    seeds[tid] = dict(tone=tone.group(1) if tone else "?",
                      light=(dl.group(1) if dl else "", al.group(1) if al else ""),
                      dark=(dd.group(1) if dd else "", ad.group(1) if ad else ""))

print("\nQ2 品牌种子（primary / accent）")
bad = []
for tid, s in seeds.items():
    for mode in ("light", "dark"):
        v = res.get("%s.%s" % (tid, mode), {})
        got = (v.get("primary", "#")[1:7], v.get("accent", "#")[1:7])
        want = s[mode]
        ok = all(g.lower() == w.lower() for g, w in zip(got, want))
        if not ok:
            bad.append((tid, mode, got, want))
print("   10 主题 × 亮暗 = 20 组，不一致:", len(bad))
for t, m, g, w in bad:
    print("     %s.%s 交付=%s 代码=%s" % (t, m, g, w))

# ── Q3 tone 分组 + 去暖幅度 ─────────────────────────────────────────────────
print("\nQ3 tone 分组与中性层漂移")
NEUT = ("bg", "appBg", "surface", "surface2", "ink", "ink2", "muted", "faint",
        "line", "lineSoft")
grp = collections.defaultdict(list)
for k, v in res.items():
    grp[tuple(v[f] for f in NEUT)].append(k)
tone_of = collections.defaultdict(set)
for tid, s in seeds.items():
    tone_of[s["tone"]].add(tid)
print("   交付侧中性层去重组数: %d （代码侧 3 tone × 2 亮度 = 6）" % len(grp))
for tone, ids in sorted(tone_of.items()):
    for mode in ("light", "dark"):
        pick = None
        for g, ks in grp.items():
            if "%s.%s" % (sorted(ids)[0], mode) in ks:
                pick = dict(zip(NEUT, g))
        if not pick:
            continue
        r, g_, b = hexpair(pick["bg"])
        print("   %-8s %-5s 主题 %d 个  bg=%s  R-B=%+d  surface=%s  ink=%s"
              % (tone, mode, len(ids), pick["bg"][:7], r - b, pick["surface"][:7],
                 pick["ink"][:7]))

print("\n   代码侧中性层（theme_registry.dart）")
for tn, pal in (("light", "_toneLight"), ("dark", "_toneDark")):
    seg = reg.split("const Map<ToneId, TonePalette> %s = {" % pal, 1)[1].split("\n};", 1)[0]
    for m in re.finditer(r"ToneId\.(\w+):\s*TonePalette\(\s*bg:\s*0x[0-9A-Fa-f]{2}([0-9A-Fa-f]{6})"
                         r",\s*appBg:\s*0x[0-9A-Fa-f]{2}([0-9A-Fa-f]{6})"
                         r",\s*surface:\s*0x[0-9A-Fa-f]{2}([0-9A-Fa-f]{6})", seg):
        r, g_, b = hexpair("#" + m.group(2))
        print("   %-8s %-5s  bg=#%s  R-B=%+d  surface=#%s"
              % (m.group(1), tn, m.group(2), r - b, m.group(3)))

print("\n   去暖幅度（bg 的 R-B，越大越暖）")
print("   --------------------------------------------------")
print("   tone     代码 R-B   交付 R-B   说明")
print("   --------------------------------------------------")
DEL = {
    "cool":    (-2, -2, "本就偏冷，微调色相不暖"),
    "warm":    (14, 3, "★ 关键：从米黄 +14 拉到 +3"),
    "neutral": (2, -1, "★ 关键：从微暖 +2 拉到冷 -1"),
}
for k, (a, b, note) in DEL.items():
    print("   %-8s %+9d %+10d   %s" % (k, a, b, note))
