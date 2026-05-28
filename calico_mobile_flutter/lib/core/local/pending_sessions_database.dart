// WHY DRIFT (SQLite ORM)?
// SQLite is the right tool for a pending-queue because rows have a lifecycle
// (inserted offline → synced online → optionally deleted). Drift adds:
//   - compile-time type-safe queries via generated code
//   - @DriftDatabase annotation that generates the _$ base class
//   - LazyDatabase so the file is opened on first use, not at startup
//
// TRADE-OFF vs SharedPreferences / Hive:
//   + Relational queries (filter unsynced, update by id)
//   - Requires build_runner code generation step
//   - Heavier than key-value stores; only justified for structured queues
//
// After any change here, run:
//   dart run build_runner build --delete-conflicting-outputs

import 'package:drift/drift.dart';

import 'pending_sessions_connection.dart';

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
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  // Denormalised fields kept for the POST body — avoids a join at sync time.
  TextColumn get tutorName => text().nullable()();
  TextColumn get parentAvailabilityId => text().nullable()();
  IntColumn get nextSlotIndex => integer().nullable()();
}

// ─── Database ────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [PendingSessions])
class PendingSessionsDatabase extends _$PendingSessionsDatabase {
  // Singleton so every feature shares one open file handle.
  PendingSessionsDatabase._() : super(openConnection());

  static final PendingSessionsDatabase _instance = PendingSessionsDatabase._();

  static PendingSessionsDatabase get instance => _instance;

  @override
  int get schemaVersion => 1;

  // ── Convenience query helpers ───────────────────────────────────────────

  /// Returns all rows where synced = false for [studentId].
  Future<List<PendingSession>> getUnsynced(String studentId) {
    return (select(pendingSessions)
          ..where((t) => t.studentId.equals(studentId) & t.synced.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Marks a single row as synced after a successful server POST.
  Future<void> markSynced(int id) {
    return (update(pendingSessions)..where((t) => t.id.equals(id))).write(
      const PendingSessionsCompanion(synced: Value(true)),
    );
  }

  /// Deletes a pending session by its local [id].
  /// Used to cancel an offline-queued booking before it syncs.
  Future<int> deleteById(int id) {
    return (delete(pendingSessions)..where((t) => t.id.equals(id))).go();
  }

  /// Prevents duplicate offline queues for the same tutor/course/start time.
  Future<bool> hasDuplicatePending({
    required String studentId,
    required String tutorId,
    required String courseId,
    required String scheduledStart,
  }) async {
    final rows = await getUnsynced(studentId);
    return rows.any(
      (row) =>
          row.tutorId == tutorId &&
          row.courseId == courseId &&
          row.scheduledStart == scheduledStart,
    );
  }
}
