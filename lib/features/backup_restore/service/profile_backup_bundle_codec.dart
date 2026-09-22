import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashing;
import 'package:lotti/features/backup_restore/domain/profile_backup_bundle_header.dart';
import 'package:lotti/features/backup_restore/domain/profile_backup_manifest.dart';
import 'package:lotti/features/backup_restore/service/profile_backup_bundle_store.dart';
import 'package:lotti/features/backup_restore/service/quiesced_profile_snapshot_service.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:pointycastle/export.dart';

/// The passphrase does not unlock the bundle — or its key slot was damaged,
/// which is indistinguishable by design.
class ProfileBackupWrongPassphraseException implements Exception {
  const ProfileBackupWrongPassphraseException();

  @override
  String toString() =>
      'ProfileBackupWrongPassphraseException: wrong passphrase, or the '
      "backup's key slot is damaged";
}

/// The passphrase is too short to protect a file anyone who obtains it can
/// attack offline.
class ProfileBackupWeakPassphraseException implements Exception {
  const ProfileBackupWeakPassphraseException();

  @override
  String toString() =>
      'ProfileBackupWeakPassphraseException: use at least '
      '${ProfileBackupBundleCodec.minimumPassphraseLength} characters';
}

/// The bundle was unlocked but its content is damaged, truncated, reordered
/// or does not match its manifest.
class ProfileBackupBundleCorruptException implements Exception {
  const ProfileBackupBundleCorruptException(this.message);

  final String message;

  @override
  String toString() => 'ProfileBackupBundleCorruptException: $message';
}

/// Turns a staged snapshot into an encrypted, portable bundle file, and back.
///
/// ## File layout
///
/// ```text
/// "LOTTIBAK" | version u8 | header length u32 BE | header JSON | chunks…
/// ```
///
/// The header ([ProfileBackupBundleHeader]) holds the key slots and nothing
/// about the profile. The payload is one plaintext stream — an archive of the
/// snapshot's `manifest.json` and every payload file in manifest order —
/// encrypted in [profileBackupChunkSize] chunks with ChaCha20-Poly1305 under
/// a random 256-bit data key:
///
/// - chunk *i*'s nonce is *i* as 11 big-endian bytes followed by a final-chunk
///   flag, so the data key (fresh per bundle) never reuses a nonce;
/// - every chunk authenticates SHA-256 of the magic, version and header core,
///   so it cannot be moved to another bundle or survive a header edit;
/// - only the last chunk carries the final flag, so dropping trailing chunks,
///   appending bytes or reordering chunks all fail authentication.
///
/// The data key is stored wrapped in each key slot under a key derived from
/// the passphrase with Argon2id. Nothing is ever written to disk unencrypted
/// by this class, and extraction writes a file only after the chunk holding
/// its bytes has authenticated.
///
/// All work runs synchronously inside a background isolate.
class ProfileBackupBundleCodec {
  ProfileBackupBundleCodec({
    this._kdf = BackupKdfParameters.recommended,
    DateTime Function()? now,
    @visibleForTesting this.afterWrite,
    @visibleForTesting String Function()? nameSuffix,
  }) : _now = now ?? DateTime.now,
       _nameSuffix = nameSuffix ?? (() => _randomHex(4));

  /// Shortest passphrase [package] accepts, in Unicode code points.
  static const minimumPassphraseLength = 12;

  final BackupKdfParameters _kdf;
  final DateTime Function() _now;
  final String Function() _nameSuffix;

  /// Runs on the written partial bundle before it is verified, so tests can
  /// damage it the way a failing disk would.
  @visibleForTesting
  final Future<void> Function(File partial)? afterWrite;

