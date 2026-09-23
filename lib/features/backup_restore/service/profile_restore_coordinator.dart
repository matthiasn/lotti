import 'dart:io';

import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/database/onboarding_metrics_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/backup_restore/domain/profile_backup_manifest.dart';
import 'package:lotti/features/backup_restore/service/closed_sqlite_file.dart';
import 'package:lotti/features/backup_restore/service/profile_restore_preflight.dart';
import 'package:lotti/features/daily_os_next/database/day_processing_db.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/profiles/service/profile_switcher.dart';
import 'package:lotti/get_it.dart';
import 'package:meta/meta.dart';

/// Closes the running profile, runs the work, and restarts it — with a
/// health check and a rollback when the work replaced the profile's files.
/// [ProfileSwitcher.runWithGenerationClosed] in production.
typedef RestoringGenerationRunner =
    Future<void> Function(
      Future<void> Function(ClosedProfileGeneration closed) whileClosed, {
      Future<void> Function()? verifyRestarted,
      Future<void> Function()? rollBack,
    });

/// A restore, backup or profile switch is already running.
class ProfileRestoreBusyException implements Exception {
  const ProfileRestoreBusyException();

  @override
  String toString() =>
      'ProfileRestoreBusyException: a restore, backup or profile switch is '
      'running';
}

/// Opens every database of the running generation.
///
/// Drift opens a database — and runs its migrations — on the first query, so
/// a bootstrap that returned says nothing yet about whether a restored
/// profile's databases work. This forces each one open and fails if any
/// cannot be opened or migrated.
Future<void> verifyProfileDatabasesOpen({GetIt? serviceLocator}) async {
  final locator = serviceLocator ?? getIt;
  Future<void> open<T extends GeneratedDatabase>() async {
    if (!locator.isRegistered<T>()) return;
    await locator<T>().customSelect('SELECT count(*) FROM sqlite_master').get();
  }

  await open<JournalDb>();
  await open<SettingsDb>();
  await open<SyncDatabase>();
  await open<AgentDatabase>();
  await open<EditorDb>();
  await open<ConsumptionDatabase>();
  await open<NotificationsDb>();
  await open<OnboardingMetricsDb>();
  await open<DayProcessingDb>();
  if (locator.isRegistered<AiConfigRepository>()) {
    // The repository owns its database privately; any read opens it.
    await locator<AiConfigRepository>().getConfigById('restore-open-check');
  }
}

/// Replaces the running profile with the contents of a backup, keeping the
/// original until the restored one has started and opened its databases.
///
/// 1. **Preflight**, with the profile still running: the bundle is decrypted
///    into the profile root's hidden restore folder and checked
///    ([ProfileRestorePreflight]). A bad bundle ends here and the running
///    profile is untouched.
/// 2. **Swap**, with the profile closed strictly: the profile's own entries
///    move aside and the restored ones move in, each step journaled.
/// 3. **Start** the restored profile and open every database
///    ([verifyProfileDatabasesOpen]). If that fails, the swap is undone and
///    the original profile starts again ([ProfileRolledBackException]).
/// 4. **Commit**: the original is deleted.
///
/// A crash anywhere between 2 and 4 is finished or undone at the next launch
/// by `ProfileRootSwap.recover`.
class ProfileRestoreCoordinator {
  ProfileRestoreCoordinator({
    required this._runClosed,
    ProfileContext Function()? currentProfile,
    ProfileRestorePreflight? preflight,
    Future<void> Function()? verifyRestarted,
    @visibleForTesting Future<void> Function(Directory root)? settleDatabases,
  }) : _currentProfile = currentProfile ?? getIt.get<ProfileContext>,
       _preflight = preflight ?? ProfileRestorePreflight(),
       _verifyRestarted = verifyRestarted ?? verifyProfileDatabasesOpen,
       _settleDatabases = settleDatabases ?? settleProfileDatabases;

  final RestoringGenerationRunner _runClosed;
  final ProfileContext Function() _currentProfile;
  final ProfileRestorePreflight _preflight;
  final Future<void> Function() _verifyRestarted;
  final Future<void> Function(Directory root) _settleDatabases;

  bool _running = false;

  /// Whether a restore is in progress.
  bool get isRunning => _running;

  /// Restores [bundle], unlocked with [passphrase], over the running
  /// profile, and returns the restored profile's manifest.
  ///
  /// Fails without changing the running profile when the bundle cannot be
  /// read or does not fit ([ProfileRestoreIncompatibleException] and the
  /// bundle codec's exceptions), when the profile cannot be closed cleanly
  /// ([ProfileQuiescenceException]), or when another lifecycle operation is
  /// running ([ProfileRestoreBusyException]). Reports
  /// [ProfileRolledBackException] when the restored profile would not start
  /// and the original was put back, and [ProfileRestartException] when the
  /// app has to be relaunched to finish recovering.
  Future<ProfileBackupManifest> restore({
    required File bundle,
    required String passphrase,
  }) async {
    if (_running) throw const ProfileRestoreBusyException();
    _running = true;
    try {
      final profile = _currentProfile();
      final prepared = await _preflight.prepare(
        bundle: bundle,
        passphrase: passphrase,
        profileRoot: profile.root,
        profileType: profile.profile.type,
      );
      final swap = prepared.swap;
      var swapped = false;
      try {
        await _runClosed(
          (closed) async {
            if (closed.root.path != swap.root.path) {
              throw const ProfileRestoreIncompatibleException(
                'The active profile changed while the backup was checked.',
              );
            }
            // Nothing may still hold a database open when files move.
            await _settleDatabases(closed.root);
            try {
              swap.swapIn();
              swapped = true;
            } catch (_) {
              try {
                swap.rollBack();
              } catch (error, stackTrace) {
                // The root is half-swapped: starting it could let a database
                // be created fresh in place of a missing one. Leave the
                // profile closed; the next launch rolls it back.
                throw ProfileRestartException(error, stackTrace);
              }
              rethrow;
            }
          },
          verifyRestarted: _verifyRestarted,
          rollBack: () async {
            // The rejected generation's databases must be fully closed before
            // its files move out; if they are not, the rollback fails and the
            // next launch finishes it.
            await _settleDatabases(swap.root);
            swap.rollBack();
          },
        );
      } on ProfileLifecycleBusyException {
        prepared.discard();
        throw const ProfileRestoreBusyException();
      } catch (_) {
        // A rolled-back swap has already cleaned up; a stuck one keeps its
        // journal for the next launch. Only an untouched stage is discarded.
        if (!swapped) prepared.discard();
        rethrow;
      }
      swap.commit();
      return prepared.manifest;
    } finally {
      _running = false;
    }
  }
}
