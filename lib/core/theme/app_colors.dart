import 'package:flutter/material.dart';

/// Палитра UI-kit (тёмная тема + оранжевый акцент).
abstract final class AppColors {
  static const backgroundTop = Color(0xFF1A1D23);
  static const backgroundBottom = Color(0xFF242830);

  static const surface = Color(0xFF2A2F38);
  static const surfaceRaised = Color(0xFF323845);
  static const surfaceInset = Color(0xFF1E2229);

  static const accent = Color(0xFFFF7A1A);
  static const accentDark = Color(0xFFE85D04);
  static const accentGlow = Color(0x40FF7A1A);

  static const textPrimary = Color(0xFFF4F6FA);
  static const textSecondary = Color(0xFF9BA3B0);
  static const textMuted = Color(0xFF6B7280);

  static const border = Color(0x33FFFFFF);
  static const borderFocus = Color(0xFFFF7A1A);

  static const success = Color(0xFF4ADE80);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);
  static const info = Color(0xFF60A5FA);

  static const gradientAccent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8F3D), Color(0xFFE85D04)],
  );

  static const gradientBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundTop, backgroundBottom],
  );
}
