import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashing;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/backup_restore/domain/profile_backup_bundle_header.dart';
import 'package:lotti/features/backup_restore/service/profile_backup_bundle_codec.dart';
import 'package:lotti/features/backup_restore/service/quiesced_profile_snapshot_service.dart';
import 'package:path/path.dart' as p;
import 'package:pointycastle/export.dart';
import 'package:sqlite3/sqlite3.dart';

/// Cheap enough for tests; production uses [BackupKdfParameters.recommended].
const _testKdf = BackupKdfParameters(
  memoryKiB: 64,
  iterations: 1,
  parallelism: 1,
);
const _passphrase = 'correct horse battery staple';
const _secretValue = 'my private journal line';

void main() {
  late Directory testRoot;
  late Directory sourceRoot;
  late Directory stagingParent;
  late Directory outputDirectory;
  var snapshotCounter = 0;

  setUp(() {
    testRoot = Directory.systemTemp.createTempSync('lotti_bundle_test_');
    sourceRoot = Directory(p.join(testRoot.path, 'profile'))..createSync();
    stagingParent = Directory(p.join(testRoot.path, 'staging'))..createSync();
    outputDirectory = Directory(p.join(testRoot.path, 'backups'));
    writeDatabase(sourceRoot, 'db.sqlite', _secretValue);
    writeDatabase(sourceRoot, 'settings.sqlite', 'a setting');
  });

  tearDown(() {
    if (testRoot.existsSync()) testRoot.deleteSync(recursive: true);
  });

  ProfileBackupBundleCodec codec() => ProfileBackupBundleCodec(
    kdf: _testKdf,
    now: () => DateTime.utc(2026, 9, 22, 20, 15),
  );

  Future<StagedProfileSnapshot> stage() =>
      QuiescedProfileSnapshotService(
        snapshotIdGenerator: () => 'snapshot-${snapshotCounter++}',
        now: () => DateTime.utc(2026, 9, 22, 20, 15),
      ).stage(
        sourceRoot: sourceRoot,
        stagingParent: stagingParent,
        appVersion: '1.1.23+4404',
        profileType: 'real',
      );

  /// Media spanning several chunks, so chunk order and boundaries matter.
  void addMedia(int size, {String name = 'images/2026/photo.jpg'}) {
    File(p.join(sourceRoot.path, name))
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(
        Uint8List.fromList(List.generate(size, (i) => (i * 31 + 7) & 0xff)),
      );
  }

  Future<File> packageFresh() async => codec().package(
    snapshot: await stage(),
    outputDirectory: outputDirectory,
    passphrase: _passphrase,
  );

  Directory target([String name = 'restored']) =>
      Directory(p.join(testRoot.path, name));

  group('ProfileBackupBundleCodec', () {
    test('round-trips every staged file byte for byte', () async {
      addMedia(200 * 1024);
      final snapshot = await stage();
      final stagedManifest = File(
        p.join(snapshot.directory.path, profileBackupManifestFileName),
      ).readAsStringSync();
      final expected = {
        for (final entry in snapshot.manifest.files)
          entry.relativePath: File(
            p.join(snapshot.payloadDirectory.path, entry.relativePath),
          ).readAsBytesSync(),
      };

      final bundle = await codec().package(
        snapshot: snapshot,
        outputDirectory: outputDirectory,
        passphrase: _passphrase,
      );

      expect(
        p.basename(bundle.path),
        matches(r'^lotti-backup-20260922T201500Z-[0-9a-f]{8}\.lottibackup$'),
      );
      // Only the published bundle remains: no partial, no plaintext stage.
      expect(outputDirectory.listSync().map((e) => e.path), [bundle.path]);
      expect(snapshot.directory.existsSync(), isFalse);

      final manifest = await codec().extract(
        bundle: bundle,
        passphrase: _passphrase,
        targetDirectory: target(),
      );

      expect(
        File(
          p.join(target().path, profileBackupManifestFileName),
        ).readAsStringSync(),
        stagedManifest,
      );
      expect(manifest.files.map((f) => f.relativePath), expected.keys);
      for (final MapEntry(key: path, value: bytes) in expected.entries) {
        expect(
          File(
            p.join(target().path, profileBackupPayloadDirectoryName, path),
          ).readAsBytesSync(),
          bytes,
          reason: path,
        );
      }
    });

    test('the only readable part says nothing about the profile', () async {
      final bundle = await packageFresh();
      final bytes = bundle.readAsBytesSync();

      for (final private in [
        _secretValue,
        'db.sqlite',
        'settings.sqlite',
        '1.1.23',
        'real',
        'manifest',
      ]) {
        expect(
          _indexOf(bytes, utf8.encode(private)),
          -1,
          reason: '"$private" must only exist inside the ciphertext',
        );
      }
      final headerLength = ByteData.sublistView(bytes, 9, 13).getUint32(0);
      final header =
          jsonDecode(utf8.decode(bytes.sublist(13, 13 + headerLength)))
              as Map<String, Object?>;
      expect(header.keys, [
        'bundleId',
        'chunkSize',
        'cipher',
        'keySlots',
        'version',
      ]);
      final slot = (header['keySlots']! as List).single as Map<String, Object?>;
      expect(slot['kdf'], containsPair('memoryKiB', _testKdf.memoryKiB));
      expect(slot['kdf'], containsPair('algorithm', 'argon2id'));
    });

    test('a wrong passphrase is refused and writes nothing', () async {
      final bundle = await packageFresh();

      await expectLater(
        codec().extract(
          bundle: bundle,
          passphrase: 'not the passphrase at all',
          targetDirectory: target(),
        ),
        throwsA(isA<ProfileBackupWrongPassphraseException>()),
      );
      expect(target().existsSync(), isFalse);
    });

    group('rejects tampering', () {
      late File bundle;
      late Uint8List original;
      late int payloadStart;

      setUp(() async {
        addMedia(300 * 1024);
        bundle = await packageFresh();
        original = bundle.readAsBytesSync();
        payloadStart = 13 + ByteData.sublistView(original, 9, 13).getUint32(0);
      });

      Future<void> expectRejected(
        Uint8List tampered,
        Matcher error,
      ) async {
        final forged = File(p.join(testRoot.path, 'forged.lottibackup'))
          ..writeAsBytesSync(tampered);
        await expectLater(
          codec().extract(
            bundle: forged,
            passphrase: _passphrase,
            targetDirectory: target(),
          ),
          throwsA(error),
        );
        // A partial extraction is removed again.
        expect(target().existsSync(), isFalse);
      }

      const sealedChunk = profileBackupChunkSize + 16;

      /// A failed tag check, as opposed to damage the archive framing would
      /// catch on its own.
      final authenticationFailure = isA<ProfileBackupBundleCorruptException>()
          .having(
            (e) => e.message,
            'message',
            contains('damaged or incomplete'),
          );

      test('a flipped ciphertext byte', () async {
        final tampered = Uint8List.fromList(original);
        tampered[payloadStart + sealedChunk + 100] ^= 0x01;
        await expectRejected(
          tampered,
          authenticationFailure,
        );
      });

      test('a flipped byte in the last chunk, after earlier files were '
          'written', () async {
        final tampered = Uint8List.fromList(original);
        tampered[tampered.length - 5] ^= 0x80;
        await expectRejected(
          tampered,
          isA<ProfileBackupBundleCorruptException>(),
        );
      });

      test('trailing chunks dropped at a chunk boundary', () async {
        final whole = (original.length - payloadStart) ~/ sealedChunk;
        await expectRejected(
          original.sublist(0, payloadStart + (whole - 1) * sealedChunk),
          authenticationFailure,
        );
      });

      test('a truncated final chunk', () async {
        await expectRejected(
          original.sublist(0, original.length - 3),
          isA<ProfileBackupBundleCorruptException>(),
        );
      });

      test('bytes appended after the end', () async {
        await expectRejected(
          Uint8List.fromList([...original, 0, 1, 2]),
          authenticationFailure,
        );
      });

      test('two chunks swapped', () async {
        final tampered = Uint8List.fromList(original);
        final first = original.sublist(
          payloadStart,
          payloadStart + sealedChunk,
        );
        final second = original.sublist(
          payloadStart + sealedChunk,
          payloadStart + 2 * sealedChunk,
        );
        tampered
          ..setRange(payloadStart, payloadStart + sealedChunk, second)
          ..setRange(
            payloadStart + sealedChunk,
            payloadStart + 2 * sealedChunk,
            first,
          );
        await expectRejected(
          tampered,
          authenticationFailure,
        );
      });

      test(
        'a chunk spliced in from another bundle with the same passphrase',
        () async {
          final other = (await packageFresh()).readAsBytesSync();
          final otherStart =
              13 + ByteData.sublistView(other, 9, 13).getUint32(0);
          final tampered = Uint8List.fromList(original)
            ..setRange(
              payloadStart,
              payloadStart + sealedChunk,
              other.sublist(otherStart, otherStart + sealedChunk),
            );
          await expectRejected(
            tampered,
            isA<ProfileBackupBundleCorruptException>(),
          );
        },
      );

      test('an edited header', () async {
        final headerText = utf8.decode(original.sublist(13, payloadStart));
        final header = jsonDecode(headerText) as Map<String, Object?>;
        final id = base64.decode(header['bundleId']! as String);
        id[0] ^= 0xff;
        final edited = utf8.encode(
          headerText.replaceFirst(
            header['bundleId']! as String,
            base64.encode(id),
          ),
        );
        expect(edited.length, payloadStart - 13);
        final tampered = Uint8List.fromList(original)
          ..setRange(13, payloadStart, edited);
        // The key slot is bound to the header, so it no longer unlocks.
        await expectRejected(
          tampered,
          isA<ProfileBackupWrongPassphraseException>(),
        );
      });
    });

    test('a file that is not a Lotti backup is recognised as such', () async {
      final notABackup = File(p.join(testRoot.path, 'holiday.jpg'))
        ..writeAsBytesSync(List.filled(100, 0x42));

      await expectLater(
        codec().extract(
          bundle: notABackup,
          passphrase: _passphrase,
          targetDirectory: target(),
        ),
        throwsA(
          isA<ProfileBackupBundleFormatException>().having(
            (e) => e.message,
            'message',
            contains('not a Lotti backup'),
          ),
        ),
      );
    });

    test('a backup from a newer Lotti names the reason', () async {
      final tampered = (await packageFresh()).readAsBytesSync();
      tampered[8] = profileBackupBundleVersion + 1;
      final newer = File(p.join(testRoot.path, 'newer.lottibackup'))
        ..writeAsBytesSync(tampered);

      await expectLater(
        codec().extract(
          bundle: newer,
          passphrase: _passphrase,
          targetDirectory: target(),
        ),
        throwsA(
          isA<ProfileBackupBundleFormatException>().having(
            (e) => e.message,
            'message',
            contains('newer version'),
          ),
        ),
      );
    });

    test('an exact multiple of the chunk size round-trips', () async {
      // The last chunk is then full: the classic off-by-one where a writer
      // emits it unflagged and adds an empty final chunk, or a reader stops
      // one short. Grow a media file until the plaintext stream lands exactly
      // on a boundary.
      var mediaSize = 150 * 1024;
      StagedProfileSnapshot? aligned;
      for (var attempt = 0; attempt < 6 && aligned == null; attempt++) {
        addMedia(mediaSize);
        final snapshot = await stage();
        final length = _plaintextLength(snapshot);
        final remainder = length % profileBackupChunkSize;
        if (remainder == 0) {
          aligned = snapshot;
        } else {
          snapshot.directory.deleteSync(recursive: true);
          mediaSize += profileBackupChunkSize - remainder;
        }
      }
      expect(aligned, isNotNull, reason: 'could not align the stream');

      final bundle = await codec().package(
        snapshot: aligned!,
        outputDirectory: outputDirectory,
        passphrase: _passphrase,
      );
      final payloadBytes =
          bundle.lengthSync() -
          13 -
          ByteData.sublistView(bundle.readAsBytesSync(), 9, 13).getUint32(0);
      // Only full chunks: no trailing empty chunk was appended.
      expect(payloadBytes % (profileBackupChunkSize + 16), 0);

      await expectLater(
        codec().extract(
          bundle: bundle,
          passphrase: _passphrase,
          targetDirectory: target(),
        ),
        completes,
      );
    });

    test(
      'a short passphrase is refused and the plaintext stage still removed',
      () async {
        final snapshot = await stage();

        await expectLater(
          codec().package(
            snapshot: snapshot,
            outputDirectory: outputDirectory,
            passphrase: 'too short',
          ),
          throwsA(isA<ProfileBackupWeakPassphraseException>()),
        );

        expect(snapshot.directory.existsSync(), isFalse);
        expect(outputDirectory.existsSync(), isFalse);
      },
    );

    test('a stage changed after publishing is never sealed, and an existing '
        'backup is left alone', () async {
      final existing = await packageFresh();
      final existingBytes = existing.readAsBytesSync();
      final snapshot = await stage();
      File(
        p.join(snapshot.payloadDirectory.path, 'settings.sqlite'),
      ).writeAsBytesSync([1, 2, 3], mode: FileMode.append);

      await expectLater(
        codec().package(
          snapshot: snapshot,
          outputDirectory: outputDirectory,
          passphrase: _passphrase,
        ),
        throwsA(isA<ProfileSnapshotSourceChangedException>()),
      );

      expect(outputDirectory.listSync().map((e) => e.path), [existing.path]);
      expect(existing.readAsBytesSync(), existingBytes);
      expect(snapshot.directory.existsSync(), isFalse);
    });

    test(
      'a bundle damaged on disk before it is verified is never published',
      () async {
        final snapshot = await stage();
        final damaging = ProfileBackupBundleCodec(
          kdf: _testKdf,
          afterWrite: (partial) async {
            final bytes = partial.readAsBytesSync();
            bytes[bytes.length - 1] ^= 0x01;
            partial.writeAsBytesSync(bytes);
          },
        );

        await expectLater(
          damaging.package(
            snapshot: snapshot,
            outputDirectory: outputDirectory,
            passphrase: _passphrase,
          ),
          throwsA(isA<ProfileBackupBundleCorruptException>()),
        );

        expect(outputDirectory.listSync(), isEmpty);
        expect(snapshot.directory.existsSync(), isFalse);
      },
    );

    test('never replaces a bundle that already has the chosen name', () async {
      final taken =
          File(
              p.join(
                outputDirectory.path,
                'lotti-backup-20260922T201500Z-0000abcd.lottibackup',
              ),
            )
            ..parent.createSync(recursive: true)
            ..writeAsStringSync('an earlier backup');
      final snapshot = await stage();

      await expectLater(
        ProfileBackupBundleCodec(
          kdf: _testKdf,
          now: () => DateTime.utc(2026, 9, 22, 20, 15),
          nameSuffix: () => '0000abcd',
        ).package(
          snapshot: snapshot,
          outputDirectory: outputDirectory,
          passphrase: _passphrase,
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect(taken.readAsStringSync(), 'an earlier backup');
      expect(outputDirectory.listSync().map((e) => e.path), [taken.path]);
      expect(snapshot.directory.existsSync(), isFalse);
    });

    test('exceptions describe themselves', () {
      expect(
        const ProfileBackupWrongPassphraseException().toString(),
        contains('wrong passphrase'),
      );
      expect(
        const ProfileBackupWeakPassphraseException().toString(),
        contains('at least 12 characters'),
      );
      expect(
        const ProfileBackupBundleCorruptException('truncated').toString(),
        'ProfileBackupBundleCorruptException: truncated',
      );
      expect(
        const ProfileBackupBundleFormatException('not a backup').toString(),
        'ProfileBackupBundleFormatException: not a backup',
      );
    });

    group('resolveInsideRoot', () {
      final root = p.join('restore', 'payload');

      test('joins a canonical relative path', () {
        expect(
          resolveInsideRoot(root, 'images/2026/photo.jpg'),
          p.join(root, 'images', '2026', 'photo.jpg'),
        );
      });

      for (final escape in ['../outside.txt', 'images/../../outside.txt']) {
        test('refuses $escape', () {
          expect(
            () => resolveInsideRoot(root, escape),
            throwsA(isA<ProfileBackupBundleCorruptException>()),
          );
        });
      }

      test('refuses an absolute path', () {
        expect(
          () => resolveInsideRoot(root, p.join(p.separator, 'etc', 'passwd')),
          throwsA(isA<ProfileBackupBundleCorruptException>()),
        );
      });
    });

    test('extraction never writes into an existing directory', () async {
      final bundle = await packageFresh();
      final occupied = target()..createSync();
      File(p.join(occupied.path, 'keep.txt')).writeAsStringSync('mine');

      await expectLater(
        codec().extract(
          bundle: bundle,
          passphrase: _passphrase,
          targetDirectory: occupied,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        File(p.join(occupied.path, 'keep.txt')).readAsStringSync(),
        'mine',
      );
    });

    test('uses the recommended key derivation by default', () async {
      final bundle = await ProfileBackupBundleCodec().package(
        snapshot: await stage(),
        outputDirectory: outputDirectory,
        passphrase: _passphrase,
      );
      final bytes = bundle.readAsBytesSync();
      final headerLength = ByteData.sublistView(bytes, 9, 13).getUint32(0);
      final header = ProfileBackupBundleHeader.fromBytes(
        bytes.sublist(13, 13 + headerLength),
      );

      final kdf = header.keySlots.single.kdf;
      expect(kdf.memoryKiB, BackupKdfParameters.recommended.memoryKiB);
      expect(kdf.iterations, BackupKdfParameters.recommended.iterations);
      expect(kdf.parallelism, BackupKdfParameters.recommended.parallelism);
    });
  });

  group('reading a bundle written from the documented format', () {
    late StagedProfileSnapshot snapshot;
    late List<int> manifestBytes;
    late List<(String, List<int>)> entries;

    setUp(() async {
      addMedia(90 * 1024);
      snapshot = await stage();
      manifestBytes = File(
        p.join(snapshot.directory.path, profileBackupManifestFileName),
      ).readAsBytesSync();
      entries = [
        for (final entry in snapshot.manifest.files)
          (
            'payload/${entry.relativePath}',
            File(
              p.join(snapshot.payloadDirectory.path, entry.relativePath),
            ).readAsBytesSync(),
          ),
      ];
    });

    Future<void> expectCorrupt(List<int> archive, String fragment) async {
      final forged = File(p.join(testRoot.path, 'forged.lottibackup'))
        ..writeAsBytesSync(_forgeBundle(archive));
      await expectLater(
        codec().extract(
          bundle: forged,
          passphrase: _passphrase,
          targetDirectory: target(),
        ),
        throwsA(
          isA<ProfileBackupBundleCorruptException>().having(
            (e) => e.message,
            'message',
            contains(fragment),
          ),
        ),
      );
      expect(target().existsSync(), isFalse);
    }

    test(
      'an independent writer following the documentation is readable',
      () async {
        final forged = File(p.join(testRoot.path, 'forged.lottibackup'))
          ..writeAsBytesSync(
            _forgeBundle(_archive(manifest: manifestBytes, entries: entries)),
          );

        await codec().extract(
          bundle: forged,
          passphrase: _passphrase,
          targetDirectory: target(),
        );

        for (final (name, bytes) in entries) {
          expect(File(p.join(target().path, name)).readAsBytesSync(), bytes);
        }
      },
    );

    test('a file whose bytes do not match the manifest', () async {
      final (name, bytes) = entries.last;
      final altered = List<int>.of(bytes)..[0] ^= 0xff;
      await expectCorrupt(
        _archive(
          manifest: manifestBytes,
          entries: [...entries.take(entries.length - 1), (name, altered)],
        ),
        'Checksum mismatch',
      );
    });

    test('an invalid manifest', () async {
      await expectCorrupt(
        _archive(manifest: utf8.encode('{"formatVersion":1}'), entries: []),
        'manifest is invalid',
      );
    });

    test('no manifest first', () async {
      await expectCorrupt(
        _archive(manifest: null, entries: entries),
        'manifest is missing',
      );
    });

    test('files in a different order than the manifest', () async {
      await expectCorrupt(
        _archive(manifest: manifestBytes, entries: entries.reversed.toList()),
        'Unexpected archive entry',
      );
    });

    test('a file the manifest does not list', () async {
      await expectCorrupt(
        _archive(
          manifest: manifestBytes,
          entries: [...entries, ('payload/extra.txt', utf8.encode('extra'))],
        ),
        'unexpected extra data',
      );
    });

    test('bytes after the end record', () async {
      await expectCorrupt(
        _archive(manifest: manifestBytes, entries: entries, trailing: [9]),
        'unexpected extra data',
      );
    });

    test('a stream that stops inside a file', () async {
      final full = _archive(manifest: manifestBytes, entries: entries);
      await expectCorrupt(full.sublist(0, full.length - 10), 'ends too early');
    });

    test('an unknown archive format', () async {
      await expectCorrupt(
        _archive(manifest: manifestBytes, entries: entries, magic: 'OTHERARC'),
        'Unknown archive format',
      );
    });

    test('a chunk moved between bundles that share a data key', () async {
      // Only the bundle id differs, so nothing but the header binding in the
      // chunks' authenticated data can tell them apart.
      final plaintext = _archive(manifest: manifestBytes, entries: entries);
      final host = _forgeBundle(plaintext);
      final donor = _forgeBundle(plaintext, bundleIdByte: 9);
      // Control: untouched, the host bundle is perfectly readable, so the
      // rejection below can only come from the splice.
      final control = File(p.join(testRoot.path, 'control.lottibackup'))
        ..writeAsBytesSync(host);
      await codec().extract(
        bundle: control,
        passphrase: _passphrase,
        targetDirectory: target('control'),
      );
      final hostStart = 13 + ByteData.sublistView(host, 9, 13).getUint32(0);
      final donorStart = 13 + ByteData.sublistView(donor, 9, 13).getUint32(0);
      const sealedChunk = profileBackupChunkSize + 16;
      host.setRange(
        hostStart,
        hostStart + sealedChunk,
        donor.sublist(donorStart, donorStart + sealedChunk),
      );
      final forged = File(p.join(testRoot.path, 'spliced.lottibackup'))
        ..writeAsBytesSync(host);

      await expectLater(
        codec().extract(
          bundle: forged,
          passphrase: _passphrase,
          targetDirectory: target(),
        ),
        throwsA(
          isA<ProfileBackupBundleCorruptException>().having(
            (e) => e.message,
            'message',
            contains('damaged or incomplete'),
          ),
        ),
      );
      expect(target().existsSync(), isFalse);
    });

    test('a file name that is not UTF-8', () async {
      final archive = BytesBuilder()
        ..add([...utf8.encode('LOTTIARC'), 1, 1])
        ..add((ByteData(2)..setUint16(0, 2)).buffer.asUint8List())
        ..add([0xff, 0xfe])
        ..add(Uint8List(8));
      await expectCorrupt(archive.takeBytes(), 'Unreadable file name');
    });

    test('an unknown record kind', () async {
      await expectCorrupt(
        [...utf8.encode('LOTTIARC'), 1, 7],
        'Unknown archive record',
      );
    });
  });
}

void writeDatabase(Directory root, String name, String value) {
  final database = sqlite3.open(p.join(root.path, name));
  try {
    database
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('CREATE TABLE probe (value TEXT NOT NULL)')
      ..execute('INSERT INTO probe VALUES (?)', [value]);
  } finally {
    database.close();
  }
}

/// Length of the archive stream the codec encrypts for [snapshot].
int _plaintextLength(StagedProfileSnapshot snapshot) {
  int record(String name, int size) =>
      1 + 2 + utf8.encode(name).length + 8 + size;
  final manifestSize = File(
    p.join(snapshot.directory.path, profileBackupManifestFileName),
  ).lengthSync();
  return 9 +
      record('manifest.json', manifestSize) +
      snapshot.manifest.files.fold<int>(
        0,
        (sum, f) => sum + record('payload/${f.relativePath}', f.sizeBytes),
      ) +
      1;
}

int _indexOf(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}

/// Builds the plaintext archive stream exactly as documented on
/// [ProfileBackupBundleCodec].
List<int> _archive({
  required List<int>? manifest,
  required List<(String, List<int>)> entries,
  List<int> trailing = const [],
  String magic = 'LOTTIARC',
}) {
  final out = BytesBuilder()..add([...ascii.encode(magic), 1]);
  void record(String name, List<int> bytes) {
    final nameBytes = utf8.encode(name);
    out
      ..addByte(1)
      ..add((ByteData(2)..setUint16(0, nameBytes.length)).buffer.asUint8List())
      ..add(nameBytes)
      ..add((ByteData(8)..setUint64(0, bytes.length)).buffer.asUint8List())
      ..add(bytes);
  }

  if (manifest != null) record('manifest.json', manifest);
  for (final (name, bytes) in entries) {
    record(name, bytes);
  }
  out
    ..addByte(0)
    ..add(trailing);
  return out.takeBytes();
}

/// Encrypts [plaintext] into a bundle following the documented container
/// format, without using the codec's own writer.
Uint8List _forgeBundle(List<int> plaintext, {int bundleIdByte = 7}) {
  Uint8List bytes(int length, int value) =>
      Uint8List.fromList(List.filled(length, value));
  Uint8List seal(
    Uint8List key,
    Uint8List nonce,
    List<int> aad,
    List<int> data,
  ) {
    final cipher = ChaCha20Poly1305(ChaCha7539Engine(), Poly1305())
      ..init(
        true,
        AEADParameters(KeyParameter(key), 128, nonce, Uint8List.fromList(aad)),
      );
    final input = Uint8List.fromList(data);
    final out = Uint8List(input.length + 16);
    cipher.doFinal(out, cipher.processBytes(input, 0, input.length, out, 0));
    return out;
  }

  final dataKey = bytes(32, 8);
  final draft = BackupKeySlot(
    salt: bytes(16, 5),
    kdf: _testKdf,
    nonce: bytes(12, 6),
    wrappedKey: bytes(48, 0),
  );
  final core = ProfileBackupBundleHeader(
    bundleId: bytes(16, bundleIdByte),
    keySlots: [draft],
  );
  final keyEncryptionKey = Uint8List(32);
  (Argon2BytesGenerator()..init(
        Argon2Parameters(
          Argon2Parameters.ARGON2_id,
          draft.salt,
          desiredKeyLength: 32,
          iterations: _testKdf.iterations,
          memory: _testKdf.memoryKiB,
          lanes: _testKdf.parallelism,
        ),
      ))
      .deriveKey(utf8.encode(_passphrase), 0, keyEncryptionKey, 0);
  final header = ProfileBackupBundleHeader(
    bundleId: core.bundleId,
    keySlots: [
      BackupKeySlot(
        salt: draft.salt,
        kdf: _testKdf,
        nonce: draft.nonce,
        wrappedKey: seal(keyEncryptionKey, draft.nonce, [
          ...utf8.encode('lotti-backup-key-slot'),
          ...core.coreBytes(),
          ...draft.kdfBinding(),
        ], dataKey),
      ),
    ],
  );
  final headerBytes = header.toBytes();
  final chunkAad = hashing.sha256.convert([
    ...ascii.encode(profileBackupBundleMagic),
    profileBackupBundleVersion,
    ...header.coreBytes(),
  ]).bytes;

  final out = BytesBuilder()
    ..add(ascii.encode(profileBackupBundleMagic))
    ..addByte(profileBackupBundleVersion)
    ..add((ByteData(4)..setUint32(0, headerBytes.length)).buffer.asUint8List())
    ..add(headerBytes);
  final chunkCount = max(1, (plaintext.length / profileBackupChunkSize).ceil());
  for (var i = 0; i < chunkCount; i++) {
    final last = i == chunkCount - 1;
    final nonce = Uint8List(12);
    ByteData.sublistView(nonce).setUint64(3, i);
    nonce[11] = last ? 1 : 0;
    final start = i * profileBackupChunkSize;
    final end = min(start + profileBackupChunkSize, plaintext.length);
    out.add(seal(dataKey, nonce, chunkAad, plaintext.sublist(start, end)));
  }
  return out.takeBytes();
}
