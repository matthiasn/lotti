import 'dart:io';

import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/database/onboarding_metrics_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/backup_restore/domain/profile_backup_catalog.dart';
import 'package:lotti/features/backup_restore/domain/profile_backup_manifest.dart';
import 'package:lotti/features/backup_restore/service/closed_sqlite_file.dart';
import 'package:lotti/features/backup_restore/service/profile_backup_bundle_codec.dart';
import 'package:lotti/features/backup_restore/service/profile_root_swap.dart';
import 'package:lotti/features/daily_os_next/database/day_processing_db.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

/// The backup is intact but cannot be restored here: it belongs to another
/// kind of profile, lacks a required store, or comes from a newer schema.
class ProfileRestoreIncompatibleException implements Exception {
  const ProfileRestoreIncompatibleException(this.message);

  final String message;

  @override
  String toString() => 'ProfileRestoreIncompatibleException: $message';
}

/// The newest schema this build can open, per database store.
///
/// A backup may carry an older schema — Drift migrates it on first open —
/// but never a newer one: Drift cannot migrate downwards. Stores whose schema
/// is owned elsewhere, like the Matrix SDK's, are not listed.
@visibleForTesting
const Map<String, int> restorableSchemaVersions = {
  'journal': JournalDb.currentSchemaVersion,
  'sync': SyncDatabase.currentSchemaVersion,
  'agents': AgentDatabase.currentSchemaVersion,
  'editor-drafts': EditorDb.currentSchemaVersion,
  'ai-consumption': ConsumptionDatabase.currentSchemaVersion,
  'settings': SettingsDb.currentSchemaVersion,
  'notifications': NotificationsDb.currentSchemaVersion,
  'onboarding-metrics': OnboardingMetricsDb.currentSchemaVersion,
  'ai-config': AiConfigDb.currentSchemaVersion,
  'day-processing': DayProcessingDb.currentSchemaVersion,
};

/// A backup decrypted and fully checked next to the profile it will replace,
/// ready for [ProfileRootSwap.swapIn].
@immutable
class PreparedProfileRestore {
  const PreparedProfileRestore({required this.swap, required this.manifest});

  final ProfileRootSwap swap;
  final ProfileBackupManifest manifest;

  /// Deletes the staged copy when the restore is abandoned before the swap.
  void discard() {
    if (swap.incomingDirectory.existsSync()) {
      swap.incomingDirectory.deleteSync(recursive: true);
    }
    _removeEmptyWorkDirectory(swap);
  }
}

/// Decrypts a backup into the profile root's restore folder and checks that
/// it can replace the running profile — all while that profile keeps
/// running, and without touching any of its files.
class ProfileRestorePreflight {
  ProfileRestorePreflight({
    ProfileBackupBundleCodec? codec,
    String Function()? restoreIdGenerator,
  }) : _codec = codec ?? ProfileBackupBundleCodec(),
       _restoreId = restoreIdGenerator ?? const Uuid().v4;

  final ProfileBackupBundleCodec _codec;
  final String Function() _restoreId;

  /// Extracts [bundle] with [passphrase] for the profile of [profileType]
  /// rooted at [profileRoot], and verifies:
  ///
  /// - authenticity and every file against the manifest (the codec);
  /// - that the backup was taken from the same kind of profile;
  /// - that every store the catalog requires is present;
  /// - that every database this build knows declares its schema, and that
  ///   the file's own schema matches the declaration and is no newer than
  ///   this build can open;
  /// - that every database passes SQLite's `integrity_check`;
  /// - that nothing in it would land on a device-owned entry of the root.
  ///
  /// Refuses to start while an earlier restore is pending. Any failure
  /// removes the extracted copy again.
  Future<PreparedProfileRestore> prepare({
    required File bundle,
    required String passphrase,
    required Directory profileRoot,
    required ProfileType profileType,
  }) async {
    if (ProfileRootSwap.hasPendingRestore(profileRoot)) {
      // Normally finished at launch; decrypting a second copy next to it
      // would only make the next recovery harder.
      throw const ProfileRestoreSwapException(
        'An earlier restore has not been finished or undone.',
      );
    }
    final swap = ProfileRootSwap(profileRoot, restoreId: _restoreId());
    final ProfileBackupManifest manifest;
    try {
      manifest = await _codec.extract(
        bundle: bundle,
        passphrase: passphrase,
        targetDirectory: swap.incomingDirectory,
      );
    } catch (_) {
      _removeEmptyWorkDirectory(swap);
      rethrow;
    }
    final prepared = PreparedProfileRestore(swap: swap, manifest: manifest);
    try {
      _check(manifest, swap.incomingPayload, profileType);
    } catch (_) {
      prepared.discard();
      rethrow;
    }
    return prepared;
  }

  static void _check(
    ProfileBackupManifest manifest,
    Directory payload,
    ProfileType profileType,
  ) {
    if (manifest.profileType != profileType.name) {
      throw ProfileRestoreIncompatibleException(
        'This backup is of a ${manifest.profileType} profile and cannot '
        'replace a ${profileType.name} one.',
      );
    }

    final files = {for (final file in manifest.files) file.relativePath};
    for (final store in ProfileBackupCatalog.stores) {
      if (store.required && !files.contains(store.relativePath)) {
        throw ProfileRestoreIncompatibleException(
          'The backup is missing ${store.relativePath}.',
        );
      }
    }

    for (final store in manifest.stores) {
      final supported = restorableSchemaVersions[store.id];
      if (supported != null && store.schemaVersion == null) {
        throw ProfileRestoreIncompatibleException(
          'The backup declares no schema for ${store.relativePath}.',
        );
      }
      if (store.kind == BackupStoreKind.sqliteDatabase &&
          files.contains(store.relativePath)) {
        _checkDatabase(
          File(p.join(payload.path, store.relativePath)),
          declaredVersion: store.schemaVersion,
          supportedVersion: supported,
        );
      }
    }

    for (final entity in payload.listSync(followLinks: false)) {
      if (ProfileRootSwap.isDeviceEntry(p.basename(entity.path))) {
        throw ProfileRestoreIncompatibleException(
          'The backup contains ${p.basename(entity.path)}, which belongs to '
          'the device and is never restored.',
        );
      }
    }
  }

  static void _checkDatabase(
    File database, {
    required int? declaredVersion,
    required int? supportedVersion,
  }) {
    final name = p.basename(database.path);
    final ClosedSqliteReport report;
    try {
      report = inspectClosedSqliteFile(database);
    } on SqliteException catch (error) {
      throw ProfileRestoreIncompatibleException(
        '$name is not a readable database: ${error.message}',
      );
    }
    if (report.problems.isNotEmpty) {
      throw ProfileRestoreIncompatibleException(
        '$name failed its integrity check: ${report.problems.first}',
      );
    }
    // The file is the authority: it has to agree with the manifest, and it
    // is what gets opened, so its own schema is what must not be too new.
    if (declaredVersion != null && report.userVersion != declaredVersion) {
      throw ProfileRestoreIncompatibleException(
        '$name has schema ${report.userVersion}, but the backup declares '
        '$declaredVersion.',
      );
    }
    if (supportedVersion != null && report.userVersion > supportedVersion) {
      throw ProfileRestoreIncompatibleException(
        'The backup was made by a newer version of Lotti ($name schema '
        '${report.userVersion}, this version reads up to $supportedVersion).',
      );
    }
  }
}

void _removeEmptyWorkDirectory(ProfileRootSwap swap) {
  final work = swap.workDirectory;
  if (work.existsSync() && work.listSync().isEmpty) work.deleteSync();
}
