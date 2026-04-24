import 'package:connectivity_plus/connectivity_plus.dart';

import '../local/pending_sessions_database.dart';
import '../network/api_client.dart';

/// Reads all unsynced rows from the SQLite pending_sessions table and POSTs
/// each one to the server.  Called every time the connectivity stream reports
/// that the device has come back online.
///
/// WHY A DEDICATED SERVICE?
/// Keeps the sync logic in one place that is reusable from the home screen,
/// a background fetch, or any future entry-point.  The BookingBottomSheet
/// writes rows; this service drains them.  Clear single-responsibility split.
class SyncService {
  final ApiClient _apiClient;

  const SyncService(this._apiClient);

  /// Syncs all pending session bookings for [studentId].
  ///
  /// Bails out immediately if still offline so the method is safe to call
  /// optimistically on every connectivity-restored event.
  ///
  /// Each row is POST-ed individually; on success it is marked synced = true.
  /// Failures are swallowed per-row so one bad booking doesn't block the rest.
  Future<void> syncPendingSessions(String studentId) async {
    // Guard: re-check connectivity before hitting the network.
    final results = await Connectivity().checkConnectivity();
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (!isOnline) return;

    final db = PendingSessionsDatabase.instance;
    final pending = await db.getUnsynced(studentId);

    for (final row in pending) {
      try {
        await _apiClient.post('/tutoring-sessions', body: {
          'tutorId': row.tutorId,
          'studentId': row.studentId,
          'courseId': row.courseId,
          'scheduledStart': row.scheduledStart,
          'scheduledEnd': row.scheduledEnd,
          'location': row.location,
          'requiresApproval': false,
          'bookingSource': row.bookingSource,
          if (row.tutorName != null) 'tutorName': row.tutorName,
          if (row.parentAvailabilityId != null)
            'parentAvailabilityId': row.parentAvailabilityId,
          if (row.nextSlotIndex != null) 'slotIndex': row.nextSlotIndex,
        });
        // Mark synced so the home screen stops showing the ⏳ badge for it.
        await db.markSynced(row.id);
      } catch (_) {
        // Leave row as unsynced — will retry on the next connectivity event.
      }
    }
  }
}
