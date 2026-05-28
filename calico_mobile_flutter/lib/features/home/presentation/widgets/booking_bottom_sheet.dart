import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/local/pending_sessions_database.dart';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/analytics_repository_impl.dart';
import '../../data/repositories/session_repository_impl.dart';
import '../../domain/entities/tutor_entity.dart';

class BookingBottomSheet extends StatefulWidget {
  final TutorEntity tutor;
  final String studentId;
  final String courseId;
  final String bookingSource;
  final VoidCallback? onBooked;

  const BookingBottomSheet({
    super.key,
    required this.tutor,
    required this.studentId,
    required this.courseId,
    required this.bookingSource,
    this.onBooked,
  });

  @override
  State<BookingBottomSheet> createState() => _BookingBottomSheetState();
}

class _BookingBottomSheetState extends State<BookingBottomSheet> {
  static const Duration _defaultSessionDuration = Duration(hours: 1);
  bool _isLoading = false;
  bool _booked = false;
  // True when the booking was queued in SQLite because the device was offline.
  bool _savedOffline = false;
  String? _error;
  double? _successRate;

  ({DateTime start, DateTime end}) _bookingWindow() {
    final start = widget.tutor.nextSlotStart;
    if (start == null) {
      throw StateError('Selected tutor has no valid start slot');
    }

    // Product rule: bookings from this flow reserve a 1-hour session.
    // If backend analytics sends a wider availability block (e.g. 3h),
    // we only take the first hour to avoid unrealistic accidental bookings.
    final blockEnd = widget.tutor.nextSlotEnd;
    final cappedEnd = start.add(_defaultSessionDuration);
    final end = blockEnd != null && blockEnd.isBefore(cappedEnd)
        ? blockEnd
        : cappedEnd;
    return (start: start, end: end);
  }

  String _formatSlot() {
    final DateTime start;
    final DateTime end;
    try {
      final window = _bookingWindow();
      start = window.start.toLocal();
      end = window.end.toLocal();
    } catch (_) {
      return 'No slot available';
    }

    String fmt(DateTime dt) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $period';
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
      day = '${start.month}/${start.day}/${start.year}';
    }

