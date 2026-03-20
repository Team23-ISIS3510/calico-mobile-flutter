import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/available_tutor_model.dart';

/// Displays name, star rating, and the next available time slot.
class TutorCarouselCard extends StatelessWidget {
  final AvailableTutorModel tutor;

  const TutorCarouselCard({super.key, required this.tutor});

  String _formatSlot() {
    final start = tutor.nextSlotStart;
    if (start == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final slotDay = DateTime(start.year, start.month, start.day);

    final h = start.hour;
    final m = start.minute.toString().padLeft(2, '0');
    final period = h < 12 ? 'AM' : 'PM';
    final displayHour = h % 12 == 0 ? 12 : h % 12;
    final timeStr = '$displayHour:$m $period';

    if (slotDay == today) return 'Today\n$timeStr';
    if (slotDay == tomorrow) return 'Tomorrow\n$timeStr';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[start.month - 1]} ${start.day}\n$timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final slotText = _formatSlot();

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 8),
          // Name
          Text(
            tutor.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lexend(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.black,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          // Rating
          Row(
            children: [
              const Icon(Icons.star_rounded, color: AppColors.primary, size: 14),
              const SizedBox(width: 2),
              Text(
                tutor.rating.toStringAsFixed(1),
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Next available slot
          if (slotText.isNotEmpty)
            Text(
              slotText,
              maxLines: 2,
              style: GoogleFonts.lexend(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.brown,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }
}
