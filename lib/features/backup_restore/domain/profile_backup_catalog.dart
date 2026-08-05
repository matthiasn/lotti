import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/database/onboarding_metrics_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/database/objectbox_embedding_store.dart';
import 'package:lotti/features/ai/database/sharded_embedding_store.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/daily_os_next/database/day_processing_db.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_startup.dart';
import 'package:lotti/features/demo/seed/demo_seed_manifest.dart';
import 'package:lotti/features/profiles/profile_paths.dart';
import 'package:lotti/features/sync/matrix/client.dart';
import 'package:path/path.dart' as p;

/// The physical shape of one cataloged profile store.
enum BackupStoreKind {
  /// A SQLite database copied only after every connection is closed.
  sqliteDatabase,

  /// A directory whose files are classified recursively.
  directory,

  /// A single non-database file.
  file,

  /// Forward-compatible profile content not yet assigned a dedicated store.
  opaqueProfileContent,
}

/// What snapshot code must do when it encounters a profile-relative path.
enum BackupPathTreatment {
  /// Preserve the path in the protected backup payload.
  include,

  /// Omit the path because the app can deterministically regenerate it.
  rebuild,

  /// Omit the path because it is outside the active profile backup boundary.
  exclude,

  /// Abort capture because the path proves the source is not safely quiesced.
  reject,
}

/// The minimum protection required for a path included in a backup.
enum BackupSensitivity {
  /// User content that belongs only inside the encrypted bundle payload.
  personal,

  /// Credentials or session material requiring explicit encrypted handling.
  credentials,

  /// Content that is intentionally omitted and carries no bundle requirement.
  none,
}

/// One stable store or path policy in the profile backup contract.
class ProfileBackupStore {
  const ProfileBackupStore({
    required this.id,
    required this.relativePath,
    required this.kind,
    required this.treatment,
    required this.sensitivity,
    required this.required,
    required this.rationale,
  });

  /// Stable identity written into backup manifests.
  final String id;

  /// Canonical path below the active profile root.
  ///
  /// An empty value is reserved for the include-by-default root policy.
  final String relativePath;

  /// Physical shape of this store.
  final BackupStoreKind kind;

  /// Snapshot treatment for this store.
  final BackupPathTreatment treatment;

  /// Protection required if the store is included.
  final BackupSensitivity sensitivity;

  /// Whether a usable initialized profile must contain this store.
  final bool required;

  /// Architectural reason for the treatment.
  final String rationale;
}

/// Fully resolved policy for one concrete file or directory.
class BackupPathDecision {
  const BackupPathDecision({
    required this.storeId,
    required this.kind,
    required this.treatment,
    required this.sensitivity,
    required this.required,
    required this.rationale,
  });

  factory BackupPathDecision.fromStore(ProfileBackupStore store) =>
      BackupPathDecision(
        storeId: store.id,
        kind: store.kind,
        treatment: store.treatment,
        sensitivity: store.sensitivity,
        required: store.required,
        rationale: store.rationale,
      );

  /// Stable store identity used by the manifest.
  final String storeId;

  /// Physical shape of the matched store.
  final BackupStoreKind kind;

  /// Required handling for this path.
  final BackupPathTreatment treatment;

  /// Required protection for included content.
  final BackupSensitivity sensitivity;

  /// Whether the matched store is mandatory in an initialized profile.
  final bool required;

  /// Architectural reason for the decision.
  final String rationale;
}

/// Versioned source-of-truth for the active profile backup boundary.
abstract final class ProfileBackupCatalog {
  /// Increment when path classification or store identity changes.
  static const int version = 1;

  static const String _audioWaveformDirectory = 'audio_waveforms';
  static const String _legacyBackupDirectory = 'backup';
  static const String _logsDirectory = 'logs';

  static const ProfileBackupStore _opaqueProfileContent = ProfileBackupStore(
    id: 'profile-content',
    relativePath: '',
    kind: BackupStoreKind.opaqueProfileContent,
    treatment: BackupPathTreatment.include,
    sensitivity: BackupSensitivity.personal,
    required: false,
    rationale:
        'Unknown profile-root content is included by default so a newly added '
        'authoritative file cannot be silently omitted by an older catalog.',
  );