  /// Encrypts [snapshot] into a new bundle in [outputDirectory].
  ///
  /// The bundle is written under a hidden partial name, flushed to disk,
  /// decrypted and checked against the manifest end to end with
  /// [passphrase], and only then renamed to its final name — so an
  /// interrupted or failed run never leaves a bundle that looks complete, and
  /// never touches an existing one. The staged snapshot is plaintext, so it is
  /// deleted whatever the outcome.
  Future<File> package({
    required StagedProfileSnapshot snapshot,
    required Directory outputDirectory,
    required String passphrase,
  }) async {
    try {
      if (passphrase.runes.length < minimumPassphraseLength) {
        throw const ProfileBackupWeakPassphraseException();
      }
      outputDirectory.createSync(recursive: true);
      final name = ProfileBackupBundleStore.bundleFileName(
        createdAt: _now(),
        suffix: _nameSuffix(),
      );
      final destination = p.join(outputDirectory.path, name);
      final partial = p.join(
        outputDirectory.path,
        ProfileBackupBundleStore.partialFileName(name),
      );
      final kdf = _kdf;
      final manifestPath = p.join(
        snapshot.directory.path,
        profileBackupManifestFileName,
      );
      final payloadPath = snapshot.payloadDirectory.path;
      try {
        await Isolate.run(
          () => _writeBundle(
            partialPath: partial,
            manifestPath: manifestPath,
            payloadPath: payloadPath,
            passphrase: passphrase,
            kdf: kdf,
          ),
        );
        await afterWrite?.call(File(partial));
        await Isolate.run(
          () => _readBundle(
            bundlePath: partial,
            passphrase: passphrase,
            targetPath: null,
          ),
        );
        if (File(destination).existsSync()) {
          throw FileSystemException('A backup with this name exists', name);
        }
        return File(partial).renameSync(destination);
      } catch (_) {
        final leftover = File(partial);
        if (leftover.existsSync()) leftover.deleteSync();
        rethrow;
      }
    } finally {
      if (snapshot.directory.existsSync()) {
        snapshot.directory.deleteSync(recursive: true);
      }
    }
  }

  /// Decrypts [bundle] into [targetDirectory], which must not exist yet,
  /// laid out like a staged snapshot (`manifest.json` and `payload/`), and
  /// returns its verified manifest.
  ///
  /// Every file is checked against the manifest's size and SHA-256. On any
  /// failure [targetDirectory] is removed again.
  Future<ProfileBackupManifest> extract({
    required File bundle,
    required String passphrase,
    required Directory targetDirectory,
  }) async {
    if (targetDirectory.existsSync()) {
      throw FileSystemException(
        'Restore target already exists',
        targetDirectory.path,
      );
    }
    final bundlePath = bundle.path;
    final targetPath = targetDirectory.path;
    final manifestJson = await Isolate.run(
      () => _readBundle(
        bundlePath: bundlePath,
        passphrase: passphrase,
        targetPath: targetPath,
      ),
    );
    return ProfileBackupManifest.fromJson(manifestJson);
  }
}

// --------------------------------------------------------------------------
// Everything below runs inside the background isolate.

const _archiveMagic = 'LOTTIARC';
const _archiveVersion = 1;
const _recordFile = 1;
const _recordEnd = 0;
const _manifestEntryName = 'manifest.json';
const int _maxManifestBytes = 16 * 1024 * 1024;
const int _maxHeaderBytes = 64 * 1024;
const _tagLength = 16;
const int _ioBlock = 1024 * 1024;

final _random = Random.secure();

Uint8List _randomBytes(int length) =>
    Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));

String _randomHex(int bytes) => _randomBytes(
  bytes,
).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List _deriveKey(String passphrase, BackupKeySlot slot) {
  final generator = Argon2BytesGenerator()
    ..init(
      Argon2Parameters(
        Argon2Parameters.ARGON2_id,
        slot.salt,
        desiredKeyLength: 32,
        iterations: slot.kdf.iterations,
        memory: slot.kdf.memoryKiB,
        lanes: slot.kdf.parallelism,
      ),
    );
  final key = Uint8List(32);
  generator.deriveKey(utf8.encode(passphrase), 0, key, 0);
  return key;
}

