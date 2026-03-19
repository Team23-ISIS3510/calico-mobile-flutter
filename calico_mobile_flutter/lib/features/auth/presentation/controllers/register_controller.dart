import 'package:flutter/foundation.dart';
import '../../domain/models/register_request.dart';
import '../../domain/repositories/auth_repository.dart';

enum RegisterStatus { idle, loading, success, failure }

/// Holds all registration state and exposes a single [register] command.
/// After a successful registration [userId] holds the Firebase UID so the
/// screen can navigate to HomeScreen with the correct student ID.
class RegisterController extends ChangeNotifier {
  final AuthRepository _repository;

  RegisterController(this._repository);

  RegisterStatus _status = RegisterStatus.idle;
  String? _errorMessage;
  String? _userId;

  RegisterStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get userId => _userId;
  bool get isLoading => _status == RegisterStatus.loading;

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _update(RegisterStatus.loading, error: null);

    try {
      _userId = await _repository.register(
        RegisterRequest(name: name, email: email, password: password),
      );
      _update(RegisterStatus.success);
    } on Exception catch (e) {
      _update(RegisterStatus.failure, error: e.toString());
    }
  }

  void reset() => _update(RegisterStatus.idle, error: null);

  void _update(RegisterStatus status, {String? error}) {
    _status = status;
    _errorMessage = error;
    notifyListeners();
  }
}
