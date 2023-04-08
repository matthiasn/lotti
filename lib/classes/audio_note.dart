import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio_note.freezed.dart';
part 'audio_note.g.dart';

@freezed
class AudioNote with _$AudioNote {
  factory AudioNote({
    required DateTime createdAt,
    required String audioFile,
    required String audioDirectory,
    required Duration duration,
  }) = _AudioNote;

  factory AudioNote.fromJson(Map<String, dynamic> json) =>
      _$AudioNoteFromJson(json);
}
