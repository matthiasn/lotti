import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// Payloads smaller than this are decoded inline — the fixed cost of spawning
/// a one-shot isolate for `compute` dominates the actual `gzip.decode` cost
/// for tiny payloads, and attachments in this range show up in bursts during
/// catch-up. Values above the threshold (agent entities ~500 B – 145 KB in
/// production, task payloads up to several KB) hand off to the worker so the
/// UI isolate keeps ticking while the decode runs.
const int _inlineGzipThreshold = 2 * 1024;

/// Decodes the raw downloaded attachment bytes according to any encoding
/// declared in the Matrix event content. Currently only gzip is recognized.
///
/// Returns the bytes unchanged when no `com.lotti.encoding` header is present,
/// so the decoder is a safe no-op on non-encoded attachments and on every
/// attachment produced by senders that predate this feature.
///
/// Larger gzip payloads are decoded on a worker isolate via `compute` so that
/// `gzip.decode` — which is synchronous and CPU-bound — does not stall the UI
/// isolate during a catch-up slice. Small payloads stay inline to avoid the
/// one-shot isolate spin-up cost dominating their decode time.
///
/// Must wrap every caller of `event.downloadAndDecryptAttachment()` that
/// treats the bytes as a concrete payload (JSON, media file, etc.), otherwise
/// a gzipped `.json` attachment reaches `utf8.decode` as `0x1f 0x8b ...` and
/// explodes with `FormatException: Unexpected extension byte`.
Future<Uint8List> decodeAttachmentBytes({
  required Event event,
  required Uint8List downloadedBytes,
  required String relativePath,
  required LoggingService logging,
}) async {
  final encoding = event.content[attachmentEncodingKey];
  if (encoding != attachmentEncodingGzip) return downloadedBytes;
  final Uint8List decoded;
  if (downloadedBytes.length < _inlineGzipThreshold) {
    final result = gzip.decode(downloadedBytes);
    decoded = result is Uint8List ? result : Uint8List.fromList(result);
  } else {
    decoded = await compute(_gzipDecodeWorker, downloadedBytes);
  }
  logging.captureEvent(
    'gzipDecoded path=$relativePath '
    'compressed=${downloadedBytes.length} decoded=${decoded.length} '
    'ratio=${formatCompressionRatio(raw: decoded.length, compressed: downloadedBytes.length)}',
    domain: syncLoggingDomain,
    subDomain: 'attachment.decode',
  );
  return decoded;
}

/// Worker entry point for `compute`. Must be a top-level function so the
/// runtime can hand it to a background isolate.
Uint8List _gzipDecodeWorker(Uint8List bytes) {
  final result = gzip.decode(bytes);
  return result is Uint8List ? result : Uint8List.fromList(result);
}

/// Formats a gzip compression ratio as `compressed / raw` to 3 decimals.
///
/// Rendered identically on both ends of a sync (sender and receiver) so that
/// `grep 'ratio=' sync-*.log` aggregates cleanly across peers.
/// Returns `'-'` when [raw] is 0 to keep the log line well-formed on the
/// defensively-handled empty-payload path.
String formatCompressionRatio({required int raw, required int compressed}) {
  if (raw <= 0) return '-';
  return (compressed / raw).toStringAsFixed(3);
}
