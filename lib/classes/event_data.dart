import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/event_status.dart';

part 'event_data.freezed.dart';
part 'event_data.g.dart';

@freezed
abstract class EventData with _$EventData {
  const factory EventData({
    required String title,
    required double stars,
    required EventStatus status,
  }) = _EventData;

  factory EventData.fromJson(Map<String, dynamic> json) =>
      _$EventDataFromJson(json);
}
