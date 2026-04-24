import 'package:flutter/foundation.dart';
import 'package:calico_mobile_flutter/features/profile/domain/models/user_profile.dart';
import 'package:calico_mobile_flutter/features/profile/domain/repositories/profile_repository.dart';

enum ProfileStatus { idle, loading, success, failure }

class ProfileController extends ChangeNotifier {
  final ProfileRepository _repository;
  final String userId;

  ProfileController(this._repository, this.userId);

  ProfileStatus _status = ProfileStatus.idle;
  String? _errorMessage;
  UserProfile? _profile;
  bool _fromCache = false;

  ProfileStatus get status => _status;
  String? get errorMessage => _errorMessage;
  UserProfile? get profile => _profile;
  bool get isLoading => _status == ProfileStatus.loading;

  /// True when the displayed profile came from the local SharedPreferences
  /// cache rather than a fresh API response.  The UI shows a badge when true.
  bool get fromCache => _fromCache;

  Future<void> loadProfile() async {
    _update(ProfileStatus.loading);
    try {
      _profile = await _repository.getProfile(userId);
      _fromCache = _repository.lastLoadFromCache;
      _update(ProfileStatus.success);
    } on Exception catch (e) {
      _update(ProfileStatus.failure, error: e.toString());
    }
  }

  Future<void> updateProfile({
    String? description,
    List<String>? courses,
  }) async {
    _update(ProfileStatus.loading);
    try {
      _profile = await _repository.updateProfile(
        userId,
        description: description,
        courses: courses,
      );
      _update(ProfileStatus.success);
    } on Exception catch (e) {
      _update(ProfileStatus.failure, error: e.toString());
    }
  }

  void _update(ProfileStatus status, {String? error}) {
    _status = status;
    _errorMessage = error;
    notifyListeners();
  }
}
