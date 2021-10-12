import 'package:json_annotation/json_annotation.dart';
import 'package:wisely/sync/vector_clock.dart';

part 'audio_note.g.dart';

@JsonSerializable()
class AudioNote {
  final String id;
  final int timestamp;
  final DateTime createdAt;
  final int utcOffset;
  final String timezone;
  final String audioFile;
  final String audioDirectory;
  Duration duration;
  DateTime? updatedAt;
  String? transcript;
  double? latitude;
  double? longitude;
  VectorClock? vectorClock;

  AudioNote({
    required this.id,
    required this.timestamp,
    required this.createdAt,
    required this.utcOffset,
    required this.timezone,
    required this.audioFile,
    required this.audioDirectory,
    required this.duration,
    this.updatedAt,
    this.transcript,
    this.latitude,
    this.longitude,
    this.vectorClock,
  });

  factory AudioNote.fromJson(Map<String, dynamic> json) =>
      _$AudioNoteFromJson(json);

  Map<String, dynamic> toJson() => _$AudioNoteToJson(this);

  @override
  String toString() {
    return 'AudioNote id: $id, created: $createdAt, '
        'audioFile: $audioFile, duration: $duration';
  }
}
