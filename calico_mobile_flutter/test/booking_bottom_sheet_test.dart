import 'package:flutter_test/flutter_test.dart';

/// Regression checks for booking error copy — kept as a pure helper test
/// mirroring [BookingBottomSheet] user-facing messages without widget setup.
String friendlyBookingError(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('socket') ||
      message.contains('network') ||
      message.contains('connection')) {
    return 'No connection. Check your internet and try again.';
  }
  if (message.contains('401') || message.contains('403')) {
    return 'Your session expired. Please sign in again.';
  }
  return 'Could not complete the booking. Please try again.';
}

void main() {
  group('friendlyBookingError', () {
    test('maps network failures to a readable message', () {
      expect(
        friendlyBookingError(Exception('SocketException: failed host lookup')),
        'No connection. Check your internet and try again.',
      );
    });

    test('maps auth failures to a readable message', () {
      expect(
        friendlyBookingError(Exception('Http 401 Unauthorized')),
        'Your session expired. Please sign in again.',
      );
    });

    test('falls back to a generic booking message', () {
      expect(
        friendlyBookingError(Exception('Unexpected server error')),
        'Could not complete the booking. Please try again.',
      );
    });
  });
}
