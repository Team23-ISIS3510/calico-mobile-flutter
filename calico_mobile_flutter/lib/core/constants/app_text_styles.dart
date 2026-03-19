import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract final class AppTextStyles {
  // ── Auth ──────────────────────────────────────────────────────────────────

  static TextStyle get fieldPlaceholder => GoogleFonts.lexend(
        fontWeight: FontWeight.w400,
        fontSize: 16,
        height: 1.5,
        color: AppColors.brown,
      );

  static TextStyle get buttonLabel => GoogleFonts.lexend(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        height: 1.5,
        color: AppColors.black,
      );

  static TextStyle get linkText => GoogleFonts.lexend(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        height: 1.5,
        color: AppColors.brown,
      );

  static TextStyle get errorText => GoogleFonts.lexend(
        fontWeight: FontWeight.w400,
        fontSize: 12,
        color: const Color(0xFFB00020),
      );

  // ── Home / shared ─────────────────────────────────────────────────────────

  /// Bold 22 px black — used for section headers ("Courses Section", etc.)
  static TextStyle get sectionTitle => GoogleFonts.lexend(
        fontWeight: FontWeight.w700,
        fontSize: 22,
        height: 28 / 22,
        color: AppColors.black,
      );

  /// Medium 16 px black — course / session primary line
  static TextStyle get itemTitle => GoogleFonts.lexend(
        fontWeight: FontWeight.w500,
        fontSize: 16,
        height: 1.5,
        color: AppColors.black,
      );

  /// Regular 14 px brown — course code / tutor name / secondary line
  static TextStyle get itemSubtitle => GoogleFonts.lexend(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        height: 1.5,
        color: AppColors.brown,
      );

  /// Regular 16 px brown — search bar hint / input placeholder
  static TextStyle get searchHint => GoogleFonts.lexend(
        fontWeight: FontWeight.w400,
        fontSize: 16,
        height: 1.5,
        color: AppColors.brown,
      );
}
