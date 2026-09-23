import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/backup_restore/domain/profile_backup_bundle_header.dart';
import 'package:lotti/features/backup_restore/domain/profile_backup_catalog.dart';
import 'package:lotti/features/backup_restore/domain/profile_backup_manifest.dart';
import 'package:lotti/features/backup_restore/service/profile_backup_bundle_codec.dart';
import 'package:lotti/features/backup_restore/service/profile_restore_preflight.dart';
import 'package:lotti/features/backup_restore/service/profile_root_swap.dart';
import 'package:lotti/features/backup_restore/service/quiesced_profile_snapshot_service.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

const _kdf = BackupKdfParameters(memoryKiB: 64, iterations: 1, parallelism: 1);
const _passphrase = 'correct horse battery staple';

void main() {
  late Directory testRoot;
  late Directory profileRoot;
  late Directory staging;
  late Directory bundles;

  setUp(() {
    testRoot = Directory.systemTemp.createTempSync('lotti_preflight_');
    profileRoot = Directory(p.join(testRoot.path, 'profile'))..createSync();
    staging = Directory(p.join(testRoot.path, 'staging'))..createSync();
    bundles = Directory(p.join(testRoot.path, 'bundles'));
    File(p.join(profileRoot.path, 'db.sqlite')).writeAsStringSync('live');
  });

  tearDown(() => testRoot.deleteSync(recursive: true));

  ProfileBackupBundleCodec codec() => ProfileBackupBundleCodec(kdf: _kdf);

  ProfileRestorePreflight preflight() => ProfileRestorePreflight(
    codec: codec(),
    restoreIdGenerator: () => 'r1',
  );

  void writeDatabase(Directory root, String name, {int userVersion = 1}) {
    final database = sqlite3.open(p.join(root.path, name));
    try {
      database
        ..execute('CREATE TABLE probe (value TEXT)')
        ..execute("INSERT INTO probe VALUES ('$name')")
        ..userVersion = userVersion;
    } finally {
      database.close();
    }
  }

  /// A real backup of a real profile, staged and encrypted.
  Future<File> realBundle({String profileType = 'real'}) async {
    final source = Directory(p.join(testRoot.path, 'source'))..createSync();
    writeDatabase(source, 'db.sqlite', userVersion: 40);
    writeDatabase(source, 'settings.sqlite');
    File(p.join(source.path, 'images', 'a.jpg'))
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    final snapshot = await QuiescedProfileSnapshotService().stage(
      sourceRoot: source,
      stagingParent: staging,
      appVersion: '1.1.24+4410',
      profileType: profileType,
    );
    return codec().package(
      snapshot: snapshot,
      outputDirectory: bundles,
      passphrase: _passphrase,
    );
  }

  /// A bundle built from files and a manifest as given, for the cases a real
  /// capture cannot produce.
  Future<File> craftedBundle({
    required Map<String, List<int>> files,
    Map<String, int?> schemaVersions = const {},
    String profileType = 'real',
  }) async {
    final directory = Directory(p.join(staging.path, 'crafted'))..createSync();
    final payload = Directory(p.join(directory.path, 'payload'))..createSync();
    final stores = <BackupManifestStore>[];
    final entries = <BackupManifestFile>[];
    for (final MapEntry(key: path, value: bytes) in files.entries) {
      File(p.join(payload.path, path))
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(bytes);
      final decision = ProfileBackupCatalog.classify(path);
      final isDatabase = decision.kind == BackupStoreKind.sqliteDatabase;
      final storePath = isDatabase || decision.kind == BackupStoreKind.file
          ? path
          : path.split('/').first;
      if (!stores.any((store) => store.id == decision.storeId)) {
        stores.add(
          BackupManifestStore(
            id: decision.storeId,
            relativePath: storePath,
            kind: decision.kind,
            sensitivity: decision.sensitivity,
            required: decision.required,
            schemaVersion: !isDatabase
                ? null
                : schemaVersions.containsKey(decision.storeId)
                ? schemaVersions[decision.storeId]
                : 1,
          ),
        );
      }
      entries.add(
        BackupManifestFile(
          storeId: decision.storeId,
          relativePath: path,
          sizeBytes: bytes.length,
          sha256: sha256.convert(bytes).toString(),
        ),
      );
    }
    final manifest = ProfileBackupManifest(
      createdAt: DateTime.utc(2026, 9, 23),
      appVersion: '1.1.24+4410',
      profileType: profileType,
      stores: stores,
      files: entries,
    );
    File(
      p.join(directory.path, profileBackupManifestFileName),
    ).writeAsStringSync(jsonEncode(manifest.toJson()));
    return codec().package(
      snapshot: StagedProfileSnapshot(
        directory: directory,
        payloadDirectory: payload,
        manifest: manifest,
      ),
      outputDirectory: bundles,
      passphrase: _passphrase,
    );
  }

  List<int> databaseBytes({int userVersion = 1}) {
    final scratch = Directory(p.join(testRoot.path, 'scratch'))
      ..createSync(recursive: true);
    final name = 'db-$userVersion-${scratch.listSync().length}.sqlite';
    writeDatabase(scratch, name, userVersion: userVersion);
    return File(p.join(scratch.path, name)).readAsBytesSync();
  }

  List<int> orphanedPagesDatabaseBytes() {
    final path = p.join(testRoot.path, 'orphaned.sqlite');
    final database = sqlite3.open(path);
    try {
      database
        ..execute('CREATE TABLE probe (value TEXT)')
        ..execute('CREATE INDEX probe_value ON probe (value)');
      for (var i = 0; i < 500; i++) {
        database.execute('INSERT INTO probe VALUES (?)', ['row $i' * 10]);
      }
      database
        ..execute('PRAGMA writable_schema = ON')
        ..execute("DELETE FROM sqlite_master WHERE name = 'probe_value'")
        ..execute('PRAGMA writable_schema = OFF');
    } finally {
      database.close();
    }
    return File(path).readAsBytesSync();
  }

  Future<void> expectRejected(
    Future<File> bundle,
    Matcher error, {
    ProfileType profileType = ProfileType.real,
  }) async {
    final file = await bundle;
    await expectLater(
      preflight().prepare(
        bundle: file,
        passphrase: _passphrase,
        profileRoot: profileRoot,
        profileType: profileType,
      ),
      throwsA(error),
    );
    // Nothing was left behind, and the live profile was never touched.
    expect(
      Directory(
        p.join(profileRoot.path, profileRestoreWorkDirectoryName),
      ).existsSync(),
      isFalse,
    );
    expect(
      File(p.join(profileRoot.path, 'db.sqlite')).readAsStringSync(),
      'live',
    );
  }

  Matcher incompatible(String fragment) =>
      isA<ProfileRestoreIncompatibleException>().having(
        (e) => e.message,
        'message',
        contains(fragment),
      );

  test('stages a valid backup next to the profile, ready to swap', () async {
    final prepared = await preflight().prepare(
      bundle: await realBundle(),
      passphrase: _passphrase,
      profileRoot: profileRoot,
      profileType: ProfileType.real,
    );

    expect(prepared.manifest.profileType, 'real');
    expect(
      prepared.swap.incomingPayload.path,
      p.join(
        profileRoot.path,
        profileRestoreWorkDirectoryName,
        'incoming-r1',
        'payload',
      ),
    );
    expect(
      File(
        p.join(prepared.swap.incomingPayload.path, 'images', 'a.jpg'),
      ).readAsBytesSync(),
      [1, 2, 3],
    );
    // Reading the databases created no SQLite companions to carry along.
    expect(
      prepared.swap.incomingPayload
          .listSync()
          .map((e) => p.basename(e.path))
          .where((name) => name.endsWith('-wal') || name.endsWith('-shm')),
      isEmpty,
    );
    expect(
      File(p.join(profileRoot.path, 'db.sqlite')).readAsStringSync(),
      'live',
    );

    prepared.discard();
    expect(
      Directory(
        p.join(profileRoot.path, profileRestoreWorkDirectoryName),
      ).existsSync(),
      isFalse,
    );
  });

  test('a wrong passphrase leaves no restore folder behind', () async {
    final bundle = await realBundle();

    await expectLater(
      preflight().prepare(
        bundle: bundle,
        passphrase: 'not the passphrase',
        profileRoot: profileRoot,
        profileType: ProfileType.real,
      ),
      throwsA(isA<ProfileBackupWrongPassphraseException>()),
    );
    expect(
      Directory(
        p.join(profileRoot.path, profileRestoreWorkDirectoryName),
      ).existsSync(),
      isFalse,
    );
  });

  test('refuses to start while an earlier restore is pending', () async {
    final bundle = await realBundle();
    final journal =
        File(
            p.join(
              profileRoot.path,
              profileRestoreWorkDirectoryName,
              'restore-journal.json',
            ),
          )
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(
            '{"version":1,"restoreId":"earlier","phase":"restored"}',
          );

    await expectLater(
      preflight().prepare(
        bundle: bundle,
        passphrase: _passphrase,
        profileRoot: profileRoot,
        profileType: ProfileType.real,
      ),
      throwsA(isA<ProfileRestoreSwapException>()),
    );
    // The pending restore is left exactly as it was, for launch to recover.
    expect(
      Directory(
        p.join(profileRoot.path, profileRestoreWorkDirectoryName),
      ).listSync().map((e) => e.path),
      [journal.path],
    );
  });

  test('refuses a backup of another kind of profile', () async {
    await expectRejected(
      realBundle(profileType: 'guest'),
      incompatible('guest profile and cannot replace a real one'),
    );
  });

  test('refuses a backup without a required store', () async {
    await expectRejected(
      craftedBundle(files: {'db.sqlite': databaseBytes()}),
      incompatible('missing settings.sqlite'),
    );
  });

  test('refuses a schema newer than this build reads', () async {
    const newer = JournalDb.currentSchemaVersion + 1;
    await expectRejected(
      craftedBundle(
        files: {
          'db.sqlite': databaseBytes(userVersion: newer),
          'settings.sqlite': databaseBytes(),
        },
        schemaVersions: {'journal': newer},
      ),
      incompatible('newer version of Lotti (db.sqlite schema $newer'),
    );
  });

  test('refuses a known database that declares no schema', () async {
    // Nothing would then hold the file to this build's limit, so a newer
    // database could reach the swap.
    await expectRejected(
      craftedBundle(
        files: {
          'db.sqlite': databaseBytes(userVersion: 999),
          'settings.sqlite': databaseBytes(),
        },
        schemaVersions: {'journal': null},
      ),
      incompatible('declares no schema for db.sqlite'),
    );
  });

  test('accepts an older schema, which Drift migrates', () async {
    final prepared = await preflight().prepare(
      bundle: await craftedBundle(
        files: {
          'db.sqlite': databaseBytes(userVersion: 3),
          'settings.sqlite': databaseBytes(),
        },
        schemaVersions: {'journal': 3},
      ),
      passphrase: _passphrase,
      profileRoot: profileRoot,
      profileType: ProfileType.real,
    );

    expect(
      prepared.manifest.stores
          .firstWhere((s) => s.id == 'journal')
          .schemaVersion,
      3,
    );
  });

  test('refuses a database whose schema disagrees with the manifest', () async {
    await expectRejected(
      craftedBundle(
        files: {
          'db.sqlite': databaseBytes(userVersion: 5),
          'settings.sqlite': databaseBytes(),
        },
        schemaVersions: {'journal': 3},
      ),
      incompatible('db.sqlite has schema 5, but the backup declares 3'),
    );
  });

  test('refuses a file that is not a database', () async {
    await expectRejected(
      craftedBundle(
        files: {
          'db.sqlite': utf8.encode('not a database at all, just text'),
          'settings.sqlite': databaseBytes(),
        },
      ),
      incompatible('db.sqlite is not a readable database'),
    );
  });

  test('refuses a database that fails its integrity check', () async {
    // It opens and reads, but an index was dropped from the schema without
    // freeing its pages: exactly what integrity_check exists to catch.
    await expectRejected(
      craftedBundle(
        files: {
          'db.sqlite': orphanedPagesDatabaseBytes(),
          'settings.sqlite': databaseBytes(),
        },
      ),
      incompatible('db.sqlite failed its integrity check'),
    );
  });

  test('refuses content that would land on a device-owned entry', () async {
    await expectRejected(
      craftedBundle(
        files: {
          'db.sqlite': databaseBytes(),
          'settings.sqlite': databaseBytes(),
          'logs/general.log': utf8.encode('from another device'),
        },
      ),
      incompatible('logs, which belongs to the device'),
    );
  });

  test('describes an incompatibility', () {
    expect(
      const ProfileRestoreIncompatibleException('older app').toString(),
      'ProfileRestoreIncompatibleException: older app',
    );
  });

  test('knows the schema of every database it restores', () {
    final databases = ProfileBackupCatalog.stores.where(
      (store) =>
          store.kind == BackupStoreKind.sqliteDatabase &&
          store.treatment == BackupPathTreatment.include &&
          store.id != 'matrix-sdk',
    );

    expect(
      restorableSchemaVersions.keys.toSet(),
      databases.map((store) => store.id).toSet(),
      reason: 'a new database store needs its schema limit here',
    );
  });
}
