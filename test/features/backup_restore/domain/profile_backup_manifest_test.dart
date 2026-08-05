import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/backup_restore/domain/profile_backup_catalog.dart';
import 'package:lotti/features/backup_restore/domain/profile_backup_manifest.dart';

void main() {
  const hashA =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const hashB =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  BackupManifestStore journalStore() => const BackupManifestStore(
    id: 'journal',
    relativePath: 'db.sqlite',
    kind: BackupStoreKind.sqliteDatabase,
    sensitivity: BackupSensitivity.personal,
    required: true,
    schemaVersion: 45,
  );

  group('ProfileBackupManifest', () {
    test('round-trips a deterministic, path-sorted manifest', () {
      final manifest = ProfileBackupManifest(
        createdAt: DateTime.utc(2026, 8, 6, 12, 30),
        appVersion: '1.0.4+4285',
        profileType: 'real',
        stores: [
          journalStore(),
          const BackupManifestStore(
            id: 'media',
            relativePath: 'images',
            kind: BackupStoreKind.directory,
            sensitivity: BackupSensitivity.personal,
            required: false,
          ),
        ],
        files: const [
          BackupManifestFile(
            storeId: 'media',
            relativePath: 'images/entry.jpg',
            sizeBytes: 4,
            sha256: hashB,
          ),
          BackupManifestFile(
            storeId: 'journal',
            relativePath: 'db.sqlite',
            sizeBytes: 1024,
            sha256: hashA,
          ),
        ],
      );

      expect(
        manifest.files.map((file) => file.relativePath),
        ['db.sqlite', 'images/entry.jpg'],
      );
      expect(
        ProfileBackupManifest.fromJson(manifest.toJson()),
        manifest,
      );
      expect(manifest.toJson()['formatVersion'], 1);
      expect(manifest.toJson()['catalogVersion'], 1);
    });

    test('rejects files that do not resolve to a declared store', () {
      expect(
        () => ProfileBackupManifest(
          createdAt: DateTime.utc(2026, 8, 6),
          appVersion: '1.0.4+4285',
          profileType: 'real',
          stores: [journalStore()],
          files: const [
            BackupManifestFile(
              storeId: 'missing',
              relativePath: 'db.sqlite',
              sizeBytes: 1,
              sha256: hashA,
            ),
          ],
        ),
        throwsFormatException,
      );
    });

    test('represents forward-compatible files with an opaque root store', () {
      final manifest = ProfileBackupManifest(
        createdAt: DateTime.utc(2026, 8, 6),
        appVersion: '1.0.4+4285',
        profileType: 'real',
        stores: const [
          BackupManifestStore(
            id: 'profile-content',
            relativePath: '',
            kind: BackupStoreKind.opaqueProfileContent,
            sensitivity: BackupSensitivity.personal,
            required: false,
          ),
        ],
        files: const [
          BackupManifestFile(
            storeId: 'profile-content',
            relativePath: 'future_feature/data.bin',
            sizeBytes: 1,
            sha256: hashA,
          ),
        ],
      );

      expect(ProfileBackupManifest.fromJson(manifest.toJson()), manifest);
    });

    test('rejects duplicate, unsafe, and malformed file records', () {
      final base = <String, Object?>{
        'formatVersion': 1,
        'catalogVersion': 1,
        'createdAt': '2026-08-06T00:00:00.000Z',
        'appVersion': '1.0.4+4285',
        'profileType': 'real',
        'stores': [journalStore().toJson()],
      };

      for (final files in [
        [
          {
            'storeId': 'journal',
            'relativePath': 'db.sqlite',
            'sizeBytes': 1,
            'sha256': hashA,
          },
          {
            'storeId': 'journal',
            'relativePath': 'db.sqlite',
            'sizeBytes': 1,
            'sha256': hashA,
          },
        ],
        [
          {
            'storeId': 'journal',
            'relativePath': '../db.sqlite',
            'sizeBytes': 1,
            'sha256': hashA,
          },
        ],
        [
          {
            'storeId': 'journal',
            'relativePath': 'db.sqlite',
            'sizeBytes': -1,
            'sha256': hashA,
          },
        ],
        [
          {
            'storeId': 'journal',
            'relativePath': 'db.sqlite',
            'sizeBytes': 1,
            'sha256': 'not-a-sha256',
          },
        ],
      ]) {
        expect(
          () => ProfileBackupManifest.fromJson({...base, 'files': files}),
          throwsFormatException,
        );
      }
    });

    test('rejects future formats and non-UTC creation timestamps', () {
      final json = ProfileBackupManifest(
        createdAt: DateTime.utc(2026, 8, 6),
        appVersion: '1.0.4+4285',
        profileType: 'guest',
        stores: [journalStore()],
        files: const [
          BackupManifestFile(
            storeId: 'journal',
            relativePath: 'db.sqlite',
            sizeBytes: 1,
            sha256: hashA,
          ),
        ],
      ).toJson();

      expect(
        () => ProfileBackupManifest.fromJson({...json, 'formatVersion': 2}),
        throwsUnsupportedError,
      );
      expect(
        () => ProfileBackupManifest.fromJson({
          ...json,
          'createdAt': '2026-08-06T00:00:00+02:00',
        }),
        throwsFormatException,
      );
    });
  });
}
