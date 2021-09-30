class AudioNote {
  final String id;
  final int createdAt;
  final int updatedAt;
  final String transcript;
  final String audioFile;
  final int duration;
  final double latitude;
  final double longitude;
  final String vectorClock;

  AudioNote({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.transcript,
    required this.audioFile,
    required this.duration,
    required this.latitude,
    required this.longitude,
    required this.vectorClock,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'transcript': transcript,
      'audioFile': audioFile,
      'duration': duration,
      'latitude': latitude,
      'longitude': longitude,
      'vector_clock': vectorClock,
    };
  }

  @override
  String toString() {
    return 'AudioNote{id: $id, created: $createdAt, audioFile: $audioFile}';
  }
}
