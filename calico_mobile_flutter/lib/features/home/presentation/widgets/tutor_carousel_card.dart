import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/available_tutor_model.dart';

/// Card used in the "Top Rated & Available Soon" horizontal carousel.
/// Shows tutor name, rating, location, and the next available time slot
/// with a live countdown.
class TutorCarouselCard extends StatelessWidget {
  final AvailableTutorModel tutor;
  final VoidCallback? onTap;

  const TutorCarouselCard({super.key, required this.tutor, this.onTap});

  /// "Today  3:00 – 4:00 PM" or "Tomorrow  3:00 PM" etc.
  String _slotRange() {
    final start = tutor.nextSlotStart;
    if (start == null) return '';

    String fmt(DateTime dt) {
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = h < 12 ? 'AM' : 'PM';
      final dh = h % 12 == 0 ? 12 : h % 12;
      return '$dh:$m $period';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final slotDay = DateTime(start.year, start.month, start.day);

    String day;
    if (slotDay == today) {
      day = 'Today';
    } else if (slotDay == tomorrow) {
      day = 'Tomorrow';
    } else {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      day = '${months[start.month - 1]} ${start.day}';
    }

    final end = tutor.nextSlotEnd;
    if (end != null) return '$day  ${fmt(start)} – ${fmt(end)}';
    return '$day  ${fmt(start)}';
  }

  /// "in 30 min" / "in 2h 15min" / "Ongoing"
  String _countdown() {
    final start = tutor.nextSlotStart;
    if (start == null) return '';
    final diff = start.difference(DateTime.now());
    if (diff.isNegative) return 'Ongoing';
    if (diff.inMinutes < 1) return 'Starting now';
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes} min';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return m == 0 ? 'in ${h}h' : 'in ${h}h ${m}min';
  }

  @override
  Widget build(BuildContext context) {
    final slotRange = _slotRange();
    final countdown = _countdown();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.primary.withOpacity(0.2),
        child: Container(
          width: 204,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar + name + rating row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tutor.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.lexend(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              tutor.rating.toStringAsFixed(1),
                              style: GoogleFonts.lexend(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                tutor.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.lexend(
                                  fontSize: 11,
                                  color: AppColors.brown,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Slot pill
              if (slotRange.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          slotRange,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.lexend(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Countdown
              if (countdown.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  countdown,
                  style: GoogleFonts.lexend(
                    fontSize: 11,
                    color: AppColors.brown,
                  ),
                ),
              ],

              // Booking history badge
              if (tutor.bookingCount != null && tutor.bookingCount! > 0) ...[
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      size: 12,
                      color: AppColors.brown,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Booked ${tutor.bookingCount}×',
                      style: GoogleFonts.lexend(
                        fontSize: 11,
                        color: AppColors.brown,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
