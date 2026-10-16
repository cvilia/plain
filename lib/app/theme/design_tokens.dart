/// Spacing and radius scales. Brand colors live in [AppColors] ThemeExtension
/// (see app_colors.dart) — access via `context.colors`.
/// 真值 ui-kit/00-foundation/tokens.json 的 `scale`。
library;

class Spacing {
  Spacing._();
  static const double hair = 2;   // 分隔线、细缝
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl5 = 20;   // 卡片内边距常用档（名字保留令牌表写法）
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;  // 页面分节
}

class Radii {
  Radii._();
  // 设计稿圆角只有 4+1 档：r1=8, r2=12, r3=16, r4=24, pill=999
  static const double r1 = 8;     // 小标签、序号圆片、主题色卡
  static const double r2 = 12;    // 按键、输入框、chip、tile
  static const double r3 = 16;    // 面板、卡片
  static const double r4 = 24;    // 大卡片、弹层
  static const double pill = 999; // 全圆
  // 兼容旧名
  static const double xs = r1;
  static const double sm = r1;
  static const double md = r2;
  static const double lg = r3;
  static const double xl = r4;
}
