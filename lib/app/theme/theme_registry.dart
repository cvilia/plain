/// Theme registry: compile-time color constants for 10 themes × 2 brightness.
/// Values are authoritative from 04-技术架构设计.md §16.1 — do not modify without re-running contrast gate.
library;

/// Theme identifiers. [id] is the frozen persistence key (pinyin, never
/// renamed). [name] is display-only. Old Chinese storage values are mapped
/// via [_legacyNameToId] in [ThemeId.fromId].
enum ThemeId {
  qingci('qingci', '青瓷', '品牌默认 · 青绿 × 蜜桃'),
  dianlan('dianlan', '靛蓝', '沉稳 · 深蓝 × 琥珀'),
  zhuqing('zhuqing', '竹青', '素雅 · 草绿 × 藤紫'),
  haiyan('haiyan', '海盐', '深邃 · 青蓝 × 珊瑚'),
  ouhe('ouhe', '藕荷', '柔美 · 藕紫 × 沙金'),
  taoyao('taoyao', '桃夭', '浪漫 · 桃粉 × 青碧'),
  feiying('feiying', '绯樱', '古朴 · 绯红 × 松绿'),
  xinghuang('xinghuang', '杏黄', '温暖 · 杏黄 × 湖蓝'),
  doulv('doulv', '豆绿', '清新 · 豆绿 × 藤紫'),
  subai('subai', '素白', '极简 · 炭黑 × 橘红');

  const ThemeId(this.id, this.name, this.tag);

  /// Stable persistence key. Frozen once published — never follows [name].
  final String id;

  /// Display name (UI only).
  final String name;
  final String tag;

  static const Map<String, String> _legacyNameToId = {
    '松烟': 'zhuqing',
    '深海': 'haiyan',
    '雾紫': 'ouhe',
    '海棠': 'taoyao',
    '宣纸': 'feiying',
    '赤陶': 'xinghuang',
    '抹茶': 'doulv',
  };

  static ThemeId fromId(String? v) {
    if (v == null || v.isEmpty) return ThemeId.qingci;
    for (final t in values) {
      if (t.id == v || t.name == v) return t;
    }
    final migrated = _legacyNameToId[v];
    if (migrated != null) {
      for (final t in values) {
        if (t.id == migrated) return t;
      }
    }
    return ThemeId.qingci;
  }
}

/// Neutral tone palettes (3 tones × 2 brightness).
enum ToneId { cool, warm, neutral }

class TonePalette {
  const TonePalette({
    required this.bg, required this.appBg, required this.surface, required this.surface2,
    required this.ink, required this.ink2, required this.muted, required this.faint,
    required this.line, required this.lineSoft,
  });

  final int bg; final int appBg; final int surface; final int surface2;
  final int ink; final int ink2; final int muted; final int faint;
  final int line; final int lineSoft;
}

/// Brand layer: 9 opaque fields. Soft/tint layers are NOT stored here —
/// they are brand color + global alpha (see [kSoftAlphaLight] etc.).
class BrandPalette {
  const BrandPalette({
    required this.p, required this.pd,
    required this.a, required this.ad,
    required this.hero0, required this.hero1,
    required this.heroDark0, required this.heroDark1,
    required this.frame,
  });

  final int p; final int pd;
  final int a; final int ad;
  final int hero0; final int hero1;
  final int heroDark0; final int heroDark1;
  final int frame;
}

class ThemeSpec {
  const ThemeSpec({
    required this.id, required this.name, required this.tag,
    required this.tone, required this.light, required this.dark,
  });

  final ThemeId id;
  final String name;
  final String tag;
  final ToneId tone;
  final BrandPalette light;
  final BrandPalette dark;
}

// ─── Soft-layer alphas (global, not per-theme) — §4.1 透明度政策 ─────────────
// Light: soft 16% / tint 10% / aSoft 16%.
// Dark:  soft 26% / tint 16% / aSoft 26% (higher, else invisible on dark).

const double kSoftAlphaLight = 0.16;
const double kTintAlphaLight = 0.10;
const double kASoftAlphaLight = 0.16;
const double kSoftAlphaDark = 0.26;
const double kTintAlphaDark = 0.16;
const double kASoftAlphaDark = 0.26;

// ─── Neutral layer: 3 tones × 2 brightness ───────────────────────────────────

