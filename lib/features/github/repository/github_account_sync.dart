import 'package:lotti/features/github/repository/github_token_storage.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/model/sync_secret.dart';

/// Carries the user's GitHub account between their devices on the sync
/// channel inference keys use: end-to-end encrypted, applied into the
/// receiver's keychain, the latest version winning.
class GitHubAccountSync {
  GitHubAccountSync({
    required this._enqueue,
    this._rescan,
  });

  final Future<void> Function(SyncMessage message) _enqueue;
  final Future<void> Function()? _rescan;

  /// Sends [record] — a token, or a disconnection — to the other devices,
  /// with its own stamp, so sending the same version again changes nothing
  /// there. The device-local [GitHubAccountRecord.verified] stays here.
  Future<void> publish(GitHubAccountRecord record) => _enqueue(
    SyncMessage.gitHubAccount(
      updatedAt: record.updatedAt,
      status: SyncEntryStatus.update,
      token: record.token == null ? null : SyncSecret(record.token!),
      login: record.login,
    ),
  );

  /// Whether this world syncs at all; a guest world has nothing to ask.
  bool get canCheckOtherDevices => _rescan != null;

  /// Asks sync to catch up now, so an account another device sent arrives;
  /// what arrives is announced on its own.
  Future<void> checkOtherDevices() async => _rescan?.call();
}
