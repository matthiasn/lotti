import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/backup_restore/domain/profile_backup_manifest.dart';
import 'package:lotti/features/backup_restore/service/quiesced_profile_snapshot_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory testRoot;
  late Directory sourceRoot;
  late Directory stagingParent;

  setUp(() {
    testRoot = Directory.systemTemp.createTempSync('lotti_snapshot_test_');
    sourceRoot = Directory(p.join(testRoot.path, 'source'))
      ..createSync(recursive: true);
    stagingParent = Directory(p.join(testRoot.path, 'staging'))
      ..createSync(recursive: true);
  });

  tearDown(() {
    if (testRoot.existsSync()) {
      testRoot.deleteSync(recursive: true);
    }
  });

  void createWalDatabase(
    String relativePath, {
    required int schemaVersion,
    required String value,
  }) {
    final file = File(p.join(sourceRoot.path, relativePath));
    file.parent.createSync(recursive: true);
    final database = sqlite3.open(file.path);
    try {
      database
        ..execute('PRAGMA journal_mode = WAL')
        ..execute('CREATE TABLE snapshot_probe (value TEXT NOT NULL)')
        ..execute('INSERT INTO snapshot_probe VALUES (?)', [value])
        ..execute('PRAGMA user_version = $schemaVersion');
      expect(
        File('${file.path}-wal').existsSync(),
        isTrue,
        reason: 'the fixture must exercise a database that was WAL-backed',
      );
    } finally {
      database.dispose();
    }
  }

  void createRequiredDatabases() {
    createWalDatabase(
      'db.sqlite',
      schemaVersion: 45,
      value: 'committed journal value',
    );
    createWalDatabase(
      'settings.sqlite',
      schemaVersion: 1,
      value: 'profile setting',
    );
  }

  QuiescedProfileSnapshotService service({
    ProfileSnapshotTestHooks? hooks,
  }) => QuiescedProfileSnapshotService(
    snapshotIdGenerator: () => 'snapshot-id',
    now: () => DateTime.utc(2026, 8, 6, 12, 30),
    testHooks: hooks,
  );

  group('QuiescedProfileSnapshotService', () {
    test('reports actionable exception diagnostics', () {
      expect(
        const ProfileSnapshotException('capture failed').toString(),
        'ProfileSnapshotException: capture failed',
      );
      expect(
        const ProfileSnapshotException(
          'capture failed',
          cause: FileSystemException('disk unavailable'),
        ).toString(),
        contains('disk unavailable'),
      );
    });

    test('rejects a missing source before creating staging output', () async {
      sourceRoot.deleteSync(recursive: true);

      await expectLater(
        service().stage(
          sourceRoot: sourceRoot,
          stagingParent: stagingParent,
          appVersion: '1.0.4+4285',
          profileType: 'real',
        ),
        throwsA(
          isA<ProfileSnapshotException>().having(
            (error) => error.message,
            'message',
            contains('does not exist'),
          ),
        ),
      );
      expect(stagingParent.listSync(), isEmpty);
    });

    test('rejects an unsafe generated snapshot id', () async {
      createRequiredDatabases();
      final unsafeService = QuiescedProfileSnapshotService(
        snapshotIdGenerator: () => '../escape',
      );

      await expectLater(
        unsafeService.stage(
          sourceRoot: sourceRoot,
          stagingParent: stagingParent,
          appVersion: '1.0.4+4285',
          profileType: 'real',
        ),
        throwsA(
          isA<ProfileSnapshotException>().having(
            (error) => error.message,
            'message',
            contains('unsafe path characters'),
          ),
        ),
      );
      expect(stagingParent.listSync(), isEmpty);
    });

    test('preserves an existing snapshot destination', () async {
      createRequiredDatabases();
      final existing = Directory(
        p.join(stagingParent.path, 'profile-snapshot-snapshot-id'),
      )..createSync();
      final sentinel = File(p.join(existing.path, 'sentinel'))
        ..writeAsStringSync('keep me');

      await expectLater(
        service().stage(
          sourceRoot: sourceRoot,
          stagingParent: stagingParent,
          appVersion: '1.0.4+4285',
          profileType: 'real',
        ),
        throwsA(
          isA<ProfileSnapshotException>().having(
            (error) => error.message,
            'message',
            contains('already exists'),
          ),
        ),
      );
      expect(sentinel.readAsStringSync(), 'keep me');
      expect(
        stagingParent.listSync().map((entry) => entry.path),
        [existing.path],
      );
    });

    test('requires every mandatory authoritative store', () async {
      createWalDatabase(
        'settings.sqlite',
        schemaVersion: 1,
        value: 'profile setting',
      );

      await expectLater(
        service().stage(
          sourceRoot: sourceRoot,
          stagingParent: stagingParent,
          appVersion: '1.0.4+4285',
          profileType: 'real',
        ),
        throwsA(
          isA<ProfileSnapshotValidationException>().having(
            (error) => error.message,
            'message',
            contains('db.sqlite'),
          ),
        ),
      );
      expect(stagingParent.listSync(), isEmpty);
    });

    test('rejects symbolic links in included source content', () async {
      createRequiredDatabases();
      final external = File(p.join(testRoot.path, 'outside.jpg'))
        ..writeAsStringSync('outside');
      final images = Directory(p.join(sourceRoot.path, 'images'))..createSync();
      Link(p.join(images.path, 'linked.jpg')).createSync(external.path);

      await expectLater(
        service().stage(
          sourceRoot: sourceRoot,
          stagingParent: stagingParent,
          appVersion: '1.0.4+4285',
          profileType: 'real',
        ),
        throwsA(
          isA<ProfileSnapshotException>().having(
            (error) => error.message,
            'message',
            contains('symbolic links'),
          ),
        ),
      );
      expect(stagingParent.listSync(), isEmpty);
    });

    test('rejects a staging symlink that resolves inside the source', () async {
      createRequiredDatabases();
      final stagingLink = Link(p.join(testRoot.path, 'staging-link'))
        ..createSync(sourceRoot.path);

      await expectLater(
        service().stage(
          sourceRoot: sourceRoot,
          stagingParent: Directory(stagingLink.path),
          appVersion: '1.0.4+4285',
          profileType: 'real',
        ),
        throwsA(
          isA<ProfileSnapshotException>().having(
            (error) => error.message,
            'message',
            contains('Resolved snapshot source'),
          ),
        ),
      );
      expect(stagingParent.listSync(), isEmpty);
    });

    test(
      'stages a verified closed WAL world and omits non-authority',
      () async {
        createRequiredDatabases();
        final includedFiles = <String, List<int>>{
          'images/2026-08-06/photo.jpg': [1, 2, 3, 4],
          'audio/2026-08-06/recording.m4a': [5, 6, 7],
          'agent_entities/agent.json': utf8.encode('{"agent":true}'),
          'future_feature/data.bin': [8, 9],
        };
        for (final entry in includedFiles.entries) {
          final file = File(p.join(sourceRoot.path, entry.key));
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(entry.value);
        }

        for (final path in [
          'logs/general.log',
          'backup/legacy.sqlite',
          'guest_profiles/guest/db.sqlite',
          'objectbox_embeddings_sharded/default/data.mdb',
          'audio_waveforms/ab/cache.json',
          'fts5_db.sqlite',
        ]) {
          final file = File(p.join(sourceRoot.path, path));
          file.parent.createSync(recursive: true);
          file.writeAsStringSync('not part of the snapshot');
        }
        File(p.join(sourceRoot.path, 'profiles.json')).writeAsStringSync('{}');

        final snapshot = await service().stage(
          sourceRoot: sourceRoot,
          stagingParent: stagingParent,
          appVersion: '1.0.4+4285',
          profileType: 'real',
        );

        expect(
          p.basename(snapshot.directory.path),
          'profile-snapshot-snapshot-id',
        );
        expect(snapshot.directory.existsSync(), isTrue);
        expect(
          stagingParent.listSync().where(
            (entry) => p.basename(entry.path).contains('.partial'),
          ),
          isEmpty,
        );

        final manifestPaths = snapshot.manifest.files
            .map((file) => file.relativePath)
            .toList(growable: false);
        expect(manifestPaths, orderedEquals([...manifestPaths]..sort()));
        expect(
          manifestPaths,
          containsAll(<String>[
            'db.sqlite',
            'settings.sqlite',
            ...includedFiles.keys,
          ]),
        );
        for (final excludedPath in [
          'logs/general.log',
          'backup/legacy.sqlite',
          'guest_profiles/guest/db.sqlite',
          'objectbox_embeddings_sharded/default/data.mdb',
          'audio_waveforms/ab/cache.json',
          'fts5_db.sqlite',
          'profiles.json',
        ]) {
          expect(manifestPaths, isNot(contains(excludedPath)));
        }

        final stores = {
          for (final store in snapshot.manifest.stores) store.id: store,
        };
        expect(stores['journal']?.schemaVersion, 45);
        expect(stores['settings']?.schemaVersion, 1);
        expect(stores['profile-content']?.relativePath, isEmpty);

        for (final record in snapshot.manifest.files) {
          final copied = File(
            p.join(snapshot.payloadDirectory.path, record.relativePath),
          );
          expect(copied.existsSync(), isTrue, reason: record.relativePath);
          expect(copied.lengthSync(), record.sizeBytes);
          expect(
            sha256.convert(copied.readAsBytesSync()).toString(),
            record.sha256,
          );
        }

        final restoredJournal = sqlite3.open(
          p.join(snapshot.payloadDirectory.path, 'db.sqlite'),
          mode: OpenMode.readOnly,
        );
        try {
          expect(
            restoredJournal
                .select(
                  'SELECT value FROM snapshot_probe',
                )
                .single['value'],
            'committed journal value',
          );
        } finally {
          restoredJournal.dispose();
        }

        final manifestJson =
            jsonDecode(
                  File(
                    p.join(
                      snapshot.directory.path,
                      profileBackupManifestFileName,
                    ),
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(
          ProfileBackupManifest.fromJson(manifestJson),
          snapshot.manifest,
        );
      },
    );

    test('rejects an SQLite companion and removes the partial stage', () async {
      createRequiredDatabases();
      File(
        p.join(sourceRoot.path, 'future_store.sqlite-wal'),
      ).writeAsBytesSync([1, 2, 3]);

      await expectLater(
        service().stage(
          sourceRoot: sourceRoot,
          stagingParent: stagingParent,
          appVersion: '1.0.4+4285',
          profileType: 'real',
        ),
        throwsA(isA<ProfileSnapshotException>()),
      );
      expect(stagingParent.listSync(), isEmpty);
    });

    test(
      'detects same-size source mutation even with restored mtime',
      () async {
        createRequiredDatabases();
        final source = File(p.join(sourceRoot.path, 'images/photo.jpg'));
        source.parent.createSync(recursive: true);
        source.writeAsStringSync('AAAA');
        final originalModified = source.lastModifiedSync();
        var mutated = false;

        await expectLater(
          service(
            hooks: ProfileSnapshotTestHooks(
              afterFileCopied:
                  ({
                    required sourceFile,
                    required targetFile,
                    required relativePath,
                  }) async {
                    if (!mutated && relativePath == 'images/photo.jpg') {
                      mutated = true;
                      sourceFile
                        ..writeAsStringSync('BBBB')
                        ..setLastModifiedSync(originalModified);
                    }
                  },
            ),
          ).stage(
            sourceRoot: sourceRoot,
            stagingParent: stagingParent,
            appVersion: '1.0.4+4285',
            profileType: 'real',
          ),
          throwsA(isA<ProfileSnapshotSourceChangedException>()),
        );
        expect(mutated, isTrue);
        expect(stagingParent.listSync(), isEmpty);
      },
    );

    test('detects a file added after the initial inventory scan', () async {
      createRequiredDatabases();
      var added = false;

      await expectLater(
        service(
          hooks: ProfileSnapshotTestHooks(
            afterFileCopied:
                ({
                  required sourceFile,
                  required targetFile,
                  required relativePath,
                }) async {
                  if (!added && relativePath == 'settings.sqlite') {
                    added = true;
                    final file = File(
                      p.join(sourceRoot.path, 'images/late.jpg'),
                    );
                    file.parent.createSync(recursive: true);
                    file.writeAsStringSync('late');
                  }
                },
          ),
        ).stage(
          sourceRoot: sourceRoot,
          stagingParent: stagingParent,
          appVersion: '1.0.4+4285',
          profileType: 'real',
        ),
        throwsA(
          isA<ProfileSnapshotSourceChangedException>().having(
            (error) => error.message,
            'message',
            contains('inventory changed'),
          ),
        ),
      );
      expect(added, isTrue);
      expect(stagingParent.listSync(), isEmpty);
    });

    test('detects metadata drift in the final inventory scan', () async {
      createRequiredDatabases();
      final image = File(p.join(sourceRoot.path, 'images/photo.jpg'));
      image.parent.createSync(recursive: true);
      image.writeAsStringSync('original');
      var mutated = false;

      await expectLater(
        service(
          hooks: ProfileSnapshotTestHooks(
            afterFileCopied:
                ({
                  required sourceFile,
                  required targetFile,
                  required relativePath,
                }) async {
                  if (!mutated && relativePath == 'settings.sqlite') {
                    mutated = true;
                    image.writeAsStringSync('changed size');
                  }
                },
          ),
        ).stage(
          sourceRoot: sourceRoot,
          stagingParent: stagingParent,
          appVersion: '1.0.4+4285',
          profileType: 'real',
        ),
        throwsA(
          isA<ProfileSnapshotSourceChangedException>().having(
            (error) => error.message,
            'message',
            contains('images/photo.jpg'),
          ),
        ),
      );
      expect(mutated, isTrue);
      expect(stagingParent.listSync(), isEmpty);
    });

    test('detects a source file removed immediately after copying', () async {
      createRequiredDatabases();
      final image = File(p.join(sourceRoot.path, 'images/photo.jpg'));
      image.parent.createSync(recursive: true);
      image.writeAsStringSync('original');

      await expectLater(
        service(
          hooks: ProfileSnapshotTestHooks(
            afterFileCopied:
                ({
                  required sourceFile,
                  required targetFile,
                  required relativePath,
                }) async {
                  if (relativePath == 'images/photo.jpg') {
                    sourceFile.deleteSync();
                  }
                },
          ),
        ).stage(
          sourceRoot: sourceRoot,
          stagingParent: stagingParent,
          appVersion: '1.0.4+4285',
          profileType: 'real',
        ),
        throwsA(
          isA<ProfileSnapshotSourceChangedException>().having(
            (error) => error.message,
            'message',
            contains('disappeared during'),
          ),
        ),
      );
      expect(stagingParent.listSync(), isEmpty);
    });

    test('detects a source file replaced by a symbolic link', () async {
      createRequiredDatabases();
      final image = File(p.join(sourceRoot.path, 'images/photo.jpg'));
      image.parent.createSync(recursive: true);
      image.writeAsStringSync('original');
      final external = File(p.join(testRoot.path, 'outside.jpg'))
        ..writeAsStringSync('outside');

      await expectLater(
        service(
          hooks: ProfileSnapshotTestHooks(
            afterFileCopied:
                ({
                  required sourceFile,
                  required targetFile,
                  required relativePath,
                }) async {
                  if (relativePath == 'images/photo.jpg') {
                    sourceFile.deleteSync();
                    Link(sourceFile.path).createSync(external.path);
                  }
                },
          ),
        ).stage(
          sourceRoot: sourceRoot,
          stagingParent: stagingParent,
          appVersion: '1.0.4+4285',
          profileType: 'real',
        ),
        throwsA(
          isA<ProfileSnapshotSourceChangedException>().having(
            (error) => error.message,
            'message',
            contains('stopped being a regular file'),
          ),
        ),
      );
      expect(stagingParent.listSync(), isEmpty);
    });

    test('detects source size drift immediately after copying', () async {
      createRequiredDatabases();
      final image = File(p.join(sourceRoot.path, 'images/photo.jpg'));
      image.parent.createSync(recursive: true);
      image.writeAsStringSync('original');

      await expectLater(
        service(
          hooks: ProfileSnapshotTestHooks(
            afterFileCopied:
                ({
                  required sourceFile,
                  required targetFile,
                  required relativePath,
                }) async {
                  if (relativePath == 'images/photo.jpg') {
                    sourceFile.writeAsStringSync('longer source');
                  }
                },
          ),
        ).stage(
          sourceRoot: sourceRoot,
          stagingParent: stagingParent,
          appVersion: '1.0.4+4285',
          profileType: 'real',
        ),
        throwsA(
          isA<ProfileSnapshotSourceChangedException>().having(
            (error) => error.message,
            'message',
            contains('changed during'),
          ),
        ),
      );
      expect(stagingParent.listSync(), isEmpty);
    });

    test('detects copied target corruption before manifesting it', () async {
      createRequiredDatabases();
      final image = File(p.join(sourceRoot.path, 'images/photo.jpg'));
      image.parent.createSync(recursive: true);
      image.writeAsStringSync('original');

      await expectLater(
        service(
          hooks: ProfileSnapshotTestHooks(
            afterFileCopied:
                ({
                  required sourceFile,
                  required targetFile,
                  required relativePath,
                }) async {
                  if (relativePath == 'images/photo.jpg') {
                    targetFile.writeAsStringSync('corrupt');
                  }
                },
          ),
        ).stage(
          sourceRoot: sourceRoot,
          stagingParent: stagingParent,
          appVersion: '1.0.4+4285',
          profileType: 'real',
        ),
        throwsA(
          isA<ProfileSnapshotValidationException>().having(
            (error) => error.message,
            'message',
            contains('Copied bytes failed'),
          ),
        ),
      );
      expect(stagingParent.listSync(), isEmpty);
    });

    test('rehashes source bytes after the final inventory scan', () async {
      createRequiredDatabases();
      final image = File(p.join(sourceRoot.path, 'images/photo.jpg'));
      image.parent.createSync(recursive: true);
      image.writeAsStringSync('AAAA');
      final originalModified = image.lastModifiedSync();

      await expectLater(
        service(
          hooks: ProfileSnapshotTestHooks(
            beforeFinalSourceVerification: () async {
              image
                ..writeAsStringSync('BBBB')
                ..setLastModifiedSync(originalModified);
            },
          ),
        ).stage(
          sourceRoot: sourceRoot,
          stagingParent: stagingParent,
          appVersion: '1.0.4+4285',
          profileType: 'real',
        ),
        throwsA(
          isA<ProfileSnapshotSourceChangedException>().having(
            (error) => error.message,
            'message',
            contains('before publication'),
          ),
        ),
      );
      expect(stagingParent.listSync(), isEmpty);
    });

    test('detects source removal after the final inventory scan', () async {
      createRequiredDatabases();
      final image = File(p.join(sourceRoot.path, 'images/photo.jpg'));
      image.parent.createSync(recursive: true);
      image.writeAsStringSync('original');

      await expectLater(
        service(
          hooks: ProfileSnapshotTestHooks(
            beforeFinalSourceVerification: () async {
              image.deleteSync();
            },
          ),
        ).stage(
          sourceRoot: sourceRoot,
          stagingParent: stagingParent,
          appVersion: '1.0.4+4285',
          profileType: 'real',
        ),
        throwsA(
          isA<ProfileSnapshotSourceChangedException>().having(
            (error) => error.message,
            'message',
            contains('disappeared before publication'),
          ),
        ),
      );
      expect(stagingParent.listSync(), isEmpty);
    });

    test('cleans a failed publish and succeeds when retried', () async {
      createRequiredDatabases();
      var publishAttempts = 0;
      final snapshotService = service(
        hooks: ProfileSnapshotTestHooks(
          beforePublish: (partialDirectory) async {
            publishAttempts++;
            if (publishAttempts == 1) {
              throw const FileSystemException('injected publish failure');
            }
          },
        ),
      );

      await expectLater(
        snapshotService.stage(
          sourceRoot: sourceRoot,
          stagingParent: stagingParent,
          appVersion: '1.0.4+4285',
          profileType: 'real',
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(stagingParent.listSync(), isEmpty);

      final retry = await snapshotService.stage(
        sourceRoot: sourceRoot,
        stagingParent: stagingParent,
        appVersion: '1.0.4+4285',
        profileType: 'real',
      );
      expect(retry.directory.existsSync(), isTrue);
      expect(publishAttempts, 2);
    });

    final stagedTamperCases =
        <
          ({
            String name,
            String expectedMessage,
            void Function(Directory partialDirectory) tamper,
          })
        >[
          (
            name: 'a missing staged manifest',
            expectedMessage: 'manifest is missing',
            tamper: (partialDirectory) {
              File(
                p.join(partialDirectory.path, profileBackupManifestFileName),
              ).deleteSync();
            },
          ),
          (
            name: 'invalid staged manifest JSON',
            expectedMessage: 'not valid JSON',
            tamper: (partialDirectory) {
              File(
                p.join(partialDirectory.path, profileBackupManifestFileName),
              ).writeAsStringSync('{');
            },
          ),
          (
            name: 'a non-object staged manifest',
            expectedMessage: 'root must be an object',
            tamper: (partialDirectory) {
              File(
                p.join(partialDirectory.path, profileBackupManifestFileName),
              ).writeAsStringSync('[]');
            },
          ),
          (
            name: 'a staged manifest missing required fields',
            expectedMessage: 'failed validation',
            tamper: (partialDirectory) {
              File(
                p.join(partialDirectory.path, profileBackupManifestFileName),
              ).writeAsStringSync('{}');
            },
          ),
          (
            name: 'a missing staged payload',
            expectedMessage: 'payload is missing',
            tamper: (partialDirectory) {
              Directory(
                p.join(
                  partialDirectory.path,
                  profileBackupPayloadDirectoryName,
                ),
              ).deleteSync(recursive: true);
            },
          ),
          (
            name: 'a symbolic link in the staged payload',
            expectedMessage: 'may not contain symbolic links',
            tamper: (partialDirectory) {
              Link(
                p.join(
                  partialDirectory.path,
                  profileBackupPayloadDirectoryName,
                  'images',
                  'linked.jpg',
                ),
              ).createSync(p.join(testRoot.path, 'outside.jpg'));
            },
          ),
          (
            name: 'an extra staged payload file',
            expectedMessage: 'do not match the manifest',
            tamper: (partialDirectory) {
              File(
                p.join(
                  partialDirectory.path,
                  profileBackupPayloadDirectoryName,
                  'images',
                  'extra.jpg',
                ),
              ).writeAsStringSync('extra');
            },
          ),
          (
            name: 'a renamed staged payload file',
            expectedMessage: 'do not match the manifest',
            tamper: (partialDirectory) {
              final images = Directory(
                p.join(
                  partialDirectory.path,
                  profileBackupPayloadDirectoryName,
                  'images',
                ),
              );
              File(p.join(images.path, 'photo.jpg')).renameSync(
                p.join(images.path, 'renamed.jpg'),
              );
            },
          ),
          (
            name: 'staged payload checksum drift',
            expectedMessage: 'checksum verification',
            tamper: (partialDirectory) {
              File(
                p.join(
                  partialDirectory.path,
                  profileBackupPayloadDirectoryName,
                  'images',
                  'photo.jpg',
                ),
              ).writeAsStringSync('tampered');
            },
          ),
        ];

    for (final testCase in stagedTamperCases) {
      test('rejects ${testCase.name} and removes the partial stage', () async {
        createRequiredDatabases();
        final image = File(p.join(sourceRoot.path, 'images/photo.jpg'));
        image.parent.createSync(recursive: true);
        image.writeAsStringSync('original');
        File(p.join(testRoot.path, 'outside.jpg')).writeAsStringSync('outside');

        await expectLater(
          service(
            hooks: ProfileSnapshotTestHooks(
              beforePublish: (partialDirectory) async {
                testCase.tamper(partialDirectory);
              },
            ),
          ).stage(
            sourceRoot: sourceRoot,
            stagingParent: stagingParent,
            appVersion: '1.0.4+4285',
            profileType: 'real',
          ),
          throwsA(
            isA<ProfileSnapshotValidationException>().having(
              (error) => error.message,
              'message',
              contains(testCase.expectedMessage),
            ),
          ),
        );
        expect(stagingParent.listSync(), isEmpty);
      });
    }

    test('rejects a valid manifest changed before publication', () async {
      createRequiredDatabases();

      await expectLater(
        service(
          hooks: ProfileSnapshotTestHooks(
            beforePublish: (partialDirectory) async {
              final manifestFile = File(
                p.join(
                  partialDirectory.path,
                  profileBackupManifestFileName,
                ),
              );
              final manifestJson =
                  jsonDecode(manifestFile.readAsStringSync())
                      as Map<String, dynamic>;
              manifestJson['appVersion'] = 'changed-version';
              manifestFile.writeAsStringSync(jsonEncode(manifestJson));
            },
          ),
        ).stage(
          sourceRoot: sourceRoot,
          stagingParent: stagingParent,
          appVersion: '1.0.4+4285',
          profileType: 'real',
        ),
        throwsA(
          isA<ProfileSnapshotValidationException>().having(
            (error) => error.message,
            'message',
            contains('manifest changed'),
          ),
        ),
      );
      expect(stagingParent.listSync(), isEmpty);
    });

    test(
      'rejects staged SQLite schema drift with a matching checksum',
      () async {
        createRequiredDatabases();

        await expectLater(
          service(
            hooks: ProfileSnapshotTestHooks(
              beforePublish: (partialDirectory) async {
                final copiedDatabase = File(
                  p.join(
                    partialDirectory.path,
                    profileBackupPayloadDirectoryName,
                    'db.sqlite',
                  ),
                );
                final database = sqlite3.open(copiedDatabase.path);
                try {
                  database.userVersion = 46;
                } finally {
                  database.dispose();
                }

                final manifestFile = File(
                  p.join(
                    partialDirectory.path,
                    profileBackupManifestFileName,
                  ),
                );
                final manifestJson =
                    jsonDecode(manifestFile.readAsStringSync())
                        as Map<String, dynamic>;
                final files = (manifestJson['files']! as List<dynamic>)
                    .cast<Map<String, dynamic>>();
                files.singleWhere(
                    (record) => record['relativePath'] == 'db.sqlite',
                  )
                  ..['sizeBytes'] = copiedDatabase.lengthSync()
                  ..['sha256'] = sha256
                      .convert(copiedDatabase.readAsBytesSync())
                      .toString();
                manifestFile.writeAsStringSync(jsonEncode(manifestJson));
              },
            ),
          ).stage(
            sourceRoot: sourceRoot,
            stagingParent: stagingParent,
            appVersion: '1.0.4+4285',
            profileType: 'real',
          ),
          throwsA(
            isA<ProfileSnapshotValidationException>().having(
              (error) => error.message,
              'message',
              contains('schema version changed'),
            ),
          ),
        );
        expect(stagingParent.listSync(), isEmpty);
      },
    );

    test('rejects b-tree damage while running integrity_check', () async {
      final journal = File(p.join(sourceRoot.path, 'db.sqlite'));
      final database = sqlite3.open(journal.path);
      late int pageSize;
      try {
        database
          ..execute('CREATE TABLE probe (value INTEGER NOT NULL)')
          ..execute('INSERT INTO probe VALUES (1)')
          ..userVersion = 45;
        pageSize =
            database.select('PRAGMA page_size').single.values.single! as int;
      } finally {
        database.dispose();
      }
      final damagedBytes = journal.readAsBytesSync()..[pageSize] = 0;
      journal.writeAsBytesSync(damagedBytes, flush: true);
      createWalDatabase(
        'settings.sqlite',
        schemaVersion: 1,
        value: 'profile setting',
      );

      await expectLater(
        service().stage(
          sourceRoot: sourceRoot,
          stagingParent: stagingParent,
          appVersion: '1.0.4+4285',
          profileType: 'real',
        ),
        throwsA(
          isA<ProfileSnapshotValidationException>().having(
            (error) => error.message,
            'message',
            contains('Unable to validate SQLite database'),
          ),
        ),
      );
      expect(stagingParent.listSync(), isEmpty);
    });

    test(
      'fails integrity validation for a corrupt required database',
      () async {
        File(p.join(sourceRoot.path, 'db.sqlite')).writeAsStringSync('corrupt');
        createWalDatabase(
          'settings.sqlite',
          schemaVersion: 1,
          value: 'profile setting',
        );

        await expectLater(
          service().stage(
            sourceRoot: sourceRoot,
            stagingParent: stagingParent,
            appVersion: '1.0.4+4285',
            profileType: 'real',
          ),
          throwsA(isA<ProfileSnapshotValidationException>()),
        );
        expect(stagingParent.listSync(), isEmpty);
      },
    );

    test('refuses a staging parent nested inside the source root', () async {
      createRequiredDatabases();
      final nested = Directory(p.join(sourceRoot.path, 'staging'));

      await expectLater(
        service().stage(
          sourceRoot: sourceRoot,
          stagingParent: nested,
          appVersion: '1.0.4+4285',
          profileType: 'real',
        ),
        throwsA(isA<ProfileSnapshotException>()),
      );
      expect(nested.existsSync(), isFalse);
    });
  });
}
