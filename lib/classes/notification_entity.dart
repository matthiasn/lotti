import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/sync/vector_clock.dart';

part 'notification_entity.freezed.dart';
part 'notification_entity.g.dart';

@freezed
sealed class NotificationEntity with _$NotificationEntity {
  const factory NotificationEntity.taskSuggestion({
    required NotificationMeta meta,
    required String linkedTaskId,
    required int suggestionCount,
    required String title,
    required String body,
  }) = TaskSuggestionNotification;

  const factory NotificationEntity.taskOverdue({
    required NotificationMeta meta,
    required String linkedTaskId,
    required String title,
    required String body,
  }) = TaskOverdueNotification;

  /// A check-in reminder for a tracked person (ADR 0039 Decision 1).
  ///
  /// Armed ahead of the due day by the relationship agent's deterministic
  /// tier, so the OS alarm is already scheduled when the app closes — the
  /// one thing the in-app banner channel structurally cannot do. The row is
  /// the durable record; the OS notification is a projection of it.
  ///
  /// [title] and [body] are baked at write time by the arming device and
  /// then sync as-is, so a two-device/two-locale setup shows the armer's
  /// language on both. Deliberate: the alternative is re-rendering copy on
  /// read, which the two task variants do not do either.
  const factory NotificationEntity.relationshipCheckIn({
    required NotificationMeta meta,
    required String linkedRelationshipId,
    required String title,
    required String body,
  }) = RelationshipCheckInNotification;

  /// One or more habits the auto-completion engine checked off on [dayKey]
  /// (`yyyy-MM-dd`, the local calendar day the completions count for).
  ///
  /// Written the moment the engine completes, so it is due on arrival; the
  /// row is the durable record and the OS banner its projection, the same
  /// split as the other variants. Several habits completed by one import
  /// share a row so the user gets one notification, not one per habit.
  ///
  /// [title] and [body] are baked in the completing device's locale (see the
  /// check-in variant for why).
  const factory NotificationEntity.habitAutoCompleted({
    required NotificationMeta meta,
    required List<String> linkedHabitIds,
    required String dayKey,
    required String title,
    required String body,
  }) = HabitAutoCompletedNotification;

  factory NotificationEntity.fromJson(Map<String, dynamic> json) =>
      _$NotificationEntityFromJson(json);
}

@freezed
abstract class NotificationMeta with _$NotificationMeta {
  const factory NotificationMeta({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime scheduledFor,
    required VectorClock vectorClock,
    required String originatingHostId,
    DateTime? seenAt,
    DateTime? actedOnAt,
    DateTime? deletedAt,
    String? category,
  }) = _NotificationMeta;

  factory NotificationMeta.fromJson(Map<String, dynamic> json) =>
      _$NotificationMetaFromJson(json);
}

extension NotificationEntityFields on NotificationEntity {
  NotificationMeta get meta => switch (this) {
    TaskSuggestionNotification(:final meta) => meta,
    TaskOverdueNotification(:final meta) => meta,
    RelationshipCheckInNotification(:final meta) => meta,
    HabitAutoCompletedNotification(:final meta) => meta,
  };

  String get id => meta.id;

  String get type => switch (this) {
    TaskSuggestionNotification() => 'taskSuggestion',
    TaskOverdueNotification() => 'taskOverdue',
    RelationshipCheckInNotification() => 'relationshipCheckIn',
    HabitAutoCompletedNotification() => 'habitAutoCompleted',
  };

  String? get linkedEntityId => switch (this) {
    TaskSuggestionNotification(:final linkedTaskId) => linkedTaskId,
    TaskOverdueNotification(:final linkedTaskId) => linkedTaskId,
    RelationshipCheckInNotification(:final linkedRelationshipId) =>
      linkedRelationshipId,
    // A grouped row links several habits; the row itself leads to the
    // habits page, so no single id is "the" linked entity.
    HabitAutoCompletedNotification() => null,
  };

  NotificationEntity copyWithMeta(NotificationMeta meta) => switch (this) {
    TaskSuggestionNotification(
      :final linkedTaskId,
      :final suggestionCount,
      :final title,
      :final body,
    ) =>
      NotificationEntity.taskSuggestion(
        meta: meta,
        linkedTaskId: linkedTaskId,
        suggestionCount: suggestionCount,
        title: title,
        body: body,
      ),
    TaskOverdueNotification(:final linkedTaskId, :final title, :final body) =>
      NotificationEntity.taskOverdue(
        meta: meta,
        linkedTaskId: linkedTaskId,
        title: title,
        body: body,
      ),
    RelationshipCheckInNotification(
      :final linkedRelationshipId,
      :final title,
      :final body,
    ) =>
      NotificationEntity.relationshipCheckIn(
        meta: meta,
        linkedRelationshipId: linkedRelationshipId,
        title: title,
        body: body,
      ),
    HabitAutoCompletedNotification(
      :final linkedHabitIds,
      :final dayKey,
      :final title,
      :final body,
    ) =>
      NotificationEntity.habitAutoCompleted(
        meta: meta,
        linkedHabitIds: linkedHabitIds,
        dayKey: dayKey,
        title: title,
        body: body,
      ),
  };
}
