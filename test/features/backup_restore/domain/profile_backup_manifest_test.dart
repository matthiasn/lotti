import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

  ProfileBackupManifest validManifest() => ProfileBackupManifest(
    createdAt: DateTime.utc(2026, 8, 6),
    appVersion: '1.0.4+4285',
    profileType: 'real',
    stores: [journalStore()],
    files: const [
      BackupManifestFile(
        storeId: 'journal',
        relativePath: 'db.sqlite',
        sizeBytes: 1,
        sha256: hashA,
      ),
    ],
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
      final roundTripped = ProfileBackupManifest.fromJson(manifest.toJson());
      expect(roundTripped, manifest);
      expect(roundTripped.hashCode, manifest.hashCode);
      expect(
        roundTripped.stores.first.hashCode,
        manifest.stores.first.hashCode,
      );
      expect(roundTripped.files.first.hashCode, manifest.files.first.hashCode);
      expect(manifest.toJson()['formatVersion'], 1);
      expect(
        manifest.toJson()['catalogVersion'],
        ProfileBackupCatalog.version,
      );
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
          'catalogVersion': ProfileBackupCatalog.version + 1,
        }),
        throwsUnsupportedError,
      );
      expect(
        () => ProfileBackupManifest.fromJson({
          ...json,
          'createdAt': '2026-08-06T00:00:00+02:00',
        }),
        throwsFormatException,
      );
      expect(
        () => ProfileBackupManifest.fromJson({
          ...json,
          'createdAt': 'not-a-dateZ',
        }),
        throwsFormatException,
      );
    });

    test('rejects invalid typed manifest semantics', () {
      const file = BackupManifestFile(
        storeId: 'journal',
        relativePath: 'db.sqlite',
        sizeBytes: 1,
        sha256: hashA,
      );
      final cases = <({String name, void Function() create})>[
        (
          name: 'local creation time',
          create: () => ProfileBackupManifest(
            createdAt: DateTime(2026, 8, 6),
            appVersion: '1.0.4+4285',
            profileType: 'real',
            stores: [journalStore()],
            files: const [file],
          ),
        ),
        (
          name: 'blank app version',
          create: () => ProfileBackupManifest(
            createdAt: DateTime.utc(2026, 8, 6),
            appVersion: '   ',
            profileType: 'real',
            stores: [journalStore()],
            files: const [file],
          ),
        ),
        (
          name: 'unknown profile type',
          create: () => ProfileBackupManifest(
            createdAt: DateTime.utc(2026, 8, 6),
            appVersion: '1.0.4+4285',
            profileType: 'temporary',
            stores: [journalStore()],
            files: const [file],
          ),
        ),
        (
          name: 'invalid store id',
          create: () => ProfileBackupManifest(
            createdAt: DateTime.utc(2026, 8, 6),
            appVersion: '1.0.4+4285',
            profileType: 'real',
            stores: const [
              BackupManifestStore(
                id: 'Invalid_ID',
                relativePath: 'db.sqlite',
                kind: BackupStoreKind.sqliteDatabase,
                sensitivity: BackupSensitivity.personal,
                required: true,
                schemaVersion: 45,
              ),
            ],
            files: const [],
          ),
        ),
        (
          name: 'duplicate store id',
          create: () => ProfileBackupManifest(
            createdAt: DateTime.utc(2026, 8, 6),
            appVersion: '1.0.4+4285',
            profileType: 'real',
            stores: [
              journalStore(),
              const BackupManifestStore(
                id: 'journal',
                relativePath: 'other.sqlite',
                kind: BackupStoreKind.sqliteDatabase,
                sensitivity: BackupSensitivity.personal,
                required: false,
              ),
            ],
            files: const [],
          ),
        ),
        (
          name: 'duplicate store path',
          create: () => ProfileBackupManifest(
            createdAt: DateTime.utc(2026, 8, 6),
            appVersion: '1.0.4+4285',
            profileType: 'real',
            stores: [
              journalStore(),
              const BackupManifestStore(
                id: 'journal-copy',
                relativePath: 'db.sqlite',
                kind: BackupStoreKind.sqliteDatabase,
                sensitivity: BackupSensitivity.personal,
                required: false,
              ),
            ],
            files: const [],
          ),
        ),
        (
          name: 'schema on a directory store',
          create: () => ProfileBackupManifest(
            createdAt: DateTime.utc(2026, 8, 6),
            appVersion: '1.0.4+4285',
            profileType: 'real',
            stores: const [
              BackupManifestStore(
                id: 'media',
                relativePath: 'images',
                kind: BackupStoreKind.directory,
                sensitivity: BackupSensitivity.personal,
                required: false,
                schemaVersion: 1,
              ),
            ],
            files: const [],
          ),
        ),
        (
          name: 'negative schema version',
          create: () => ProfileBackupManifest(
            createdAt: DateTime.utc(2026, 8, 6),
            appVersion: '1.0.4+4285',
            profileType: 'real',
            stores: const [
              BackupManifestStore(
                id: 'journal',
                relativePath: 'db.sqlite',
                kind: BackupStoreKind.sqliteDatabase,
                sensitivity: BackupSensitivity.personal,
                required: true,
                schemaVersion: -1,
              ),
            ],
            files: const [],
          ),
        ),
        (
          name: 'file outside its declared store',
          create: () => ProfileBackupManifest(
            createdAt: DateTime.utc(2026, 8, 6),
            appVersion: '1.0.4+4285',
            profileType: 'real',
            stores: [journalStore()],
            files: const [
              BackupManifestFile(
                storeId: 'journal',
                relativePath: 'other.sqlite',
                sizeBytes: 1,
                sha256: hashA,
              ),
            ],
          ),
        ),
      ];

      for (final testCase in cases) {
        expect(
          testCase.create,
          throwsFormatException,
          reason: testCase.name,
        );
      }
    });

    test('rejects malformed untrusted manifest fields', () {
      final validJson = validManifest().toJson();
      final malformed = <({String name, Map<String, Object?> json})>[
        (
          name: 'zero format version',
          json: {...validJson, 'formatVersion': 0},
        ),
        (
          name: 'zero catalog version',
          json: {...validJson, 'catalogVersion': 0},
        ),
        (
          name: 'empty required string',
          json: {...validJson, 'appVersion': ''},
        ),
        (
          name: 'non-integer schema',
          json: {
            ...validJson,
            'stores': [
              {...journalStore().toJson(), 'schemaVersion': '45'},
            ],
          },
        ),
        (
          name: 'non-boolean required flag',
          json: {
            ...validJson,
            'stores': [
              {...journalStore().toJson(), 'required': 'yes'},
            ],
          },
        ),
        (
          name: 'unknown store kind',
          json: {
            ...validJson,
            'stores': [
              {...journalStore().toJson(), 'kind': 'archive'},
            ],
          },
        ),
        (
          name: 'non-list stores',
          json: {...validJson, 'stores': 'journal'},
        ),
        (
          name: 'non-object store',
          json: {
            ...validJson,
            'stores': [1],
          },
        ),
      ];

      for (final testCase in malformed) {
        expect(
          () => ProfileBackupManifest.fromJson(testCase.json),
          throwsFormatException,
          reason: testCase.name,
        );
      }
    });

    test('reports the specific invalid value and manifest field', () {
      expect(
        () => ProfileBackupManifest(
          createdAt: DateTime.utc(2026, 8, 6),
          appVersion: '1.0.4+4285',
          profileType: 'real',
          stores: [journalStore()],
          files: const [
            BackupManifestFile(
              storeId: 'journal',
              relativePath: 'db.sqlite',
              sizeBytes: -1,
              sha256: hashA,
            ),
          ],
        ),
        throwsA(
          isA<FormatException>()
              .having(
                (error) => error.message,
                'message',
                contains('db.sqlite'),
              )
              .having((error) => error.source, 'source', -1),
        ),
      );

      final validJson = validManifest().toJson();
      expect(
        () => ProfileBackupManifest.fromJson({
          ...validJson,
          'stores': const [
            <Object?, Object?>{1: 'journal'},
          ],
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('field stores'),
          ),
        ),
      );
    });
  });

  group('manifest properties', () {
    glados.Glados2(
      glados.any.manifestParts,
      glados.IntAnys(glados.any).intInRange(0, 20),
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'a manifest survives JSON and ignores the order it was given in',
      (parts, rotation) {
        ProfileBackupManifest build(
          List<BackupManifestStore> stores,
          List<BackupManifestFile> files,
        ) => ProfileBackupManifest(
          createdAt: parts.createdAt,
          appVersion: '1.0.4+4285',
          profileType: parts.guest ? 'guest' : 'real',
          stores: stores,
          files: files,
        );
        final manifest = build(parts.stores, parts.files);
        final shuffled = build(
          _rotate(parts.stores.reversed.toList(), rotation),
          _rotate(parts.files.reversed.toList(), rotation),
        );
        final wire =
            jsonDecode(jsonEncode(manifest.toJson())) as Map<String, Object?>;

        expect(ProfileBackupManifest.fromJson(wire), manifest);
        expect(ProfileBackupManifest.fromJson(manifest.toJson()), manifest);
        expect(shuffled, manifest);
        expect(shuffled.toJson(), manifest.toJson());
        expect(
          manifest.files.map((f) => f.relativePath).toList(),
          [...parts.files.map((f) => f.relativePath)]..sort(),
        );
      },
      tags: 'glados',
    );
  });
}

