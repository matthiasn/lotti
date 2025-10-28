import 'dart:io';

import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/descriptor_catch_up_manager.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_event_classifier.dart'
    as ec;
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/features/sync/matrix/save_attachment.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// AttachmentIngestor
///
/// Purpose
/// - Encapsulates first-pass attachment handling for the sync pipeline:
///   - Record descriptors into AttachmentIndex and emit observability logs
///   - Optionally prefetch media (image/audio/video) when policy allows
///   - Clear pending jsonPaths via [DescriptorCatchUpManager] and nudge scans
///
/// This helper has no internal state; it operates on provided arguments and
/// returns whether a media file was newly written.
class AttachmentIngestor {
  const AttachmentIngestor();

  /// Processes attachment-related behavior for an event.
  ///
  /// Returns `true` if a media prefetch wrote a new file.
  Future<bool> process({
    required Event event,
    required LoggingService logging,
    required Directory documentsDirectory,
    required AttachmentIndex? attachmentIndex,
    required bool collectMetrics,
    required MetricsCounters metrics,
    required num? lastProcessedTs,
    required Duration attachmentTsGate,
    required String? currentUserId,
    required DescriptorCatchUpManager? descriptorCatchUp,
    required void Function() scheduleLiveScan,
    required Future<void> Function() retryNow,
  }) async {
    var wroteMedia = false;

    // Record descriptors when present and emit a compact observability line.
    final rpAny = event.content['relativePath'];
    if (rpAny is String && rpAny.isNotEmpty) {
      attachmentIndex?.record(event);
      if (collectMetrics) {
        metrics
          ..incPrefetch()
          ..addLastPrefetched(rpAny);
      }
      try {
        final mime = event.attachmentMimetype;
        final content = event.content;
        final hasUrl = content.containsKey('url') ||
            content.containsKey('mxc') ||
            content.containsKey('mxcUrl') ||
            content.containsKey('uri');
        final hasEnc = content.containsKey('file');
        final msgType = content['msgtype'];
        logging.captureEvent(
          'attachmentEvent id=${event.eventId} path=$rpAny mime=$mime msgtype=$msgType hasUrl=$hasUrl hasFile=$hasEnc',
          domain: syncLoggingDomain,
          subDomain: 'attachment.observe',
        );
      } catch (_) {
        // best-effort logging only
      }
      if (descriptorCatchUp?.removeIfPresent(rpAny) ?? false) {
        scheduleLiveScan();
        await retryNow();
      }
    }
    // Media prefetch policy (images/audio/video) for remote attachments only.
    if (ec.MatrixEventClassifier.shouldPrefetchAttachment(
        event, currentUserId)) {
      // Timestamp gate: skip clearly older attachments relative to last processed
      if (lastProcessedTs != null) {
        final ts = TimelineEventOrdering.timestamp(event);
        if (ts < lastProcessedTs.toInt() - attachmentTsGate.inMilliseconds) {
          logging.captureEvent(
            'prefetch.skip.tsGate id=${event.eventId}',
            domain: syncLoggingDomain,
            subDomain: 'prefetch',
          );
          return false;
        }
      }
      try {
        final wrote = await saveAttachment(
          event,
          loggingService: logging,
          documentsDirectory: documentsDirectory,
        );
        if (wrote) {
          wroteMedia = true;
          // Descriptor pending clearance (and retryNow) is handled above when
          // the descriptor path is observed. No need to repeat here.
        }
      } catch (err, st) {
        logging.captureException(
          err,
          domain: syncLoggingDomain,
          subDomain: 'prefetch',
          stackTrace: st,
        );
        if (collectMetrics) metrics.incFailures();
      }
    }

    return wroteMedia;
  }
}
