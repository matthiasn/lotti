import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/matrix_native_implementations.dart';
import 'package:matrix/matrix.dart';

/// Records what it is asked to decrypt and answers with a marker, standing in
/// for the vodozemac-backed dummy that unit tests cannot load.
class _RecordingInline extends NativeImplementationsDummy {
  final decrypted = <EncryptedFile>[];

  @override
  Future<Uint8List?> decryptFile(
    EncryptedFile file, {
    bool retryInDummy = true,
  }) async {
    decrypted.add(file);
    return Uint8List.fromList([42]);
  }
}

/// Stops the offloaded callback right after it initialised vodozemac, before
/// it reaches the native decryption a unit test cannot run.
class _InitReached implements Exception {}

EncryptedFile _file(int size) =>
    EncryptedFile(data: Uint8List(size), k: 'k', iv: 'iv', sha256: 'sha');

void main() {
  late _RecordingInline inline;
  late List<Object?> computedMessages;
  late int vodozemacInits;

  Future<R> fakeCompute<Q, R>(
    FutureOr<R> Function(Q message) callback,
    Q message, {
    String? debugLabel,
  }) async {
    computedMessages.add(message);
    return callback(message);
  }

  Future<void> vodozemacInit() async {
    vodozemacInits++;
    throw _InitReached();
  }

  MatrixNativeImplementations build() => MatrixNativeImplementations(
    computeCallback: fakeCompute,
    vodozemacInit: vodozemacInit,
    inline: inline,
  );

  setUp(() {
    inline = _RecordingInline();
    computedMessages = [];
    vodozemacInits = 0;
  });

  group('MatrixNativeImplementations.decryptFile', () {
    test(
      'decrypts a file below the threshold on the calling isolate',
      () async {
        final file = _file(matrixDecryptOffloadThresholdBytes - 1);

        final result = await build().decryptFile(file);

        expect(result, [42]);
        expect(inline.decrypted, [same(file)]);
        expect(computedMessages, isEmpty);
        expect(vodozemacInits, 0);
      },
    );

    test(
      'hands a file at the threshold to a background isolate that '
      'initialises vodozemac before decrypting',
      () async {
        final file = _file(matrixDecryptOffloadThresholdBytes);

        await expectLater(
          build().decryptFile(file),
          throwsA(isA<_InitReached>()),
        );

        expect(computedMessages, [same(file)]);
        expect(vodozemacInits, 1);
        expect(inline.decrypted, isEmpty);
      },
    );
  });
}
