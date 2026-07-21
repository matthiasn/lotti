import 'package:freezed_annotation/freezed_annotation.dart';

part 'day_audio_context.freezed.dart';
part 'day_audio_context.g.dart';

/// Immutable Daily OS provenance carried from microphone admission through
/// journal persistence, local processing, Activity projection, and agent
/// context assembly.
@freezed
abstract class DayAudioContext with _$DayAudioContext {
  const factory DayAudioContext({
    required String dayId,
    required DateTime planDate,
    required String recordingSessionId,
    required String activityEntryId,
    required String processingJobId,
    required DateTime capturedAt,
    required String intent,
    @Default(1) int schemaVersion,
    String? originHostId,
    String? continuationOperationId,
    String? baselineRevisionId,
  }) = _DayAudioContext;

  factory DayAudioContext.fromJson(Map<String, dynamic> json) =>
      _$DayAudioContextFromJson(json);
}
