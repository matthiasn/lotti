import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

enum ImagePathMigrationStatus {
  alreadyCorrect,
  migrated,
  metadataUpdated,
  missing,
  conflict,
  invalid,
  failed,
}

class ImagePathMigrationOutcome {
  const ImagePathMigrationOutcome({
    required this.entryId,
    required this.status,
    this.error,
  });

  final String entryId;
  final ImagePathMigrationStatus status;
  final Object? error;
}

class ImagePathMigrationReport {
  ImagePathMigrationReport(Iterable<ImagePathMigrationOutcome> outcomes)
    : outcomes = List.unmodifiable(outcomes);

  final List<ImagePathMigrationOutcome> outcomes;

  int count(ImagePathMigrationStatus status) =>
      outcomes.where((outcome) => outcome.status == status).length;

  int get affected =>
      count(ImagePathMigrationStatus.migrated) +
      count(ImagePathMigrationStatus.metadataUpdated);
}

/// Repairs image entries written by the legacy screenshot path bug.
///
/// The old writer appended `images/...` directly to the documents root and
/// therefore created a sibling directory such as `Documentsimages`. Recovery
/// copies into the canonical documents tree, verifies the bytes, atomically
/// publishes the target, persists corrected metadata, and only then removes
/// the legacy source.
class ImagePathMigrationService {
  ImagePathMigrationService({
    required this.documentsDirectory,
    required this.journalDb,
    required this.persistenceLogic,
    required this.logger,
    this.uuid = const Uuid(),
  });

  static const _batchSize = 200;

  final Directory documentsDirectory;
  final JournalDb journalDb;
  final PersistenceLogic persistenceLogic;
  final DomainLogger logger;
  final Uuid uuid;

  Future<ImagePathMigrationOutcome> _migrateImage(JournalImage image) async {
    final canonicalDirectory = canonicalImageDirectory(
      image.data.imageDirectory,
    );
    final canonicalPath = getCanonicalImagePath(
      image,
      documentsDirectory: documentsDirectory.path,
    );
    final legacyPath = getLegacyMalformedImagePath(
      image,
      documentsDirectory: documentsDirectory.path,
    );

    if (!_isInsideDocuments(canonicalPath)) {
      return _outcome(image, ImagePathMigrationStatus.invalid);
    }

    final canonicalFile = File(canonicalPath);
    final legacyFile = File(legacyPath);
    final metadataNeedsUpdate = image.data.imageDirectory != canonicalDirectory;

    try {
      final canonicalExists = canonicalFile.existsSync();
      final legacyExists =
          p.normalize(legacyPath) != p.normalize(canonicalPath) &&
          legacyFile.existsSync();

      if (canonicalExists && legacyExists) {
        final matches = await _filesMatch(canonicalFile, legacyFile);
        if (!matches && metadataNeedsUpdate) {
          return _outcome(image, ImagePathMigrationStatus.conflict);
        }
      }

      if (!canonicalExists) {
        if (!legacyExists) {
          return _outcome(image, ImagePathMigrationStatus.missing);
        }
        final copied = await _copyVerifiedAtomically(
          source: legacyFile,
          target: canonicalFile,
        );
        if (!copied) {
          return _outcome(image, ImagePathMigrationStatus.conflict);
        }
      }

      if (metadataNeedsUpdate) {
        final updated = image.copyWith(
          data: image.data.copyWith(imageDirectory: canonicalDirectory),
        );
        final persisted = await persistenceLogic.updateJournalEntity(
          updated,
          image.meta,
        );
        if (!persisted) {
          return _outcome(image, ImagePathMigrationStatus.failed);
        }
      }

      if (legacyExists && await _filesMatch(canonicalFile, legacyFile)) {
        _deleteLegacyFiles(
          legacyFile: legacyFile,
          canonicalFile: canonicalFile,
        );
      }

      if (!canonicalExists && legacyExists) {
        return _outcome(image, ImagePathMigrationStatus.migrated);
      }
      if (metadataNeedsUpdate) {
        return _outcome(image, ImagePathMigrationStatus.metadataUpdated);
      }
      return _outcome(image, ImagePathMigrationStatus.alreadyCorrect);
    } catch (error, stackTrace) {
      logger.error(
        LogDomain.persistence,
        error,
        stackTrace: stackTrace,
        subDomain: 'imagePathMigration',
      );
      return ImagePathMigrationOutcome(
        entryId: image.id,
        status: ImagePathMigrationStatus.failed,
        error: error,
      );
    }
  }

