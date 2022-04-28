import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/geolocation.dart';

part 'check_list_item.freezed.dart';
part 'check_list_item.g.dart';

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
