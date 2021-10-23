import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wisely/sync/vector_clock.dart';

part 'audio_note.freezed.dart';
part 'audio_note.g.dart';

@freezed
class AudioNote with _$AudioNote {
  factory AudioNote({
    required String id,
    required int timestamp,
    required DateTime createdAt,
    required int utcOffset,
    required String timezone,
    required String audioFile,
    required String audioDirectory,
    required Duration duration,
    DateTime? updatedAt,
    String? transcript,
    double? latitude,
    double? longitude,
    VectorClock? vectorClock,
  }) = _AudioNote;

  factory AudioNote.fromJson(Map<String, dynamic> json) =>
      _$AudioNoteFromJson(json);
}
