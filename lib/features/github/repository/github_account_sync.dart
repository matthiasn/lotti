import 'package:lotti/features/github/repository/github_token_storage.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/model/sync_secret.dart';

/// Carries the user's GitHub account between their devices on the sync
/// channel inference keys use: end-to-end encrypted, applied into the
/// receiver's keychain, the latest version winning.
///
/// A change made here is owed until the outbox has taken its row
/// ([flushOwed]); a refused row leaves it owed, and it is sent again at the
/// next start or the next change (`RetryOwed` in
/// `specs/tla/GitHubAccountSync.tla`), so no change is lost to a transient
/// outbox failure.
class GitHubAccountSync {
  GitHubAccountSync({
    required this._storage,
    required this._enqueueOrThrow,
    this._rescan,
  });

  final GitHubTokenStorage _storage;

  /// The outbox's failure-reporting enqueue: it throws when no row was
  /// created, rather than logging and swallowing it.
  final Future<void> Function(SyncMessage message) _enqueueOrThrow;
  final Future<void> Function()? _rescan;

  /// Sends the held version if a change made here still owes it; returns
  /// whether nothing is owed any more. A failure leaves it owed.
  Future<bool> flushOwed() async {
    final record = await _storage.read();
    if (record == null || !record.owed) return true;
    try {
      await _enqueueOrThrow(_message(record));
    } on Exception {
      return false;
    }
    await _storage.markSent(record);
    return true;
  }

  /// Sends the held token again with its own stamp, so sending the same
  /// version twice changes nothing on the other devices; returns whether the
  /// outbox took it, or null when there is no token to send.
  Future<bool?> resend() async {
    final record = await _storage.read();
    if (record == null || !record.connected) return null;
    try {
      await _enqueueOrThrow(_message(record));
      return true;
    } on Exception {
      return false;
    }
  }

  /// Whether this world syncs at all; a guest world has nothing to ask.
  bool get canCheckOtherDevices => _rescan != null;

  /// Asks sync to catch up now, so an account another device sent arrives;
  /// what arrives is announced on its own.
  Future<void> checkOtherDevices() async => _rescan?.call();

  /// The device-local [GitHubAccountRecord.verified] and
  /// [GitHubAccountRecord.owed] stay here.
  static SyncMessage _message(GitHubAccountRecord record) =>
      SyncMessage.gitHubAccount(
        updatedAt: record.updatedAt,
        status: SyncEntryStatus.update,
        token: record.token == null ? null : SyncSecret(record.token!),
        login: record.login,
      );
}
