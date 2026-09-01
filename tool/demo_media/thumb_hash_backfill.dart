// The demo-media ThumbHash backfill: one blurred stand-in per object in the
// Penguin Logistics catalog, computed from the object's bytes in R2 and
// written into lib/features/demo/media/generated/demo_media_thumb_hashes.g.dart
// so the app can draw it before the object has downloaded.
//
// The entry point is thumb_hashes.dart next to this file; this library holds
// the logic so a test can drive it with an in-memory catalog, a fake
// downloader and no clock.
//
// The catalog comes from the app itself, so nothing here needs S3 credentials
// or a bucket listing: plain HTTPS GETs against the public origin, retried
// with backoff on 429 and 5xx because r2.dev rate-limits bursts.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/utils/thumbhash.dart';

/// Where the generated map lives, relative to the repository root.
const demoMediaThumbHashesPath =
    'lib/features/demo/media/generated/demo_media_thumb_hashes.g.dart';

/// Attempts per object before its download counts as failed.
const thumbHashBackfillMaxAttempts = 4;

/// Bytes for one catalog object; throws [ThumbHashDownloadException] when
/// the origin did not hand them over.
typedef ThumbHashDownload = Future<Uint8List> Function(Uri uri);

/// Waits between attempts. Injected so a test never sleeps.
typedef ThumbHashDelay = Future<void> Function(Duration duration);

/// A download that did not produce the object's bytes.
class ThumbHashDownloadException implements Exception {
  const ThumbHashDownloadException(this.uri, {this.statusCode, this.cause});

  final Uri uri;

  /// The HTTP status, or null when no response arrived at all.
  final int? statusCode;

  /// The underlying error when no response arrived.
  final Object? cause;

  /// Rate limiting, server errors and no-response failures are worth another
  /// try; a 404 for an object that is not there is not.
  bool get isTransient {
    final status = statusCode;
    return status == null || status == 429 || status >= 500;
  }

  @override
  String toString() => statusCode == null
      ? 'No response for $uri: $cause'
      : 'HTTP $statusCode for $uri';
}

/// A [ThumbHashDownload] over [client], mapping every way a GET can fall
/// short onto [ThumbHashDownloadException] so the backfill can tell a retry
/// from a dead end.
Future<Uint8List> downloadWithClient(
  http.Client client,
  Uri uri, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final http.Response response;
  try {
    response = await client.get(uri).timeout(timeout);
  } on http.ClientException catch (error) {
    throw ThumbHashDownloadException(uri, cause: error);
  } on TimeoutException catch (error) {
    throw ThumbHashDownloadException(uri, cause: error);
  }
  if (response.statusCode != 200) {
    throw ThumbHashDownloadException(uri, statusCode: response.statusCode);
  }
  return response.bodyBytes;
}

/// What one run did, by object file name, and the map it leaves behind.
class ThumbHashBackfillReport {
  const ThumbHashBackfillReport({
    required this.hashes,
    required this.processed,
    required this.skipped,
    required this.pruned,
    required this.failures,
  });

  /// The complete map to write: every catalog digest that has a hash.
  final Map<String, String> hashes;

  /// Objects hashed on this run.
  final List<String> processed;

  /// Objects that already had a hash and were left alone.
  final List<String> skipped;

  /// Digests dropped because no catalog object carries them any more.
  final List<String> pruned;

  /// Objects that could not be hashed, with the reason.
  final Map<String, Object> failures;

  bool get hasFailures => failures.isNotEmpty;

  String get summary =>
      'processed ${processed.length}, skipped ${skipped.length}, '
      'pruned ${pruned.length}, failed ${failures.length}';
}

/// The ThumbHash of an encoded image (WebP, JPEG, PNG, …).
///
/// The image is shrunk so its longest edge is at most
/// [thumbHashMaxInputExtent], the hash's input limit, box-filtered so that
/// what survives is the average of each region rather than a sample of it.
ThumbHash thumbHashForImageBytes(Uint8List bytes) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on Object catch (error) {
    // A decoder that trips over junk bytes throws whatever it likes
    // (a RangeError for a buffer shorter than its header, say); to the
    // backfill that is one thing: not an image.
    throw FormatException('Not a decodable image: $error');
  }
  if (decoded == null) {
    throw const FormatException('Not a decodable image');
  }
  final longest = math.max(decoded.width, decoded.height);
  final resized = longest <= thumbHashMaxInputExtent
      ? decoded
      : img.copyResize(
          decoded,
          width: math.max(
            1,
            (decoded.width * thumbHashMaxInputExtent / longest).round(),
          ),
          height: math.max(
            1,
            (decoded.height * thumbHashMaxInputExtent / longest).round(),
          ),
          interpolation: img.Interpolation.average,
        );
  final rgba = resized
      .convert(format: img.Format.uint8, numChannels: 4)
      .getBytes(order: img.ChannelOrder.rgba);
  return ThumbHash.encode(
    width: resized.width,
    height: resized.height,
    rgba: rgba,
  );
}

