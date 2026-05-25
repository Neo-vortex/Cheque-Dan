import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary brand colors
  static const Color primary = Color(0xFF1E6B5E);
  static const Color primaryLight = Color(0xFF2D9E8C);
  static const Color primaryDark = Color(0xFF124840);

  // Secondary accent
  static const Color secondary = Color(0xFFF5A623);
  static const Color secondaryLight = Color(0xFFFFC355);
  static const Color secondaryDark = Color(0xFFD4860A);

  // Status colors
  static const Color active = Color(0xFF2196F3);
  static const Color cleared = Color(0xFF4CAF50);
  static const Color returned = Color(0xFFF44336);
  static const Color pending = Color(0xFFFF9800);
  static const Color draft = Color(0xFF9E9E9E);
  static const Color cancelled = Color(0xFF607D8B);

  // Due date indicator colors
  static const Color overdue = Color(0xFFE53935);
  static const Color dueToday = Color(0xFFFF7043);
  static const Color upcoming = Color(0xFFFFB300);
  static const Color safe = Color(0xFF43A047);

  // Risk colors
  static const Color riskSafe = Color(0xFF4CAF50);
  static const Color riskWarning = Color(0xFFFF9800);
  static const Color riskCritical = Color(0xFFF44336);

  // Direction colors
  static const Color issued = Color(0xFFEF5350);
  static const Color received = Color(0xFF66BB6A);

  // Light theme neutrals
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F3F5);
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);

  // Dark theme neutrals
  static const Color darkBackground = Color(0xFF0F1923);
  static const Color darkSurface = Color(0xFF1A2535);
  static const Color darkSurfaceVariant = Color(0xFF243040);
  static const Color darkBorder = Color(0xFF2E3D4F);
  static const Color darkDivider = Color(0xFF243040);

  // Light text colors
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF5C6670);
  static const Color textHint = Color(0xFFADB5BD);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Dark text colors
  static const Color darkTextPrimary = Color(0xFFE8EDF2);
  static const Color darkTextSecondary = Color(0xFF8FA3B8);
  static const Color darkTextHint = Color(0xFF4A5F72);

  // Chart colors
  static const List<Color> chartColors = [
    Color(0xFF1E6B5E),
    Color(0xFFF5A623),
    Color(0xFF4FC3F7),
    Color(0xFFBA68C8),
    Color(0xFFFF8A65),
    Color(0xFF81C784),
  ];
}
