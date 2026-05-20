import 'package:lotti/classes/notification_entity.dart';

/// Collapses inbox rows to the user-visible identity.
///
/// Task-suggestion notifications are a task-level affordance: the user should
/// see the latest "N suggestions need attention" row for a task, never one row
/// per agent wake/change set. Other notification kinds keep their row identity
/// because their IDs are already stable for the underlying event.
List<NotificationEntity> deduplicateInboxNotifications(
  List<NotificationEntity> entries,
) {
  final byIdentity = <String, NotificationEntity>{};

  for (final entry in entries) {
    final key = _inboxIdentityKey(entry);
    final existing = byIdentity[key];
    if (existing == null || _prefers(entry, existing)) {
      byIdentity[key] = entry;
    }
  }

  final result = byIdentity.values.toList()..sort(_compareInboxOrder);
  return result;
}

/// Counts unseen user-visible inbox rows.
///
/// Seen-but-unacted rows remain active for lifecycle cleanup, but the bell badge
/// is specifically an unseen count. Filter before deduplication so duplicate
/// task-suggestion waves still collapse without making seen rows visible again.
int countUnseenInboxNotifications(List<NotificationEntity> entries) {
  final unseen = entries.where((row) => row.meta.seenAt == null).toList();
  return deduplicateInboxNotifications(unseen).length;
}

String _inboxIdentityKey(NotificationEntity entity) {
  return switch (entity) {
    TaskSuggestionNotification(:final linkedTaskId) =>
      'taskSuggestion:$linkedTaskId',
    _ => entity.id,
  };
}

bool _prefers(NotificationEntity candidate, NotificationEntity existing) {
  final updated = candidate.meta.updatedAt.compareTo(existing.meta.updatedAt);
  if (updated != 0) return updated > 0;

  final created = candidate.meta.createdAt.compareTo(existing.meta.createdAt);
  if (created != 0) return created > 0;

  final scheduled = candidate.meta.scheduledFor.compareTo(
    existing.meta.scheduledFor,
  );
  if (scheduled != 0) return scheduled > 0;

  return candidate.id.compareTo(existing.id) > 0;
}

int _compareInboxOrder(NotificationEntity a, NotificationEntity b) {
  final scheduled = a.meta.scheduledFor.compareTo(b.meta.scheduledFor);
  if (scheduled != 0) return scheduled;

  final updated = b.meta.updatedAt.compareTo(a.meta.updatedAt);
  if (updated != 0) return updated;

  return a.id.compareTo(b.id);
}
