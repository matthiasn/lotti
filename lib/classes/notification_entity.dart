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
  };

  String get id => meta.id;

  String get type => switch (this) {
    TaskSuggestionNotification() => 'taskSuggestion',
    TaskOverdueNotification() => 'taskOverdue',
    RelationshipCheckInNotification() => 'relationshipCheckIn',
  };

  String? get linkedEntityId => switch (this) {
    TaskSuggestionNotification(:final linkedTaskId) => linkedTaskId,
    TaskOverdueNotification(:final linkedTaskId) => linkedTaskId,
    RelationshipCheckInNotification(:final linkedRelationshipId) =>
      linkedRelationshipId,
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
  };
}
