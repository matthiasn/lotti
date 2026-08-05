import 'package:collection/collection.dart';
import 'package:lotti/features/backup_restore/domain/profile_backup_catalog.dart';
import 'package:meta/meta.dart';

final RegExp _storeIdPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
final RegExp _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');

/// One store declaration captured in a backup manifest.
@immutable
class BackupManifestStore {
  const BackupManifestStore({
    required this.id,
    required this.relativePath,
    required this.kind,
    required this.sensitivity,
    required this.required,
    this.schemaVersion,
  });

  factory BackupManifestStore.fromJson(Map<String, Object?> json) {
    final kind = _requiredEnum(json, 'kind', BackupStoreKind.values);
    return BackupManifestStore(
      id: _requiredString(json, 'id'),
      relativePath: _storeRelativePath(json, kind),
      kind: kind,
      sensitivity: _requiredEnum(
        json,
        'sensitivity',
        BackupSensitivity.values,
      ),
      required: _requiredBool(json, 'required'),
      schemaVersion: _optionalInt(json, 'schemaVersion'),
    );
  }

  /// Stable catalog identity.
  final String id;

  /// Canonical root path of the store within the profile.
  final String relativePath;

  /// Physical shape of the store.
  final BackupStoreKind kind;

  /// Protection required for the store's contents.
  final BackupSensitivity sensitivity;

  /// Whether restore requires the store to be present.
  final bool required;

  /// SQLite `user_version` captured from a validated database copy.
  final int? schemaVersion;

  /// JSON representation embedded in the manifest.
  Map<String, Object?> toJson() => {
    'id': id,
    'relativePath': relativePath,
    'kind': kind.name,
    'sensitivity': sensitivity.name,
    'required': required,
    if (schemaVersion != null) 'schemaVersion': schemaVersion,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupManifestStore &&
          id == other.id &&
          relativePath == other.relativePath &&
          kind == other.kind &&
          sensitivity == other.sensitivity &&
          required == other.required &&
          schemaVersion == other.schemaVersion;

  @override
  int get hashCode => Object.hash(
    id,
    relativePath,
    kind,
    sensitivity,
    required,
    schemaVersion,
  );
}

/// One copied file and its content-integrity metadata.
@immutable
class BackupManifestFile {
  const BackupManifestFile({
    required this.storeId,
    required this.relativePath,
    required this.sizeBytes,
    required this.sha256,
  });

  factory BackupManifestFile.fromJson(Map<String, Object?> json) =>
      BackupManifestFile(
        storeId: _requiredString(json, 'storeId'),
        relativePath: _requiredString(json, 'relativePath'),
        sizeBytes: _requiredInt(json, 'sizeBytes'),
        sha256: _requiredString(json, 'sha256'),
      );

  /// Stable ID of the owning [BackupManifestStore].
  final String storeId;

  /// Canonical path below the snapshot root.
  final String relativePath;

  /// Exact byte length used during verification.
  final int sizeBytes;

  /// Lowercase hexadecimal SHA-256 digest of the copied bytes.
  final String sha256;

  /// JSON representation embedded in the manifest.
  Map<String, Object?> toJson() => {
    'storeId': storeId,
    'relativePath': relativePath,
    'sizeBytes': sizeBytes,
    'sha256': sha256,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupManifestFile &&
          storeId == other.storeId &&
          relativePath == other.relativePath &&
          sizeBytes == other.sizeBytes &&
          sha256 == other.sha256;

  @override
  int get hashCode => Object.hash(storeId, relativePath, sizeBytes, sha256);
}

/// Versioned description of one complete, verified profile snapshot.
@immutable
class ProfileBackupManifest {
  /// Creates a manifest using the current format and catalog versions.
  factory ProfileBackupManifest({
    required DateTime createdAt,
    required String appVersion,
    required String profileType,
    required List<BackupManifestStore> stores,
    required List<BackupManifestFile> files,
  }) => ProfileBackupManifest._validated(
    formatVersion: currentFormatVersion,
    catalogVersion: ProfileBackupCatalog.version,
    createdAt: createdAt,
    appVersion: appVersion,
    profileType: profileType,
    stores: stores,
    files: files,
  );

  const ProfileBackupManifest._({
    required this.formatVersion,
    required this.catalogVersion,
    required this.createdAt,
    required this.appVersion,
    required this.profileType,
    required this.stores,
    required this.files,
  });

