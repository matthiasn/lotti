import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:lotti/features/backup_restore/domain/profile_backup_catalog.dart';
import 'package:lotti/features/backup_restore/domain/profile_backup_manifest.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

/// File name of the manifest beside a staged snapshot payload.
const profileBackupManifestFileName = 'manifest.json';

/// Directory containing profile-root files inside a staged snapshot.
const profileBackupPayloadDirectoryName = 'payload';

/// Base failure reported while staging a quiesced profile.
class ProfileSnapshotException implements Exception {
  const ProfileSnapshotException(this.message, {this.cause});

  /// Actionable failure description.
  final String message;

  /// Lower-level error, when one exists.
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'ProfileSnapshotException: $message'
      : 'ProfileSnapshotException: $message ($cause)';
}

/// The source changed after capture began and cannot be trusted as quiesced.
class ProfileSnapshotSourceChangedException extends ProfileSnapshotException {
  const ProfileSnapshotSourceChangedException(super.message, {super.cause});
}

/// Staged bytes or a SQLite database failed integrity validation.
class ProfileSnapshotValidationException extends ProfileSnapshotException {
  const ProfileSnapshotValidationException(super.message, {super.cause});
}

/// Deterministic lifecycle seams for real-I/O snapshot tests.
@visibleForTesting
@immutable
class ProfileSnapshotTestHooks {
  const ProfileSnapshotTestHooks({
    this.afterFileCopied,
    this.beforeSourceRehash,
    this.beforeFinalSourceVerification,
    this.beforePublish,
  });

  /// Runs after the target file is written, before source stability is checked.
  final Future<void> Function({
    required File sourceFile,
    required File targetFile,
    required String relativePath,
  })?
  afterFileCopied;

  /// Runs after source metadata is stable, before source bytes are rehashed.
  final Future<void> Function({
    required File sourceFile,
    required String relativePath,
  })?
  beforeSourceRehash;

  /// Runs after the final inventory scan, before source hashes are rechecked.
  final Future<void> Function()? beforeFinalSourceVerification;

  /// Runs immediately before the completed partial directory is verified.
  final Future<void> Function(Directory partialDirectory)? beforePublish;
}

/// A verified snapshot that has been atomically published in the staging root.
@immutable
class StagedProfileSnapshot {
  const StagedProfileSnapshot({
    required this.directory,
    required this.payloadDirectory,
    required this.manifest,
  });

  /// Published snapshot directory containing the payload and manifest.
  final Directory directory;

  /// Profile-root-shaped payload directory.
  final Directory payloadDirectory;

  /// Parsed manifest verified against [payloadDirectory].
  final ProfileBackupManifest manifest;
}

/// Builds an integrity-checked snapshot from an already-quiesced profile root.
///
/// This service does not stop application writers. Its caller must first prove
/// strict quiescence. Journal companions and source mutation make the operation
/// fail closed, so lifecycle code cannot accidentally turn a live filesystem
/// copy into an apparently valid backup.
class QuiescedProfileSnapshotService {
  QuiescedProfileSnapshotService({
    String Function()? snapshotIdGenerator,
    DateTime Function()? now,
    @visibleForTesting this.testHooks,
  }) : _snapshotIdGenerator = snapshotIdGenerator ?? const Uuid().v4,
       _now = now ?? DateTime.now;

  final String Function() _snapshotIdGenerator;
  final DateTime Function() _now;

  /// Optional deterministic hooks used only by real-I/O tests.
  @visibleForTesting
  final ProfileSnapshotTestHooks? testHooks;

  static final RegExp _safeSnapshotId = RegExp(r'^[a-zA-Z0-9_-]+$');

