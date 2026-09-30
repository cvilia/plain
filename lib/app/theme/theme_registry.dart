/// Theme registry: compile-time color constants for 10 themes × 2 brightness.
/// Values are authoritative from 需求变更.md §4.3–4.5 — do not modify without re-running contrast gate.
library;

/// Theme identifiers. Order and names are frozen once published (user prefs persist by ID).
enum ThemeId {
  qingci('青瓷', '品牌默认 · 青绿 × 蜜桃'),
  dianlan('靛蓝', '沉稳 · 深蓝 × 琥珀'),
  songyan('松烟', '素雅 · 灰蓝 × 苔绿'),
  shenhai('深海', '深邃 · 青蓝 × 珊瑚'),
  wuzi('雾紫', '柔美 · 紫灰 × 沙金'),
  haitang('海棠', '浪漫 · 绛粉 × 樱粉'),
  xuanzhi('宣纸', '古朴 · 褐灰 × 朱红'),
  chitao('赤陶', '温暖 · 陶红 × 青碧'),
  mocha('抹茶', '清新 · 草绿 × 姜黄'),
  subai('素白', '极简 · 炭黑 × 橘红');

  const ThemeId(this.name, this.tag);
  final String name;
  final String tag;

  static ThemeId fromId(String? v) {
    for (final t in values) {
      if (t.name == v || t.id == v) return t;
    }
    return ThemeId.qingci;
  }

  String get id => name; // use Chinese name as stable ID for storage
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

class BrandPalette {
  const BrandPalette({
    required this.p, required this.pd, required this.ps, required this.pt,
    required this.a, required this.ad, required this.as_,
    required this.hero0, required this.hero1,
    required this.heroDark0, required this.heroDark1,
    required this.frame,
  });

