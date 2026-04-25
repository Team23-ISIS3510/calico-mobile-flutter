class SessionEntity {
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

  const SessionEntity({
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

    if (hasName && hasEmail) return 'Tutor: $tutorName, $tutorEmail';
    if (hasName) return 'Tutor: $tutorName';
    if (hasEmail) return 'Tutor: $tutorEmail';
    return 'Tutor: $tutorId';
  }

  String get displayCourse =>
      courseName != null && courseName!.isNotEmpty ? courseName! : (courseId ?? '');
}
