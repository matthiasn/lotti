import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:matrix/matrix.dart';

/// Ciphertext size from which [MatrixNativeImplementations.decryptFile]
/// decrypts on a background isolate. Below it the SHA-256 check and AES-CTR
/// pass take well under a millisecond, less than spawning an isolate and
/// loading the vodozemac library into it — and nearly every synced entry is a
/// JSON attachment of a few kilobytes.
const int matrixDecryptOffloadThresholdBytes = 64 * 1024;

/// Runs `callback(message)` on another isolate; the shape of Flutter's
/// [compute] that [NativeImplementationsIsolate] takes.
typedef MatrixComputeCallback =
    Future<R> Function<Q, R>(
      FutureOr<R> Function(Q message) callback,
      Q message, {
      String? debugLabel,
    });

/// The Matrix SDK's demanding crypto, run off the UI isolate.
///
/// Without this the SDK falls back to [NativeImplementations.dummy], which
/// decrypts every downloaded attachment, derives SSSS keys and builds key
/// backup uploads on the calling isolate — for a multi-megabyte image that is
/// tens to hundreds of milliseconds of frames lost mid-scroll. Each spawned
/// isolate initialises vodozemac itself, because its Rust bindings are bound
/// per isolate.
class MatrixNativeImplementations extends NativeImplementationsIsolate {
  MatrixNativeImplementations({
    MatrixComputeCallback computeCallback = compute,
    Future<void> Function() vodozemacInit = vod.init,
    @visibleForTesting this._inline = NativeImplementations.dummy,
  }) : super(computeCallback, vodozemacInit: vodozemacInit);

  final NativeImplementations _inline;

  @override
  Future<Uint8List?> decryptFile(
    EncryptedFile file, {
    bool retryInDummy = true,
  }) async {
    if (file.data.lengthInBytes < matrixDecryptOffloadThresholdBytes) {
      return _inline.decryptFile(file, retryInDummy: retryInDummy);
    }
    return super.decryptFile(file, retryInDummy: retryInDummy);
  }
}
