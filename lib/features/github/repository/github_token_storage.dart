import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:meta/meta.dart';

/// The user's GitHub account on this device: the token, the login it was
/// checked against, when that was last set anywhere, and whether this
/// device has checked it itself.
///
/// The token and login sync to the user's other devices, end-to-end
/// encrypted, like an inference provider's API key; [token] null is a
/// disconnection, which syncs too. [updatedAt] orders the versions: the
/// later one wins, and an equal stamp is decided by content, so every device
/// keeps the same one (`SyncSettings` in `specs/tla/`). [verified] is this
/// device's own: a token that arrived by sync is checked with GitHub before
/// it is shown as connected.
@immutable
class GitHubAccountRecord {
  const GitHubAccountRecord({
    required this.updatedAt,
    this.token,
    this.login,
    this.verified = false,
  });

  factory GitHubAccountRecord.fromJson(Map<String, dynamic> json) =>
      GitHubAccountRecord(
        token: json['token'] as String?,
        login: json['login'] as String?,
        updatedAt: json['updatedAt'] as int,
        verified: json['verified'] == true,
      );

  final String? token;
  final String? login;

  /// Epoch milliseconds of the change, on the device that made it.
  final int updatedAt;
  final bool verified;

  bool get connected => token != null && token!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'token': token,
    'login': login,
    'updatedAt': updatedAt,
    'verified': verified,
  };

  /// Whether this version replaces [other]: a later stamp, or the same stamp
  /// and the greater content, so two devices holding both pick the same.
  bool isNewerThan(GitHubAccountRecord other) {
    if (updatedAt != other.updatedAt) return updatedAt > other.updatedAt;
    return _content.compareTo(other._content) > 0;
  }

  String get _content => '${token ?? ''}\u0000${login ?? ''}';
}

/// [profile]'s storage: the one namespace the settings page, the client and
/// a received account all use.
GitHubTokenStorage gitHubTokenStorageForProfile(
  SecureStorage storage,
  ProfileContext profile,
) => GitHubTokenStorage(storage, namespace: profile.profile.id);

/// The user's GitHub account record ([GitHubAccountRecord]) in the device
/// keystore.
///
/// Namespaced by profile, so a demo or guest world never reads the real one;
/// guest worlds have no sync stack either, so nothing arrives there. The
/// record is one keystore value, written in one step, so the token, its login
/// and its stamp never disagree. Nothing here is logged or exported; the
/// token leaves the device only end-to-end encrypted to the user's own
/// devices, and as the `Authorization` header of a request to
/// `api.github.com`.
class GitHubTokenStorage {
  GitHubTokenStorage(this._storage, {required String namespace})
    : _recordKey = 'github_account:$namespace',
      _legacyTokenKey = 'github_token:$namespace',
      _legacyLoginKey = 'github_login:$namespace';

  final SecureStorage _storage;
  final String _recordKey;
  final String _legacyTokenKey;
  final String _legacyLoginKey;

  /// The record, or null when this device has never held one. A token saved
  /// before the record existed is moved into it once, as verified and stamped
  /// zero, so any version from another device replaces it.
  Future<GitHubAccountRecord?> read() async {
    final stored = await _storage.read(key: _recordKey);
    if (stored != null) {
      return GitHubAccountRecord.fromJson(
        jsonDecode(stored) as Map<String, dynamic>,
      );
    }
    final legacyToken = await _storage.read(key: _legacyTokenKey);
    if (legacyToken == null) return null;
    final migrated = GitHubAccountRecord(
      token: legacyToken,
      login: await _storage.read(key: _legacyLoginKey),
      updatedAt: 0,
      verified: true,
    );
    await _write(migrated);
    await _storage.delete(key: _legacyTokenKey);
    await _storage.delete(key: _legacyLoginKey);
    return migrated;
  }

  Future<String?> readToken() async {
    final record = await read();
    return record != null && record.connected ? record.token : null;
  }

  /// The login the stored token was checked against.
  Future<String?> readLogin() async {
    final record = await read();
    return record != null && record.connected ? record.login : null;
  }

  /// Stores a token the user entered here and GitHub accepted; returns the
  /// record to send to the other devices.
  Future<GitHubAccountRecord> save({
    required String token,
    required String login,
  }) async {
    final record = GitHubAccountRecord(
      token: token,
      login: login,
      updatedAt: await _nextStamp(),
      verified: true,
    );
    await _write(record);
    return record;
  }

  /// Forgets the token here; returns the disconnection to send to the other
  /// devices, so it is forgotten there too.
  Future<GitHubAccountRecord> clear() async {
    final record = GitHubAccountRecord(updatedAt: await _nextStamp());
    await _write(record);
    return record;
  }

  /// Stores [incoming], received from another device, if it is newer than
  /// what is held; returns whether it was. It is not verified here yet.
  Future<bool> applyIfNewer(GitHubAccountRecord incoming) async {
    final held = await read();
    if (held != null && !incoming.isNewerThan(held)) return false;
    await _write(
      GitHubAccountRecord(
        token: incoming.token,
        login: incoming.login,
        updatedAt: incoming.updatedAt,
      ),
    );
    return true;
  }

  /// Records that GitHub accepted the held token as [login]'s.
  Future<void> markVerified(String login) async {
    final held = await read();
    if (held == null || !held.connected) return;
    await _write(
      GitHubAccountRecord(
        token: held.token,
        login: login,
        updatedAt: held.updatedAt,
        verified: true,
      ),
    );
  }

  /// Now, or just after the held stamp if this device's clock is behind it,
  /// so a change made here always replaces the version it was made over.
  Future<int> _nextStamp() async {
    final now = clock.now().millisecondsSinceEpoch;
    final held = (await read())?.updatedAt ?? 0;
    return now > held ? now : held + 1;
  }

  Future<void> _write(GitHubAccountRecord record) =>
      _storage.write(key: _recordKey, value: jsonEncode(record.toJson()));
}
