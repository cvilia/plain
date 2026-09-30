/// AppTokens: 46-field immutable value object resolved from ThemeSpec × Brightness.
/// Field names map 1:1 from CSS variables (kebab → camelCase). See 需求变更.md §4.2.
library;

import 'package:flutter/material.dart';

class AppTokens {
  const AppTokens({
    // ── Neutral layer ──
    required this.bg, required this.appBg, required this.surface, required this.surface2,
    required this.ink, required this.ink2, required this.muted, required this.faint,
    required this.line, required this.lineSoft,
    // ── Brand: primary ──
    required this.primary, required this.primaryDeep, required this.primarySoft, required this.primaryTint,
    // ── Brand: accent ──
    required this.accent, required this.accentDeep, required this.accentSoft,
    required this.accentGrad, // sheen → accent
    // ── Derived ──
    required this.onPrimary, required this.onAccent,
    required this.primaryInk, required this.accentInk,
    // ── Semantic: income ──
    required this.income, required this.incomeSoft, required this.incomeLine, required this.incomeInk,
    // ── Semantic: status ──
    required this.okSoft, required this.okInk,
    required this.warnSoft, required this.warnInk,
    required this.dnBg, required this.dnInk,
    // ── Atmosphere ──
    required this.heroGrad0, required this.heroGrad1,
    required this.heroDarkGrad0, required this.heroDarkGrad1,
    required this.frame,
    // ── Charts ──
    required this.chartTrack, required this.barFill, required this.dash,
    // ── Glow / shadow ──
    required this.glowPrimary, required this.glowAccent,
    required this.shadowPrimary, required this.shadowAccent, required this.toastBg,
    required this.shadow1, required this.shadow2, required this.shadow3,
  });

  // Neutral
  final Color bg; final Color appBg; final Color surface; final Color surface2;
  final Color ink; final Color ink2; final Color muted; final Color faint;
  final Color line; final Color lineSoft;

  // Brand: primary
  final Color primary; final Color primaryDeep; final Color primarySoft; final Color primaryTint;

  // Brand: accent
  final Color accent; final Color accentDeep; final Color accentSoft;
  final Gradient accentGrad;

  // Derived
  final Color onPrimary; final Color onAccent;
  final Color primaryInk; final Color accentInk;

  // Income
  final Color income; final Color incomeSoft; final Color incomeLine; final Color incomeInk;

  // Status
  final Color okSoft; final Color okInk;
  final Color warnSoft; final Color warnInk;
  final Color dnBg; final Color dnInk;

  // Atmosphere
  final Color heroGrad0; final Color heroGrad1;
  final Color heroDarkGrad0; final Color heroDarkGrad1;
  final Color frame;

  // Charts
  final Color chartTrack; final Color barFill; final Color dash;

  // Glow / shadow
  final Color glowPrimary; final Color glowAccent;
  final Color shadowPrimary; final Color shadowAccent; final Color toastBg;
  final Color shadow1; final Color shadow2; final Color shadow3;
}

/// Build a linear gradient from two colors.
Gradient linearGradient(Color a, Color b) =>
    LinearGradient(colors: [a, b]);

/// Build a hero gradient (white text sits on top).
Gradient heroGradient(Color a, Color b) =>
    LinearGradient(colors: [a, b], begin: Alignment.topLeft, end: Alignment.bottomRight);
