class Entry {
  final String entryId;
  final int createdAt;
  final int updatedAt;
  final int utcOffset;
  final String timezone;
  final String plainText;
  final String markdown;
  final String quill;
  final double latitude;
  final double longitude;
  final String commentFor;
  final String vectorClock;

  Entry({
    required this.entryId,
    required this.createdAt,
    required this.updatedAt,
    required this.utcOffset,
    required this.timezone,
    required this.plainText,
    required this.markdown,
    required this.quill,
    required this.latitude,
    required this.longitude,
    required this.commentFor,
    required this.vectorClock,
  });

  Map<String, dynamic> toMap() {
    return {
      'entry_id': entryId,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'plain_text': plainText,
      'markdown': markdown,
      'quill': quill,
      'latitude': latitude,
      'longitude': longitude,
      'comment_for': commentFor,
      'vector_clock': vectorClock,
    };
  }

  @override
  String toString() {
    return 'Entry{id: $entryId, created: $createdAt, plainText: $plainText}';
  }
}
