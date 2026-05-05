import 'package:flutter/foundation.dart';

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
  /// Returns a [SyncResult] with the number of rows successfully synced and
  /// a list of error messages for rows that failed.  Callers are responsible
  /// for verifying connectivity before calling.
  ///
  /// Rows are POSTed individually so one failure doesn't block the rest.
  Future<SyncResult> syncPendingSessions(String studentId) async {
    final db = PendingSessionsDatabase.instance;
    final pending = await db.getUnsynced(studentId);

    debugPrint('[SyncService] ${pending.length} pending row(s) for studentId=$studentId');

    int synced = 0;
    final errors = <String>[];

    for (final row in pending) {
      debugPrint(
        '[SyncService] Posting row id=${row.id} '
        'tutorId=${row.tutorId} courseId=${row.courseId} '
        'start=${row.scheduledStart}',
      );
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
        await db.markSynced(row.id);
        synced++;
        debugPrint('[SyncService] Row ${row.id} → synced OK');
      } catch (e) {
        debugPrint('[SyncService] Row ${row.id} → FAILED: $e');
        errors.add(e.toString());
      }
    }

    debugPrint('[SyncService] Done: synced=$synced errors=${errors.length}');
    return SyncResult(synced: synced, errors: errors);
  }
}

class SyncResult {
  final int synced;
  final List<String> errors;

  const SyncResult({required this.synced, required this.errors});

  bool get hasErrors => errors.isNotEmpty;
  bool get allSucceeded => errors.isEmpty && synced > 0;
}
