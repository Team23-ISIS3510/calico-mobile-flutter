import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class OfflineCacheNotice extends StatelessWidget {
  final DateTime? lastUpdated;
  final EdgeInsetsGeometry padding;

  const OfflineCacheNotice({
    super.key,
    required this.lastUpdated,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEDE5D0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 18,
              color: AppColors.brown,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mostrando datos locales (offline) — Actualizado: ${_format(lastUpdated)}',
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  color: AppColors.brown,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _format(DateTime? dt) {
    if (dt == null) return 'desconocido';
    final local = dt.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    final rawHour = local.hour;
    final hour = rawHour == 0
        ? 12
        : rawHour > 12
            ? rawHour - 12
            : rawHour;
    final min = local.minute.toString().padLeft(2, '0');
    final ampm = rawHour >= 12 ? 'PM' : 'AM';
    return '$dd/$mm/$yyyy · $hour:$min $ampm';
  }
}
