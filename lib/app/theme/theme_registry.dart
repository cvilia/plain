/// Theme registry: compile-time color constants for 10 themes × 2 brightness.
/// Values are authoritative from 04-技术架构设计.md §16.1 — do not modify without re-running contrast gate.
library;

/// Theme identifiers. [id] is the frozen persistence key (pinyin, never
/// renamed). [name] is display-only. Old Chinese storage values are mapped
/// via [_legacyNameToId] in [ThemeId.fromId].
enum ThemeId {
  qingci('qingci', '青瓷', '清爽 · 青绿 × 蜜桃'),
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
    if (v == null || v.isEmpty) return ThemeId.subai;
    for (final t in values) {
      if (t.id == v || t.name == v) return t;
    }
    final migrated = _legacyNameToId[v];
    if (migrated != null) {
      for (final t in values) {
        if (t.id == migrated) return t;
      }
    }
    return ThemeId.subai;
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
    bg: 0xFFF1F5F3, appBg: 0xFFF8FAF9, surface: 0xFFFFFFFF, surface2: 0xFFFAFCFB,
    ink: 0xFF1F2D28, ink2: 0xFF3D524B, muted: 0xFF5A6B65, faint: 0xFF8A9691,
    line: 0xFFE2E8E3, lineSoft: 0xFFECF0EB,
  ),
  ToneId.warm: TonePalette(
    bg: 0xFFF6F1E8, appBg: 0xFFFCF8F1, surface: 0xFFFFFEFB, surface2: 0xFFFAF6EF,
    ink: 0xFF241F18, ink2: 0xFF4A4238, muted: 0xFF6A6257, faint: 0xFF968E80,
    line: 0xFFE6E0D3, lineSoft: 0xFFEFEADF,
  ),
  ToneId.neutral: TonePalette(
    bg: 0xFFF3F3F1, appBg: 0xFFFAFAF8, surface: 0xFFFFFFFF, surface2: 0xFFFCFCFA,
    ink: 0xFF1C1C1B, ink2: 0xFF454544, muted: 0xFF656563, faint: 0xFF92928F,
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
  // 青瓷：清爽青绿 × 珊瑚（默认）
  ThemeId.qingci: ThemeSpec(
    id: ThemeId.qingci, name: '青瓷', tag: '清爽 · 青绿 × 蜜桃', tone: ToneId.cool,
    light: BrandPalette(
      p: 0xFF14B8A6, pd: 0xFF0D9488, a: 0xFFFF6B6B, ad: 0xFFF43F5E,
      hero0: 0xFF0F766E, hero1: 0xFF2DD4BF,
      heroDark0: 0xFF134E4A, heroDark1: 0xFF115E59, frame: 0xFF115E59,
    ),
    dark: BrandPalette(
      p: 0xFF5EEAD4, pd: 0xFF2DD4BF, a: 0xFFFB7185, ad: 0xFFF43F5E,
      hero0: 0xFF115E59, hero1: 0xFF14B8A6,
      heroDark0: 0xFF042F2E, heroDark1: 0xFF115E59, frame: 0xFF115E59,
    ),
  ),
  // 靛蓝：宝蓝 × 明黄
  ThemeId.dianlan: ThemeSpec(
    id: ThemeId.dianlan, name: '靛蓝', tag: '沉稳 · 深蓝 × 琥珀', tone: ToneId.cool,
    light: BrandPalette(
      p: 0xFF3B82F6, pd: 0xFF2563EB, a: 0xFFF59E0B, ad: 0xFFD97706,
      hero0: 0xFF1D4ED8, hero1: 0xFF60A5FA,
      heroDark0: 0xFF1E3A5F, heroDark1: 0xFF1D4ED8, frame: 0xFF1E3A5F,
    ),
    dark: BrandPalette(
      p: 0xFF93C5FD, pd: 0xFF60A5FA, a: 0xFFFBBF24, ad: 0xFFF59E0B,
      hero0: 0xFF1E3A8A, hero1: 0xFF3B82F6,
      heroDark0: 0xFF0B1B3A, heroDark1: 0xFF1E3A8A, frame: 0xFF1E3A8A,
    ),
  ),
  // 竹青：草绿 × 藤紫
  ThemeId.zhuqing: ThemeSpec(
    id: ThemeId.zhuqing, name: '竹青', tag: '素雅 · 草绿 × 藤紫', tone: ToneId.cool,
    light: BrandPalette(
      p: 0xFF4ADE80, pd: 0xFF22C55E, a: 0xFFA78BFA, ad: 0xFF8B5CF6,
      hero0: 0xFF15803D, hero1: 0xFF86EFAC,
      heroDark0: 0xFF14532D, heroDark1: 0xFF166534, frame: 0xFF14532D,
    ),
    dark: BrandPalette(
      p: 0xFF86EFAC, pd: 0xFF4ADE80, a: 0xFFC4B5FD, ad: 0xFFA78BFA,
      hero0: 0xFF166534, hero1: 0xFF22C55E,
      heroDark0: 0xFF052E16, heroDark1: 0xFF166534, frame: 0xFF166534,
    ),
  ),
  // 海盐：青蓝 × 珊瑚
  ThemeId.haiyan: ThemeSpec(
    id: ThemeId.haiyan, name: '海盐', tag: '深邃 · 青蓝 × 珊瑚', tone: ToneId.cool,
    light: BrandPalette(
      p: 0xFF06B6D4, pd: 0xFF0891B2, a: 0xFFFB7185, ad: 0xFFE11D48,
      hero0: 0xFF0E7490, hero1: 0xFF22D3EE,
      heroDark0: 0xFF164E63, heroDark1: 0xFF155E75, frame: 0xFF164E63,
    ),
    dark: BrandPalette(
      p: 0xFF67E8F9, pd: 0xFF22D3EE, a: 0xFFFDA4AF, ad: 0xFFFB7185,
      hero0: 0xFF155E75, hero1: 0xFF06B6D4,
      heroDark0: 0xFF083344, heroDark1: 0xFF155E75, frame: 0xFF155E75,
    ),
  ),
  // 藕荷：柔紫 × 沙金
  ThemeId.ouhe: ThemeSpec(
    id: ThemeId.ouhe, name: '藕荷', tag: '柔美 · 藕紫 × 沙金', tone: ToneId.cool,
    light: BrandPalette(
      p: 0xFFA78BFA, pd: 0xFF8B5CF6, a: 0xFFFBBF24, ad: 0xFFF59E0B,
      hero0: 0xFF6D28D9, hero1: 0xFFC4B5FD,
      heroDark0: 0xFF4C1D95, heroDark1: 0xFF5B21B6, frame: 0xFF4C1D95,
    ),
    dark: BrandPalette(
      p: 0xFFC4B5FD, pd: 0xFFA78BFA, a: 0xFFFDE68A, ad: 0xFFFBBF24,
      hero0: 0xFF5B21B6, hero1: 0xFF8B5CF6,
      heroDark0: 0xFF2E1065, heroDark1: 0xFF5B21B6, frame: 0xFF5B21B6,
    ),
  ),
  // 桃夭：桃粉 × 青碧
  ThemeId.taoyao: ThemeSpec(
    id: ThemeId.taoyao, name: '桃夭', tag: '浪漫 · 桃粉 × 青碧', tone: ToneId.cool,
    light: BrandPalette(
      p: 0xFFF472B6, pd: 0xFFEC4899, a: 0xFF2DD4BF, ad: 0xFF14B8A6,
      hero0: 0xFFBE185D, hero1: 0xFFFB7185,
      heroDark0: 0xFF831843, heroDark1: 0xFF9D174D, frame: 0xFF831843,
    ),
    dark: BrandPalette(
      p: 0xFFF9A8D4, pd: 0xFFF472B6, a: 0xFF5EEAD4, ad: 0xFF2DD4BF,
      hero0: 0xFF9D174D, hero1: 0xFFEC4899,
      heroDark0: 0xFF500724, heroDark1: 0xFF9D174D, frame: 0xFF9D174D,
    ),
  ),
  // 绯樱：正红 × 松绿
  ThemeId.feiying: ThemeSpec(
    id: ThemeId.feiying, name: '绯樱', tag: '古朴 · 绯红 × 松绿', tone: ToneId.cool,
    light: BrandPalette(
      p: 0xFFEF4444, pd: 0xFFDC2626, a: 0xFF10B981, ad: 0xFF059669,
      hero0: 0xFFB91C1C, hero1: 0xFFF87171,
      heroDark0: 0xFF7F1D1D, heroDark1: 0xFF991B1B, frame: 0xFF7F1D1D,
    ),
    dark: BrandPalette(
      p: 0xFFFCA5A5, pd: 0xFFF87171, a: 0xFF6EE7B7, ad: 0xFF34D399,
      hero0: 0xFF991B1B, hero1: 0xFFEF4444,
      heroDark0: 0xFF450A0A, heroDark1: 0xFF991B1B, frame: 0xFF991B1B,
    ),
  ),
  // 杏黄：暖杏 × 湖蓝
  ThemeId.xinghuang: ThemeSpec(
    id: ThemeId.xinghuang, name: '杏黄', tag: '温暖 · 杏黄 × 湖蓝', tone: ToneId.warm,
    light: BrandPalette(
      p: 0xFFF59E0B, pd: 0xFFD97706, a: 0xFF38BDF8, ad: 0xFF0284C7,
      hero0: 0xFFB45309, hero1: 0xFFFBBF24,
      heroDark0: 0xFF78350F, heroDark1: 0xFF92400E, frame: 0xFF78350F,
    ),
    dark: BrandPalette(
      p: 0xFFFCD34D, pd: 0xFFFBBF24, a: 0xFF7DD3FC, ad: 0xFF38BDF8,
      hero0: 0xFF92400E, hero1: 0xFFF59E0B,
      heroDark0: 0xFF451A03, heroDark1: 0xFF92400E, frame: 0xFF92400E,
    ),
  ),
  // 豆绿：嫩绿 × 藤紫
  ThemeId.doulv: ThemeSpec(
    id: ThemeId.doulv, name: '豆绿', tag: '清新 · 豆绿 × 藤紫', tone: ToneId.warm,
    light: BrandPalette(
      p: 0xFF84CC16, pd: 0xFF65A30D, a: 0xFFC084FC, ad: 0xFFA855F7,
      hero0: 0xFF4D7C0F, hero1: 0xFFBEF264,
      heroDark0: 0xFF365314, heroDark1: 0xFF3F6212, frame: 0xFF365314,
    ),
    dark: BrandPalette(
      p: 0xFFD9F99D, pd: 0xFFBEF264, a: 0xFFE9D5FF, ad: 0xFFC084FC,
      hero0: 0xFF3F6212, hero1: 0xFF84CC16,
      heroDark0: 0xFF1A2E05, heroDark1: 0xFF3F6212, frame: 0xFF3F6212,
    ),
  ),
  // 素白：炭黑 × 橘红
  ThemeId.subai: ThemeSpec(
    id: ThemeId.subai, name: '素白', tag: '默认主题 · 炭黑 × 橘红', tone: ToneId.neutral,
    light: BrandPalette(
      p: 0xFF3F3F46, pd: 0xFF27272A, a: 0xFFFB923C, ad: 0xFFF97316,
      hero0: 0xFF27272A, hero1: 0xFF71717A,
      heroDark0: 0xFF18181B, heroDark1: 0xFF27272A, frame: 0xFF27272A,
    ),
    dark: BrandPalette(
      p: 0xFFD4D4D8, pd: 0xFFA1A1AA, a: 0xFFFDBA74, ad: 0xFFFB923C,
      hero0: 0xFF3F3F46, hero1: 0xFF71717A,
      heroDark0: 0xFF09090B, heroDark1: 0xFF27272A, frame: 0xFF27272A,
    ),
  ),
};

