import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wisely/sync/vector_clock.dart';

part 'image_entry.freezed.dart';
part 'image_entry.g.dart';

@freezed
class ImageEntry with _$ImageEntry {
  factory ImageEntry({
    required String id,
    required int timestamp,
    required DateTime createdAt,
    required int utcOffset,
    required String timezone,
    DateTime? updatedAt,
    String? transcript,
    double? latitude,
    double? longitude,
    VectorClock? vectorClock,
    String? imageFile,
    String? imageDirectory,
    String? plainText,
    String? markdown,
    String? quill,
  }) = _ImageEntry;

  factory ImageEntry.fromJson(Map<String, dynamic> json) =>
      _$ImageEntryFromJson(json);
}
