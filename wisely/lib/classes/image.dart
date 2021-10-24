import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wisely/classes/geolocation.dart';

import 'entry_text.dart';

part 'image.freezed.dart';
part 'image.g.dart';

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