ThemeSpec themeSpecOf(ThemeId id) => _specs[id] ?? _specs[ThemeId.subai]!;

// ─── Fixed palettes (cross-theme invariant, INV-1) ───────────────────────────

/// Category colors — 12 items, identical across all themes.
/// Fixed 12-color palette for expense category slices (INV-1).
///
/// Keyed by the stable category `iconRef` (not the display name) so user
/// renames do not break chart colors. See 12-设计规范系统.md §5.2 (INV-1).
const Map<String, int> categoryColorMap = {
  'food': 0xFFFF6B6B,
  'shopping': 0xFFF472B6,
  'daily': 0xFFA78BFA,
  'transport': 0xFF38BDF8,
  'fruit': 0xFF4ADE80,
  'entertainment': 0xFFE879F9,
  'housing': 0xFFFDBA74,
  'medical': 0xFFF87171,
  'study': 0xFF60A5FA,
  'social': 0xFFC084FC,
  'other': 0xFF94A3B8,
  'telecom': 0xFF2DD4BF,
};
/// Resolve a slice color from a category's iconRef; falls back to null.
int? categoryColorFor(String iconRef) => categoryColorMap[iconRef];

/// Income / expense semantic colors (fixed, not theme-derived).
const Map<String, int> _semLight = {
  'income': 0xFFDC2626, 'incomeSoft': 0xFFFFF1F2, 'incomeLine': 0xFFFECDD3,
  'okSoft': 0xFFECFDF5, 'okBase': 0xFF059669,
  'warnSoft': 0xFFFAEEDA, 'warnInk': 0xFF8A5A1E,
  'dnBg': 0xFFECFDF5, 'dnBase': 0xFF059669,
};
const Map<String, int> _semDark = {
  'income': 0xFFFDA4AF, 'incomeSoft': 0xFF4C0519, 'incomeLine': 0xFF881337,
  'okSoft': 0xFF022C22, 'okBase': 0xFF6EE7B7,
  'warnSoft': 0xFF453A24, 'warnInk': 0xFFE8B96A,
  'dnBg': 0xFF022C22, 'dnBase': 0xFF6EE7B7,
};

int semColor(String key, bool isDark) =>
    (isDark ? _semDark : _semLight)[key] ?? 0xFF888888;