    return '$day  ${fmt(start)} – ${fmt(end)}';
  }

  String _friendlyBookingError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('socket') ||
        message.contains('network') ||
        message.contains('connection')) {
      return 'No connection. Check your internet and try again.';
    }
    if (message.contains('401') || message.contains('403')) {
      return 'Your session expired. Please sign in again.';
    }
    return 'Could not complete the booking. Please try again.';
  }

  Future<void> _bookNow() async {
    if (widget.studentId.trim().isEmpty) {
      setState(() => _error = 'Please sign in to book a tutoring session.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // ── Offline check: queue in SQLite instead of hitting the API ────────
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.any((r) => r != ConnectivityResult.none);

    if (!isOnline) {
      await _queueOffline();
      return;
    }

    // ── Online path: POST directly to the server ─────────────────────────
    try {
      final window = _bookingWindow();
      final client = ApiClient();
      await client.post(
        '/tutoring-sessions',
        body: {
          'tutorId': widget.tutor.id,
          'studentId': widget.studentId,
          'courseId': widget.courseId,
          'scheduledStart': window.start.toIso8601String(),
          'scheduledEnd': window.end.toIso8601String(),
          'location': widget.tutor.location,
          'requiresApproval': false,
          'bookingSource': widget.bookingSource,
          'tutorName': widget.tutor.name,
          if (widget.tutor.parentAvailabilityId != null)
            'parentAvailabilityId': widget.tutor.parentAvailabilityId,
          if (widget.tutor.nextSlotIndex != null)
            'slotIndex': widget.tutor.nextSlotIndex,
        },
      );
      await _notifyBookingCompleted();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _booked = true;
      });
      // Fetch the global instant booking success rate to show in the confirmation.
      // Fire-and-forget: never block or fail the booking on this.
      client.get('/analytics/booking-success').then((data) {
        final rate = (data['successRate'] as num?)?.toDouble();
        if (mounted && rate != null) setState(() => _successRate = rate);
      }).catchError((_) {});
    } catch (e) {
      // ── Fallback: if POST failed due to network, save offline ──────────
      // The connectivity check may have returned "online" but the actual
      // request failed (unstable wifi, server unreachable, timeout).
      // Instead of losing the booking intent, persist to SQLite so
      // SyncService retries when connectivity is truly restored.
      if (_isNetworkRelatedError(e)) {
        await _queueOffline();
        return;
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _friendlyBookingError(e);
      });
    }
  }

  Future<void> _notifyBookingCompleted() async {
    final studentId = widget.studentId.trim();
    SessionRepositoryImpl.invalidate(studentId);
    await AnalyticsRepositoryImpl.invalidateTutorsForCourse(
      widget.courseId,
      studentId: studentId,
    );
    widget.onBooked?.call();
  }

  /// Persists the booking to the local SQLite pending_sessions table.
  /// On success sets [_savedOffline] = true so the UI shows the queued state.
  Future<void> _queueOffline() async {
    try {
      // If the tutor has no slot info, default to "now + 1 hour" so the
      // booking can still be queued and reconciled when online.
      late final ({DateTime start, DateTime end}) window;
      if (widget.tutor.nextSlotStart != null) {
        window = _bookingWindow();
      } else {
        final now = DateTime.now();
        window = (start: now, end: now.add(_defaultSessionDuration));
      }

      final db = PendingSessionsDatabase.instance;
      final startIso = window.start.toIso8601String();
      final isDuplicate = await db.hasDuplicatePending(
        studentId: widget.studentId,
        tutorId: widget.tutor.id,
        courseId: widget.courseId,
        scheduledStart: startIso,
      );
      if (isDuplicate) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error =
              'You already queued this session. Check Pending Sync on Home.';
        });
        return;
      }

      await db.into(db.pendingSessions).insert(
            PendingSessionsCompanion.insert(
              tutorId: widget.tutor.id,
              studentId: widget.studentId,
              courseId: widget.courseId,
              scheduledStart: startIso,
              scheduledEnd: window.end.toIso8601String(),
              location: widget.tutor.location,
              bookingSource: widget.bookingSource,
              createdAt: DateTime.now(),
              tutorName: Value(widget.tutor.name),
              parentAvailabilityId: Value(widget.tutor.parentAvailabilityId),
              nextSlotIndex: Value(widget.tutor.nextSlotIndex),
            ),
          );

      await _notifyBookingCompleted();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _savedOffline = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not save booking offline. Please try again.';
      });
    }
  }

  void _completeSheetAndPop() {
    Navigator.pop(context, true);
  }

  /// Returns true when the error looks like a connectivity / network issue
  /// rather than a server-side validation error (4xx).
  bool _isNetworkRelatedError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('socket') ||
        msg.contains('network') ||
        msg.contains('connection') ||
        msg.contains('timed out') ||
        msg.contains('timeout') ||
        msg.contains('no internet');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_savedOffline && !_booked,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_savedOffline || _booked) {
          _completeSheetAndPop();
        }
      },
      child: _buildSheet(context),
    );
  }

  Widget _buildSheet(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (_savedOffline) ...[
            const Icon(Icons.schedule, color: Colors.orange, size: 64),
            const SizedBox(height: 12),
            Text(
              'Session saved — will be booked when online',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: 8),
            Text(
              'Your booking with ${widget.tutor.name} has been queued locally '
              'and will be confirmed automatically once you reconnect.',
              textAlign: TextAlign.center,
              style: AppTextStyles.itemSubtitle,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _completeSheetAndPop,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: Text('Done', style: AppTextStyles.buttonLabel),
            ),
          ] else if (_booked) ...[
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 12),
            Text(
              'Booking confirmed!',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: 8),
            Text(
              'Your session with ${widget.tutor.name} has been booked.',
              textAlign: TextAlign.center,
              style: AppTextStyles.itemSubtitle,
            ),
            if (_successRate != null) ...[
              const SizedBox(height: 8),
              Text(
                '${_successRate!.toStringAsFixed(0)}% instant booking success rate',
                textAlign: TextAlign.center,
                style: AppTextStyles.itemSubtitle.copyWith(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _completeSheetAndPop,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: Text('Done', style: AppTextStyles.buttonLabel),
            ),
          ] else ...[
            // Tutor info
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.tutor.name, style: AppTextStyles.itemTitle),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.tutor.rating.toStringAsFixed(1),
                          style: AppTextStyles.itemSubtitle,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.tutor.location,
                          style: AppTextStyles.itemSubtitle,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Slot info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next available slot',
                    style: AppTextStyles.itemSubtitle,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(_formatSlot(), style: AppTextStyles.itemTitle),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Price
            if (widget.tutor.hourlyRate != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Price', style: AppTextStyles.itemSubtitle),
                    Text(
                      '\$${widget.tutor.hourlyRate!.toStringAsFixed(0)} (1h)',
                      style: AppTextStyles.itemTitle,
                    ),
                  ],
                ),
              ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.errorText,
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 16),

            // Book button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _bookNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: const Color(0xFFFCC06C),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.black54,
                        ),
                      )
                    : Text('Book Now', style: AppTextStyles.buttonLabel),
              ),
            ),
          ],
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}
