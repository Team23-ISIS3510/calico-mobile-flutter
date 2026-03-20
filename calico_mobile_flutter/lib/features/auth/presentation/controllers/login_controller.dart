import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/models/login_request.dart';
import '../../domain/repositories/auth_repository.dart';

enum LoginStatus { idle, loading, success, failure }

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

  Future<void> login({required String email, required String password}) async {
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

  Future<void> loginWithGoogle() async {
    _update(LoginStatus.loading, error: null);
    try {
      // 1. Trigger Google Sign In
      final googleUser = await GoogleSignIn(
        clientId:
            '1056254794426-rb68e1oa14lprk55b2f7lpprvfp4ohj7.apps.googleusercontent.com',
      ).signIn();
      if (googleUser == null) {
        // User cancelled
        _update(LoginStatus.idle, error: null);
        return;
      }

      // 2. Get auth details from Google
      final googleAuth = await googleUser.authentication;

      // 3. Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      // 5. Get the idToken to send to backend
      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null) throw Exception('Could not get idToken');

      // 6. Send to backend
      _userId = await _repository.loginWithGoogle(idToken);
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