  /// Stages and atomically publishes one closed profile snapshot.
  Future<StagedProfileSnapshot> stage({
    required Directory sourceRoot,
    required Directory stagingParent,
    required String appVersion,
    required String profileType,
  }) async {
    _validateTreeBoundary(sourceRoot, stagingParent);
    _validateResolvedTreeBoundary(sourceRoot, stagingParent);
    final createdAt = _now().toUtc();

    final inventory = await _scanIncludedEntries(sourceRoot);
    _validateIncludedStores(inventory);

    final snapshotId = _snapshotIdGenerator();
    if (!_safeSnapshotId.hasMatch(snapshotId)) {
      throw ProfileSnapshotException(
        'Snapshot id contains unsafe path characters: $snapshotId',
      );
    }

    stagingParent.createSync(recursive: true);

    final finalDirectory = Directory(
      p.join(stagingParent.path, 'profile-snapshot-$snapshotId'),
    );
    if (FileSystemEntity.typeSync(finalDirectory.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw ProfileSnapshotException(
        'Snapshot destination already exists: ${finalDirectory.path}',
      );
    }

    final partialDirectory = await stagingParent.createTemp(
      '.profile-snapshot-$snapshotId.partial-',
    );
    try {
      final payloadDirectory = Directory(
        p.join(partialDirectory.path, profileBackupPayloadDirectoryName),
      )..createSync();

      final records = <BackupManifestFile>[];
      final manifestStores = <String, BackupManifestStore>{};

      for (final entry in inventory.where(
        (entry) => entry.kind == _SnapshotEntryKind.directory,
      )) {
        Directory(
          p.joinAll([
            payloadDirectory.path,
            ...entry.relativePath.split('/'),
          ]),
        ).createSync(recursive: true);
        _addManifestStore(manifestStores, entry.decision);
      }

      for (final entry in inventory.where(
        (entry) => entry.kind == _SnapshotEntryKind.file,
      )) {
        final sourceFile = File(
          p.joinAll([sourceRoot.path, ...entry.relativePath.split('/')]),
        );
        final targetFile = File(
          p.joinAll([
            payloadDirectory.path,
            ...entry.relativePath.split('/'),
          ]),
        );
        targetFile.parent.createSync(recursive: true);

        final digest = await _copyAndVerifyStableSource(
          sourceFile: sourceFile,
          targetFile: targetFile,
          relativePath: entry.relativePath,
          initialStat: entry.stat,
        );
        final schemaVersion =
            entry.decision.kind == BackupStoreKind.sqliteDatabase
            ? _validateSqlite(targetFile)
            : null;
        _addManifestStore(
          manifestStores,
          entry.decision,
          schemaVersion: schemaVersion,
        );
        records.add(
          BackupManifestFile(
            storeId: entry.decision.storeId,
            relativePath: entry.relativePath,
            sizeBytes: digest.sizeBytes,
            sha256: digest.sha256,
          ),
        );
      }

      final finalInventory = await _scanIncludedEntries(sourceRoot);
      _validateSameInventory(inventory, finalInventory);
      await testHooks?.beforeFinalSourceVerification?.call();
      await _validateSourceDigests(sourceRoot, records);

      final manifest = ProfileBackupManifest(
        createdAt: createdAt,
        appVersion: appVersion,
        profileType: profileType,
        stores: manifestStores.values.toList(growable: false),
        files: records,
      );
      final manifestFile = File(
        p.join(partialDirectory.path, profileBackupManifestFileName),
      );
      await manifestFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
        flush: true,
      );

      await testHooks?.beforePublish?.call(partialDirectory);
      final verifiedManifest = await _verifyPartialSnapshot(partialDirectory);
      if (verifiedManifest != manifest) {
        throw const ProfileSnapshotValidationException(
          'Staged manifest changed before publication.',
        );
      }
      final terminalInventory = await _scanIncludedEntries(sourceRoot);
      _validateSameInventory(inventory, terminalInventory);

      final publishedDirectory = await partialDirectory.rename(
        finalDirectory.path,
      );
      return StagedProfileSnapshot(
        directory: publishedDirectory,
        payloadDirectory: Directory(
          p.join(
            publishedDirectory.path,
            profileBackupPayloadDirectoryName,
          ),
        ),
        manifest: verifiedManifest,
      );
    } catch (error, stackTrace) {
      try {
        if (partialDirectory.existsSync()) {
          await partialDirectory.delete(recursive: true);
        }
      } catch (cleanupError) {
        // An OS-level cleanup failure cannot be induced portably without
        // weakening the production filesystem boundary.
        // coverage:ignore-start
        Error.throwWithStackTrace(
          ProfileSnapshotException(
            'Snapshot failed and its partial stage could not be removed.',
            cause: '$error; cleanup: $cleanupError',
          ),
          stackTrace,
        );
        // coverage:ignore-end
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static void _validateTreeBoundary(
    Directory sourceRoot,
    Directory stagingParent,
  ) {
    if (!sourceRoot.existsSync()) {
      throw ProfileSnapshotException(
        'Profile source does not exist: ${sourceRoot.path}',
      );
    }
    final source = p.normalize(sourceRoot.absolute.path);
    final staging = p.normalize(stagingParent.absolute.path);
    if (p.equals(source, staging) ||
        p.isWithin(source, staging) ||
        p.isWithin(staging, source)) {
      throw const ProfileSnapshotException(
        'Snapshot source and staging directory may not overlap.',
      );
    }
  }

  static void _validateResolvedTreeBoundary(
    Directory sourceRoot,
    Directory stagingParent,
  ) {
    final source = p.normalize(sourceRoot.resolveSymbolicLinksSync());
    final staging = _resolveThroughExistingAncestor(stagingParent);
    if (p.equals(source, staging) ||
        p.isWithin(source, staging) ||
        p.isWithin(staging, source)) {
      throw const ProfileSnapshotException(
        'Resolved snapshot source and staging directory may not overlap.',
      );
    }
  }

  static String _resolveThroughExistingAncestor(Directory directory) {
    var ancestor = Directory(p.normalize(directory.absolute.path));
    final missingSegments = <String>[];
    while (FileSystemEntity.typeSync(ancestor.path, followLinks: false) ==
        FileSystemEntityType.notFound) {
      final parent = ancestor.parent;
      // A filesystem root always exists; this guards only a broken platform
      // implementation of the ancestor walk.
      // coverage:ignore-start
      if (p.equals(parent.path, ancestor.path)) {
        throw ProfileSnapshotException(
          'Unable to resolve snapshot staging path: ${directory.path}',
        );
      }
      // coverage:ignore-end
      missingSegments.add(p.basename(ancestor.path));
      ancestor = parent;
    }
    return p.normalize(
      p.joinAll([
        ancestor.resolveSymbolicLinksSync(),
        ...missingSegments.reversed,
      ]),
    );
  }

  static Future<List<_SnapshotSourceEntry>> _scanIncludedEntries(
    Directory sourceRoot,
  ) async {
    final entries = <_SnapshotSourceEntry>[];

    Future<void> scan(Directory directory, String relativeDirectory) async {
      final children = await directory.list(followLinks: false).toList()
        ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
      for (final child in children) {
        final name = p.basename(child.path);
        final relativePath = relativeDirectory.isEmpty
            ? name
            : '$relativeDirectory/$name';
        final decision = ProfileBackupCatalog.classify(relativePath);
        if (decision.treatment == BackupPathTreatment.reject) {
          throw ProfileSnapshotException(
            'Unsafe snapshot source at $relativePath: ${decision.rationale}',
          );
        }
        if (decision.treatment == BackupPathTreatment.exclude ||
            decision.treatment == BackupPathTreatment.rebuild) {
          continue;
        }

        final type = FileSystemEntity.typeSync(child.path, followLinks: false);
        if (type == FileSystemEntityType.link) {
          throw ProfileSnapshotException(
            'Snapshot source may not contain symbolic links: $relativePath',
          );
        }
        if (type == FileSystemEntityType.directory) {
          final stat = child.statSync();
          entries.add(
            _SnapshotSourceEntry(
              relativePath: relativePath,
              kind: _SnapshotEntryKind.directory,
              decision: decision,
              stat: stat,
            ),
          );
          await scan(Directory(child.path), relativePath);
          continue;
        }
        if (type == FileSystemEntityType.file) {
          entries.add(
            _SnapshotSourceEntry(
              relativePath: relativePath,
              kind: _SnapshotEntryKind.file,
              decision: decision,
              stat: child.statSync(),
            ),
          );
          continue;
        }
        throw ProfileSnapshotSourceChangedException(
          'Snapshot source disappeared while scanning: $relativePath',
        );
      }
    }

    await scan(sourceRoot, '');
    entries.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return entries;
  }

  static void _validateIncludedStores(List<_SnapshotSourceEntry> inventory) {
    final entriesByPath = {
      for (final entry in inventory) entry.relativePath: entry,
    };
    for (final store in ProfileBackupCatalog.stores) {
      if (store.treatment != BackupPathTreatment.include) {
        continue;
      }
      final entry = entriesByPath[store.relativePath];
      if (entry == null) {
        if (store.required) {
          throw ProfileSnapshotValidationException(
            'Required profile store is missing: ${store.relativePath}',
          );
        }
        continue;
      }
      final expectedKind = store.kind == BackupStoreKind.directory
          ? _SnapshotEntryKind.directory
          : _SnapshotEntryKind.file;
      if (entry.kind != expectedKind) {
        final expectedDescription = expectedKind == _SnapshotEntryKind.file
            ? 'a regular file'
            : 'a directory';
        throw ProfileSnapshotValidationException(
          'Profile store ${store.relativePath} must be '
          '$expectedDescription.',
        );
      }
    }
  }

  static void _validateSameInventory(
    List<_SnapshotSourceEntry> initial,
    List<_SnapshotSourceEntry> finalInventory,
  ) {
    if (initial.length != finalInventory.length) {
      throw const ProfileSnapshotSourceChangedException(
        'Profile file inventory changed during snapshot capture.',
      );
    }
    for (var index = 0; index < initial.length; index++) {
      final before = initial[index];
      final after = finalInventory[index];
      if (before.relativePath != after.relativePath ||
          before.kind != after.kind ||
          before.stat.size != after.stat.size ||
          before.stat.modified.toUtc() != after.stat.modified.toUtc()) {
        throw ProfileSnapshotSourceChangedException(
          'Profile path changed during snapshot capture: '
          '${before.relativePath}',
        );
      }
    }
  }

  Future<_FileDigest> _copyAndVerifyStableSource({
    required File sourceFile,
    required File targetFile,
    required String relativePath,
    required FileStat initialStat,
  }) async {
    if (FileSystemEntity.typeSync(sourceFile.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw ProfileSnapshotSourceChangedException(
        'Source path is no longer a regular file: $relativePath',
      );
    }
    final digestSink = _DigestSink();
    final converter = sha256.startChunkedConversion(digestSink);
    final output = targetFile.openWrite();
    var sizeBytes = 0;
    try {
      await for (final chunk in sourceFile.openRead()) {
        converter.add(chunk);
        output.add(chunk);
        sizeBytes += chunk.length;
      }
      await output.flush();
    } finally {
      converter.close();
      await output.close();
    }
    final copiedSha256 = digestSink.digest.toString();

    await testHooks?.afterFileCopied?.call(
      sourceFile: sourceFile,
      targetFile: targetFile,
      relativePath: relativePath,
    );

    final finalType = FileSystemEntity.typeSync(
      sourceFile.path,
      followLinks: false,
    );
    if (finalType == FileSystemEntityType.notFound) {
      throw ProfileSnapshotSourceChangedException(
        'Source file disappeared during snapshot capture: $relativePath',
      );
    }
    if (finalType != FileSystemEntityType.file) {
      throw ProfileSnapshotSourceChangedException(
        'Source path stopped being a regular file: $relativePath',
      );
    }
    final finalStat = sourceFile.statSync();
    if (initialStat.size != finalStat.size ||
        initialStat.modified.toUtc() != finalStat.modified.toUtc() ||
        sizeBytes != initialStat.size) {
      throw ProfileSnapshotSourceChangedException(
        'Source file changed during snapshot capture: $relativePath',
      );
    }

    await testHooks?.beforeSourceRehash?.call(
      sourceFile: sourceFile,
      relativePath: relativePath,
    );
    final stableSource = await _hashFile(sourceFile);
    if (stableSource.sizeBytes != sizeBytes ||
        stableSource.sha256 != copiedSha256) {
      throw ProfileSnapshotSourceChangedException(
        'Source bytes changed during snapshot capture: $relativePath',
      );
    }
    final copiedTarget = await _hashFile(targetFile);
    if (copiedTarget.sizeBytes != sizeBytes ||
        copiedTarget.sha256 != copiedSha256) {
      throw ProfileSnapshotValidationException(
        'Copied bytes failed verification: $relativePath',
      );
    }
    return _FileDigest(sizeBytes: sizeBytes, sha256: copiedSha256);
  }

  static Future<void> _validateSourceDigests(
    Directory sourceRoot,
    List<BackupManifestFile> records,
  ) async {
    for (final record in records) {
      final sourceFile = File(
        p.joinAll([sourceRoot.path, ...record.relativePath.split('/')]),
      );
      if (!sourceFile.existsSync()) {
        throw ProfileSnapshotSourceChangedException(
          'Source file disappeared before publication: ${record.relativePath}',
        );
      }
      final digest = await _hashFile(sourceFile);
      if (digest.sizeBytes != record.sizeBytes ||
          digest.sha256 != record.sha256) {
        throw ProfileSnapshotSourceChangedException(
          'Source bytes changed before publication: ${record.relativePath}',
        );
      }
    }
  }

  static int _validateSqlite(File databaseFile) {
    Database? database;
    try {
      database = sqlite3.open(
        Uri.file(
          databaseFile.path,
        ).replace(queryParameters: const {'immutable': '1'}).toString(),
        mode: OpenMode.readOnly,
        uri: true,
      );
      final check = database.select('PRAGMA integrity_check');
      if (check.length != 1 || check.single.values.single != 'ok') {
        throw ProfileSnapshotValidationException(
          'SQLite integrity_check failed for ${databaseFile.path}: $check',
        );
      }
      return database.userVersion;
    } on ProfileSnapshotValidationException {
      rethrow;
    } catch (error) {
      throw ProfileSnapshotValidationException(
        'Unable to validate SQLite database: ${databaseFile.path}',
        cause: error,
      );
    } finally {
      database?.close();
    }
  }

  static void _addManifestStore(
    Map<String, BackupManifestStore> target,
    BackupPathDecision decision, {
    int? schemaVersion,
  }) {
    final catalogStore = ProfileBackupCatalog.stores.firstWhere(
      (store) => store.id == decision.storeId,
    );
    final candidate = BackupManifestStore(
      id: catalogStore.id,
      relativePath: catalogStore.relativePath,
      kind: catalogStore.kind,
      sensitivity: catalogStore.sensitivity,
      required: catalogStore.required,
      schemaVersion: schemaVersion,
    );
    final existing = target[decision.storeId];
    if (existing?.schemaVersion == null) {
      target[decision.storeId] = candidate;
    }
  }

  static Future<ProfileBackupManifest> _verifyPartialSnapshot(
    Directory partialDirectory,
  ) async {
    final manifestFile = File(
      p.join(partialDirectory.path, profileBackupManifestFileName),
    );
    if (!manifestFile.existsSync()) {
      throw const ProfileSnapshotValidationException(
        'Staged snapshot manifest is missing.',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(await manifestFile.readAsString());
    } catch (error) {
      throw ProfileSnapshotValidationException(
        'Staged snapshot manifest is not valid JSON.',
        cause: error,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ProfileSnapshotValidationException(
        'Staged snapshot manifest root must be an object.',
      );
    }
    final ProfileBackupManifest manifest;
    try {
      manifest = ProfileBackupManifest.fromJson(decoded);
    } catch (error) {
      throw ProfileSnapshotValidationException(
        'Staged snapshot manifest failed validation.',
        cause: error,
      );
    }
    final payloadDirectory = Directory(
      p.join(partialDirectory.path, profileBackupPayloadDirectoryName),
    );
    final payloadType = FileSystemEntity.typeSync(
      payloadDirectory.path,
      followLinks: false,
    );
    if (payloadType == FileSystemEntityType.notFound) {
      throw const ProfileSnapshotValidationException(
        'Staged snapshot payload is missing.',
      );
    }
    if (payloadType != FileSystemEntityType.directory) {
      throw const ProfileSnapshotValidationException(
        'Staged snapshot payload must be a real directory.',
      );
    }

    final actualPaths = <String>[];
    await for (final entity in payloadDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw const ProfileSnapshotValidationException(
          'Staged snapshot payload may not contain symbolic links.',
        );
      }
      if (type == FileSystemEntityType.file) {
        actualPaths.add(_manifestRelativePath(entity.path, payloadDirectory));
        continue;
      }
      if (type != FileSystemEntityType.directory) {
        throw const ProfileSnapshotValidationException(
          'Staged snapshot payload contains an unsupported filesystem entry.',
        );
      }
    }
    actualPaths.sort();
    final expectedPaths = manifest.files
        .map((file) => file.relativePath)
        .toList(growable: false);
    if (!_sameStrings(actualPaths, expectedPaths)) {
      throw ProfileSnapshotValidationException(
        'Staged payload files do not match the manifest. '
        'actual=$actualPaths expected=$expectedPaths',
      );
    }

    final storesById = {for (final store in manifest.stores) store.id: store};
    for (final record in manifest.files) {
      final file = File(
        p.joinAll([
          payloadDirectory.path,
          ...record.relativePath.split('/'),
        ]),
      );
      final digest = await _hashFile(file);
      if (digest.sizeBytes != record.sizeBytes ||
          digest.sha256 != record.sha256) {
        throw ProfileSnapshotValidationException(
          'Staged file failed checksum verification: ${record.relativePath}',
        );
      }
      if (storesById[record.storeId]?.kind == BackupStoreKind.sqliteDatabase) {
        final schemaVersion = _validateSqlite(file);
        if (schemaVersion != storesById[record.storeId]?.schemaVersion) {
          throw ProfileSnapshotValidationException(
            'SQLite schema version changed for ${record.relativePath}.',
          );
        }
      }
    }
    return manifest;
  }

  static Future<_FileDigest> _hashFile(File file) async {
    final digestSink = _DigestSink();
    final converter = sha256.startChunkedConversion(digestSink);
    var sizeBytes = 0;
    try {
      await for (final chunk in file.openRead()) {
        converter.add(chunk);
        sizeBytes += chunk.length;
      }
    } finally {
      converter.close();
    }
    return _FileDigest(
      sizeBytes: sizeBytes,
      sha256: digestSink.digest.toString(),
    );
  }

  static String _manifestRelativePath(
    String entityPath,
    Directory payloadDirectory,
  ) => p.split(p.relative(entityPath, from: payloadDirectory.path)).join('/');

  static bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

enum _SnapshotEntryKind { file, directory }

@immutable
class _SnapshotSourceEntry {
  const _SnapshotSourceEntry({
    required this.relativePath,
    required this.kind,
    required this.decision,
    required this.stat,
  });

  final String relativePath;
  final _SnapshotEntryKind kind;
  final BackupPathDecision decision;
  final FileStat stat;
}

@immutable
class _FileDigest {
  const _FileDigest({required this.sizeBytes, required this.sha256});

  final int sizeBytes;
  final String sha256;
}

class _DigestSink implements Sink<Digest> {
  late Digest digest;

  @override
  void add(Digest data) => digest = data;

  @override
  void close() {}
}