const Map<ToneId, TonePalette> _toneLight = {
  ToneId.cool: TonePalette(
    bg: 0xFFE9EFEA, appBg: 0xFFF0F4F1, surface: 0xFFFFFFFF, surface2: 0xFFF5F8F5,
    ink: 0xFF2E3B36, ink2: 0xFF52655E, muted: 0xFF606E69, faint: 0xFF8C9691,
    line: 0xFFE2E8E3, lineSoft: 0xFFECF0EB,
  ),
  ToneId.warm: TonePalette(
    bg: 0xFFEFEAE0, appBg: 0xFFF6F2E9, surface: 0xFFFFFDF8, surface2: 0xFFF7F3EA,
    ink: 0xFF332F28, ink2: 0xFF5C554A, muted: 0xFF6E675C, faint: 0xFF989183,
    line: 0xFFE6E0D3, lineSoft: 0xFFEFEADF,
  ),
  ToneId.neutral: TonePalette(
    bg: 0xFFEDEDEB, appBg: 0xFFF4F4F2, surface: 0xFFFFFFFF, surface2: 0xFFF6F6F4,
    ink: 0xFF2B2B2A, ink2: 0xFF565654, muted: 0xFF6A6A69, faint: 0xFF949491,
    line: 0xFFE3E3E0, lineSoft: 0xFFEDEDEA,
  ),
};

const Map<ToneId, TonePalette> _toneDark = {
  ToneId.cool: TonePalette(
    bg: 0xFF141A18, appBg: 0xFF222C29, surface: 0xFF2B3733, surface2: 0xFF323F3A,
    ink: 0xFFE4EBE6, ink2: 0xFFC2CFC8, muted: 0xFF8FA099, faint: 0xFF74817B,
    line: 0xFF3A4741, lineSoft: 0xFF35423D,
  ),
  ToneId.warm: TonePalette(
    bg: 0xFF191612, appBg: 0xFF26221C, surface: 0xFF2F2A22, surface2: 0xFF38332A,
    ink: 0xFFEDE7DA, ink2: 0xFFCFC6B4, muted: 0xFF9C9382, faint: 0xFF7B7465,
    line: 0xFF423B30, lineSoft: 0xFF3B352B,
  ),
  ToneId.neutral: TonePalette(
    bg: 0xFF1B1B1A, appBg: 0xFF232322, surface: 0xFF2C2C2B, surface2: 0xFF343433,
    ink: 0xFFE9E9E6, ink2: 0xFFC4C4C0, muted: 0xFF96968F, faint: 0xFF767673,
    line: 0xFF3C3C3A, lineSoft: 0xFF363634,
  ),
};

TonePalette toneOf(ToneId tone, bool isDark) =>
    (isDark ? _toneDark : _toneLight)[tone]!;

// ─── Brand layer: 10 themes × 2 brightness ───────────────────────────────────
// Values copied field-for-field from 04-技术架构设计.md §16.1. No rounding, no tweaks.

