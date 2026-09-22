import 'dart:io';

import 'package:lotti/features/backup_restore/service/quiesced_profile_snapshot_service.dart';
import 'package:lotti/features/profiles/service/profile_switcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Closes the running profile, runs the work, and starts the profile again —
/// [ProfileSwitcher.runWithGenerationClosed] in production.
typedef ClosedGenerationRunner =
    Future<T> Function<T>(
      Future<T> Function(ClosedProfileGeneration closed) whileClosed,
    );

/// A backup is already running, or a profile switch is in progress.
class ProfileBackupBusyException implements Exception {
  const ProfileBackupBusyException();

  @override
  String toString() =>
      'ProfileBackupBusyException: a backup or profile switch is running';
}

/// The backup was cancelled. Nothing it produced was kept.
class ProfileBackupCancelledException implements Exception {
  const ProfileBackupCancelledException();

  @override
  String toString() => 'ProfileBackupCancelledException';
}

/// Lets the requester of a backup call it off.
///
/// Cancellation is honoured at phase boundaries, not in the middle of one:
/// before the profile is closed, after it is closed but before anything is
/// copied, and after the snapshot is published, in which case the snapshot is
/// deleted. Once closing has begun the profile is always restarted.
class ProfileBackupCancellation {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// Captures the running profile while it is provably at rest.
///
/// The profile is closed strictly, through [ClosedGenerationRunner]: every
/// service and database must stop cleanly, or no byte is copied. The
/// snapshot service then refuses any SQLite `-wal`/`-shm` companion, which
/// SQLite only leaves behind while a connection is still open — the second,
/// independent proof that every writer really closed. Commits made before
/// the close are checkpointed into the database files by that close, so the
/// snapshot contains them.
///
/// Failures surface as typed exceptions:
/// - [ProfileBackupBusyException] — nothing was touched;
/// - [ProfileBackupCancelledException] — nothing was kept;
/// - [ProfileQuiescenceException] — the profile could not be proven closed,
///   nothing was copied, and the profile was restarted;
/// - [ProfileSnapshotException] — staging refused or failed, nothing was
///   published, and the profile was restarted;
/// - [ProfileRestartException] — the profile could not be started again; the
///   app waits on its splash and a relaunch boots the same profile.
///
/// The published snapshot is a plain staged copy. It is not a portable
/// backup until it has been packaged and encrypted.
class ProfileBackupCoordinator {
  ProfileBackupCoordinator({
    required this._runClosed,
    QuiescedProfileSnapshotService? snapshots,
    Future<String> Function()? appVersion,
  }) : _snapshots = snapshots ?? QuiescedProfileSnapshotService(),
       _appVersion = appVersion ?? _installedAppVersion;

  final ClosedGenerationRunner _runClosed;
  final QuiescedProfileSnapshotService _snapshots;
  final Future<String> Function() _appVersion;

  bool _running = false;

  /// Whether a capture is in progress.
  bool get isRunning => _running;

  static Future<String> _installedAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  /// Closes the profile, stages a verified snapshot of it below
  /// [stagingParent], and restarts the profile.
  ///
  /// [stagingParent] must lie outside the profile root. A second call while
  /// one is running throws [ProfileBackupBusyException] instead of queueing.
  Future<StagedProfileSnapshot> capture({
    required Directory stagingParent,
    ProfileBackupCancellation? cancellation,
  }) async {
    if (_running) throw const ProfileBackupBusyException();
    _running = true;
    try {
      _throwIfCancelled(cancellation);
      // Read before closing anything: a failure here costs nothing.
      final appVersion = await _appVersion();
      _throwIfCancelled(cancellation);

      try {
        return await _runClosed<StagedProfileSnapshot>((closed) async {
          _throwIfCancelled(cancellation);
          final snapshot = await _snapshots.stage(
            sourceRoot: closed.root,
            stagingParent: stagingParent,
            appVersion: appVersion,
            profileType: closed.profile.type.name,
          );
          if (cancellation?.isCancelled ?? false) {
            await snapshot.directory.delete(recursive: true);
            throw const ProfileBackupCancelledException();
          }
          return snapshot;
        });
      } on ProfileLifecycleBusyException {
        throw const ProfileBackupBusyException();
      }
    } finally {
      _running = false;
    }
  }

  static void _throwIfCancelled(ProfileBackupCancellation? cancellation) {
    if (cancellation?.isCancelled ?? false) {
      throw const ProfileBackupCancelledException();
    }
  }
}
