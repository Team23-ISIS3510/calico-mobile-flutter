import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../data/models/session_model.dart';

class SessionDetailScreen extends StatelessWidget {
  final SessionModel session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.brown),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Session Detail', style: AppTextStyles.itemTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon banner
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.calendar_today,
                    size: 40, color: AppColors.black),
              ),
            ),
            const SizedBox(height: 24),

            // Status badge
            Center(child: _StatusBadge(session.status)),
            const SizedBox(height: 24),

            _InfoCard(children: [
              _InfoRow('Date', session.formattedDate),
              _Divider(),
              _InfoRow('Tutor', session.displayTutor),
              _Divider(),
              if (session.displayCourse.isNotEmpty) ...[
                _InfoRow('Course', session.displayCourse),
                _Divider(),
              ],
              _InfoRow('Status', _capitalize(session.status)),
              _Divider(),
              _InfoRow('Session ID', session.id),
            ]),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status.toLowerCase()) {
      'pending' => (const Color(0xFFFFF3CD), const Color(0xFF856404)),
      'accepted' || 'scheduled' => (
          const Color(0xFFD1ECF1),
          const Color(0xFF0C5460)
        ),
      'completed' => (const Color(0xFFD4EDDA), const Color(0xFF155724)),
      'cancelled' || 'rejected' => (
          const Color(0xFFF8D7DA),
          const Color(0xFF721C24)
        ),
      _ => (AppColors.inputBackground, AppColors.brown),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Reused from course_detail ────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: AppTextStyles.itemSubtitle),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: AppTextStyles.itemTitle,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
        height: 1, thickness: 1, color: Color(0xFFEDE5D0), indent: 16);
  }
}