  final int p; final int pd; final int ps; final int pt;
  final int a; final int ad; final int as_;
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

// ─── Neutral layer: 3 tones × 2 brightness ───────────────────────────────────

const Map<ToneId, TonePalette> _toneLight = {
  ToneId.cool: TonePalette(
    bg: 0xFFE9EFEA, appBg: 0xFFF0F4F1, surface: 0xFFFFFFFF, surface2: 0xFFF5F8F5,
    ink: 0xFF2E3B36, ink2: 0xFF52655E, muted: 0xFF5A6862, faint: 0xFF8C9691,
    line: 0xFFE2E8E3, lineSoft: 0xFFECF0EB,
  ),
  ToneId.warm: TonePalette(
    bg: 0xFFEFEAE0, appBg: 0xFFF6F2E9, surface: 0xFFFFFDF8, surface2: 0xFFF7F3EA,
    ink: 0xFF332F28, ink2: 0xFF5C554A, muted: 0xFF6B655A, faint: 0xFF989183,
    line: 0xFFE6E0D3, lineSoft: 0xFFEFEADF,
  ),
  ToneId.neutral: TonePalette(
    bg: 0xFFEDEDEB, appBg: 0xFFF4F4F2, surface: 0xFFFFFFFF, surface2: 0xFFF6F6F4,
    ink: 0xFF2B2B2A, ink2: 0xFF565654, muted: 0xFF676765, faint: 0xFF949491,
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

const Map<ThemeId, ThemeSpec> _specs = {
  ThemeId.qingci: ThemeSpec(
    id: ThemeId.qingci, name: '青瓷', tag: '品牌默认 · 青绿 × 蜜桃', tone: ToneId.cool,
    light: BrandPalette(
      p: 0xFF46746A, pd: 0xFF3A6157, ps: 0xFFDCEAE4, pt: 0xFFE7F0EB,
      a: 0xFFE97E4F, ad: 0xFFDC6B3D, as_: 0xFFFCE9DE,
      hero0: 0xFF4A7C72, hero1: 0xFF659D91,
      heroDark0: 0xFF33413C, heroDark1: 0xFF4A5B55, frame: 0xFF31403A,
    ),
    dark: BrandPalette(
      p: 0xFF8FC3B7, pd: 0xFF6BA79A, ps: 0xFF2F4A44, pt: 0xFF2E443F,
      a: 0xFFF09A6E, ad: 0xFFE8835A, as_: 0xFF443228,
      hero0: 0xFF2C4740, hero1: 0xFF3C5B54,
      heroDark0: 0xFF252F2B, heroDark1: 0xFF313E39, frame: 0xFF2A3634,
    ),
  ),
  ThemeId.dianlan: ThemeSpec(
    id: ThemeId.dianlan, name: '靛蓝', tag: '沉稳 · 深蓝 × 琥珀', tone: ToneId.cool,
    light: BrandPalette(
      p: 0xFF34567F, pd: 0xFF28436A, ps: 0xFFDCE5F0, pt: 0xFFE6EDF5,
      a: 0xFFD9A24A, ad: 0xFFC48C33, as_: 0xFFFBF0DC,
      hero0: 0xFF2F5480, hero1: 0xFF5C86B4,
      heroDark0: 0xFF2A3A4C, heroDark1: 0xFF3E526A, frame: 0xFF2B3A4A,
    ),
    dark: BrandPalette(
      p: 0xFF8FB0D8, pd: 0xFF6B92C0, ps: 0xFF2A3A50, pt: 0xFF2C3B4E,
      a: 0xFFE8B96A, ad: 0xFFD6A44F, as_: 0xFF453A24,
      hero0: 0xFF22364F, hero1: 0xFF33506F,
      heroDark0: 0xFF1C2836, heroDark1: 0xFF2A3A4C, frame: 0xFF243040,
    ),
  ),
  ThemeId.songyan: ThemeSpec(
    id: ThemeId.songyan, name: '松烟', tag: '素雅 · 灰蓝 × 苔绿', tone: ToneId.cool,
    light: BrandPalette(
      p: 0xFF4C5A66, pd: 0xFF3D4A55, ps: 0xFFE0E5E9, pt: 0xFFE9EDF0,
      a: 0xFF7EA87A, ad: 0xFF6A9266, as_: 0xFFE6F0E4,
      hero0: 0xFF46535E, hero1: 0xFF6E7C88,
      heroDark0: 0xFF333C44, heroDark1: 0xFF49555F, frame: 0xFF333C44,
    ),
    dark: BrandPalette(
      p: 0xFFA0B0BC, pd: 0xFF7E909E, ps: 0xFF2C363D, pt: 0xFF2E373D,
      a: 0xFF9CC49A, ad: 0xFF82A87F, as_: 0xFF2B3A2B,
      hero0: 0xFF2A333A, hero1: 0xFF3C4750,
      heroDark0: 0xFF222A30, heroDark1: 0xFF333C44, frame: 0xFF283036,
    ),
  ),
  ThemeId.shenhai: ThemeSpec(
    id: ThemeId.shenhai, name: '深海', tag: '深邃 · 青蓝 × 珊瑚', tone: ToneId.cool,
    light: BrandPalette(
      p: 0xFF2C5D68, pd: 0xFF224B55, ps: 0xFFD8E7E9, pt: 0xFFE4EFF0,
      a: 0xFFE08A6A, ad: 0xFFD07452, as_: 0xFFFBE8E0,
      hero0: 0xFF26525C, hero1: 0xFF4E8391,
      heroDark0: 0xFF24333A, heroDark1: 0xFF384E57, frame: 0xFF263A42,
    ),
    dark: BrandPalette(
      p: 0xFF7FB6C0, pd: 0xFF5C97A2, ps: 0xFF233C41, pt: 0xFF243D42,
      a: 0xFFEFA189, ad: 0xFFDD8A6E, as_: 0xFF46312A,
      hero0: 0xFF1D3A41, hero1: 0xFF2C5560,
      heroDark0: 0xFF182D33, heroDark1: 0xFF24333A, frame: 0xFF20323A,
    ),
  ),
  ThemeId.wuzi: ThemeSpec(
    id: ThemeId.wuzi, name: '雾紫', tag: '柔美 · 紫灰 × 沙金', tone: ToneId.cool,
    light: BrandPalette(
      p: 0xFF6B5B95, pd: 0xFF57487E, ps: 0xFFE4E0F0, pt: 0xFFEDEAF6,
      a: 0xFFD9A26C, ad: 0xFFC78D54, as_: 0xFFFAEEDF,
      hero0: 0xFF5F5188, hero1: 0xFF8D80B8,
      heroDark0: 0xFF363046, heroDark1: 0xFF4A4260, frame: 0xFF3A3350,
    ),
    dark: BrandPalette(
      p: 0xFFB0A2D6, pd: 0xFF9284BE, ps: 0xFF332E45, pt: 0xFF353047,
      a: 0xFFE8BC8C, ad: 0xFFD6A672, as_: 0xFF453626,
      hero0: 0xFF2C2740, hero1: 0xFF413A5C,
      heroDark0: 0xFF231F33, heroDark1: 0xFF363046, frame: 0xFF312B45,
    ),
  ),
  ThemeId.haitang: ThemeSpec(
    id: ThemeId.haitang, name: '海棠', tag: '浪漫 · 绛粉 × 樱粉', tone: ToneId.cool,
    light: BrandPalette(
      p: 0xFFA2547A, pd: 0xFF8B4164, ps: 0xFFF2DFE8, pt: 0xFFF7EAF0,
      a: 0xFFE8A0B4, ad: 0xFFDB849C, as_: 0xFFFBE7EC,
      hero0: 0xFF934B6E, hero1: 0xFFC07FA0,
      heroDark0: 0xFF43303A, heroDark1: 0xFF5A4451, frame: 0xFF4A3542,
    ),
    dark: BrandPalette(
      p: 0xFFDDA0BE, pd: 0xFFC483A2, ps: 0xFF402A36, pt: 0xFF432C38,
      a: 0xFFF0B8C8, ad: 0xFFDE9FB2, as_: 0xFF452E36,
      hero0: 0xFF3A2530, hero1: 0xFF553A47,
      heroDark0: 0xFF30202A, heroDark1: 0xFF43303A, frame: 0xFF3E2934,
    ),
  ),
  ThemeId.xuanzhi: ThemeSpec(
    id: ThemeId.xuanzhi, name: '宣纸', tag: '古朴 · 褐灰 × 朱红', tone: ToneId.warm,
    light: BrandPalette(
      p: 0xFF6E6259, pd: 0xFF57504A, ps: 0xFFE7E0D6, pt: 0xFFEFEAE2,
      a: 0xFFC0453A, ad: 0xFFA83A30, as_: 0xFFF7E0DC,
      hero0: 0xFF6A5F55, hero1: 0xFF9A8B7C,
      heroDark0: 0xFF3E3830, heroDark1: 0xFF564D42, frame: 0xFF4A4238,
    ),
    dark: BrandPalette(
      p: 0xFFB5A896, pd: 0xFF95897A, ps: 0xFF3B342B, pt: 0xFF3D362D,
      a: 0xFFE88A7E, ad: 0xFFD4705F, as_: 0xFF442B27,
      hero0: 0xFF2E2820, hero1: 0xFF453C30,
      heroDark0: 0xFF262019, heroDark1: 0xFF3E3830, frame: 0xFF38302A,
    ),
  ),
  ThemeId.chitao: ThemeSpec(
    id: ThemeId.chitao, name: '赤陶', tag: '温暖 · 陶红 × 青碧', tone: ToneId.warm,
    light: BrandPalette(
      p: 0xFF9E5A3C, pd: 0xFF864A30, ps: 0xFFF0DFD5, pt: 0xFFF5E9E1,
      a: 0xFF4E8B80, ad: 0xFF3F7A6F, as_: 0xFFDCEBE7,
      hero0: 0xFF8E5136, hero1: 0xFFB98363,
      heroDark0: 0xFF40302A, heroDark1: 0xFF584338, frame: 0xFF48342A,
    ),
    dark: BrandPalette(
      p: 0xFFD8977A, pd: 0xFFC07B5C, ps: 0xFF432F26, pt: 0xFF453128,
      a: 0xFF8FC0B4, ad: 0xFF74A89B, as_: 0xFF243B36,
      hero0: 0xFF38251D, hero1: 0xFF52382B,
      heroDark0: 0xFF30201A, heroDark1: 0xFF40302A, frame: 0xFF3E2B22,
    ),
  ),
  ThemeId.mocha: ThemeSpec(
    id: ThemeId.mocha, name: '抹茶', tag: '清新 · 草绿 × 姜黄', tone: ToneId.warm,
    light: BrandPalette(
      p: 0xFF5D7C48, pd: 0xFF4D6A3B, ps: 0xFFE2EBD8, pt: 0xFFEBF1E4,
      a: 0xFFE8B96A, ad: 0xFFD6A44F, as_: 0xFFFAF0DC,
      hero0: 0xFF57753F, hero1: 0xFF7E9B60,
      heroDark0: 0xFF36402F, heroDark1: 0xFF4C583F, frame: 0xFF3E4A35,
    ),
    dark: BrandPalette(
      p: 0xFFA4C08A, pd: 0xFF87A56E, ps: 0xFF2F3A26, pt: 0xFF313C28,
      a: 0xFFE8C88A, ad: 0xFFD6B26A, as_: 0xFF453A24,
      hero0: 0xFF2A3520, hero1: 0xFF3E4F2E,
      heroDark0: 0xFF222B1A, heroDark1: 0xFF36402F, frame: 0xFF2C3624,
    ),
  ),
  ThemeId.subai: ThemeSpec(
    id: ThemeId.subai, name: '素白', tag: '极简 · 炭黑 × 橘红', tone: ToneId.neutral,
    light: BrandPalette(
      p: 0xFF2F2F2D, pd: 0xFF1F1F1E, ps: 0xFFE6E6E3, pt: 0xFFEFEFEC,
      a: 0xFFD96C47, ad: 0xFFC4573A, as_: 0xFFF8E5DD,
      hero0: 0xFF2A2A28, hero1: 0xFF4A4A47,
      heroDark0: 0xFF262624, heroDark1: 0xFF3A3A38, frame: 0xFF2A2A28,
    ),
    dark: BrandPalette(
      p: 0xFFD6D6D2, pd: 0xFFB4B4B0, ps: 0xFF33332F, pt: 0xFF353531,
      a: 0xFFE89070, ad: 0xFFD67753, as_: 0xFF44302A,
      hero0: 0xFF232322, hero1: 0xFF3A3A38,
      heroDark0: 0xFF1E1E1D, heroDark1: 0xFF262624, frame: 0xFF242422,
    ),
  ),
};

ThemeSpec themeSpecOf(ThemeId id) => _specs[id] ?? _specs[ThemeId.qingci]!;

// ─── Fixed palettes (cross-theme invariant, INV-1) ───────────────────────────

/// Category colors — 12 items, identical across all themes.
const Map<String, int> CATCOL = {
  '餐饮': 0xFFE69A6D,
  '购物': 0xFFDC8EA6,
  '日用': 0xFF9B8FD4,
  '交通': 0xFF75B2C8,
  '蔬果': 0xFF97BC81,
  '娱乐': 0xFFBFA8E9,
  '居住': 0xFFC58B72,
  '医疗': 0xFFD97C7C,
  '学习': 0xFF7FA8DC,
  '人情': 0xFFC977A8,
  '其他': 0xFFA3ABA4,
  '通讯': 0xFF6FAFA3,
};

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
