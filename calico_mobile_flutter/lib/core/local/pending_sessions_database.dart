import 'package:drift/drift.dart';

import 'pending_sessions_connection_native.dart';

part 'pending_sessions_database.g.dart';

// ─── Table definition ────────────────────────────────────────────────────────

/// Each row is a session booking queued while the device was offline.
/// The row is kept (synced = true) so the UI can show "confirmed" state;
/// the SyncService marks synced after a successful POST /tutoring-sessions.
class PendingSessions extends Table {
  /// Auto-increment primary key — used to update individual rows after sync.
  IntColumn get id => integer().autoIncrement()();

  TextColumn get tutorId => text()();
  TextColumn get studentId => text()();
  TextColumn get courseId => text()();

  /// ISO-8601 strings — stored as text to avoid timezone drift issues.
  TextColumn get scheduledStart => text()();
  TextColumn get scheduledEnd => text()();

  TextColumn get location => text()();
  TextColumn get bookingSource => text()();

  DateTimeColumn get createdAt => dateTime()();

  /// false = waiting for sync; true = successfully POSTed to the server.
  BoolColumn get synced =>
      boolean().withDefault(const Constant(false))();

  // Denormalised fields kept for the POST body — avoids a join at sync time.
  TextColumn get tutorName => text().nullable()();
  TextColumn get parentAvailabilityId => text().nullable()();
  IntColumn get nextSlotIndex => integer().nullable()();
}

// ─── Database ────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [PendingSessions])
class PendingSessionsDatabase extends _$PendingSessionsDatabase {
  // Singleton so every feature shares one open file handle.
  PendingSessionsDatabase._() : super(createConnection());

  static final PendingSessionsDatabase _instance =
      PendingSessionsDatabase._();

  static PendingSessionsDatabase get instance => _instance;

  @override
  int get schemaVersion => 1;

  // ── Convenience query helpers ───────────────────────────────────────────

  /// Returns all rows where synced = false for [studentId].
  Future<List<PendingSession>> getUnsynced(String studentId) {
    return (select(pendingSessions)
          ..where(
            (t) => t.studentId.equals(studentId) & t.synced.equals(false),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Marks a single row as synced after a successful server POST.
  Future<void> markSynced(int id) {
    return (update(pendingSessions)..where((t) => t.id.equals(id)))
        .write(const PendingSessionsCompanion(synced: Value(true)));
  }
}
