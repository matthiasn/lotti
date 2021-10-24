import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wisely/sync/vector_clock.dart';

part 'journal_entry.freezed.dart';
part 'journal_entry.g.dart';

@freezed
class Image with _$Image {
  factory Image({
    required String imageId,
    required String imageFile,
    required String imageDirectory,
  }) = _Image;

  factory Image.fromJson(Map<String, dynamic> json) => _$ImageFromJson(json);
}

@freezed
class JournalEntry with _$JournalEntry {
  factory JournalEntry({
    required String id,
    required int timestamp,
    required DateTime createdAt,
    required int utcOffset,
    required String timezone,
    DateTime? updatedAt,
    double? latitude,
    double? longitude,
    VectorClock? vectorClock,
    String? plainText,
    String? markdown,
    String? quill,
    Image? image,
  }) = _JournalEntry;

  factory JournalEntry.fromJson(Map<String, dynamic> json) =>
      _$JournalEntryFromJson(json);
}