  Future<ImagePathMigrationReport> migrateAll() async {
    final outcomes = <ImagePathMigrationOutcome>[];
    var offset = 0;

    try {
      while (true) {
        final page = await journalDb.getJournalEntities(
          types: const ['JournalImage'],
          starredStatuses: const [true, false],
          privateStatuses: const [true, false],
          flaggedStatuses: [for (final flag in EntryFlag.values) flag.index],
          ids: null,
          limit: _batchSize,
          offset: offset,
        );
        final images = page.whereType<JournalImage>();
        for (final image in images) {
          outcomes.add(await _migrateImage(image));
        }
        if (page.length < _batchSize) break;
        offset += page.length;
      }
    } catch (error, stackTrace) {
      logger.error(
        LogDomain.persistence,
        error,
        stackTrace: stackTrace,
        subDomain: 'imagePathMigration',
      );
      outcomes.add(
        ImagePathMigrationOutcome(
          entryId: 'bulk-query',
          status: ImagePathMigrationStatus.failed,
          error: error,
        ),
      );
    }

    final report = ImagePathMigrationReport(outcomes);
    logger.log(
      LogDomain.persistence,
      'Image path migration completed: total=${outcomes.length} '
      'affected=${report.affected} '
      'correct=${report.count(ImagePathMigrationStatus.alreadyCorrect)} '
      'missing=${report.count(ImagePathMigrationStatus.missing)} '
      'conflicts=${report.count(ImagePathMigrationStatus.conflict)} '
      'failed=${report.count(ImagePathMigrationStatus.failed)}',
      subDomain: 'imagePathMigration',
    );
    return report;
  }

  bool _isInsideDocuments(String path) {
    final documentsPath = p.normalize(documentsDirectory.absolute.path);
    final candidate = p.normalize(File(path).absolute.path);
    return candidate == documentsPath || p.isWithin(documentsPath, candidate);
  }

  Future<bool> _copyVerifiedAtomically({
    required File source,
    required File target,
  }) async {
    target.parent.createSync(recursive: true);
    final temporary = File(
      p.join(
        target.parent.path,
        '.${p.basename(target.path)}.${uuid.v4()}.migrating',
      ),
    );
    try {
      source.copySync(temporary.path);
      if (!await _filesMatch(source, temporary)) {
        throw const FileSystemException(
          'Copied screenshot did not match its source',
        );
      }

      if (target.existsSync()) {
        final matches = await _filesMatch(target, temporary);
        return matches;
      }
      temporary.renameSync(target.path);
      return true;
    } finally {
      if (temporary.existsSync()) {
        temporary.deleteSync();
      }
    }
  }

  Future<bool> _filesMatch(File first, File second) async {
    if (!first.existsSync() || !second.existsSync()) return false;
    if (first.lengthSync() != second.lengthSync()) return false;
    final firstDigest = await sha256.bind(first.openRead()).first;
    final secondDigest = await sha256.bind(second.openRead()).first;
    return firstDigest == secondDigest;
  }

  void _deleteLegacyFiles({
    required File legacyFile,
    required File canonicalFile,
  }) {
    legacyFile.deleteSync();
    final legacySidecar = File('${legacyFile.path}.json');
    final canonicalSidecar = File('${canonicalFile.path}.json');
    if (legacySidecar.existsSync() && canonicalSidecar.existsSync()) {
      legacySidecar.deleteSync();
    }
  }

  ImagePathMigrationOutcome _outcome(
    JournalImage image,
    ImagePathMigrationStatus status,
  ) {
    if (status == ImagePathMigrationStatus.missing ||
        status == ImagePathMigrationStatus.conflict ||
        status == ImagePathMigrationStatus.invalid) {
      logger.log(
        LogDomain.persistence,
        'Image path migration ${status.name} for ${image.id}',
        subDomain: 'imagePathMigration',
      );
    }
    return ImagePathMigrationOutcome(entryId: image.id, status: status);
  }
}
