import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wisely/sync/vector_clock.dart';

part 'journal_entry.freezed.dart';
part 'journal_entry.g.dart';

@freezed
class Geolocation with _$Geolocation {
  factory Geolocation({
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    required double latitude,
    required double longitude,
    double? altitude,
  }) = _Geolocation;

  factory Geolocation.fromJson(Map<String, dynamic> json) =>
      _$GeolocationFromJson(json);
}

@freezed
class EntryText with _$EntryText {
  factory EntryText({
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    required String plainText,
    Geolocation? geolocation,
    DateTime? updatedAt,
    String? markdown,
    String? quill,
  }) = _EntryText;

  factory EntryText.fromJson(Map<String, dynamic> json) =>
      _$EntryTextFromJson(json);
}

@freezed
class CheckListItem with _$CheckListItem {
  factory CheckListItem({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    required String plainText,
    Geolocation? geolocation,
    DateTime? updatedAt,
  }) = _CheckListItem;

  factory CheckListItem.fromJson(Map<String, dynamic> json) =>
      _$CheckListItemFromJson(json);
}

@freezed
class Image with _$Image {
  factory Image({
    required String imageId,
    required String imageFile,
    required String imageDirectory,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    EntryText? entryText,
    Geolocation? geolocation,
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
    String? timezone,
    DateTime? updatedAt,
    Geolocation? geolocation,
    VectorClock? vectorClock,
    EntryText? entryText,
    Image? image,
  }) = _JournalEntry;

  factory JournalEntry.fromJson(Map<String, dynamic> json) =>
      _$JournalEntryFromJson(json);
}