Uint8List _keySlotAad(ProfileBackupBundleHeader header, BackupKeySlot slot) =>
    Uint8List.fromList([
      ...utf8.encode('lotti-backup-key-slot'),
      ...header.coreBytes(),
      ...slot.kdfBinding(),
    ]);

Uint8List _chunkAad(ProfileBackupBundleHeader header) => Uint8List.fromList(
  hashing.sha256.convert([
    ...ascii.encode(profileBackupBundleMagic),
    profileBackupBundleVersion,
    ...header.coreBytes(),
  ]).bytes,
);

Uint8List _chunkNonce(int index, {required bool last}) {
  final nonce = Uint8List(12);
  var value = index;
  for (var i = 10; i >= 0 && value > 0; i--) {
    nonce[i] = value & 0xff;
    value >>= 8;
  }
  nonce[11] = last ? 1 : 0;
  return nonce;
}

Uint8List _seal(Uint8List key, Uint8List nonce, Uint8List aad, Uint8List data) {
  final cipher = ChaCha20Poly1305(ChaCha7539Engine(), Poly1305())
    ..init(true, AEADParameters(KeyParameter(key), 128, nonce, aad));
  final out = Uint8List(data.length + _tagLength);
  final written = cipher.processBytes(data, 0, data.length, out, 0);
  cipher.doFinal(out, written);
  return out;
}

/// Returns the plaintext, or null when authentication fails. pointycastle
/// writes the would-be plaintext before it checks the tag, so the buffer is
/// only returned once the check has passed.
Uint8List? _open(
  Uint8List key,
  Uint8List nonce,
  Uint8List aad,
  Uint8List sealed,
) {
  if (sealed.length < _tagLength) return null;
  final cipher = ChaCha20Poly1305(ChaCha7539Engine(), Poly1305())
    ..init(false, AEADParameters(KeyParameter(key), 128, nonce, aad));
  final out = Uint8List(sealed.length - _tagLength);
  try {
    final written = cipher.processBytes(sealed, 0, sealed.length, out, 0);
    cipher.doFinal(out, written);
    // pointycastle reports a failed tag check as an ArgumentError.
    // ignore: avoid_catching_errors
  } on ArgumentError {
    return null;
  }
  return out;
}

/// Buffers plaintext into chunks and writes each one sealed. A full chunk is
/// held back until more data arrives, so the chunk that ends the stream is
/// always the one marked final.
class _ChunkSealer {
  _ChunkSealer(this._out, this._key, this._aad);

  final RandomAccessFile _out;
  final Uint8List _key;
  final Uint8List _aad;
  final _buffer = Uint8List(profileBackupChunkSize);
  var _filled = 0;
  var _index = 0;

  void add(List<int> data) {
    var offset = 0;
    while (offset < data.length) {
      if (_filled == _buffer.length) _emit(last: false);
      final take = min(_buffer.length - _filled, data.length - offset);
      _buffer.setRange(_filled, _filled + take, data, offset);
      _filled += take;
      offset += take;
    }
  }

  void close() => _emit(last: true);

  void _emit({required bool last}) {
    _out.writeFromSync(
      _seal(
        _key,
        _chunkNonce(_index++, last: last),
        _aad,
        Uint8List.sublistView(_buffer, 0, _filled),
      ),
    );
    _filled = 0;
  }
}

void _addRecord(_ChunkSealer sealer, String name, int size) {
  final path = utf8.encode(name);
  final header = ByteData(1 + 2 + path.length + 8)
    ..setUint8(0, _recordFile)
    ..setUint16(1, path.length);
  final bytes = header.buffer.asUint8List()..setRange(3, 3 + path.length, path);
  ByteData.sublistView(bytes).setUint64(3 + path.length, size);
  sealer.add(bytes);
}

