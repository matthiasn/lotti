// Descriptor observation only; no filesystem access here.

import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/descriptor_catch_up_manager.dart';
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// AttachmentIngestor
///
/// Purpose
/// - Encapsulates first-pass attachment handling for the sync pipeline:
///   - Record descriptors into AttachmentIndex and emit observability logs
///   - Clear pending jsonPaths via [DescriptorCatchUpManager] and nudge scans
///
/// This helper has no internal state; it operates on provided arguments.
class AttachmentIngestor {
  const AttachmentIngestor();

  /// Processes attachment-related behavior for an event.
  Future<void> process({
    required Event event,
    required LoggingService logging,
    required AttachmentIndex? attachmentIndex,
    required bool collectMetrics,
    required MetricsCounters metrics,
    required DescriptorCatchUpManager? descriptorCatchUp,
    required void Function() scheduleLiveScan,
    required Future<void> Function() retryNow,
  }) async {
    // Record descriptors when present and emit a compact observability line.
    final rpAny = event.content['relativePath'];
    if (rpAny is String && rpAny.isNotEmpty) {
      attachmentIndex?.record(event);
      // Observability log for attachment-like events.
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
    // No media downloads here.
  }
}
