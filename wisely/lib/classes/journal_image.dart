import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wisely/classes/geolocation.dart';
import 'package:wisely/sync/vector_clock.dart';

import 'entry_text.dart';

part 'journal_image.freezed.dart';
part 'journal_image.g.dart';

@freezed
class JournalImage with _$JournalImage {
  factory JournalImage({
    required String imageId,
    required String imageFile,
    required String imageDirectory,
    required DateTime createdAt,
    int? utcOffset,
    String? timezone,
    EntryText? entryText,
    Geolocation? geolocation,
    VectorClock? vectorClock,
  }) = _JournalImage;

  factory JournalImage.fromJson(Map<String, dynamic> json) =>
      _$JournalImageFromJson(json);
}
