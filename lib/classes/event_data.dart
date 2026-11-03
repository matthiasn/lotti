import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/change_source.dart';
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

    /// The language the event's record is kept in (a `SupportedLanguage`
    /// code such as `de`): the event agent's recap and suggestions, the
    /// analyses of its photos and the summaries of its recordings are all
    /// written in it. Null until the agent reads it from the first voice memo
    /// or the user picks one.
    String? languageCode,

    /// Who set [languageCode] — the agent (from a voice memo) or the user.
    /// The agent only ever fills an empty language; the user can change it
    /// any time. Defaults to [ChangeSource.user], the safe reading for a
    /// value whose author is unknown.
    @Default(ChangeSource.user)
    @JsonKey(unknownEnumValue: ChangeSource.user)
    ChangeSource languageSource,
  }) = _EventData;

  factory EventData.fromJson(Map<String, dynamic> json) =>
      _$EventDataFromJson(json);
}
