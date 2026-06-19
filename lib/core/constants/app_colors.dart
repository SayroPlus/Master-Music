import 'package:flutter/material.dart';

/// Centralized color palette for the Music Organizer app.
///
/// Uses a dark, minimalist aesthetic with accent colors for key actions
/// and soft neutrals for surfaces and text hierarchy.
class AppColors {
  AppColors._();

  // ── Primary & Accent ──────────────────────────────────────────────────────
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF8B85FF);
  static const Color primaryDark = Color(0xFF4A42DB);
  static const Color accent = Color(0xFF00E5FF);

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF12121A);
  static const Color surfaceLight = Color(0xFF1E1E2A);
  static const Color card = Color(0xFF1A1A26);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color textHint = Color(0xFF6C6C6C);

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF29B6F6);

  // ── Confidence Levels ─────────────────────────────────────────────────────
  static const Color confidenceHigh = Color(0xFF4CAF50);
  static const Color confidenceMedium = Color(0xFFFF9800);
  static const Color confidenceLow = Color(0xFFF44336);

  // ── Dividers & Borders ────────────────────────────────────────────────────
  static const Color divider = Color(0xFF2A2A3E);
  static const Color border = Color(0xFF2A2A36);

  // ── Navigation ────────────────────────────────────────────────────────────
  static const Color navBarBackground = surface;
  static const Color navBarSelected = primary;
  static const Color navBarUnselected = Color(0xFF6C6C8A);
}
