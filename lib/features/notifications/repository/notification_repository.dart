import 'dart:async';
import 'dart:convert';

import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/features/notifications/scheduler/notification_scheduler.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:uuid/uuid.dart';

class NotificationRepository {
  NotificationRepository({
    required this._notificationsDb,
    required this._journalDb,
    required this._vectorClockService,
    required this._outboxService,
    required this._updateNotifications,
    required this._scheduler,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final NotificationsDb _notificationsDb;
  final JournalDb _journalDb;
  final VectorClockService _vectorClockService;
  final OutboxService _outboxService;
  final UpdateNotifications _updateNotifications;
  final NotificationScheduler _scheduler;
  final DateTime Function() _now;
  final Uuid _uuid = const Uuid();
  final Map<String, Future<void>> _taskSuggestionMutationTails = {};

  /// Creates (or refreshes) a `taskSuggestion` row in the synced inbox.
  ///
  /// [linkedTaskId] is the task the user opens when they tap the row. A
  /// caller-supplied [idSeed] lets a fresh agent wave use a fresh durable row
  /// after an older row was acted-on/retracted (those lifecycle fields are
  /// monotonic and cannot be cleared). Even with seeded rows, the active inbox
  /// invariant is task-scoped: task-suggestion mutations are serialized per
  /// task, and before the new row is written every other open `taskSuggestion`
  /// row for [linkedTaskId] is retracted so the bell can never show multiple
  /// suggestion rows for the same task.
  Future<NotificationEntity?> createTaskSuggestion({
    required String linkedTaskId,
    required int suggestionCount,
    required String title,
    required String body,
    DateTime? scheduledFor,
    String? category,
    String? idSeed,
  }) {
    final now = _now();
    final placeholder = NotificationEntity.taskSuggestion(
      meta: NotificationMeta(
        id: idSeed == null
            ? notificationIdForTaskSuggestion(linkedTaskId)
            : notificationIdForTaskSuggestion(idSeed),
        createdAt: now,
        updatedAt: now,
        scheduledFor: scheduledFor ?? now,
        vectorClock: const VectorClock({}),
        originatingHostId: '',
        category: category,
      ),
      linkedTaskId: linkedTaskId,
      suggestionCount: suggestionCount,
      title: title,
      body: body,
    );
    return create(placeholder);
  }

  Future<NotificationEntity?> createTaskOverdue({
    required String linkedTaskId,
    required String title,
    required String body,
    DateTime? scheduledFor,
    String? category,
  }) {
    final now = _now();
    final placeholder = NotificationEntity.taskOverdue(
      meta: NotificationMeta(
        id: notificationIdForTaskOverdue(linkedTaskId),
        createdAt: now,
        updatedAt: now,
        scheduledFor: scheduledFor ?? now,
        vectorClock: const VectorClock({}),
        originatingHostId: '',
        category: category,
      ),
      linkedTaskId: linkedTaskId,
      title: title,
      body: body,
    );
    return create(placeholder);
  }

  Future<NotificationEntity?> create(NotificationEntity entity) {
    if (entity is TaskSuggestionNotification) {
      return _withTaskSuggestionMutation(
        entity.linkedTaskId,
        () => _create(entity),
      );
    }
    return _create(entity);
  }

  Future<NotificationEntity?> _create(NotificationEntity entity) async {
    final enabled = await _journalDb.getConfigFlag(enableSyncedAlertsFlag);
    if (!enabled) return null;

    return _vectorClockService.withVcScope<NotificationEntity?>(() async {
      final host = await _vectorClockService.getHost();
      if (host == null) return null;

      final now = _now();
      // Deterministic IDs (taskSuggestion/taskOverdue) mean re-create calls
      // for the same linked task land on an existing row. Use the stored
      // createdAt + vector clock so causality keeps advancing instead of
      // resetting to the new placeholder's empty clock.
      final existing = await _notificationsDb.notificationById(entity.id);
      final previousClock =
          existing?.meta.vectorClock ??
          (entity.meta.vectorClock.vclock.isEmpty
              ? null
              : entity.meta.vectorClock);
      final vectorClock = await _vectorClockService.getNextVectorClock(
        previous: previousClock,
      );
      final enriched = entity.copyWithMeta(
        entity.meta.copyWith(
          createdAt: existing?.meta.createdAt ?? entity.meta.createdAt,
          updatedAt: now,
          scheduledFor: entity.meta.scheduledFor,
          vectorClock: vectorClock,
          originatingHostId: host,
        ),
      );

      final saved = await _notificationsDb.upsertNotification(enriched);
      if (saved == null) return null;

      if (entity is TaskSuggestionNotification) {
        await _applyOpenTaskSuggestionStateUnlocked(
          linkedTaskId: entity.linkedTaskId,
          deletedAt: now,
          exceptId: entity.id,
        );
      }

      await _outboxService.enqueueNotification(saved);
      await _scheduler.schedule(saved, now: now);
      _notify(saved, fromSync: false);
      return saved;
    }, commitWhen: (result) => result != null);
  }

  Future<NotificationEntity?> markSeen(String id) {
    return _applyLocalState(id: id, seenAt: _now());
  }

  Future<NotificationEntity?> markActedOn(String id) {
    return _applyLocalState(id: id, actedOnAt: _now());
  }

  Future<List<NotificationEntity>> markTaskSuggestionsActedOn(
    String linkedTaskId,
  ) {
    return _withTaskSuggestionMutation(
      linkedTaskId,
      () => _applyOpenTaskSuggestionStateUnlocked(
        linkedTaskId: linkedTaskId,
        actedOnAt: _now(),
      ),
    );
  }

  Future<NotificationEntity?> retract(String id) {
    return _applyLocalState(id: id, deletedAt: _now());
  }

  Future<List<NotificationEntity>> retractTaskSuggestionsForTask(
    String linkedTaskId,
  ) {
    return _withTaskSuggestionMutation(
      linkedTaskId,
      () => _applyOpenTaskSuggestionStateUnlocked(
        linkedTaskId: linkedTaskId,
        deletedAt: _now(),
      ),
    );
  }

  Future<NotificationEntity?> notificationById(String id) {
    return _notificationsDb.notificationById(id);
  }

  Future<int> unseenCount(DateTime now) {
    return _notificationsDb.unseenCount(now);
  }

  String notificationIdForTaskSuggestion(String linkedTaskId) {
    return _uuid.v5(
      Namespace.nil.value,
      jsonEncode(['taskSuggestion', linkedTaskId]),
    );
  }

  String notificationIdForTaskOverdue(String linkedTaskId) {
    return _uuid.v5(
      Namespace.nil.value,
      jsonEncode(['taskOverdue', linkedTaskId]),
    );
  }

  Future<NotificationEntity?> _applyLocalState({
    required String id,
    DateTime? seenAt,
    DateTime? actedOnAt,
    DateTime? deletedAt,
  }) async {
    final existing = await _notificationsDb.notificationById(id);
    if (existing == null) return null;
    if (!_statePatchWouldChange(
      existing,
      seenAt: seenAt,
      actedOnAt: actedOnAt,
      deletedAt: deletedAt,
    )) {
      return null;
    }

    return _vectorClockService.withVcScope<NotificationEntity?>(() async {
      final host = await _vectorClockService.getHost();
      if (host == null) return null;

      final vectorClock = await _vectorClockService.getNextVectorClock(
        previous: existing.meta.vectorClock,
      );
      final result = await _notificationsDb.mergeState(
        id: id,
        seenAt: seenAt,
        actedOnAt: actedOnAt,
        deletedAt: deletedAt,
        vectorClock: vectorClock,
        originatingHostId: host,
      );
      final updated = result.entity;
      if (updated == null || !result.changed) return null;

      final enabled = await _journalDb.getConfigFlag(enableSyncedAlertsFlag);
      if (enabled) {
        await _outboxService.enqueueNotificationStateUpdate(
          id: id,
          seenAt: seenAt,
          actedOnAt: actedOnAt,
          deletedAt: deletedAt,
          vectorClock: vectorClock,
          originatingHostId: host,
        );
      }
      await _scheduler.schedule(updated);
      _notifyStateChange(updated);
      return updated;
    }, commitWhen: (result) => result != null);
  }

  bool _statePatchWouldChange(
    NotificationEntity entity, {
    DateTime? seenAt,
    DateTime? actedOnAt,
    DateTime? deletedAt,
  }) {
    final meta = entity.meta;
    return (seenAt != null && meta.seenAt == null) ||
        (actedOnAt != null && meta.actedOnAt == null) ||
        (deletedAt != null && meta.deletedAt == null);
  }

  Future<T> _withTaskSuggestionMutation<T>(
    String linkedTaskId,
    Future<T> Function() mutation,
  ) async {
    final previous = _taskSuggestionMutationTails[linkedTaskId];
    final completer = Completer<void>();
    _taskSuggestionMutationTails[linkedTaskId] = completer.future;

    try {
      if (previous != null) {
        await previous;
      }
      return await mutation();
    } finally {
      completer.complete();
      if (identical(
        _taskSuggestionMutationTails[linkedTaskId],
        completer.future,
      )) {
        await _taskSuggestionMutationTails.remove(linkedTaskId);
      }
    }
  }

  Future<List<NotificationEntity>> _applyOpenTaskSuggestionStateUnlocked({
    required String linkedTaskId,
    String? exceptId,
    DateTime? actedOnAt,
    DateTime? deletedAt,
  }) async {
    final openRows = await _openTaskSuggestionsForTask(linkedTaskId);
    final updated = <NotificationEntity>[];
    for (final row in openRows) {
      if (row.id == exceptId) continue;
      final result = await _applyLocalState(
        id: row.id,
        actedOnAt: actedOnAt,
        deletedAt: deletedAt,
      );
      if (result != null) {
        updated.add(result);
      }
    }
    return updated;
  }

  Future<List<TaskSuggestionNotification>> _openTaskSuggestionsForTask(
    String linkedTaskId,
  ) async {
    final rows = await _notificationsDb.forLinkedEntity(linkedTaskId);
    return rows.whereType<TaskSuggestionNotification>().where((row) {
      final meta = row.meta;
      return meta.actedOnAt == null && meta.deletedAt == null;
    }).toList();
  }

  void _notify(NotificationEntity entity, {required bool fromSync}) {
    _updateNotifications.notify(
      {
        entity.id,
        if (entity.linkedEntityId != null) entity.linkedEntityId!,
        inboxNotification,
      },
      fromSync: fromSync,
    );
  }

  void _notifyStateChange(NotificationEntity entity) {
    _updateNotifications.notifyUiOnly({
      entity.id,
      if (entity.linkedEntityId != null) entity.linkedEntityId!,
      inboxNotification,
    });
  }
}
