/// Margin (chars) the full-file batch transcript must beat realtime by before
/// it replaces the realtime transcript.
///
/// Realtime and batch routinely differ by a few characters of
/// punctuation/whitespace; this margin avoids swapping out a good realtime
/// transcript for a near-identical batch one and only kicks in when batch is
/// meaningfully longer (i.e. realtime truncated).
const batchTranscriptOvertakeMargin = 8;

/// Decides whether the full-file [batchTranscript] should replace the live
/// [realtimeTranscript].
///
/// Pure selection logic shared by the capture controller's realtime finish
/// path; the actual transcription round-trip and the verify gate live in the
/// controller. Rules:
/// * An empty batch transcript never replaces realtime.
/// * Batch wins when realtime is empty or the realtime session reported it had
///   to fall back ([usedTranscriptFallback]).
/// * Otherwise batch wins only when it is longer than realtime by more than
///   [margin] characters (repairs obvious realtime truncation).
String selectFinalTranscript({
  required String realtimeTranscript,
  required String batchTranscript,
  required bool usedTranscriptFallback,
  int margin = batchTranscriptOvertakeMargin,
}) {
  if (batchTranscript.isEmpty) return realtimeTranscript;
  if (realtimeTranscript.isEmpty || usedTranscriptFallback) {
    return batchTranscript;
  }
  if (batchTranscript.length > realtimeTranscript.length + margin) {
    return batchTranscript;
  }
  return realtimeTranscript;
}
