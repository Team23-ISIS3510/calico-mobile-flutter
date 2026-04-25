import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// The Calico brand logo image.
///
/// Falls back to a text "Calico" label if the asset is missing,
/// so screens never show a broken image during development.
///
/// Usage:
///   AppLogo()                      // default size
///   AppLogo(width: 120, height: 54) // custom size
class AppLogo extends StatelessWidget {
  final double width;
  final double height;

  const AppLogo({super.key, this.width = 178, this.height = 79});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_calico.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Text(
        'Calico',
        style: GoogleFonts.lexend(
          fontWeight: FontWeight.w700,
          fontSize: 28,
          color: AppColors.brown,
        ),
      ),
    );
  }
}