void _writeBundle({
  required String partialPath,
  required String manifestPath,
  required String payloadPath,
  required String passphrase,
  required BackupKdfParameters kdf,
}) {
  final dataKey = _randomBytes(32);
  final unwrappedSlot = BackupKeySlot(
    salt: _randomBytes(BackupKeySlot.saltLength),
    kdf: kdf,
    nonce: _randomBytes(BackupKeySlot.nonceLength),
    wrappedKey: Uint8List(BackupKeySlot.wrappedKeyLength),
  );
  final core = ProfileBackupBundleHeader(
    bundleId: _randomBytes(ProfileBackupBundleHeader.bundleIdLength),
    keySlots: [unwrappedSlot],
  );
  final slot = BackupKeySlot(
    salt: unwrappedSlot.salt,
    kdf: kdf,
    nonce: unwrappedSlot.nonce,
    wrappedKey: _seal(
      _deriveKey(passphrase, unwrappedSlot),
      unwrappedSlot.nonce,
      _keySlotAad(core, unwrappedSlot),
      dataKey,
    ),
  );
  final header = ProfileBackupBundleHeader(
    bundleId: core.bundleId,
    keySlots: [slot],
  );
  final headerBytes = header.toBytes();

  final manifestBytes = File(manifestPath).readAsBytesSync();
  final manifest = ProfileBackupManifest.fromJson(
    jsonDecode(utf8.decode(manifestBytes)) as Map<String, Object?>,
  );

  final out = File(partialPath).openSync(mode: FileMode.writeOnly);
  try {
    out
      ..writeFromSync(ascii.encode(profileBackupBundleMagic))
      ..writeByteSync(profileBackupBundleVersion)
      ..writeFromSync(
        (ByteData(4)..setUint32(0, headerBytes.length)).buffer.asUint8List(),
      )
      ..writeFromSync(headerBytes);

    final sealer = _ChunkSealer(out, dataKey, _chunkAad(header))
      ..add([...ascii.encode(_archiveMagic), _archiveVersion]);
    _addRecord(sealer, _manifestEntryName, manifestBytes.length);
    sealer.add(manifestBytes);

    final block = Uint8List(_ioBlock);
    for (final entry in manifest.files) {
      final source = File(p.join(payloadPath, entry.relativePath));
      _addRecord(sealer, 'payload/${entry.relativePath}', entry.sizeBytes);
      final input = source.openSync();
      final digest = _DigestCollector();
      final hasher = hashing.sha256.startChunkedConversion(digest);
      var copied = 0;
      try {
        while (true) {
          final read = input.readIntoSync(block);
          if (read == 0) break;
          final bytes = Uint8List.sublistView(block, 0, read);
          copied += read;
          if (copied > entry.sizeBytes) break;
          hasher.add(bytes);
          sealer.add(bytes);
        }
      } finally {
        input.closeSync();
      }
      hasher.close();
      // The staged snapshot was verified when it was published; anything
      // that changed it since must not be sealed into a backup.
      if (copied != entry.sizeBytes || digest.hex != entry.sha256) {
        throw ProfileSnapshotSourceChangedException(
          'Staged file changed before packaging: ${entry.relativePath}',
        );
      }
    }
    sealer
      ..add([_recordEnd])
      ..close();
    out.flushSync();
  } finally {
    out.closeSync();
  }
}

class _DigestCollector implements Sink<hashing.Digest> {
  late String hex;

  @override
  void add(hashing.Digest data) => hex = data.toString();

  @override
  void close() {}
}

/// Pulls authenticated plaintext out of the chunk stream on demand.
class _PlainReader {
  _PlainReader(this._file, this._key, this._aad, this._remaining);

  final RandomAccessFile _file;
  final Uint8List _key;
  final Uint8List _aad;
  int _remaining;
  var _index = 0;
  var _sawLast = false;
  Uint8List _chunk = Uint8List(0);
  var _offset = 0;

