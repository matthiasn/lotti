/// Pure transcript-merge logic for realtime transcription backends that
/// re-send the full confirmed transcript instead of incremental deltas
/// (e.g. MLX Qwen3-ASR confirmed events).
library;

/// Extracts the newly confirmed delta when a backend reports the full
/// confirmed transcript [next] after having reported [previous].
///
/// Handles growth (append remainder), truncation/rewind (empty delta),
/// suffix/prefix overlap (e.g. re-chunked confirmations), and divergence
/// (falls back to everything after the common prefix). The result is always
/// a suffix of [next], so appending it never duplicates confirmed text.
String confirmedTextDelta({
  required String previous,
  required String next,
}) {
  if (previous.isEmpty || next.startsWith(previous)) {
    return next.substring(previous.length);
  }
  if (previous.startsWith(next)) {
    return '';
  }

  final overlapLength = _suffixPrefixOverlapLength(previous, next);
  if (overlapLength > 0) {
    return next.substring(overlapLength);
  }

  return next.substring(_commonPrefixLength(previous, next));
}

/// Picks the more complete transcript between the backend's final text and
/// the locally accumulated deltas: returns [accumulatedText] when its trimmed
/// form is strictly longer than the trimmed [finalText], otherwise
/// [finalText].
String moreCompleteTranscript({
  required String finalText,
  required String accumulatedText,
}) {
  final trimmedFinal = finalText.trim();
  final trimmedAccumulated = accumulatedText.trim();
  if (trimmedAccumulated.length > trimmedFinal.length) {
    return accumulatedText;
  }
  return finalText;
}

int _suffixPrefixOverlapLength(String previous, String next) {
  final maxLength = previous.length < next.length
      ? previous.length
      : next.length;
  for (var length = maxLength; length > 0; length--) {
    if (previous.endsWith(next.substring(0, length))) {
      return length;
    }
  }
  return 0;
}

int _commonPrefixLength(String a, String b) {
  final maxLength = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < maxLength; i++) {
    if (a.codeUnitAt(i) != b.codeUnitAt(i)) {
      return i;
    }
  }
  return maxLength;
}
