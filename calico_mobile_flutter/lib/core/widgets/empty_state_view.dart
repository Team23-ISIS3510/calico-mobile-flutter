import 'package:flutter/material.dart';
import '../constants/app_text_styles.dart';

/// Subtle placeholder shown when a list has no items to display.
///
/// Usage:
///   EmptyStateView('No courses found')
///   EmptyStateView('Sign in to see your sessions')
class EmptyStateView extends StatelessWidget {
  final String message;

  const EmptyStateView(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Text(message, style: AppTextStyles.itemSubtitle),
    );
  }
}
