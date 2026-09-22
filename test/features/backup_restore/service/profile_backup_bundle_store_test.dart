import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/backup_restore/service/profile_backup_bundle_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory backups;
  late Directory staging;

  setUp(() {
    root = Directory.systemTemp.createTempSync('lotti_bundle_store_');
    backups = Directory(p.join(root.path, 'backups'))..createSync();
    staging = Directory(p.join(root.path, 'staging'))..createSync();
  });

  tearDown(() => root.deleteSync(recursive: true));

  File touch(Directory directory, String name) =>
      File(p.join(directory.path, name))..writeAsStringSync(name);

  List<String> names(Iterable<FileSystemEntity> entities) =>
      entities.map((e) => p.basename(e.path)).toList();

  group('bundleFileName', () {
    test('stamps the UTC creation time and the random suffix', () {
      expect(
        ProfileBackupBundleStore.bundleFileName(
          createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
          suffix: '0a1b2c3d',
        ),
        'lotti-backup-20260102T030405Z-0a1b2c3d.lottibackup',
      );
    });

    test('converts a local time to UTC', () {
      final local = DateTime(2026, 9, 22, 20, 15, 30);

      expect(
        ProfileBackupBundleStore.bundleFileName(
          createdAt: local,
          suffix: 'ffffffff',
        ),
        ProfileBackupBundleStore.bundleFileName(
          createdAt: local.toUtc(),
          suffix: 'ffffffff',
        ),
      );
    });

    for (final suffix in ['ABCDEF12', 'abc', '../../x', 'abcdefg1']) {
      test('rejects the suffix "$suffix"', () {
        expect(
          () => ProfileBackupBundleStore.bundleFileName(
            createdAt: DateTime.utc(2026),
            suffix: suffix,
          ),
          throwsArgumentError,
        );
      });
    }

    test('hides a partial bundle behind a dot', () {
      expect(
        ProfileBackupBundleStore.partialFileName('lotti-backup-x.lottibackup'),
        '.lotti-backup-x.lottibackup.partial',
      );
    });
  });

  group('retention', () {
    const oldest = 'lotti-backup-20260101T000000Z-00000000.lottibackup';
    const older = 'lotti-backup-20260301T000000Z-00000000.lottibackup';
    const newerSameSecond =
        'lotti-backup-20260601T000000Z-00000001.lottibackup';
    const newer = 'lotti-backup-20260601T000000Z-00000000.lottibackup';
    const newest = 'lotti-backup-20260922T201500Z-abcdef01.lottibackup';

    void createBundles() {
      // Created out of order, so nothing can depend on creation or mtime.
      for (final name in [newer, oldest, newest, older, newerSameSecond]) {
        touch(backups, name);
      }
    }

    test('lists bundles newest first by name, not by file time', () {
      createBundles();
      touch(backups, 'notes.txt');
      touch(backups, '.$newest.partial');
      Directory(
        p.join(
          backups.path,
          'lotti-backup-20990101T000000Z-00000000.lottibackup',
        ),
      ).createSync();

      expect(names(ProfileBackupBundleStore.bundlesIn(backups)), [
        newest,
        newerSameSecond,
        newer,
        older,
        oldest,
      ]);
    });

    test('keeps the newest and deletes only expired bundles', () {
      createBundles();
      touch(backups, 'my-own-file.lottibackup');

      final deleted = ProfileBackupBundleStore.applyRetention(backups, keep: 2);

      expect(names(deleted), [newer, older, oldest]);
      expect(
        names(backups.listSync())..sort(),
        [
          'my-own-file.lottibackup',
          newerSameSecond,
          newest,
        ]..sort(),
      );
    });

    test('keeping more than exist deletes nothing', () {
      createBundles();

      expect(
        ProfileBackupBundleStore.applyRetention(backups, keep: 10),
        isEmpty,
      );
      expect(backups.listSync(), hasLength(5));
    });

    test('never deletes the last backup', () {
      createBundles();

      expect(
        () => ProfileBackupBundleStore.applyRetention(backups, keep: 0),
        throwsArgumentError,
      );
      expect(backups.listSync(), hasLength(5));
    });

    test('a missing directory holds no bundles', () {
      expect(
        ProfileBackupBundleStore.bundlesIn(
          Directory(p.join(root.path, 'none')),
        ),
        isEmpty,
      );
    });
  });

  group('removeLeftovers', () {
    test('removes partial bundles and plaintext stages, and nothing else', () {
      const published = 'lotti-backup-20260922T201500Z-abcdef01.lottibackup';
      touch(backups, published);
      final partial = touch(
        backups,
        '.lotti-backup-20260922T201600Z-abcdef02.lottibackup.partial',
      );
      touch(backups, 'user-notes.partial');
      final stagedSnapshot = Directory(
        p.join(staging.path, 'profile-snapshot-1234'),
      )..createSync();
      File(
        p.join(stagedSnapshot.path, 'manifest.json'),
      ).writeAsStringSync('{}');
      final partialSnapshot = Directory(
        p.join(staging.path, '.profile-snapshot-1234.partial-XyZ9'),
      )..createSync();
      Directory(
        p.join(staging.path, 'profile-snapshot-notes.d.bak'),
      ).createSync();
      touch(staging, 'profile-snapshot-file');

      final removed = ProfileBackupBundleStore.removeLeftovers(
        outputDirectory: backups,
        stagingParent: staging,
      );

      expect(
        removed,
        [
          partial.path,
          partialSnapshot.path,
          stagedSnapshot.path,
        ]..sort(),
      );
      expect(
        names(backups.listSync())..sort(),
        [
          published,
          'user-notes.partial',
        ]..sort(),
      );
      expect(names(staging.listSync())..sort(), [
        'profile-snapshot-file',
        'profile-snapshot-notes.d.bak',
      ]);
    });

    test('keeps a directory that only starts like a partial snapshot', () {
      final nearMatch = Directory(
        p.join(staging.path, '.profile-snapshot-1234.partial-XyZ9.user-data'),
      )..createSync();

      expect(
        ProfileBackupBundleStore.removeLeftovers(
          outputDirectory: backups,
          stagingParent: staging,
        ),
        isEmpty,
      );
      expect(nearMatch.existsSync(), isTrue);
    });

    test('removes a partial snapshot named by the platform itself', () {
      // The snapshot service names its partial directory with createTemp; the
      // pattern has to match whatever suffix this platform generates.
      final partial = staging.createTempSync('.profile-snapshot-1234.partial-');

      expect(
        ProfileBackupBundleStore.removeLeftovers(
          outputDirectory: backups,
          stagingParent: staging,
        ),
        [partial.path],
      );
      expect(partial.existsSync(), isFalse);
    });

    test('tolerates directories that do not exist', () {
      expect(
        ProfileBackupBundleStore.removeLeftovers(
          outputDirectory: Directory(p.join(root.path, 'no-backups')),
          stagingParent: Directory(p.join(root.path, 'no-staging')),
        ),
        isEmpty,
      );
    });
  });
}