  /// Every fixed store and directory policy known to this catalog version.
  static const List<ProfileBackupStore> stores = [
    ProfileBackupStore(
      id: 'journal',
      relativePath: journalDbFileName,
      kind: BackupStoreKind.sqliteDatabase,
      treatment: BackupPathTreatment.include,
      sensitivity: BackupSensitivity.personal,
      required: true,
      rationale: 'Primary journal, task, definition, and link authority.',
    ),
    ProfileBackupStore(
      id: 'sync',
      relativePath: syncDbFileName,
      kind: BackupStoreKind.sqliteDatabase,
      treatment: BackupPathTreatment.include,
      sensitivity: BackupSensitivity.personal,
      required: false,
      rationale: 'Owns pending outbox work and local sync progress.',
    ),
    ProfileBackupStore(
      id: 'agents',
      relativePath: agentDbFileName,
      kind: BackupStoreKind.sqliteDatabase,
      treatment: BackupPathTreatment.include,
      sensitivity: BackupSensitivity.personal,
      required: false,
      rationale: 'Owns agent state, history, proposals, and observations.',
    ),
    ProfileBackupStore(
      id: 'editor-drafts',
      relativePath: editorDbFileName,
      kind: BackupStoreKind.sqliteDatabase,
      treatment: BackupPathTreatment.include,
      sensitivity: BackupSensitivity.personal,
      required: false,
      rationale: 'Unsaved editor drafts cannot be reconstructed elsewhere.',
    ),
    ProfileBackupStore(
      id: 'ai-consumption',
      relativePath: consumptionDbFileName,
      kind: BackupStoreKind.sqliteDatabase,
      treatment: BackupPathTreatment.include,
      sensitivity: BackupSensitivity.personal,
      required: false,
      rationale: 'Owns the local AI usage and interaction ledger.',
    ),
    ProfileBackupStore(
      id: 'settings',
      relativePath: settingsDbFileName,
      kind: BackupStoreKind.sqliteDatabase,
      treatment: BackupPathTreatment.include,
      sensitivity: BackupSensitivity.personal,
      required: true,
      rationale: 'Owns profile-local settings and authoritative host identity.',
    ),
    ProfileBackupStore(
      id: 'full-text-index',
      relativePath: fts5DbFileName,
      kind: BackupStoreKind.sqliteDatabase,
      treatment: BackupPathTreatment.rebuild,
      sensitivity: BackupSensitivity.none,
      required: false,
      rationale: 'A derived search index rebuilt from the journal database.',
    ),
    ProfileBackupStore(
      id: 'notifications',
      relativePath: notificationsDbFileName,
      kind: BackupStoreKind.sqliteDatabase,
      treatment: BackupPathTreatment.include,
      sensitivity: BackupSensitivity.personal,
      required: false,
      rationale: 'Owns scheduled, delivered, and synced notifications.',
    ),
    ProfileBackupStore(
      id: 'onboarding-metrics',
      relativePath: onboardingMetricsDbFileName,
      kind: BackupStoreKind.sqliteDatabase,
      treatment: BackupPathTreatment.include,
      sensitivity: BackupSensitivity.personal,
      required: false,
      rationale: 'Owns profile-local onboarding progress and measurements.',
    ),
    ProfileBackupStore(
      id: 'ai-config',
      relativePath: aiConfigDbFileName,
      kind: BackupStoreKind.sqliteDatabase,
      treatment: BackupPathTreatment.include,
      sensitivity: BackupSensitivity.credentials,
      required: false,
      rationale:
          'Owns AI providers, models, prompts, profiles, and currently API keys.',
    ),
    ProfileBackupStore(
      id: 'day-processing',
      relativePath: dayProcessingDbFileName,
      kind: BackupStoreKind.sqliteDatabase,
      treatment: BackupPathTreatment.include,
      sensitivity: BackupSensitivity.personal,
      required: false,
      rationale: 'Owns the durable Daily OS processing outbox.',
    ),
    ProfileBackupStore(
      id: 'matrix-sdk',
      relativePath: matrixDatabaseRelativePath,
      kind: BackupStoreKind.sqliteDatabase,
      treatment: BackupPathTreatment.include,
      sensitivity: BackupSensitivity.credentials,
      required: false,
      rationale:
          'Contains Matrix login sessions and encryption state for real profiles.',
    ),
    ProfileBackupStore(
      id: 'audio-media',
      relativePath: 'audio',
      kind: BackupStoreKind.directory,
      treatment: BackupPathTreatment.include,
      sensitivity: BackupSensitivity.personal,
      required: false,
      rationale:
          'Audio bytes are authoritative files referenced by journal rows.',
    ),
    ProfileBackupStore(
      id: 'image-media',
      relativePath: 'images',
      kind: BackupStoreKind.directory,
      treatment: BackupPathTreatment.include,
      sensitivity: BackupSensitivity.personal,
      required: false,
      rationale:
          'Image bytes are authoritative files referenced by journal rows.',
    ),
    ProfileBackupStore(
      id: 'agent-entity-sidecars',
      relativePath: 'agent_entities',
      kind: BackupStoreKind.directory,
      treatment: BackupPathTreatment.include,
      sensitivity: BackupSensitivity.personal,
      required: false,
      rationale: 'File-backed sync payloads may be referenced by pending work.',
    ),
    ProfileBackupStore(
      id: 'agent-link-sidecars',
      relativePath: 'agent_links',
      kind: BackupStoreKind.directory,
      treatment: BackupPathTreatment.include,
      sensitivity: BackupSensitivity.personal,
      required: false,
      rationale: 'File-backed sync payloads may be referenced by pending work.',
    ),
    ProfileBackupStore(
      id: 'notification-sidecars',
      relativePath: 'notifications',
      kind: BackupStoreKind.directory,
      treatment: BackupPathTreatment.include,
      sensitivity: BackupSensitivity.personal,
      required: false,
      rationale: 'Synced notification payloads back pending outbox rows.',
    ),
    ProfileBackupStore(
      id: 'outbox-bundles',
      relativePath: 'outbox_bundles',
      kind: BackupStoreKind.directory,
      treatment: BackupPathTreatment.include,
      sensitivity: BackupSensitivity.personal,
      required: false,
      rationale: 'Pending bundle files may be referenced by the sync outbox.',
    ),
    ProfileBackupStore(
      id: 'matrix-auxiliary',
      relativePath: matrixDatabaseDirectoryName,
      kind: BackupStoreKind.directory,
      treatment: BackupPathTreatment.include,
      sensitivity: BackupSensitivity.credentials,
      required: false,
      rationale:
          'Future Matrix SDK files inherit the session-store protection.',
    ),
    ProfileBackupStore(
      id: 'demo-seed-metadata',
      relativePath: demoSeedManifestFileName,
      kind: BackupStoreKind.file,
      treatment: BackupPathTreatment.include,
      sensitivity: BackupSensitivity.personal,
      required: false,
      rationale:
          'Guest restore needs the seed boundary to preserve user additions.',
    ),
    ProfileBackupStore(
      id: 'embedding-index',
      relativePath: kObjectBoxEmbeddingsDirectoryName,
      kind: BackupStoreKind.directory,
      treatment: BackupPathTreatment.rebuild,
      sensitivity: BackupSensitivity.none,
      required: false,
      rationale: 'Legacy embeddings are derived from authoritative entities.',
    ),
    ProfileBackupStore(
      id: 'sharded-embedding-index',
      relativePath: kObjectBoxShardedEmbeddingsDirectoryName,
      kind: BackupStoreKind.directory,
      treatment: BackupPathTreatment.rebuild,
      sensitivity: BackupSensitivity.none,
      required: false,
      rationale: 'Vector indexes are derived from authoritative entities.',
    ),
    ProfileBackupStore(
      id: 'audio-waveform-cache',
      relativePath: _audioWaveformDirectory,
      kind: BackupStoreKind.directory,
      treatment: BackupPathTreatment.rebuild,
      sensitivity: BackupSensitivity.none,
      required: false,
      rationale:
          'Waveform previews are a bounded cache derived from audio files.',
    ),
    ProfileBackupStore(
      id: 'legacy-day-processing-outbox',
      relativePath: legacyDayProcessingOutboxDirectory,
      kind: BackupStoreKind.directory,
      treatment: BackupPathTreatment.exclude,
      sensitivity: BackupSensitivity.none,
      required: false,
      rationale:
          'The mandatory startup migration imports every recoverable legacy '
          'job into day_processing.sqlite before backup can be requested.',
    ),
    ProfileBackupStore(
      id: 'diagnostic-logs',
      relativePath: _logsDirectory,
      kind: BackupStoreKind.directory,
      treatment: BackupPathTreatment.exclude,
      sensitivity: BackupSensitivity.none,
      required: false,
      rationale:
          'Diagnostics are not profile authority and may contain secrets.',
    ),
    ProfileBackupStore(
      id: 'legacy-database-backups',
      relativePath: _legacyBackupDirectory,
      kind: BackupStoreKind.directory,
      treatment: BackupPathTreatment.exclude,
      sensitivity: BackupSensitivity.none,
      required: false,
      rationale:
          'Excluding nested backups prevents recursion and stale restores.',
    ),
    ProfileBackupStore(
      id: 'guest-profile-container',
      relativePath: guestProfilesDirName,
      kind: BackupStoreKind.directory,
      treatment: BackupPathTreatment.exclude,
      sensitivity: BackupSensitivity.none,
      required: false,
      rationale:
          'One backup represents one active profile, never sibling worlds.',
    ),
    ProfileBackupStore(
      id: 'profile-registry',
      relativePath: profilesRegistryFileName,
      kind: BackupStoreKind.file,
      treatment: BackupPathTreatment.exclude,
      sensitivity: BackupSensitivity.none,
      required: false,
      rationale:
          'The registry is device-global metadata outside any one profile.',
    ),
    _opaqueProfileContent,
  ];

