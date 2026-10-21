/// Theme registry: compile-time color constants for 10 themes × 2 brightness.
///
/// 一张主题 = 中性层（[TonePalette]）× 品牌层（[BrandPalette]）+ 纸色 wash 强度。
/// 品牌层是按 `_specs` 上方那 7 条门禁反推出来的，不是设计稿抄本；改值先读注释。
library;

/// Theme identifiers. [id] is the frozen persistence key (pinyin, never
/// renamed). [name] is display-only. Old Chinese storage values are mapped
/// via [_legacyNameToId] in [ThemeId.fromId].
enum ThemeId {
  qingci('qingci', '青瓷', '清爽 · 青绿 × 蜜桃'),
  dianlan('dianlan', '靛蓝', '沉稳 · 深蓝 × 琥珀'),
  zhuqing('zhuqing', '竹青', '素雅 · 草绿 × 藕粉'),
  haiyan('haiyan', '海盐', '深邃 · 青蓝 × 珊瑚'),
  ouhe('ouhe', '藕荷', '柔美 · 藕紫 × 沙金'),
  taoyao('taoyao', '桃夭', '浪漫 · 桃粉 × 青碧'),
  feiying('feiying', '绯樱', '古朴 · 绯红 × 黛蓝'),
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
    required this.washLight, required this.washDark,
  });

  final ThemeId id;
  final String name;
  final String tag;
  final ToneId tone;
  final BrandPalette light;
  final BrandPalette dark;

  /// 页面纸色（`appBg` / `bg`）叠品牌色的强度 —— 亮色。
  ///
  /// 每个主题的整页底色 = 中性纸色 × 品牌主色 wash，因此「素白」几乎是灰白，
  /// 「桃夭」是淡粉，「靛蓝」是淡薰衣草。卡片（`surface`）仍接近纯色，靠
  /// 明度差（卡片比页面浅一档）而不是「页面纯白 + 卡片纯白」来分层。
  final double washLight;

  /// 页面纸色叠品牌色的强度 —— 暗色。暗色不能直接叠品牌色：品牌亮色会把
  /// 纸色提亮，`ink` 对纸色的对比度会掉到 12:1 以下。所以先压暗 30% 再叠。
  final double washDark;
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

// v3 Quiet Ledger: de-warm neutrals. Values from redesign-v3/01-tokens.json
// (cool / neutral / sand). ToneId.warm maps to v3 "sand" (杏黄/豆绿).
const Map<ToneId, TonePalette> _toneLight = {
  ToneId.cool: TonePalette(
    bg: 0xFFF4F6F6, appBg: 0xFFFAFBFB, surface: 0xFFFFFFFF, surface2: 0xFFF5F7F7,
    ink: 0xFF0E1413, ink2: 0xFF36403E, muted: 0xFF5B6765, faint: 0xFF78857F,
    line: 0xFFE3E8E7, lineSoft: 0xFFEDF1F0,
  ),
  ToneId.warm: TonePalette(
    bg: 0xFFF7F6F4, appBg: 0xFFFCFBF9, surface: 0xFFFEFCF9, surface2: 0xFFF7F6F3,
    ink: 0xFF121110, ink2: 0xFF3A3835, muted: 0xFF615D58, faint: 0xFF7D7871,
    line: 0xFFE6E4DF, lineSoft: 0xFFF0EEE9,
  ),
  ToneId.neutral: TonePalette(
    bg: 0xFFF5F5F6, appBg: 0xFFFBFBFC, surface: 0xFFFFFFFF, surface2: 0xFFF6F6F8,
    ink: 0xFF101012, ink2: 0xFF38383D, muted: 0xFF5E5E65, faint: 0xFF7B7B81,
    line: 0xFFE4E4E8, lineSoft: 0xFFEFEFF2,
  ),
};

