import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/tuning.dart';
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
  final decoded = downloadedBytes.length < _inlineGzipThreshold
      ? _asUint8List(gzip.decode(downloadedBytes))
      : await compute(_gzipDecodeWorker, downloadedBytes);
  logging.captureEvent(
    'gzipDecoded path=$relativePath '
    'compressed=${downloadedBytes.length} decoded=${decoded.length} '
    'ratio=${formatCompressionRatio(raw: decoded.length, compressed: downloadedBytes.length)}',
    domain: syncLoggingDomain,
    subDomain: 'attachment.decode',
  );
  return decoded;
}

Uint8List _gzipDecodeWorker(Uint8List bytes) =>
    _asUint8List(gzip.decode(bytes));

/// Gzip-encodes [bytes], offloading to a worker isolate above
/// [_inlineGzipThreshold] so a multi-KB JSON attachment does not stall the
/// UI isolate inside the outbox send path.
///
/// The threshold matches [decodeAttachmentBytes] so both directions pay the
/// one-shot isolate spin-up cost only when the saved main-isolate time is
/// larger than it. Senders below the threshold encode inline.
Future<Uint8List> gzipEncodeBytes(Uint8List bytes) async {
  if (bytes.length < _inlineGzipThreshold) {
    return _asUint8List(gzip.encode(bytes));
  }
  return compute(_gzipEncodeWorker, bytes);
}

Uint8List _gzipEncodeWorker(Uint8List bytes) =>
    _asUint8List(gzip.encode(bytes));

/// `gzip.encode` / `gzip.decode` from `dart:io` return a Uint8List-backed
/// `List<int>`, so the cast avoids an unnecessary copy via
/// `Uint8List.fromList`. Falls back to a copy only when the runtime happens
/// to hand back a non-Uint8List view.
Uint8List _asUint8List(List<int> result) =>
    result is Uint8List ? result : Uint8List.fromList(result);

/// Deduplicates concurrent `downloadAttachmentWithTimeout` calls for the
/// same Matrix event. Without this, the retry tracker (which reschedules
/// a failed prepare with exponential backoff) could stack multiple
/// orphaned SDK downloads on top of an earlier one that has already
/// timed out locally but is still running server-side — each retry
/// spawning a fresh socket/FD. Keyed by `event.eventId`; the future
/// removes itself from the map once it settles.
final Map<String, Future<MatrixFile>> _inFlightAttachmentDownloads =
    <String, Future<MatrixFile>>{};

/// Downloads + decrypts [event]'s attachment with a bounded wait. A hang
/// on the underlying HTTP call used to stall the entire apply pipeline —
/// the live-scan guard never released, and every subsequent timeline
/// signal was silently coalesced. Converting the hang into a
/// `FileSystemException` lets the retry tracker reschedule with backoff
/// and frees the pipeline for other events.
///
/// Dart's `Future.timeout` completes the wrapper but cannot cancel the
/// underlying SDK call, so concurrent retries for the same event are
/// deduplicated via [_inFlightAttachmentDownloads]: callers share the
/// first in-flight download instead of each spawning a fresh one.
/// [pathForError] is included in the `FileSystemException` path slot so
/// diagnostics can tell which attachment timed out.
Future<MatrixFile> downloadAttachmentWithTimeout(
  Event event, {
  String? pathForError,
  Duration? timeout,
}) async {
  final effective = timeout ?? SyncTuning.attachmentDownloadTimeout;
  // `event.eventId` is typed non-nullable but mocks can still return null
  // and the in-memory event list has had intermittent empty-id entries
  // historically. Guard defensively; an absent key falls back to
  // non-dedup'd download behaviour.
  final key = _safeEventId(event);
  final existing = key == null ? null : _inFlightAttachmentDownloads[key];
  final download =
      existing ??
      () {
        final future = event.downloadAndDecryptAttachment();
        if (key != null) {
          _inFlightAttachmentDownloads[key] = future;
          future.whenComplete(() {
            if (identical(_inFlightAttachmentDownloads[key], future)) {
              _inFlightAttachmentDownloads.remove(key);
            }
          });
        }
        return future;
      }();
  try {
    return await download.timeout(effective);
  } on TimeoutException {
    throw FileSystemException(
      'attachment download timed out after ${effective.inSeconds}s',
      pathForError ?? key ?? 'unknown',
    );
  }
}

String? _safeEventId(Event event) {
  try {
    final id = event.eventId;
    return id.isEmpty ? null : id;
  } catch (_) {
    return null;
  }
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
