import 'package:flutter/material.dart';

/// Unified design system colors supporting both Dark and Light themes.
class AppColors {
  // Brand accents
  static const Color primaryCyan = Color(0xFF06B6D4);
  static const Color primaryCyanDark = Color(0xFF0891B2);
  static const Color accentIndigo = Color(0xFF6366F1);
  static const Color accentPurple = Color(0xFF8B5CF6);

  // Status colors
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color infoBlue = Color(0xFF3B82F6);

  // Dark Theme Palette (Cyber Slate)
  static const Color darkBackground = Color(0xFF0A0E17);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkCardBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Light Theme Palette (Clean Modern)
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Terminal Log Colors
  static const Color terminalBg = Color(0xFF030712);
  static const Color terminalText = Color(0xFFE2E8F0);
  static const Color terminalTimestamp = Color(0xFF64748B);
  static const Color terminalInfo = Color(0xFF38BDF8);
  static const Color terminalWarning = Color(0xFFFBBF24);
  static const Color terminalError = Color(0xFFF87171);
  static const Color terminalSuccess = Color(0xFF34D399);
}
