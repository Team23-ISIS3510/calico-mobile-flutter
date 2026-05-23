import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Singleton façade over the local SQLite cache.
///
/// Holds the tables that back the selective offline-cache strategy for the
/// home feature: upcoming sessions per student, and the go-to tutor per
/// (student, course) pair. The "Top Rated & Available Soon" carousel lives
/// in a separate Hive box — see [AvailableTutorsHiveCache].
///
/// In-memory L1 LRU + TTL for the HTTP payloads that feed these rows lives in
/// [SessionRepositoryImpl] and [AnalyticsRepositoryImpl] — see
/// [HomeRemoteMemoryCachePolicy]; this database remains the L2 offline layer.
class AppDatabaseService {
  AppDatabaseService._();

  static final AppDatabaseService instance = AppDatabaseService._();

  static const String _dbFileName = 'calico_cache.db';
  // v2: the cached_available_tutors table moved to a Hive box. The migration
  // in _onUpgrade drops it on existing installs.
  // v3: added remote-first L2 caches for the full course catalog (single row)
  // and the full per-student session history (used by the Courses screen +
  // BQ6 recency computation).
  static const int _dbVersion = 3;

  static const String tableUpcomingSessions = 'cache_upcoming_sessions';
  static const String tableGoToTutor = 'cached_go_to_tutor';
  static const String tableCoursesCatalog = 'cache_courses_catalog';
  static const String tableStudentSessionsFull = 'cache_student_sessions_full';

  Database? _db;
  Completer<Database>? _opening;

  Future<Database> openDB() async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;

    final pending = _opening;
    if (pending != null) return pending.future;

    final completer = Completer<Database>();
    _opening = completer;
    try {
      final dir = await getDatabasesPath();
      final path = p.join(dir, _dbFileName);
      final db = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      _db = db;
      completer.complete(db);
      return db;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      _opening = null;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableUpcomingSessions (
        student_id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        last_updated INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableGoToTutor (
        student_id TEXT NOT NULL,
        course_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        last_updated INTEGER NOT NULL,
        PRIMARY KEY (student_id, course_id)
      )
    ''');
    await _createCoursesCatalog(db);
    await _createStudentSessionsFull(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 kept the tutor carousel in SQLite; v2 moved it to Hive.
      await db.execute('DROP TABLE IF EXISTS cached_available_tutors');
    }
    if (oldVersion < 3) {
      await _createCoursesCatalog(db);
      await _createStudentSessionsFull(db);
    }
  }

  // ── v3 schema ─────────────────────────────────────────────────────────────

  // Catalog is shared across students, so a single fixed-key row is enough.
  // The 'id' column is reserved for that key (e.g. 'all'); future variants
  // (filtered catalogs, per-faculty subsets) could reuse the same table.
  Future<void> _createCoursesCatalog(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCoursesCatalog (
        id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        last_updated INTEGER NOT NULL
      )
    ''');
  }

  // Holds the FULL student session list (past + upcoming), feeding BQ6 and
  // any other recency analytics. Kept separate from [tableUpcomingSessions]
  // which only stores the filtered upcoming subset for Home.
  Future<void> _createStudentSessionsFull(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableStudentSessionsFull (
        student_id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        last_updated INTEGER NOT NULL
      )
    ''');
  }

  Future<void> upsert(String table, Map<String, Object?> values) async {
    final db = await openDB();
    await db.insert(
      table,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> queryOne(
    String table, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final db = await openDB();
    final rows = await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> clearTable(String table) async {
    final db = await openDB();
    return db.delete(table);
  }

  Future<void> clearAll() async {
    final db = await openDB();
    final batch = db.batch();
    batch.delete(tableUpcomingSessions);
    batch.delete(tableGoToTutor);
    batch.delete(tableCoursesCatalog);
    batch.delete(tableStudentSessionsFull);
    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
