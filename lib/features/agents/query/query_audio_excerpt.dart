import 'dart:math' as math;

import 'package:lotti/classes/audio_transcript_timing.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';

/// A range of the original recording, including a little listening context.
/// Long quotations retain their full duration rather than being cut mid-proof.
class QueryAudioExcerpt {
  const QueryAudioExcerpt({required this.start, required this.end});

  final Duration start;
  final Duration end;
}

/// Locates the saved words without asking an LLM to invent a time offset.
/// Case, punctuation, whitespace and generated speaker labels may differ;
/// substituted, missing or repeated wording fails closed. Every timestamp
/// comes from a provider segment bound to this source's text fingerprint.
QueryAudioExcerpt? queryAudioExcerpt({
  required QueryEvidence evidence,
  required AudioTranscriptTiming timing,
  required Duration duration,
}) {
  if (!evidence.hasValidPassage ||
      evidence.kind != QuerySourceKind.recording ||
      evidence.fingerprint != timing.sourceFingerprint ||
      duration <= Duration.zero ||
      timing.segments.isEmpty ||
      timing.segments.length > 30000) {
    return null;
  }
  // Imported recordings may lack duration metadata. Timed speech provides a
  // conservative end boundary; never pad beyond it when duration is unknown.
  final recordingEnd = duration == Duration.zero
      ? timing.segments.last.endMilliseconds
      : duration.inMilliseconds;
  final words = <String>[];
  final owners = <int>[];
  var previousStart = -1;
  var previousEnd = -1;
  var characters = 0;
  for (final (index, segment) in timing.segments.indexed) {
    final start = segment.startMilliseconds;
    final end = segment.endMilliseconds;
    characters += segment.text.length;
    if (start < 0 ||
        end <= start ||
        start < previousStart ||
        end < previousEnd ||
        end > recordingEnd ||
        characters > 2000000) {
      return null;
    }
    final segmentWords = _words(segment.text);
    if (segmentWords.isEmpty) return null;
    words.addAll(segmentWords);
    owners.addAll(List.filled(segmentWords.length, index));
    previousStart = start;
    previousEnd = end;
  }
  final quote = _words(evidence.quote);
  if (quote.isEmpty || quote.length > words.length) return null;
  // KMP keeps even repetitive, hours-long transcripts linear in input size.
  final prefix = List.filled(quote.length, 0);
  for (var i = 1, matched = 0; i < quote.length; i++) {
    while (matched > 0 && quote[i] != quote[matched]) {
      matched = prefix[matched - 1];
    }
    if (quote[i] == quote[matched]) matched++;
    prefix[i] = matched;
  }
  int? found;
  for (var i = 0, matched = 0; i < words.length; i++) {
    while (matched > 0 && words[i] != quote[matched]) {
      matched = prefix[matched - 1];
    }
    if (words[i] == quote[matched]) matched++;
    if (matched == quote.length) {
      if (found != null) return null;
      found = i - quote.length + 1;
      matched = prefix[matched - 1];
    }
  }
  if (found == null) return null;
  final first = timing.segments[owners[found]].startMilliseconds;
  final last =
      timing.segments[owners[found + quote.length - 1]].endMilliseconds;
  final padding = math.max(5000, (60000 - (last - first)) ~/ 2);
  final start = math.max(0, first - padding);
  final end = math.min(recordingEnd, last + padding);
  return QueryAudioExcerpt(
    start: Duration(milliseconds: start),
    end: Duration(milliseconds: end),
  );
}

List<String> _words(String text) => RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true)
    .allMatches(
      text.replaceAll(RegExp(r'^\s*\[Speaker \d+\]\s*', multiLine: true), ''),
    )
    .map((match) => match.group(0)!.toLowerCase())
    .toList();