  factory ProfileBackupManifest._validated({
    required int formatVersion,
    required int catalogVersion,
    required DateTime createdAt,
    required String appVersion,
    required String profileType,
    required List<BackupManifestStore> stores,
    required List<BackupManifestFile> files,
  }) {
    if (formatVersion > currentFormatVersion) {
      throw UnsupportedError(
        'Backup format $formatVersion is newer than supported '
        '$currentFormatVersion.',
      );
    }
    if (formatVersion < 1) {
      throw const FormatException('Backup formatVersion must be positive.');
    }
    if (catalogVersion > ProfileBackupCatalog.version) {
      throw UnsupportedError(
        'Backup catalog $catalogVersion is newer than supported '
        '${ProfileBackupCatalog.version}.',
      );
    }
    if (catalogVersion < 1) {
      throw const FormatException('Backup catalogVersion must be positive.');
    }
    if (!createdAt.isUtc) {
      throw const FormatException('Backup createdAt must be UTC.');
    }
    if (appVersion.trim().isEmpty) {
      throw const FormatException('Backup appVersion may not be empty.');
    }
    if (profileType != 'real' && profileType != 'guest') {
      throw FormatException('Unsupported backup profileType.', profileType);
    }

    final sortedStores = [...stores]..sort((a, b) => a.id.compareTo(b.id));
    final storeIds = <String>{};
    final storePaths = <String>{};
    for (final store in sortedStores) {
      if (!_storeIdPattern.hasMatch(store.id)) {
        throw FormatException('Invalid backup store id.', store.id);
      }
      if (store.kind != BackupStoreKind.opaqueProfileContent ||
          store.relativePath.isNotEmpty) {
        ProfileBackupCatalog.validateRelativePath(store.relativePath);
      }
      if (!storeIds.add(store.id)) {
        throw FormatException('Duplicate backup store id.', store.id);
      }
      if (!storePaths.add(store.relativePath)) {
        throw FormatException(
          'Duplicate backup store path.',
          store.relativePath,
        );
      }
      if (store.schemaVersion case final schemaVersion?) {
        if (store.kind != BackupStoreKind.sqliteDatabase || schemaVersion < 0) {
          throw FormatException(
            'schemaVersion is valid only for SQLite stores and may not be '
            'negative.',
            schemaVersion,
          );
        }
      }
    }

    final storesById = {for (final store in sortedStores) store.id: store};
    final sortedFiles = [...files]
      ..sort((a, b) => a.relativePath.compareTo(b.relativePath));
    final filePaths = <String>{};
    for (final file in sortedFiles) {
      ProfileBackupCatalog.validateRelativePath(file.relativePath);
      if (!filePaths.add(file.relativePath)) {
        throw FormatException('Duplicate backup file path.', file.relativePath);
      }
      final store = storesById[file.storeId];
      if (store == null) {
        throw FormatException(
          'Backup file references an unknown store.',
          file.storeId,
        );
      }
      if (!_belongsToStore(file.relativePath, store)) {
        throw FormatException(
          'Backup file does not belong to its declared store.',
          file.relativePath,
        );
      }
      if (file.sizeBytes < 0) {
        throw FormatException('Backup file size may not be negative.', file);
      }
      if (!_sha256Pattern.hasMatch(file.sha256)) {
        throw FormatException('Invalid SHA-256 digest.', file.sha256);
      }
    }

    return ProfileBackupManifest._(
      formatVersion: formatVersion,
      catalogVersion: catalogVersion,
      createdAt: createdAt,
      appVersion: appVersion,
      profileType: profileType,
      stores: List.unmodifiable(sortedStores),
      files: List.unmodifiable(sortedFiles),
    );
  }

  /// Parses and validates an untrusted manifest document.
  factory ProfileBackupManifest.fromJson(Map<String, Object?> json) {
    final formatVersion = _requiredInt(json, 'formatVersion');
    if (formatVersion > currentFormatVersion) {
      throw UnsupportedError(
        'Backup format $formatVersion is newer than supported '
        '$currentFormatVersion.',
      );
    }
    final catalogVersion = _requiredInt(json, 'catalogVersion');
    if (catalogVersion > ProfileBackupCatalog.version) {
      throw UnsupportedError(
        'Backup catalog $catalogVersion is newer than supported '
        '${ProfileBackupCatalog.version}.',
      );
    }
    final createdAtRaw = _requiredString(json, 'createdAt');
    if (!createdAtRaw.endsWith('Z')) {
      throw const FormatException('Backup createdAt must use UTC Z notation.');
    }
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null || !createdAt.isUtc) {
      throw FormatException('Invalid backup createdAt.', createdAtRaw);
    }

