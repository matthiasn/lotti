import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_helpers.dart'
    as msh;
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
// Platform toggle no longer needed here.
import 'package:matrix/matrix.dart';

class MatrixEventClassifier {
  const MatrixEventClassifier._();

  static bool isAttachment(Event e) => e.attachmentMimetype.isNotEmpty;

  /// True if the event is a Lotti sync payload, either by msgtype or fallback
  /// base64 JSON payload containing a runtimeType.
  static bool isSyncPayloadEvent(Event e) {
    final content = e.content;
    final msgType = content['msgtype'];
    if (msgType == syncMessageType) return true;
    return msh.isLikelySyncPayloadEvent(e);
  }

  // Prefetch removed.

  static num timestamp(Event e) => TimelineEventOrdering.timestamp(e);
}
