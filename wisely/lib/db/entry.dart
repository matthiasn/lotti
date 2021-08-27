class Entry {
  final int id;
  final int timestamp;
  final String plainText;
  final double latitude;
  final double longitude;

  Entry({
    required this.id,
    required this.timestamp,
    required this.plainText,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp,
      'plainText': plainText,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  @override
  String toString() {
    return 'Entry{id: $id, timestamp: $timestamp, plainText: $plainText}';
  }
}