const Map<ToneId, TonePalette> _toneDark = {
  ToneId.cool: TonePalette(
    bg: 0xFF101413, appBg: 0xFF181D1C, surface: 0xFF202625, surface2: 0xFF293130,
    ink: 0xFFE8EDEA, ink2: 0xFFBEC8C4, muted: 0xFF8E9895, faint: 0xFF6F7975,
    line: 0xFF2F3634, lineSoft: 0xFF272E2C,
  ),
  ToneId.warm: TonePalette(
    bg: 0xFF131211, appBg: 0xFF1B1A18, surface: 0xFF232220, surface2: 0xFF2C2B28,
    ink: 0xFFEDECE9, ink2: 0xFFC6C2BD, muted: 0xFF96928C, faint: 0xFF77726B,
    line: 0xFF35332F, lineSoft: 0xFF2D2B28,
  ),
  ToneId.neutral: TonePalette(
    bg: 0xFF121214, appBg: 0xFF1A1A1D, surface: 0xFF222225, surface2: 0xFF2B2B2F,
    ink: 0xFFECECEE, ink2: 0xFFC2C2C7, muted: 0xFF93939B, faint: 0xFF74747C,
    line: 0xFF33333A, lineSoft: 0xFF2B2B32,
  ),
};

TonePalette toneOf(ToneId tone, bool isDark) =>
    (isDark ? _toneDark : _toneLight)[tone]!;

// ─── Brand layer: 10 themes × 2 brightness ───────────────────────────────────
//
// 这套色值是「按门禁反推」出来的，不是从设计稿抄的。改任何一个值之前先读下面 7 条，
// 改完必须跑 `test/theme_gates_test.dart`（同一套规则的可执行版）：
//
//   R1 同主题内 主色 ↔ 强调色 可区分：OKLab ΔE ≥ 15 或色相 ≥ 60°。
//      旧值里 `绯樱 p=#EF4444 / a=#10B981` 没问题，但 `靛蓝 p=#3B82F6 / a=#F59E0B` 之外
//      几支都踩在「同色系抬一档」上，主次衬托不出来。
//   R2 品牌 ink（文字级）与语义「支出红 / 收入绿」可区分：ΔE ≥ 10 或色相 ≥ 25°。
//      旧值 `青瓷 p=#14B8A6` → `primaryInk` 与收入绿同屏分不开；`绯樱 p=#EF4444`
//      与支出红 ΔE 6.1。**暗色尤其难**：语义支出红 `#FDA4AF` 是一支很浅的粉，
//      任何红系品牌算出来的 4.5:1 ink 都会落在它旁边，所以绯樱暗色改成低彩度
//      深酒红（`#72313A`）—— ink 被反推成 `#B8989C` 才拉得开 ΔE 12。
//   R3 跨主题主色两两 ΔE ≥ 8。两支主题不会同屏，只在选择器色块并排，8 够了。
//   R4 页面纸色（`appBg`）= 中性纸 × 品牌主色 wash，见 [ThemeSpec.washLight]。
//      亮色与纯白 ΔE ≥ 2.2（肉眼能看出「这个主题有底色」），
//      暗色与中性底 ΔE ≥ 1.5。
//   R5 ink 层级对**纸色**的对比度：ink ≥ 12 / ink2 ≥ 7 / muted ≥ 4.5 / faint ≥ 3.0。
//      旧值 `faint` 在淡色纸上一律掉到 2.9x，所以三套中性层的 faint 统一压深了一点。
//   R6 描边对纸色可见（≥ 1.06）且与品牌色 ΔE ≥ 15（亮）/ 12（暗）—— 边框不许抢品牌色。
//      描边也掺 5% 品牌色，否则纯灰线放在彩色纸上一眼就是「没调过」。
//   R7 导航选中色（`primaryInk`）≥ 4.5:1，且 FAB 底色恒等于它、图标对 FAB 底 ≥ 4.5。
//
// hero0/hero1/heroDark0/heroDark1 直接按「白字 4.6:1」反解亮度上限生成，
// 所以运行时 `cm.heroSafe()` 是 no-op —— 旧值里 `青瓷 hero1=#2DD4BF` 白字只有
// 1.86:1，全靠 heroSafe 在运行时压暗，压完跟 hero0 几乎同色，渐变等于没了。

