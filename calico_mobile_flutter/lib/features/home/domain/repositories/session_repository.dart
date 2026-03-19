import '../../data/models/session_model.dart';

abstract class SessionRepository {
  /// Returns tutoring sessions for the given student UID.
  Future<List<SessionModel>> getStudentSessions(String studentId);
}
