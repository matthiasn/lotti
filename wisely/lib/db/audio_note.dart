import 'package:json_annotation/json_annotation.dart';

part 'audio_note.g.dart';

@JsonSerializable()
class AudioNote {
  final String id;
  final int createdAt;
  final String audioFile;
  final String audioDirectory;
  int duration;
  int? updatedAt;
  String? transcript;
  double? latitude;
  double? longitude;
  String? vectorClock;

  AudioNote({
    required this.id,
    required this.createdAt,
    required this.audioFile,
    required this.audioDirectory,
    required this.duration,
    this.updatedAt,
    this.transcript,
    this.latitude,
    this.longitude,
    this.vectorClock,
  });

  @override
  String toString() {
    return 'AudioNote{id: $id, created: $createdAt, audioFile: $audioFile}';
  }
}
