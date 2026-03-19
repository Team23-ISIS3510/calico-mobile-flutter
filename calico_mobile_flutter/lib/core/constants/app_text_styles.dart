import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract final class AppTextStyles {
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
        color: Color(0xFFB00020),
      );
}
