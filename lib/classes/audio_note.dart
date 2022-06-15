import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/sync/vector_clock.dart';

part 'audio_note.freezed.dart';
part 'audio_note.g.dart';

@freezed
class AudioNote with _$AudioNote {
  factory AudioNote({
    required String id,
    required int timestamp,
    required DateTime createdAt,
    required String audioFile,
    required String audioDirectory,
    required Duration duration,
    int? utcOffset,
    String? timezone,
    DateTime? updatedAt,
    String? transcript,
    EntryText? entryText,
    Geolocation? geolocation,
    VectorClock? vectorClock,
  }) = _AudioNote;

  factory AudioNote.fromJson(Map<String, dynamic> json) =>
      _$AudioNoteFromJson(json);
}