  bool _nextChunk() {
    if (_sawLast) return false;
    final take = min(profileBackupChunkSize + _tagLength, _remaining);
    if (take < _tagLength) {
      throw const ProfileBackupBundleCorruptException(
        'The backup is truncated.',
      );
    }
    final sealed = _file.readSync(take);
    if (sealed.length != take) {
      throw const ProfileBackupBundleCorruptException(
        'The backup is truncated.',
      );
    }
    _remaining -= take;
    final last = _remaining == 0;
    final plain = _open(_key, _chunkNonce(_index++, last: last), _aad, sealed);
    if (plain == null) {
      throw const ProfileBackupBundleCorruptException(
        'The backup is damaged or incomplete.',
      );
    }
    _sawLast = last;
    _chunk = plain;
    _offset = 0;
    return true;
  }

  /// Hands [length] bytes to [sink] in chunk-sized pieces.
  void readInto(int length, void Function(Uint8List bytes) sink) {
    var needed = length;
    while (needed > 0) {
      if (_offset == _chunk.length && !_nextChunk()) {
        throw const ProfileBackupBundleCorruptException(
          'The backup ends too early.',
        );
      }
      final take = min(needed, _chunk.length - _offset);
      sink(Uint8List.sublistView(_chunk, _offset, _offset + take));
      _offset += take;
      needed -= take;
    }
  }

  Uint8List read(int length) {
    final builder = BytesBuilder(copy: false);
    readInto(length, (bytes) => builder.add(Uint8List.fromList(bytes)));
    return builder.takeBytes();
  }

  /// True once every byte has been consumed and the final chunk was seen.
  bool get isExhausted {
    while (_offset == _chunk.length) {
      if (!_nextChunk()) return true;
    }
    return false;
  }

  ({String name, int size})? readRecord() {
    final kind = read(1).single;
    if (kind == _recordEnd) return null;
    if (kind != _recordFile) {
      throw const ProfileBackupBundleCorruptException(
        'Unknown archive record.',
      );
    }
    final nameLength = ByteData.sublistView(read(2)).getUint16(0);
    final String name;
    try {
      name = utf8.decode(read(nameLength));
    } on FormatException {
      throw const ProfileBackupBundleCorruptException('Unreadable file name.');
    }
    final size = ByteData.sublistView(read(8)).getUint64(0);
    return (name: name, size: size);
  }
}