  static final RegExp _atomicTemporaryFile = RegExp(
    r'(?:\.tmp\.\d+\.\d+\.media|\.bak\.\d+)$',
  );

  /// Resolves the catalog policy for one canonical profile-relative path.
  static BackupPathDecision classify(String relativePath) {
    validateRelativePath(relativePath);

    for (final store in stores) {
      if (store.relativePath.isNotEmpty &&
          store.kind != BackupStoreKind.directory &&
          relativePath == store.relativePath) {
        return BackupPathDecision.fromStore(store);
      }
    }

    ProfileBackupStore? directoryMatch;
    for (final store in stores) {
      if (store.kind != BackupStoreKind.directory ||
          store.relativePath.isEmpty) {
        continue;
      }
      if (relativePath == store.relativePath ||
          relativePath.startsWith('${store.relativePath}/')) {
        if (directoryMatch == null ||
            store.relativePath.length > directoryMatch.relativePath.length) {
          // No current directory policies overlap; this preserves the intended
          // longest-prefix behavior for future nested policies.
          directoryMatch = store; // coverage:ignore-line
        }
      }
    }
    if (relativePath.startsWith('$profilesRegistryFileName.tmp.') ||
        relativePath.startsWith('$profilesRegistryFileName.bak.')) {
      return BackupPathDecision.fromStore(
        stores.firstWhere((store) => store.id == 'profile-registry'),
      );
    }
    if (directoryMatch != null &&
        (directoryMatch.treatment == BackupPathTreatment.exclude ||
            directoryMatch.treatment == BackupPathTreatment.rebuild)) {
      return BackupPathDecision.fromStore(directoryMatch);
    }
    if (_isSqliteCompanion(relativePath)) {
      return const BackupPathDecision(
        storeId: 'sqlite-companion',
        kind: BackupStoreKind.file,
        treatment: BackupPathTreatment.reject,
        sensitivity: BackupSensitivity.personal,
        required: false,
        rationale:
            'A WAL, SHM, or rollback journal means quiescence was not proven.',
      );
    }
    if (_atomicTemporaryFile.hasMatch(relativePath)) {
      return const BackupPathDecision(
        storeId: 'interrupted-atomic-write',
        kind: BackupStoreKind.file,
        treatment: BackupPathTreatment.reject,
        sensitivity: BackupSensitivity.personal,
        required: false,
        rationale:
            'Temporary or moved-aside files require recovery before capture.',
      );
    }
    if (directoryMatch != null) {
      return BackupPathDecision.fromStore(directoryMatch);
    }

    return BackupPathDecision.fromStore(_opaqueProfileContent);
  }

  /// Rejects absolute, escaping, platform-specific, or non-normal paths.
  static void validateRelativePath(String relativePath) {
    if (relativePath.isEmpty ||
        relativePath.startsWith('/') ||
        relativePath.contains(r'\') ||
        relativePath.contains(':') ||
        p.posix.normalize(relativePath) != relativePath) {
      throw FormatException(
        'Backup paths must be canonical profile-relative POSIX paths.',
        relativePath,
      );
    }
    final segments = relativePath.split('/');
    if (segments.any(
      (segment) => segment.isEmpty || segment == '.' || segment == '..',
    )) {
      throw FormatException(
        'Backup paths may not contain empty or traversal segments.',
        relativePath,
      );
    }
  }

  static bool _isSqliteCompanion(String relativePath) {
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      if (relativePath.endsWith(suffix)) return true;
    }
    return false;
  }
}
