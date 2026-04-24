import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/services/motion_alert_file_log.dart';

class AlertHistoryScreen extends StatefulWidget {
  const AlertHistoryScreen({super.key});

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> {
  late Future<List<AlertLogEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = MotionAlertFileLog.instance.readAlertEvents();
  }

  Future<void> _refresh() async {
    final next = MotionAlertFileLog.instance.readAlertEvents();
    setState(() => _future = next);
    await next;
  }

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
        title: Text(
          'Historial de alertas',
          style: AppTextStyles.itemTitle,
        ),
      ),
      body: FutureBuilder<List<AlertLogEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final entries = snapshot.data ?? const <AlertLogEntry>[];
          if (entries.isEmpty) {
            return _EmptyHistoryState(onRefresh: _refresh);
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFE9E1CF),
              ),
              itemBuilder: (context, index) =>
                  _AlertHistoryTile(entry: entries[index]),
            ),
          );
        },
      ),
    );
  }
}

class _AlertHistoryTile extends StatelessWidget {
  final AlertLogEntry entry;

  const _AlertHistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final icon = entry.success
        ? const Icon(Icons.check_circle_rounded,
            color: Color(0xFF2F8F5A), size: 28)
        : const Icon(Icons.warning_amber_rounded,
            color: Color(0xFFC9302C), size: 28);

    final formattedDate = _formatDate(entry.timestamp);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: icon,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.reason.isEmpty ? 'Alerta de emergencia' : entry.reason,
            style: AppTextStyles.itemTitle,
          ),
          const SizedBox(height: 2),
          Text(
            formattedDate,
            style: GoogleFonts.lexend(
              fontSize: 12,
              color: AppColors.brown,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.toEmail.isEmpty
                  ? 'Destinatario desconocido'
                  : entry.toEmail,
              style: AppTextStyles.itemSubtitle,
            ),
            if (!entry.success && (entry.error?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 4),
              Text(
                entry.error!,
                style: GoogleFonts.lexend(
                  fontSize: 11,
                  color: const Color(0xFFC9302C),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final dd = local.day.toString().padLeft(2, '0');
    final mon = months[local.month - 1];
    final yyyy = local.year.toString();
    final rawHour = local.hour;
    final hour = rawHour == 0
        ? 12
        : rawHour > 12
            ? rawHour - 12
            : rawHour;
    final min = local.minute.toString().padLeft(2, '0');
    final ampm = rawHour >= 12 ? 'PM' : 'AM';
    return '$dd $mon $yyyy · $hour:$min $ampm';
  }
}

class _EmptyHistoryState extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _EmptyHistoryState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.history_toggle_off_rounded,
                      size: 56,
                      color: AppColors.brown,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Aún no hay alertas registradas',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.itemTitle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cuando el sensor de movimiento dispare una alerta, '
                      'verás el registro aquí.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.itemSubtitle,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