List<T> _rotate<T>(List<T> items, int by) => items.isEmpty
    ? items
    : [...items.skip(by % items.length), ...items.take(by % items.length)];

typedef _ManifestParts = ({
  DateTime createdAt,
  bool guest,
  List<BackupManifestStore> stores,
  List<BackupManifestFile> files,
});

extension _AnyManifestParts on glados.Any {
  /// One to four directory stores (`dir-0` → `d0`, …) and a SQLite store,
  /// with up to eight distinct files spread over them.
  glados.Generator<_ManifestParts> get manifestParts =>
      glados.CombinableAny(this).combine4(
        glados.IntAnys(this).intInRange(0, 4102444800000),
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(1, 5),
        glados.ListAnys(this).listWithLengthInRange(
          0,
          9,
          glados.CombinableAny(this).combine3(
            glados.IntAnys(this).intInRange(0, 5),
            glados.IntAnys(this).intInRange(0, 6),
            glados.IntAnys(this).intInRange(0, 100000),
            (int store, int name, int size) => (store, name, size),
          ),
        ),
        (
          int millis,
          bool guest,
          int directories,
          List<(int, int, int)> fileSpecs,
        ) {
          final stores = [
            for (var i = 0; i < directories; i++)
              BackupManifestStore(
                id: 'dir-$i',
                relativePath: 'd$i',
                kind: BackupStoreKind.directory,
                sensitivity: BackupSensitivity.values[i % 3],
                required: i.isEven,
              ),
            const BackupManifestStore(
              id: 'journal',
              relativePath: 'db.sqlite',
              kind: BackupStoreKind.sqliteDatabase,
              sensitivity: BackupSensitivity.personal,
              required: true,
              schemaVersion: 45,
            ),
          ];
          final files = <String, BackupManifestFile>{};
          for (final (store, name, size) in fileSpecs) {
            final file = store >= directories
                ? BackupManifestFile(
                    storeId: 'journal',
                    relativePath: 'db.sqlite',
                    sizeBytes: size,
                    sha256: 'a' * 64,
                  )
                : BackupManifestFile(
                    storeId: 'dir-$store',
                    relativePath: 'd$store/sub$name/file$name.bin',
                    sizeBytes: size,
                    sha256: (name.toRadixString(16) * 64).substring(0, 64),
                  );
            files.putIfAbsent(file.relativePath, () => file);
          }
          return (
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              millis,
              isUtc: true,
            ).add(Duration(microseconds: millis % 1000)),
            guest: guest,
            stores: stores,
            files: files.values.toList(),
          );
        },
      );
}
