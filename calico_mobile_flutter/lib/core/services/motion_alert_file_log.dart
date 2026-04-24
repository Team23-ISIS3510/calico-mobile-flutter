import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persistent JSONL log for motion-alert send attempts.
///
/// Each attempt (successful or not) is appended as a single JSON line to
/// `<appDocuments>/alerts/alert_history.jsonl`. The append-only format lets
/// the history screen read the file in reverse without rewriting previous
/// entries.
class MotionAlertFileLog {
  MotionAlertFileLog({String directoryName = 'alerts', String fileName = 'alert_history.jsonl'})
      : _directoryName = directoryName,
        _fileName = fileName;

  static final MotionAlertFileLog instance = MotionAlertFileLog();

  final String _directoryName;
  final String _fileName;

  /// Resolves the absolute path to the log file, creating its parent directory
  /// on demand. Visible-for-testing / used by [readAlertEvents].
  Future<File> resolveLogFile() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final alertsDir = Directory(p.join(baseDir.path, _directoryName));
    if (!await alertsDir.exists()) {
      await alertsDir.create(recursive: true);
    }
    return File(p.join(alertsDir.path, _fileName));
  }

  /// Appends one event to the log. Swallows all I/O failures so logging can
  /// never break the alert flow. Returns `true` on success.
  Future<bool> appendAlertEvent({
    required String reason,
    required String toEmail,
    required String location,
    required bool success,
    String? error,
    DateTime? timestamp,
  }) async {
    try {
      final file = await resolveLogFile();
      final payload = <String, Object?>{
        'timestamp': (timestamp ?? DateTime.now()).toUtc().toIso8601String(),
        'reason': reason,
        'toEmail': toEmail,
        'location': location,
        'success': success,
        'error': error,
      };
      final line = '${jsonEncode(payload)}\n';
      await file.writeAsString(
        line,
        mode: FileMode.append,
        flush: true,
      );
      return true;
    } catch (_) {
      // Logging is best-effort; never surface I/O errors to the caller.
      return false;
    }
  }

  /// Reads every logged event, newest first. Returns an empty list if the
  /// file does not exist yet or if it cannot be parsed.
  Future<List<AlertLogEntry>> readAlertEvents() async {
    try {
      final file = await resolveLogFile();
      if (!await file.exists()) return const <AlertLogEntry>[];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return const <AlertLogEntry>[];

      final lines = const LineSplitter().convert(content);
      final entries = <AlertLogEntry>[];
      for (var i = lines.length - 1; i >= 0; i--) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final entry = AlertLogEntry.tryParse(line);
        if (entry != null) entries.add(entry);
      }
      return entries;
    } catch (_) {
      return const <AlertLogEntry>[];
    }
  }

  /// Deletes the log file. Best-effort.
  Future<void> clear() async {
    try {
      final file = await resolveLogFile();
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Ignore — file may already be missing.
    }
  }
}

class AlertLogEntry {
  const AlertLogEntry({
    required this.timestamp,
    required this.reason,
    required this.toEmail,
    required this.location,
    required this.success,
    this.error,
  });

  final DateTime timestamp;
  final String reason;
  final String toEmail;
  final String location;
  final bool success;
  final String? error;

  static AlertLogEntry? tryParse(String line) {
    try {
      final map = jsonDecode(line);
      if (map is! Map<String, dynamic>) return null;
      final rawTs = map['timestamp']?.toString() ?? '';
      final ts = DateTime.tryParse(rawTs)?.toLocal();
      if (ts == null) return null;
      return AlertLogEntry(
        timestamp: ts,
        reason: map['reason']?.toString() ?? '',
        toEmail: map['toEmail']?.toString() ?? '',
        location: map['location']?.toString() ?? '',
        success: map['success'] == true,
        error: map['error']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}
