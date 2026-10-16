/// 动效时长与曲线 · 真值 ui-kit/00-foundation/tokens.json 的 `motion`。
///
/// ⚠️ 不要把它命名为 `Durations` —— package:flutter/material.dart 导出了同名类
/// （src/material/motion.dart，3.16 起），凡同时 import material 与本文件的文件
/// 引用它**直接编译不过**。所以叫 `MotionDurations`。
library;

import 'package:flutter/animation.dart';

class MotionDurations {
  MotionDurations._();

  /// 按压回弹、开关、勾选 —— 短反馈。
  static const Duration fast = Duration(milliseconds: 150);

  /// 展开、翻面、页面内过渡。
  static const Duration base = Duration(milliseconds: 300);

  /// 弹层、大范围转场。
  static const Duration slow = Duration(milliseconds: 480);
}

/// 缓动曲线。`Cubic(a, b, c, d)` 的四个控制点与 CSS `cubic-bezier` 逐字对应。
class MotionCurves {
  MotionCurves._();

  /// `cubic-bezier(.16, 1, .3, 1)` —— 出场、上浮。快起缓收。
  static const Cubic out = Cubic(0.16, 1.0, 0.3, 1.0);

  /// `cubic-bezier(.34, 1.56, .64, 1)` —— **带过冲**的弹簧。
  /// 全套 App 的按压语言：返回键、图标键、卡片都走它。
  static const Cubic spring = Cubic(0.34, 1.56, 0.64, 1.0);

  /// `cubic-bezier(.4, 0, .2, 1)` —— 进出场对称。
  static const Cubic io = Cubic(0.4, 0.0, 0.2, 1.0);
}