const Map<ThemeId, ThemeSpec> _specs = {
  // 清爽：青瓷绿底 × 蜜桃橘强调
  ThemeId.qingci: ThemeSpec(
    id: ThemeId.qingci, name: '青瓷', tag: '清爽 · 青绿 × 蜜桃', tone: ToneId.cool,
    washLight: 0.072, washDark: 0.1,
    light: BrandPalette(
      p: 0xFF2C7A8C, pd: 0xFF205865,
      a: 0xFFE07852, ad: 0xFFD95626,
      hero0: 0xFF1A4953, hero1: 0xFF337C8C,
      heroDark0: 0xFF0F2A30, heroDark1: 0xFF18424C,
      frame: 0xFF0F2A30,
    ),
    dark: BrandPalette(
      p: 0xFF79BFC8, pd: 0xFF5CB1BC,
      a: 0xFFF0A189, ad: 0xFFEC8465,
      hero0: 0xFF20484E, hero1: 0xFF3B7B84,
      heroDark0: 0xFF122A2D, heroDark1: 0xFF1D4247,
      frame: 0xFF122A2D,
    ),
  ),
  // 沉稳：靛蓝底 × 琥珀黄强调
  ThemeId.dianlan: ThemeSpec(
    id: ThemeId.dianlan, name: '靛蓝', tag: '沉稳 · 深蓝 × 琥珀', tone: ToneId.cool,
    washLight: 0.07, washDark: 0.105,
    light: BrandPalette(
      p: 0xFF3B2BB6, pd: 0xFF2D218C,
      a: 0xFFCE8D1C, ad: 0xFFA26E16,
      hero0: 0xFF1D1559, hero1: 0xFF372A95,
      heroDark0: 0xFF110C34, heroDark1: 0xFF1A1351,
      frame: 0xFF110C34,
    ),
    dark: BrandPalette(
      p: 0xFFA38BE4, pd: 0xFF896ADC,
      a: 0xFFF2C15F, ad: 0xFFEFB239,
      hero0: 0xFF271559, hero1: 0xFF472A95,
      heroDark0: 0xFF170C34, heroDark1: 0xFF231351,
      frame: 0xFF170C34,
    ),
  ),
  // 素雅：竹青绿底 × 藕粉强调
  ThemeId.zhuqing: ThemeSpec(
    id: ThemeId.zhuqing, name: '竹青', tag: '素雅 · 草绿 × 藕粉', tone: ToneId.cool,
    washLight: 0.085, washDark: 0.11,
    light: BrandPalette(
      p: 0xFF43802D, pd: 0xFF2F5B20,
      a: 0xFFCB7292, ad: 0xFFBD4C76,
      hero0: 0xFF2B511D, hero1: 0xFF488233,
      heroDark0: 0xFF192F11, heroDark1: 0xFF274A1A,
      frame: 0xFF192F11,
    ),
    dark: BrandPalette(
      p: 0xFF7CC760, pd: 0xFF63BD42,
      a: 0xFFE4AABF, ad: 0xFFDA8BA8,
      hero0: 0xFF2B511D, hero1: 0xFF488233,
      heroDark0: 0xFF192F11, heroDark1: 0xFF274A1A,
      frame: 0xFF192F11,
    ),
  ),
  // 深邃：海盐蓝底 × 珊瑚强调
  ThemeId.haiyan: ThemeSpec(
    id: ThemeId.haiyan, name: '海盐', tag: '深邃 · 青蓝 × 珊瑚', tone: ToneId.cool,
    washLight: 0.07, washDark: 0.115,
    light: BrandPalette(
      p: 0xFF2B63AB, pd: 0xFF214B83,
      a: 0xFFDF5D49, ad: 0xFFD03C25,
      hero0: 0xFF163258, hero1: 0xFF2C5993,
      heroDark0: 0xFF0D1D33, heroDark1: 0xFF142E50,
      frame: 0xFF0D1D33,
    ),
    dark: BrandPalette(
      p: 0xFF7BA9EA, pd: 0xFF5892E4,
      a: 0xFFEF8F80, ad: 0xFFEB6F5C,
      hero0: 0xFF0F305E, hero1: 0xFF22559E,
      heroDark0: 0xFF091C37, heroDark1: 0xFF0E2C56,
      frame: 0xFF091C37,
    ),
  ),
  // 柔美：藕荷紫底 × 沙金强调
  ThemeId.ouhe: ThemeSpec(
    id: ThemeId.ouhe, name: '藕荷', tag: '柔美 · 藕紫 × 沙金', tone: ToneId.cool,
    washLight: 0.078, washDark: 0.11,
    light: BrandPalette(
      p: 0xFF8C60BE, pd: 0xFF7244A7,
      a: 0xFFB18F2F, ad: 0xFF896E24,
      hero0: 0xFF35204E, hero1: 0xFF5D3B84,
      heroDark0: 0xFF1F122D, heroDark1: 0xFF301D47,
      frame: 0xFF1F122D,
    ),
    dark: BrandPalette(
      p: 0xFFC5ABE3, pd: 0xFFB08CD9,
      a: 0xFFE0BF67, ad: 0xFFD9B145,
      hero0: 0xFF351B52, hero1: 0xFF5D358B,
      heroDark0: 0xFF1F1030, heroDark1: 0xFF30194B,
      frame: 0xFF1F1030,
    ),
  ),
  // 浪漫：桃粉底 × 青碧强调
  ThemeId.taoyao: ThemeSpec(
    id: ThemeId.taoyao, name: '桃夭', tag: '浪漫 · 桃粉 × 青碧', tone: ToneId.cool,
    washLight: 0.088, washDark: 0.115,
    light: BrandPalette(
      p: 0xFFCE4683, pd: 0xFFB12F6A,
      a: 0xFF32838F, ad: 0xFF25616A,
      hero0: 0xFF571734, hero1: 0xFF922E5B,
      heroDark0: 0xFF320D1E, heroDark1: 0xFF4F152F,
      frame: 0xFF320D1E,
    ),
    dark: BrandPalette(
      p: 0xFFDC6AB2, pd: 0xFFD449A1,
      a: 0xFF81C5CF, ad: 0xFF64B7C4,
      hero0: 0xFF591540, hero1: 0xFF952A6E,
      heroDark0: 0xFF340C25, heroDark1: 0xFF51133A,
      frame: 0xFF340C25,
    ),
  ),
  // 古朴：绯樱红底 × 黛蓝强调
  ThemeId.feiying: ThemeSpec(
    id: ThemeId.feiying, name: '绯樱', tag: '古朴 · 绯红 × 黛蓝', tone: ToneId.cool,
    washLight: 0.07, washDark: 0.115,
    light: BrandPalette(
      p: 0xFF822635, pd: 0xFF5B1A25,
      a: 0xFF294E60, ad: 0xFF1A313D,
      hero0: 0xFF551923, hero1: 0xFF8F3040,
      heroDark0: 0xFF310E14, heroDark1: 0xFF4D161F,
      frame: 0xFF310E14,
    ),
    dark: BrandPalette(
      p: 0xFF72313A, pd: 0xFF56252B,
      a: 0xFF92BDD3, ad: 0xFF75ACC7,
      hero0: 0xFF4D2127, hero1: 0xFF823D46,
      heroDark0: 0xFF2D1317, heroDark1: 0xFF461E23,
      frame: 0xFF2D1317,
    ),
  ),
  // 温暖：杏黄底 × 湖蓝强调
  ThemeId.xinghuang: ThemeSpec(
    id: ThemeId.xinghuang, name: '杏黄', tag: '温暖 · 杏黄 × 湖蓝', tone: ToneId.warm,
    washLight: 0.085, washDark: 0.115,
    light: BrandPalette(
      p: 0xFFC88219, pd: 0xFF9A6413,
      a: 0xFF296199, ad: 0xFF1E4771,
      hero0: 0xFF623F0C, hero1: 0xFF9E6A1C,
      heroDark0: 0xFF392507, heroDark1: 0xFF59390B,
      frame: 0xFF392507,
    ),
    dark: BrandPalette(
      p: 0xFFF3BB68, pd: 0xFFF0AA42,
      a: 0xFF94BDE6, ad: 0xFF73A8DE,
      hero0: 0xFF654008, hero1: 0xFFA06815,
      heroDark0: 0xFF3B2505, heroDark1: 0xFF5C3A07,
      frame: 0xFF3B2505,
    ),
  ),
  // 清新：豆绿底 × 藤紫强调
  ThemeId.doulv: ThemeSpec(
    id: ThemeId.doulv, name: '豆绿', tag: '清新 · 豆绿 × 藤紫', tone: ToneId.warm,
    washLight: 0.08, washDark: 0.095,
    light: BrandPalette(
      p: 0xFF9AB62B, pd: 0xFF778C21,
      a: 0xFFAC72C0, ad: 0xFF984FB0,
      hero0: 0xFF4B5915, hero1: 0xFF6A7B23,
      heroDark0: 0xFF2C340C, heroDark1: 0xFF445113,
      frame: 0xFF2C340C,
    ),
    dark: BrandPalette(
      p: 0xFFDAE7A6, pd: 0xFFCDDF86,
      a: 0xFFD3AFDE, ad: 0xFFC392D3,
      hero0: 0xFF4A5717, hero1: 0xFF6B7C27,
      heroDark0: 0xFF2B320D, heroDark1: 0xFF434F15,
      frame: 0xFF2B320D,
    ),
  ),
  // 极简：炭黑底 × 橘红强调
  ThemeId.subai: ThemeSpec(
    id: ThemeId.subai, name: '素白', tag: '极简 · 炭黑 × 橘红', tone: ToneId.neutral,
    washLight: 0.055, washDark: 0.085,
    light: BrandPalette(
      p: 0xFF484851, pd: 0xFF303036,
      a: 0xFFD66838, ad: 0xFFB65125,
      hero0: 0xFF34343A, hero1: 0xFF5A5A65,
      heroDark0: 0xFF1E1E22, heroDark1: 0xFF2F2F35,
      frame: 0xFF1E1E22,
    ),
    dark: BrandPalette(
      p: 0xFFD4D4D8, pd: 0xFFBFBFC5,
      a: 0xFFEAA07B, ad: 0xFFE48758,
      hero0: 0xFF34343A, hero1: 0xFF5B5B64,
      heroDark0: 0xFF1E1E21, heroDark1: 0xFF2F2F34,
      frame: 0xFF1E1E21,
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

/// Hero 卡底色。与主题无关，亮暗各一对（04-技术架构设计.md §16.1）。
const int kHeroCardLight0 = 0xFFFFFCF4;
const int kHeroCardLight1 = 0xFFF4EFE1;
const int kHeroCardDark0 = 0xFF322D25;
const int kHeroCardDark1 = 0xFF25221D;

/// 12 个一级分类的 ink（图标 / 小字前景）。
/// 由对比度反推，最差 4.53:1（见 tokens.json 的 gates.categoryInk_min）。
/// **搬值，不要重算** —— 推导宿主集没有留脚本。
const Map<String, int> categoryInkLight = {
  'food': 0xFFA23030,        'shopping': 0xFF9D3767,
  'daily': 0xFF6849B1,       'transport': 0xFF0F638E,
  'fruit': 0xFF186F42,       'entertainment': 0xFF972EA6,
  'housing': 0xFF8B5516,     'medical': 0xFFA03A3A,
  'study': 0xFF265BA4,       'social': 0xFF7341B2,
  'other': 0xFF4E5E6F,       'telecom': 0xFF0A6963,
};

const Map<String, int> categoryInkDark = {
  'food': 0xFFFFA5A5,        'shopping': 0xFFF8A8D1,
  'daily': 0xFFC9B8FC,       'transport': 0xFF89D3F6,
  'fruit': 0xFF7CE5A3,       'entertainment': 0xFFF4A9FB,
  'housing': 0xFFFBCB98,     'medical': 0xFFFCA9A9,
  'study': 0xFFA0C6FB,       'social': 0xFFD9B2FA,
  'other': 0xFFBBC6D2,       'telecom': 0xFF6BE0D6,
};

/// 按亮度取分类 ink。
int? categoryInkFor(String iconRef, bool isDark) =>
    (isDark ? categoryInkDark : categoryInkLight)[iconRef];

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
