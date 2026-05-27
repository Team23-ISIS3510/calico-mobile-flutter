import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../domain/entities/session_entity.dart';

/// Tappable list row that displays a single [SessionEntity].
///
/// Reusable across any screen within the home feature that lists sessions
/// (home feed, upcoming sessions view, calendar detail, etc.).
///
/// Usage:
///   SessionCard(session: session, onTap: () => _openDetail(session))
class SessionCard extends StatelessWidget {
  final SessionEntity session;
  final VoidCallback onTap;
  /// When true the card shows a ⏳ Pending sync badge, indicating this session
  /// was saved to the local SQLite queue while offline and has not yet been
  /// confirmed by the server.
  final bool showPendingBadge;
  /// Called when the user taps the cancel button on a pending session.
  final VoidCallback? onCancel;

  const SessionCard({
    super.key,
    required this.session,
    required this.onTap,
    this.showPendingBadge = false,
    this.onCancel,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    session.formattedDate,
                    style: AppTextStyles.itemTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    session.displayTutor,
                    style: AppTextStyles.itemSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (session.displayCourse.isNotEmpty)
                    Text(
                      session.displayCourse,
                      style: AppTextStyles.itemSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (showPendingBadge) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('⏳', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 3),
                        Text(
                          'Pending sync',
                          style: AppTextStyles.itemSubtitle.copyWith(
                            color: Colors.orange.shade700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (showPendingBadge && onCancel != null)
              IconButton(
                onPressed: onCancel,
                icon: const Icon(Icons.close, size: 22, color: Colors.red),
                tooltip: 'Cancel booking',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              )
            else
              const Icon(Icons.chevron_right, size: 28, color: AppColors.black),
          ],
        ),
      ),
    );
  }
}
