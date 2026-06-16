import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_helpers.dart'
    as msh;
// Platform toggle no longer needed here.
import 'package:matrix/matrix.dart';

/// Stateless predicates for deciding what kind of Matrix [Event] the pipeline
/// is looking at — used to filter the timeline down to the sync payloads and
/// attachments this app cares about, ignoring state events, redactions, etc.
class MatrixEventClassifier {
  const MatrixEventClassifier._();

  /// True when the event carries a file attachment (non-empty mimetype).
  static bool isAttachment(Event e) => e.attachmentMimetype.isNotEmpty;

  /// True if the event is a Lotti sync payload, either by msgtype or fallback
  /// base64 JSON payload containing a runtimeType.
  static bool isSyncPayloadEvent(Event e) {
    final content = e.content;
    final msgType = content['msgtype'];
    if (msgType == syncMessageType) return true;
    return msh.isLikelySyncPayloadEvent(e);
  }
}