/// Decrypts and verifies a bundle. With [targetPath] it also writes the
/// snapshot out; without it, it only checks. Returns the manifest JSON.
Map<String, Object?> _readBundle({
  required String bundlePath,
  required String passphrase,
  required String? targetPath,
}) {
  final file = File(bundlePath).openSync();
  var targetCreated = false;
  try {
    final length = file.lengthSync();
    final magic = file.readSync(profileBackupBundleMagic.length);
    if (magic.length != profileBackupBundleMagic.length ||
        ascii.decode(magic, allowInvalid: true) != profileBackupBundleMagic) {
      throw const ProfileBackupBundleFormatException(
        'This is not a Lotti backup.',
      );
    }
    final version = file.readByteSync();
    if (version > profileBackupBundleVersion) {
      throw ProfileBackupBundleFormatException(
        'This backup was made by a newer version of Lotti (format $version).',
      );
    }
    if (version != profileBackupBundleVersion) {
      throw const ProfileBackupBundleFormatException(
        'Unsupported backup container version.',
      );
    }
    final lengthBytes = file.readSync(4);
    if (lengthBytes.length != 4) {
      throw const ProfileBackupBundleCorruptException(
        'The backup is truncated.',
      );
    }
    final headerLength = ByteData.sublistView(lengthBytes).getUint32(0);
    if (headerLength == 0 || headerLength > _maxHeaderBytes) {
      throw const ProfileBackupBundleFormatException(
        'Malformed backup header.',
      );
    }
    final headerBytes = file.readSync(headerLength);
    if (headerBytes.length != headerLength) {
      throw const ProfileBackupBundleCorruptException(
        'The backup is truncated.',
      );
    }
    final header = ProfileBackupBundleHeader.fromBytes(headerBytes);

    Uint8List? dataKey;
    for (final slot in header.keySlots) {
      dataKey = _open(
        _deriveKey(passphrase, slot),
        slot.nonce,
        _keySlotAad(header, slot),
        slot.wrappedKey,
      );
      if (dataKey != null) break;
    }
    if (dataKey == null) throw const ProfileBackupWrongPassphraseException();

    final reader = _PlainReader(
      file,
      dataKey,
      _chunkAad(header),
      length - file.positionSync(),
    );
    if (ascii.decode(reader.read(_archiveMagic.length), allowInvalid: true) !=
            _archiveMagic ||
        reader.read(1).single != _archiveVersion) {
      throw const ProfileBackupBundleCorruptException(
        'Unknown archive format.',
      );
    }

    final manifestRecord = reader.readRecord();
    if (manifestRecord == null ||
        manifestRecord.name != _manifestEntryName ||
        manifestRecord.size > _maxManifestBytes) {
      throw const ProfileBackupBundleCorruptException(
        'The manifest is missing.',
      );
    }
    final manifestBytes = reader.read(manifestRecord.size);
    final Map<String, Object?> manifestJson;
    final ProfileBackupManifest manifest;
    try {
      manifestJson =
          jsonDecode(utf8.decode(manifestBytes)) as Map<String, Object?>;
      manifest = ProfileBackupManifest.fromJson(manifestJson);
      // Malformed JSON surfaces as FormatException, a wrong shape as a
      // TypeError from the cast or the manifest's own validation.
    } on Object {
      throw const ProfileBackupBundleCorruptException(
        'The manifest is invalid.',
      );
    }

    Directory? payloadRoot;
    if (targetPath != null) {
      Directory(targetPath).createSync(recursive: true);
      targetCreated = true;
      File(
        p.join(targetPath, profileBackupManifestFileName),
      ).writeAsBytesSync(manifestBytes, flush: true);
      payloadRoot = Directory(
        p.join(targetPath, profileBackupPayloadDirectoryName),
      )..createSync();
    }

    for (final entry in manifest.files) {
      final record = reader.readRecord();
      if (record == null ||
          record.name != 'payload/${entry.relativePath}' ||
          record.size != entry.sizeBytes) {
        throw ProfileBackupBundleCorruptException(
          'Unexpected archive entry where ${entry.relativePath} belongs.',
        );
      }
      RandomAccessFile? output;
      if (payloadRoot != null) {
        final destination = resolveInsideRoot(
          payloadRoot.path,
          entry.relativePath,
        );
        File(destination).parent.createSync(recursive: true);
        output = File(destination).openSync(mode: FileMode.writeOnly);
      }
      final digest = _DigestCollector();
      final hasher = hashing.sha256.startChunkedConversion(digest);
      try {
        reader.readInto(record.size, (bytes) {
          hasher.add(bytes);
          output?.writeFromSync(bytes);
        });
        output?.flushSync();
      } finally {
        output?.closeSync();
      }
      hasher.close();
      if (digest.hex != entry.sha256) {
        throw ProfileBackupBundleCorruptException(
          'Checksum mismatch for ${entry.relativePath}.',
        );
      }
    }

    if (reader.readRecord() != null || !reader.isExhausted) {
      throw const ProfileBackupBundleCorruptException(
        'The backup holds unexpected extra data.',
      );
    }
    return manifestJson;
  } catch (_) {
    if (targetCreated && Directory(targetPath!).existsSync()) {
      Directory(targetPath).deleteSync(recursive: true);
    }
    rethrow;
  } finally {
    file.closeSync();
  }
}

/// Joins [relativePath] onto [root], refusing any path that would land
/// outside it.
///
/// Manifest validation already rejects absolute paths and `..` segments, so
/// this is a second line of defence: a restore must never write outside its
/// target, whatever a future manifest version allows.
@visibleForTesting
String resolveInsideRoot(String root, String relativePath) {
  final destination = p.normalize(p.join(root, relativePath));
  if (!p.isWithin(root, destination)) {
    throw ProfileBackupBundleCorruptException(
      'Unsafe path in backup: $relativePath',
    );
  }
  return destination;
}
