import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../domain/entities/course_entity.dart';

/// Tappable list row that displays a single [CourseEntity].
///
/// Reusable across any screen within the home feature that lists courses
/// (home feed, search results, tutor profile, etc.).
///
/// Usage:
///   CourseCard(course: course, onTap: () => _openDetail(course))
class CourseCard extends StatelessWidget {
  final CourseEntity course;
  final VoidCallback onTap;

  const CourseCard({
    super.key,
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        constraints: const BoxConstraints(minHeight: 72),
        color: AppColors.background,
        child: Row(
          children: [
            // Book icon in beige square
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.menu_book_outlined,
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
                    course.name,
                    style: AppTextStyles.itemTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    course.code,
                    style: AppTextStyles.itemSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 28, color: AppColors.black),
          ],
        ),
      ),
    );
  }
}
