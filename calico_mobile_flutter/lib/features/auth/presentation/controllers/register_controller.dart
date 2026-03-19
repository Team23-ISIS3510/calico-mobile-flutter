import 'package:flutter/foundation.dart';
import '../../domain/models/register_request.dart';
import '../../domain/repositories/auth_repository.dart';

enum RegisterStatus { idle, loading, success, failure }

/// Holds all registration state and exposes a single [register] command.
/// Extends [ChangeNotifier] so the screen rebuilds only when this calls
/// [notifyListeners] — no rebuilds from unrelated state changes.
class RegisterController extends ChangeNotifier {
  final AuthRepository _repository;

  RegisterController(this._repository);

  RegisterStatus _status = RegisterStatus.idle;
  String? _errorMessage;

  RegisterStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == RegisterStatus.loading;

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _update(RegisterStatus.loading, error: null);

    try {
      await _repository.register(
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