    return ProfileBackupManifest._validated(
      formatVersion: formatVersion,
      catalogVersion: catalogVersion,
      createdAt: createdAt,
      appVersion: _requiredString(json, 'appVersion'),
      profileType: _requiredString(json, 'profileType'),
      stores: _requiredMapList(
        json,
        'stores',
      ).map(BackupManifestStore.fromJson).toList(growable: false),
      files: _requiredMapList(
        json,
        'files',
      ).map(BackupManifestFile.fromJson).toList(growable: false),
    );
  }

  /// Current on-disk manifest format.
  static const int currentFormatVersion = 1;

  /// Manifest structure version.
  final int formatVersion;

  /// Catalog version used to classify the profile.
  final int catalogVersion;

  /// UTC instant at which capture began.
  final DateTime createdAt;

  /// Lotti package version that produced the snapshot.
  final String appVersion;

  /// Profile kind (`real` or `guest`) without device-global registry state.
  final String profileType;

  /// Stable store declarations present in this snapshot.
  final List<BackupManifestStore> stores;

  /// Every copied file, sorted by canonical relative path.
  final List<BackupManifestFile> files;

  /// JSON representation written inside the protected bundle payload.
  Map<String, Object?> toJson() => {
    'formatVersion': formatVersion,
    'catalogVersion': catalogVersion,
    'createdAt': createdAt.toIso8601String(),
    'appVersion': appVersion,
    'profileType': profileType,
    'stores': [for (final store in stores) store.toJson()],
    'files': [for (final file in files) file.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileBackupManifest &&
          formatVersion == other.formatVersion &&
          catalogVersion == other.catalogVersion &&
          createdAt == other.createdAt &&
          appVersion == other.appVersion &&
          profileType == other.profileType &&
          const ListEquality<BackupManifestStore>().equals(
            stores,
            other.stores,
          ) &&
          const ListEquality<BackupManifestFile>().equals(files, other.files);

  @override
  int get hashCode => Object.hash(
    formatVersion,
    catalogVersion,
    createdAt,
    appVersion,
    profileType,
    Object.hashAll(stores),
    Object.hashAll(files),
  );

  static bool _belongsToStore(
    String relativePath,
    BackupManifestStore store,
  ) {
    return switch (store.kind) {
      BackupStoreKind.sqliteDatabase ||
      BackupStoreKind.file => relativePath == store.relativePath,
      BackupStoreKind.directory => relativePath.startsWith(
        '${store.relativePath}/',
      ),
      BackupStoreKind.opaqueProfileContent => true,
    };
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Manifest field $key must be a non-empty string.');
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Manifest field $key must be an integer.');
  }
  return value;
}

int? _optionalInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int) {
    throw FormatException('Manifest field $key must be an integer.');
  }
  return value;
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Manifest field $key must be a boolean.');
  }
  return value;
}

String _storeRelativePath(
  Map<String, Object?> json,
  BackupStoreKind kind,
) {
  final value = json['relativePath'];
  if (value is! String ||
      (value.isEmpty && kind != BackupStoreKind.opaqueProfileContent)) {
    throw const FormatException(
      'Manifest store relativePath must be a string; only an opaque root '
      'store may use an empty path.',
    );
  }
  return value;
}

T _requiredEnum<T extends Enum>(
  Map<String, Object?> json,
  String key,
  List<T> values,
) {
  final name = _requiredString(json, key);
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Manifest field $key has an unknown value.', name);
}

List<Map<String, Object?>> _requiredMapList(
  Map<String, Object?> json,
  String key,
) {
  final value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('Manifest field $key must be a list.');
  }
  return value
      .map((entry) {
        if (entry is! Map<Object?, Object?>) {
          throw FormatException('Manifest field $key must contain objects.');
        }
        return entry.map((key, value) {
          if (key is! String) {
            throw FormatException('Manifest field $key has a non-string key.');
          }
          return MapEntry(key, value);
        });
      })
      .toList(growable: false);
}
