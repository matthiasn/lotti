import 'dart:io';

import 'package:path/path.dart' as p;

/// Names, retention and leftover cleanup for backup bundles on disk.
///
/// Every rule here matches the exact names Lotti creates and nothing else, so
/// pointing it at a directory that also holds the user's own files can never
/// delete them.
abstract final class ProfileBackupBundleStore {
  /// File extension of a published bundle.
  static const extension = '.lottibackup';

  static final _bundleName = RegExp(
    r'^lotti-backup-(\d{8}T\d{6}Z)-([0-9a-f]{8})\.lottibackup$',
  );
  static final _partialBundleName = RegExp(
    r'^\.lotti-backup-\d{8}T\d{6}Z-[0-9a-f]{8}\.lottibackup\.partial$',
  );
  static final _stagedSnapshotName = RegExp(
    r'^profile-snapshot-[A-Za-z0-9_-]+$',
  );
  static final _partialSnapshotName = RegExp(
    r'^\.profile-snapshot-[A-Za-z0-9_-]+\.partial-',
  );

  /// `lotti-backup-20260922T201500Z-a1b2c3d4.lottibackup`: sortable by time,
  /// unique by the random [suffix], and free of anything about the profile.
  static String bundleFileName({
    required DateTime createdAt,
    required String suffix,
  }) {
    final utc = createdAt.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}'
        '${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
    final name = 'lotti-backup-$stamp-$suffix$extension';
    if (!_bundleName.hasMatch(name)) {
      throw ArgumentError.value(suffix, 'suffix', 'must be 8 lowercase hex');
    }
    return name;
  }

  /// Hidden name a bundle is written under until it has been verified.
  static String partialFileName(String bundleFileName) =>
      '.$bundleFileName.partial';

  /// The published bundles in [directory], newest first. Bundles sort by
  /// their timestamp, then by name, so the order never depends on file
  /// system metadata.
  static List<File> bundlesIn(Directory directory) {
    if (!directory.existsSync()) return const [];
    final bundles =
        directory
            .listSync(followLinks: false)
            .whereType<File>()
            .where((file) => _bundleName.hasMatch(p.basename(file.path)))
            .toList()
          ..sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    return bundles;
  }

  /// Deletes all but the [keep] newest bundles in [directory] and returns
  /// the deleted files, oldest last.
  static List<File> applyRetention(Directory directory, {required int keep}) {
    if (keep < 1) {
      throw ArgumentError.value(keep, 'keep', 'must keep at least one backup');
    }
    final expired = bundlesIn(directory).skip(keep).toList();
    for (final bundle in expired) {
      bundle.deleteSync();
    }
    return expired;
  }

  /// Removes what an interrupted backup leaves behind: partial bundles in
  /// [outputDirectory], and staged or partially staged snapshots — which are
  /// plaintext — in [stagingParent]. Returns the removed paths.
  ///
  /// Must not run while a backup is in progress, since it would delete that
  /// backup's work in flight.
  static List<String> removeLeftovers({
    required Directory outputDirectory,
    required Directory stagingParent,
  }) {
    final removed = <String>[];
    if (outputDirectory.existsSync()) {
      for (final entity in outputDirectory.listSync(followLinks: false)) {
        if (entity is File &&
            _partialBundleName.hasMatch(p.basename(entity.path))) {
          entity.deleteSync();
          removed.add(entity.path);
        }
      }
    }
    if (stagingParent.existsSync()) {
      for (final entity in stagingParent.listSync(followLinks: false)) {
        final name = p.basename(entity.path);
        if (entity is Directory &&
            (_stagedSnapshotName.hasMatch(name) ||
                _partialSnapshotName.hasMatch(name))) {
          entity.deleteSync(recursive: true);
          removed.add(entity.path);
        }
      }
    }
    return removed..sort();
  }
}
