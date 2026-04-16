import 'dart:io';
import 'dart:typed_data';

import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// Decodes the raw downloaded attachment bytes according to any encoding
/// declared in the Matrix event content. Currently only gzip is recognized.
///
/// Returns the bytes unchanged when no `com.lotti.encoding` header is present,
/// so the decoder is a safe no-op on non-encoded attachments and on every
/// attachment produced by senders that predate this feature.
///
/// Must wrap every caller of `event.downloadAndDecryptAttachment()` that
/// treats the bytes as a concrete payload (JSON, media file, etc.), otherwise
/// a gzipped `.json` attachment reaches `utf8.decode` as `0x1f 0x8b ...` and
/// explodes with `FormatException: Unexpected extension byte`.
Uint8List decodeAttachmentBytes({
  required Event event,
  required Uint8List downloadedBytes,
  required String relativePath,
  required LoggingService logging,
}) {
  final encoding = event.content[attachmentEncodingKey];
  if (encoding != attachmentEncodingGzip) return downloadedBytes;
  final decoded = gzip.decode(downloadedBytes);
  logging.captureEvent(
    'gzipDecoded path=$relativePath '
    'compressed=${downloadedBytes.length} decoded=${decoded.length} '
    'ratio=${formatCompressionRatio(raw: decoded.length, compressed: downloadedBytes.length)}',
    domain: syncLoggingDomain,
    subDomain: 'attachment.decode',
  );
  return decoded is Uint8List ? decoded : Uint8List.fromList(decoded);
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