const Map<ThemeId, ThemeSpec> _specs = {
  ThemeId.qingci: ThemeSpec(
    id: ThemeId.qingci, name: '青瓷', tag: '品牌默认 · 青绿 × 蜜桃', tone: ToneId.cool,
    light: BrandPalette(
      p: 0xFF47B8A1, pd: 0xFF3A9784, a: 0xFFE77A4B, ad: 0xFFC2663F,
      hero0: 0xFF28584B, hero1: 0xFF327B74,
      heroDark0: 0xFF3A4B48, heroDark1: 0xFF4A6461, frame: 0xFF31403D,
    ),
    dark: BrandPalette(
      p: 0xFF9FD0C6, pd: 0xFF79B9AC, a: 0xFFE2A78D, ad: 0xFFD38969,
      hero0: 0xFF2E4C46, hero1: 0xFF3D6B62,
      heroDark0: 0xFF263633, heroDark1: 0xFF314944, frame: 0xFF2B3B38,
    ),
  ),
  ThemeId.dianlan: ThemeSpec(
    id: ThemeId.dianlan, name: '靛蓝', tag: '沉稳 · 深蓝 × 琥珀', tone: ToneId.cool,
    light: BrandPalette(
      p: 0xFF437CC7, pd: 0xFF3766A3, a: 0xFFE2AC40, ad: 0xFFBE9036,
      hero0: 0xFF3B6EA0, hero1: 0xFF4670C3,
      heroDark0: 0xFF38414D, heroDark1: 0xFF475167, frame: 0xFF2F3741,
    ),
    dark: BrandPalette(
      p: 0xFF9AB4D6, pd: 0xFF7194C1, a: 0xFFE1C58E, ad: 0xFFD2AF6A,
      hero0: 0xFF2B3B4F, hero1: 0xFF385070,
      heroDark0: 0xFF242D38, heroDark1: 0xFF2E3B4C, frame: 0xFF2A323C,
    ),
  ),
  ThemeId.zhuqing: ThemeSpec(
    id: ThemeId.zhuqing, name: '竹青', tag: '素雅 · 草绿 × 藤紫', tone: ToneId.cool,
    light: BrandPalette(
      p: 0xFF71AA46, pd: 0xFF5D8B39, a: 0xFFAD7BC6, ad: 0xFF9167A6,
      hero0: 0xFF425A2B, hero1: 0xFF4D7D36,
      heroDark0: 0xFF414B3A, heroDark1: 0xFF53634A, frame: 0xFF373F31,
    ),
    dark: BrandPalette(
      p: 0xFFB4CFA0, pd: 0xFF95B87A, a: 0xFFBFA1CE, ad: 0xFFA782BA,
      hero0: 0xFF3B4B2F, hero1: 0xFF516A3E,
      heroDark0: 0xFF2D3626, heroDark1: 0xFF3C4932, frame: 0xFF323A2C,
    ),
  ),
  ThemeId.haiyan: ThemeSpec(
    id: ThemeId.haiyan, name: '海盐', tag: '深邃 · 青蓝 × 珊瑚', tone: ToneId.cool,
    light: BrandPalette(
      p: 0xFF3DA3B8, pd: 0xFF328697, a: 0xFFE26C5A, ad: 0xFFBE5B4C,
      hero0: 0xFF2C676D, hero1: 0xFF347993,
      heroDark0: 0xFF38494C, heroDark1: 0xFF485E65, frame: 0xFF303E41,
    ),
    dark: BrandPalette(
      p: 0xFF9CCAD3, pd: 0xFF74B1BE, a: 0xFFDF9B91, ad: 0xFFCF7A6D,
      hero0: 0xFF2C484E, hero1: 0xFF3A666E,
      heroDark0: 0xFF253437, heroDark1: 0xFF2F464B, frame: 0xFF2A393C,
    ),
  ),
  ThemeId.ouhe: ThemeSpec(
    id: ThemeId.ouhe, name: '藕荷', tag: '柔美 · 藕紫 × 沙金', tone: ToneId.cool,
    light: BrandPalette(
      p: 0xFFA175C7, pd: 0xFF8460A3, a: 0xFFE8A354, ad: 0xFFC38947,
      hero0: 0xFF6B4795, hero1: 0xFF9254B5,
      heroDark0: 0xFF433A4B, heroDark1: 0xFF5A4A63, frame: 0xFF39313F,
    ),
    dark: BrandPalette(
      p: 0xFFB9A0CF, pd: 0xFF9B7AB8, a: 0xFFE2BA8D, ad: 0xFFD3A269,
      hero0: 0xFF3E2F4B, hero1: 0xFF563E6A,
      heroDark0: 0xFF2E2636, heroDark1: 0xFF3E3249, frame: 0xFF332C3A,
    ),
  ),
  ThemeId.taoyao: ThemeSpec(
    id: ThemeId.taoyao, name: '桃夭', tag: '浪漫 · 桃粉 × 青碧', tone: ToneId.cool,
    light: BrandPalette(
      p: 0xFFDF6D93, pd: 0xFFB75979, a: 0xFF49A28A, ad: 0xFF3D8874,
      hero0: 0xFFA93262, hero1: 0xFFCF3A5D,
      heroDark0: 0xFF4F363E, heroDark1: 0xFF6A444D, frame: 0xFF432D35,
    ),
    dark: BrandPalette(
      p: 0xFFD897AD, pd: 0xFFC46E8B, a: 0xFFA2CDC1, ad: 0xFF84B9AA,
      hero0: 0xFF532836, hero1: 0xFF763349,
      heroDark0: 0xFF3A222A, heroDark1: 0xFF4F2C37, frame: 0xFF3E282F,
    ),
  ),
  ThemeId.feiying: ThemeSpec(
    id: ThemeId.feiying, name: '绯樱', tag: '古朴 · 绯红 × 松绿', tone: ToneId.cool,
    light: BrandPalette(
      p: 0xFFD04E68, pd: 0xFFAB4055, a: 0xFF509B55, ad: 0xFF438247,
      hero0: 0xFFA43854, hero1: 0xFFC8414F,
      heroDark0: 0xFF4E373B, heroDark1: 0xFF684649, frame: 0xFF422E32,
    ),
    dark: BrandPalette(
      p: 0xFFD897A4, pd: 0xFFC46E7F, a: 0xFFA6C9A8, ad: 0xFF88B48B,
      hero0: 0xFF512A31, hero1: 0xFF723642,
      heroDark0: 0xFF392328, heroDark1: 0xFF4D2D34, frame: 0xFF3D292D,
    ),
  ),
  ThemeId.xinghuang: ThemeSpec(
    id: ThemeId.xinghuang, name: '杏黄', tag: '温暖 · 杏黄 × 湖蓝', tone: ToneId.warm,
    light: BrandPalette(
      p: 0xFFDDA23C, pd: 0xFFB58531, a: 0xFF458BBA, ad: 0xFF3A759C,
      hero0: 0xFF624219, hero1: 0xFF8C6E1C,
      heroDark0: 0xFF504634, heroDark1: 0xFF6B6042, frame: 0xFF443B2C,
    ),
    dark: BrandPalette(
      p: 0xFFD8C097, pd: 0xFFC4A46E, a: 0xFF9EBDD1, ad: 0xFF7EA5BE,
      hero0: 0xFF554326, hero1: 0xFF795E30,
      heroDark0: 0xFF3B3121, heroDark1: 0xFF50422A, frame: 0xFF3F3627,
    ),
  ),
  ThemeId.doulv: ThemeSpec(
    id: ThemeId.doulv, name: '豆绿', tag: '清新 · 豆绿 × 藤紫', tone: ToneId.warm,
    light: BrandPalette(
      p: 0xFF86AC4D, pd: 0xFF6E8D3F, a: 0xFFAA7BC1, ad: 0xFF8F67A2,
      hero0: 0xFF49582D, hero1: 0xFF597939,
      heroDark0: 0xFF444A3B, heroDark1: 0xFF57624B, frame: 0xFF393E32,
    ),
    dark: BrandPalette(
      p: 0xFFBCCDA2, pd: 0xFF9FB57D, a: 0xFFBEA4CC, ad: 0xFFA685B7,
      hero0: 0xFF404A30, hero1: 0xFF586840,
      heroDark0: 0xFF2F3527, heroDark1: 0xFF3F4833, frame: 0xFF343A2C,
    ),
  ),
  ThemeId.subai: ThemeSpec(
    id: ThemeId.subai, name: '素白', tag: '极简 · 炭黑 × 橘红', tone: ToneId.neutral,
    light: BrandPalette(
      p: 0xFF454540, pd: 0xFF393934, a: 0xFFE4764E, ad: 0xFFC06342,
      hero0: 0xFF5A5954, hero1: 0xFF717269,
      heroDark0: 0xFF434342, heroDark1: 0xFF585856, frame: 0xFF393937,
    ),
    dark: BrandPalette(
      p: 0xFFBABAB5, pd: 0xFF9C9C96, a: 0xFFE1A48E, ad: 0xFFD2866A,
      hero0: 0xFF3F3F3C, hero1: 0xFF565652,
      heroDark0: 0xFF2F2F2D, heroDark1: 0xFF3E3E3C, frame: 0xFF343432,
    ),
  ),
};

