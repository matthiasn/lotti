import 'package:freezed_annotation/freezed_annotation.dart';

part 'check_in_data.freezed.dart';
part 'check_in_data.g.dart';

/// How an interaction with the person happened.
enum CheckInInteractionType {
  inPerson,
  call,
  videoCall,
  message,
  other,
}

/// The user's own judgment of how the interaction felt. Explicitly user-set,
/// never AI-filled (ADR 0038); the briefing grounds its health band in these
/// values first, with prose only as secondary evidence (ADR 0040 §3).
enum CheckInSentiment {
  delightful,
  good,
  neutral,
  strained,
  difficult,
}

/// Payload of a `JournalEntity.checkIn` — one logged interaction with the
/// person behind a relationship (ADR 0038). The narrative ("what we talked
/// about") is the entry's shared `entryText`; the interaction time is
/// `meta.dateFrom`/`dateTo`, so check-ins sit naturally on calendars and
/// timelines.
@freezed
abstract class CheckInData with _$CheckInData {
  const factory CheckInData({
    /// The relationship this check-in belongs to, denormalized alongside the
    /// `RelationshipLink` so `affectedIds` can emit it as a precise wake
    /// token — the `HabitCompletionData.habitId` precedent.
    required String relationshipId,
    required CheckInInteractionType interactionType,
    CheckInSentiment? sentiment,

    /// What was discussed.
    @Default([]) List<String> topics,

    /// "Next time" guidance the executive briefing surfaces (ADR 0040).
    String? payAttentionTo,
    String? avoid,
  }) = _CheckInData;

  factory CheckInData.fromJson(Map<String, dynamic> json) =>
      _$CheckInDataFromJson(json);
}
