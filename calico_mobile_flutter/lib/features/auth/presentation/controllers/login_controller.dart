import 'package:flutter/foundation.dart';
import '../../domain/models/login_request.dart';
import '../../domain/repositories/auth_repository.dart';

enum LoginStatus { idle, loading, success, failure }

/// Holds all login state and exposes a single [login] command.
/// After a successful login [userId] holds the Firebase UID so the
/// screen can navigate to HomeScreen with the correct student ID.
class LoginController extends ChangeNotifier {
  final AuthRepository _repository;

  LoginController(this._repository);

  LoginStatus _status = LoginStatus.idle;
  String? _errorMessage;
  String? _userId;

  LoginStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get userId => _userId;
  bool get isLoading => _status == LoginStatus.loading;

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _update(LoginStatus.loading, error: null);

    try {
      _userId = await _repository.login(
        LoginRequest(email: email, password: password),
      );
      _update(LoginStatus.success);
    } on Exception catch (e) {
      _update(LoginStatus.failure, error: e.toString());
    }
  }

  void reset() => _update(LoginStatus.idle, error: null);

  void _update(LoginStatus status, {String? error}) {
    _status = status;
    _errorMessage = error;
    notifyListeners();
  }
}