import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/client.dart';
import '../api/types.dart';

/// Holds the signed-in operator for the app session.
///
/// Same singleton shape as [CopilotController] — one instance for the whole
/// app, because identity is not a property of any one screen.
///
/// The token goes in [FlutterSecureStorage] (Android Keystore / iOS Keychain),
/// not SharedPreferences: it is a bearer credential, and anything that can read
/// it can act as this user until it expires.
class AuthController extends ChangeNotifier {
  AuthController._() {
    // A 401 from anywhere in the app lands here, so an expired session drops
    // the user to the login screen instead of silently emptying their inbox.
    api.onUnauthorized = () => signOut(expired: true);
  }

  static final AuthController instance = AuthController._();

  static const _storageKey = 'grid_advisor_session';
  static const _storage = FlutterSecureStorage();

  AuthSession? _session;
  bool _isRestoring = true;
  bool _isSigningIn = false;
  String? _error;

  AuthSession? get session => _session;

  bool get isSignedIn => _session != null;

  bool get isAdmin => _session?.isAdmin ?? false;

  /// True until the stored session has been read back on launch. The router
  /// waits on this so a returning user is not flashed the login screen.
  bool get isRestoring => _isRestoring;

  bool get isSigningIn => _isSigningIn;

  String? get error => _error;

  /// Reads any previously stored session. Called once at startup.
  Future<void> restore() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null) {
        final session = AuthSession.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        _session = session;
        api.authToken = session.accessToken;
      }
    } catch (_) {
      // Corrupt or unreadable storage is not worth a crash on launch — the
      // user simply signs in again.
      await _storage.delete(key: _storageKey);
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) async {
    if (_isSigningIn) return false;
    _isSigningIn = true;
    _error = null;
    notifyListeners();

    try {
      final session = await api.login(email.trim(), password);
      _session = session;
      api.authToken = session.accessToken;
      await _storage.write(key: _storageKey, value: jsonEncode(session.toJson()));
      return true;
    } catch (err) {
      _error = err is ApiError ? err.message : 'Could not sign in.';
      return false;
    } finally {
      _isSigningIn = false;
      notifyListeners();
    }
  }

  Future<void> signOut({bool expired = false}) async {
    _session = null;
    api.authToken = null;
    _error = expired ? 'Your session expired. Please sign in again.' : null;
    await _storage.delete(key: _storageKey);
    notifyListeners();
  }
}