ThemeSpec themeSpecOf(ThemeId id) => _specs[id] ?? _specs[ThemeId.qingci]!;

// ─── Fixed palettes (cross-theme invariant, INV-1) ───────────────────────────

/// Category colors — 12 items, identical across all themes.
/// Fixed 12-color palette for expense category slices (INV-1).
///
/// Keyed by the stable category `iconRef` (not the display name) so user
/// renames do not break chart colors. See 14-代码优化建议.md P0-9.
const Map<String, int> categoryColorMap = {
  'food': 0xFFE69A6D,
  'shopping': 0xFFDC8EA6,
  'daily': 0xFF9B8FD4,
  'transport': 0xFF75B2C8,
  'fruit': 0xFF97BC81,
  'entertainment': 0xFFBFA8E9,
  'housing': 0xFFC58B72,
  'medical': 0xFFD97C7C,
  'study': 0xFF7FA8DC,
  'social': 0xFFC977A8,
  'other': 0xFFA3ABA4,
  'telecom': 0xFF6FAFA3,
};

/// Resolve a slice color from a category's iconRef; falls back to null.
int? categoryColorFor(String iconRef) => categoryColorMap[iconRef];

/// Income / expense semantic colors (fixed, not theme-derived).
const Map<String, int> _semLight = {
  'income': 0xFFC74E37, 'incomeSoft': 0xFFF9E4DD, 'incomeLine': 0xFFEDC9BE,
  'okSoft': 0xFFE6F0DC, 'okBase': 0xFF5F8F53,
  'warnSoft': 0xFFFAEEDA, 'warnInk': 0xFF8A5A1E,
  'dnBg': 0xFFE4F0E6, 'dnBase': 0xFF4C7A55,
};
const Map<String, int> _semDark = {
  'income': 0xFFE8836B, 'incomeSoft': 0xFF442F2A, 'incomeLine': 0xFF5A3A34,
  'okSoft': 0xFF33452F, 'okBase': 0xFFA5C896,
  'warnSoft': 0xFF453A24, 'warnInk': 0xFFE8B96A,
  'dnBg': 0xFF2F4433, 'dnBase': 0xFF9CC4A4,
};

int semColor(String key, bool isDark) =>
    (isDark ? _semDark : _semLight)[key] ?? 0xFF888888;
