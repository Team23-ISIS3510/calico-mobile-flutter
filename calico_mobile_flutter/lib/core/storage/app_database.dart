import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Singleton façade over the local SQLite cache.
///
/// Holds three tables that back the selective offline-cache strategy for the
/// home feature: upcoming sessions per student, available tutors per course,
/// and the go-to tutor per (student, course) pair.
class AppDatabaseService {
  AppDatabaseService._();

  static final AppDatabaseService instance = AppDatabaseService._();

  static const String _dbFileName = 'calico_cache.db';
  static const int _dbVersion = 1;

  static const String tableUpcomingSessions = 'cache_upcoming_sessions';
  static const String tableAvailableTutors = 'cached_available_tutors';
  static const String tableGoToTutor = 'cached_go_to_tutor';

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
      CREATE TABLE $tableAvailableTutors (
        course_id TEXT PRIMARY KEY,
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // No migrations yet — schema is v1.
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
    batch.delete(tableAvailableTutors);
    batch.delete(tableGoToTutor);
    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
