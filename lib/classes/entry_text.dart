import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/geolocation.dart';

part 'entry_text.freezed.dart';
part 'entry_text.g.dart';

@freezed
class EntryText with _$EntryText {
  factory EntryText({
    required String plainText,
    Geolocation? geolocation,
    String? markdown,
    String? quill,
  }) = _EntryText;

  factory EntryText.fromJson(Map<String, dynamic> json) =>
      _$EntryTextFromJson(json);
}
