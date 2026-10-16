"""Generate Dart theme constants from redesign-v3/01-tokens.json."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(r"C:\Users\lizhenyu\WorkBuddy\Dev\PlainApp")
TOK = ROOT / "redesign-v3" / "01-tokens.json"
OUT = ROOT / "plain" / "lib" / "app" / "theme" / "tokens_v3_data.dart"


def hx_to_dart(css: str) -> str:
    s = css.strip()
    if s.startswith("linear-gradient"):
        raise ValueError(css)
    if not s.startswith("#"):
        raise ValueError(css)
    h = s[1:]
    if len(h) == 6:
        h = h + "FF"
    if len(h) != 8:
        raise ValueError(css)
    r, g, b, a = h[0:2], h[2:4], h[4:6], h[6:8]
    return f"0x{a}{r}{g}{b}"


def main() -> None:
    tok = json.loads(TOK.read_text(encoding="utf-8"))

    lines: list[str] = []
    lines.append("/// Generated from redesign-v3/01-tokens.json — do not hand-edit.")
    lines.append("/// Tone palettes (de-warm v3) + v3Additions fields for 10 themes × 2 modes.")
    lines.append("library;")
    lines.append("")
    lines.append("/// Neutral tone fields in fixed order.")
    lines.append(
        "const List<String> kToneFields = ["
        "'bg','appBg','surface','surface2','ink','ink2','muted','faint','line','lineSoft'];"
    )
    lines.append("")
    lines.append("/// tone -> mode -> [bg, appBg, surface, surface2, ink, ink2, muted, faint, line, lineSoft]")
    lines.append("const Map<String, Map<String, List<int>>> kTonePalettes = {")
    for tone_name, pair in tok["tones"].items():
        lines.append(f"  '{tone_name}': {{")
        for mode in ("light", "dark"):
            t = pair[mode]
            vals = ", ".join(hx_to_dart(t[k]) for k in
                             ["bg", "appBg", "surface", "surface2", "ink", "ink2",
                              "muted", "faint", "line", "lineSoft"])
            lines.append(f"    '{mode}': [{vals}],")
        lines.append("  },")
    lines.append("};")
    lines.append("")

    v3_keys = [
        "lineStrong", "lineStrongSoft", "focusRing", "surfaceInset",
        "disabledFg", "disabledBg", "overlay", "skeleton",
        "primaryPressed", "accentPressed",
    ]
    lines.append("/// v3Additions field order.")
    lines.append(f"const List<String> kV3Fields = [{', '.join(repr(k) for k in v3_keys)}];")
    lines.append("")
    lines.append("/// 'theme.mode' -> values aligned with kV3Fields.")
    lines.append("const Map<String, List<int>> kV3Additions = {")
    for key in sorted(tok["v3Additions"].keys()):
        obj = tok["v3Additions"][key]
        vals = ", ".join(hx_to_dart(obj[k]) for k in v3_keys)
        lines.append(f"  '{key}': [{vals}],")
    lines.append("};")
    lines.append("")

    # Theme tone mapping: theme id -> tone name used in v3 (sand replaces warm)
    lines.append("/// Theme id -> v3 tone key (cool | neutral | sand).")
    lines.append("const Map<String, String> kThemeToneV3 = {")
    for tid, spec in tok["themes"].items():
        tone = spec.get("tone", "cool")
        lines.append(f"  '{tid}': '{tone}',")
    lines.append("};")
    lines.append("")

    # Brand seeds (main/mainDark/accent/accentDark) — verify vs theme_registry
    lines.append("/// Brand seeds from tokens.json themes (light.p, light.a, dark.p, dark.a).")
    lines.append("/// Format: themeId -> [lightPrimary, lightAccent, darkPrimary, darkAccent]")
    lines.append("const Map<String, List<int>> kBrandSeeds = {")
    for tid, spec in tok["themes"].items():
        light_p = hx_to_dart(spec["main"])
        light_a = hx_to_dart(spec["accent"])
        dark_p = hx_to_dart(spec["mainDark"])
        dark_a = hx_to_dart(spec["accentDark"])
        lines.append(f"  '{tid}': [{light_p}, {light_a}, {dark_p}, {dark_a}],")
    lines.append("};")
    lines.append("")

    # Radii / stroke / motion for design_tokens
    rad = tok["radius"]
    lines.append("/// Radius scale v3: r1=8, r2=12, r3=16, r4=24, pill=999.")
    lines.append(
        f"const double kRadiusR1 = {rad['r1']};"
    )
    lines.append(f"const double kRadiusR2 = {rad['r2']};")
    lines.append(f"const double kRadiusR3 = {rad['r3']};")
    lines.append(f"const double kRadiusR4 = {rad['r4']};")
    lines.append(f"const double kRadiusPill = {rad['pill']};")
    lines.append("")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")
    print("tones", list(tok["tones"].keys()))
    print("v3 combos", len(tok["v3Additions"]))


if __name__ == "__main__":
    main()
