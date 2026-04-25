import '../entities/session_entity.dart';

abstract class SessionRepository {
  Future<List<SessionEntity>> getStudentSessions(String studentId);
}
