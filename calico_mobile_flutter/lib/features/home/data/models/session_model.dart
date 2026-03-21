class SessionModel {
  final String id;
  final String tutorId;
  final String studentId;
  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final String? courseId;
  final String? courseName;
  final String? tutorName;
  final String? tutorEmail;
  final String status;

  const SessionModel({
    required this.id,
    required this.tutorId,
    required this.studentId,
    this.startDateTime,
    this.endDateTime,
    this.courseId,
    this.courseName,
    this.tutorName,
    this.tutorEmail,
    required this.status,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id']?.toString() ?? '',
      tutorId: json['tutorId']?.toString() ?? '',
      studentId: json['studentId']?.toString() ?? '',
      startDateTime: _parseDate(
        json['startDateTime'] ?? json['start'] ?? json['scheduledStart'],
      ),
      endDateTime: _parseDate(
        json['endDateTime'] ?? json['end'] ?? json['scheduledEnd'],
      ),
      courseId: json['courseId']?.toString() ?? json['course']?.toString(),
      courseName: json['courseName']?.toString(),
      tutorName: json['tutorName']?.toString(),
      tutorEmail: json['tutorEmail']?.toString(),
      status: json['status']?.toString() ?? 'pending',
    );
  }

  String get formattedDate {
    if (startDateTime == null) return 'Date TBD';
    final d = startDateTime!;
    final rawHour = d.hour;
    final hour = rawHour == 0
        ? 12
        : rawHour > 12
        ? rawHour - 12
        : rawHour;
    final ampm = rawHour >= 12 ? 'PM' : 'AM';
    final min = d.minute.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$mm/$dd/${d.year} · $hour:$min $ampm';
  }

  String get displayTutor {
    final hasName = tutorName != null && tutorName!.isNotEmpty;
    final hasEmail = tutorEmail != null && tutorEmail!.isNotEmpty;

    if (hasName && hasEmail) {
      return 'Tutor: $tutorName, $tutorEmail';
    }
    if (hasName) {
      return 'Tutor: $tutorName';
    }
    if (hasEmail) {
      return 'Tutor: $tutorEmail';
    }
    return 'Tutor: $tutorId';
  }

  String get displayCourse => courseName != null && courseName!.isNotEmpty
      ? courseName!
      : (courseId ?? '');

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final parsed = DateTime.tryParse(value);
      return parsed?.toLocal();
    }

    if (value is Map) {
      final seconds = value['_seconds'] ?? value['seconds'];
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          (seconds as num).toInt() * 1000,
        ).toLocal();
      }
    }

    return null;
  }
}