/// Hashes every catalog object that [existing] does not cover yet — or every
/// object, under [force] — and reports what happened.
///
/// One object failing never stops the rest: its failure is logged and
/// reported, and the map keeps whatever it already had for that digest.
/// Digests that no catalog object carries any more are pruned, so a replaced
/// image never leaves its old hash behind. Objects are fetched one at a time
/// on purpose: the origin rate-limits bursts.
Future<ThumbHashBackfillReport> runThumbHashBackfill({
  required List<DemoMediaAsset> catalog,
  required Map<String, String> existing,
  required ThumbHashDownload download,
  required ThumbHashDelay delay,
  required StringSink log,
  bool force = false,
  int maxAttempts = thumbHashBackfillMaxAttempts,
}) async {
  final hashes = Map<String, String>.of(existing);
  final processed = <String>[];
  final skipped = <String>[];
  final failures = <String, Object>{};

  for (final asset in catalog) {
    if (!force && hashes.containsKey(asset.sha256)) {
      skipped.add(asset.fileName);
      log.writeln('- ${asset.fileName}: already hashed');
      continue;
    }
    try {
      final bytes = await _downloadWithRetry(
        asset,
        download: download,
        delay: delay,
        log: log,
        maxAttempts: maxAttempts,
      );
      final digest = sha256.convert(bytes).toString();
      if (digest != asset.sha256) {
        throw StateError(
          'Downloaded bytes digest to $digest, catalog says ${asset.sha256}',
        );
      }
      final hash = thumbHashForImageBytes(bytes).toBase64();
      hashes[asset.sha256] = hash;
      processed.add(asset.fileName);
      log.writeln('+ ${asset.fileName}: $hash');
    } catch (error) {
      failures[asset.fileName] = error;
      log.writeln('! ${asset.fileName}: $error');
    }
  }

  final catalogDigests = {for (final asset in catalog) asset.sha256};
  final pruned = [
    for (final digest in hashes.keys)
      if (!catalogDigests.contains(digest)) digest,
  ];
  for (final digest in pruned) {
    hashes.remove(digest);
    log.writeln('x $digest: no longer in the catalog');
  }

  return ThumbHashBackfillReport(
    hashes: hashes,
    processed: processed,
    skipped: skipped,
    pruned: pruned,
    failures: failures,
  );
}

Future<Uint8List> _downloadWithRetry(
  DemoMediaAsset asset, {
  required ThumbHashDownload download,
  required ThumbHashDelay delay,
  required StringSink log,
  required int maxAttempts,
}) async {
  var attempt = 0;
  while (true) {
    attempt++;
    try {
      return await download(asset.uri);
    } on ThumbHashDownloadException catch (error) {
      if (!error.isTransient || attempt >= maxAttempts) rethrow;
      final wait = Duration(seconds: 1 << (attempt - 1));
      log.writeln(
        '  ${asset.fileName}: $error, retrying in ${wait.inSeconds}s '
        '(attempt $attempt of $maxAttempts)',
      );
      await delay(wait);
    }
  }
}

/// The generated Dart source for [hashes], sorted by digest so two runs over
/// the same catalog produce the same bytes.
String renderThumbHashMap(Map<String, String> hashes) {
  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
    ..writeln('//')
    ..writeln(
      '// One ThumbHash per object in the demo-media catalog, keyed by the '
      "object's",
    )
    ..writeln(
      '// SHA-256 digest so a replaced image loses its stale hash by itself. '
      'The app',
    )
    ..writeln(
      '// draws these as blurred stand-ins while the objects download from R2.',
    )
    ..writeln('//')
    ..writeln('// Regenerate with `make demo_media_thumb_hashes`, which runs')
    ..writeln(
      '// tool/demo_media/thumb_hashes.dart. An object already in this map '
      'is left',
    )
    ..writeln('// alone unless the run is forced.')
    ..writeln()
    ..writeln('/// Base64 ThumbHash by demo-media object `sha256`.');
  if (hashes.isEmpty) {
    buffer.writeln(
      'const Map<String, String> demoMediaThumbHashes = <String, String>{};',
    );
    return buffer.toString();
  }
  buffer.writeln(
    'const Map<String, String> demoMediaThumbHashes = <String, String>{',
  );
  final digests = hashes.keys.toList()..sort();
  for (final digest in digests) {
    buffer
      ..writeln("  '$digest':")
      ..writeln("      '${hashes[digest]}',");
  }
  buffer.writeln('};');
  return buffer.toString();
}
