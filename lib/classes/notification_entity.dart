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
  };

  String get id => meta.id;

  String get title => switch (this) {
    TaskSuggestionNotification(:final title) => title,
    TaskOverdueNotification(:final title) => title,
  };

  String get body => switch (this) {
    TaskSuggestionNotification(:final body) => body,
    TaskOverdueNotification(:final body) => body,
  };

  String get type => switch (this) {
    TaskSuggestionNotification() => 'taskSuggestion',
    TaskOverdueNotification() => 'taskOverdue',
  };

  String? get linkedEntityId => switch (this) {
    TaskSuggestionNotification(:final linkedTaskId) => linkedTaskId,
    TaskOverdueNotification(:final linkedTaskId) => linkedTaskId,
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
  };
}
