import 'package:flutter/material.dart';
import '../constants/app_text_styles.dart';

/// Bold section title used above content groups (e.g. "Courses", "Sessions").
///
/// Usage:
///   SectionHeader('Courses')
///   SectionHeader('Upcoming Sessions')
class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Text(title, style: AppTextStyles.sectionTitle),
    );
  }
}
