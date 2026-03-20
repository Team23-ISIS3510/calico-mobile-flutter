import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../data/models/session_model.dart';

/// Tappable list row that displays a single [SessionModel].
///
/// Reusable across any screen within the home feature that lists sessions
/// (home feed, upcoming sessions view, calendar detail, etc.).
///
/// Usage:
///   SessionCard(session: session, onTap: () => _openDetail(session))
class SessionCard extends StatelessWidget {
  final SessionModel session;
  final VoidCallback onTap;

  const SessionCard({
    super.key,
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(minHeight: 90),
        color: AppColors.background,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Calendar icon in primary (orange) square
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    size: 24,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(session.formattedDate,
                        style: AppTextStyles.itemTitle),
                    Text(session.displayTutor,
                        style: AppTextStyles.itemSubtitle),
                    if (session.displayCourse.isNotEmpty)
                      Text(session.displayCourse,
                          style: AppTextStyles.itemSubtitle),
                  ],
                ),
              ],
            ),
            const Icon(Icons.chevron_right, size: 28, color: AppColors.black),
          ],
        ),
      ),
    );
  }
}
