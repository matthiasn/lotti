import 'package:lotti/features/sync/secure_storage.dart';

/// The user's GitHub token, and the login it belongs to, in the device
/// keystore.
///
/// Keys are namespaced by profile, so a demo or guest world never reads the
/// real one. Nothing here is synced, logged or exported: the token leaves
/// the device only as the `Authorization` header of a request to
/// `api.github.com`.
class GitHubTokenStorage {
  GitHubTokenStorage(this._storage, {required String namespace})
    : _tokenKey = 'github_token:$namespace',
      _loginKey = 'github_login:$namespace';

  final SecureStorage _storage;
  final String _tokenKey;
  final String _loginKey;

  Future<String?> readToken() async => await _storage.read(key: _tokenKey);

  /// The login the stored token was checked against when it was saved.
  Future<String?> readLogin() async => await _storage.read(key: _loginKey);

  Future<void> save({required String token, required String login}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _loginKey, value: login);
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _loginKey);
  }
}
