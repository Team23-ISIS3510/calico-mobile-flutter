import 'package:calico_mobile_flutter/features/home/domain/entities/session_entity.dart';
import 'package:calico_mobile_flutter/features/home/domain/entities/tutor_entity.dart';
import 'package:calico_mobile_flutter/features/home/domain/services/booking_availability_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final tutor = TutorEntity(
    id: 'tutor-1',
    name: 'Ana',
    rating: 4.8,
    location: 'Virtual',
    nextSlotStart: DateTime.now().add(const Duration(hours: 1)),
    nextSlotEnd: DateTime.now().add(const Duration(hours: 2)),
    availableSlotsCount: 1,
  );

  final pending = SessionEntity(
    id: 'pending_1',
    tutorId: 'tutor-1',
    studentId: 'student-1',
    startDateTime: DateTime.now().add(const Duration(hours: 1)),
    courseId: 'course-1',
    status: 'pending_local',
  );

  group('BookingAvailabilityService', () {
    test('detects conflict with pending session for same tutor and course', () {
      expect(
        BookingAvailabilityService.conflictsWithStudentSessions(
          tutor,
          [pending],
          'course-1',
        ),
        isTrue,
      );
    });

    test('filters booked tutor out of carousel list', () {
      final filtered = BookingAvailabilityService.filterBookableTutors(
        [tutor],
        [pending],
        'course-1',
      );
      expect(filtered, isEmpty);
    });

    test('hides expired slots from bookable list', () {
      final stale = TutorEntity(
        id: 'tutor-2',
        name: 'Luis',
        rating: 4.5,
        location: 'Virtual',
        nextSlotStart: DateTime.now().subtract(const Duration(hours: 2)),
        availableSlotsCount: 1,
      );
      final filtered = BookingAvailabilityService.filterBookableTutors(
        [stale],
        const [],
        'course-1',
      );
      expect(filtered, isEmpty);
    });
  });
}
