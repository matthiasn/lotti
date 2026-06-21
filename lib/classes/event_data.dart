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

    /// Id of a linked `JournalImage` used as the event's cover art. New events
    /// have none until the user picks one (or one is derived from a linked
    /// photo); the UI falls back to a category-tinted card.
    String? coverArtId,

    /// Horizontal crop offset for the cover art (0.0 = left … 1.0 = right).
    @Default(0.5) double coverArtCropX,
  }) = _EventData;

  factory EventData.fromJson(Map<String, dynamic> json) =>
      _$EventDataFromJson(json);
}
