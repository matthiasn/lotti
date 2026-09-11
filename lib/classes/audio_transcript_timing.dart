import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio_transcript_timing.freezed.dart';
part 'audio_transcript_timing.g.dart';

/// Provider-reported speech boundaries, in milliseconds from the recording's
/// start. Text is the recognizer's wording, never a replacement for a note.
@freezed
abstract class AudioTimedSegment with _$AudioTimedSegment {
  const factory AudioTimedSegment({
    required String text,
    required int startMilliseconds,
    required int endMilliseconds,
  }) = _AudioTimedSegment;

  factory AudioTimedSegment.fromJson(Map<String, dynamic> json) =>
      _$AudioTimedSegmentFromJson(json);
}

/// On-demand timing for one exact recording and stored source representation.
/// Kept separately from transcripts so enrichment cannot change searchable text
/// or make a new machine transcript supersede the user's wording.
@freezed
abstract class AudioTranscriptTiming with _$AudioTranscriptTiming {
  const factory AudioTranscriptTiming({
    required DateTime createdAt,
    required String audioSha256,
    required String sourceFingerprint,
    required String sourceVersion,
    required String providerId,
    required String model,
    required List<AudioTimedSegment> segments,
  }) = _AudioTranscriptTiming;

  factory AudioTranscriptTiming.fromJson(Map<String, dynamic> json) =>
      _$AudioTranscriptTimingFromJson(json);
}
