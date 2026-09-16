import 'dart:async';
import 'dart:convert';

import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/features/notifications/scheduler/notification_scheduler.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:uuid/uuid.dart';

class NotificationRepository {
  NotificationRepository({
    required this._notificationsDb,
    required this._vectorClockService,
    required this._outboxService,
    required this._updateNotifications,
    required this._scheduler,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final NotificationsDb _notificationsDb;
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
  /// task, and after the new row is written every other open `taskSuggestion`
  /// row for [linkedTaskId] is retracted (the new row's id is excluded) so the
  /// bell can never show multiple suggestion rows for the same task.
  Future<NotificationEntity?> createTaskSuggestion({
    required String linkedTaskId,
    required int suggestionCount,
    required String title,
    required String body,
    DateTime? scheduledFor,
    String? category,
    String? idSeed,
  }) {
    final placeholder = NotificationEntity.taskSuggestion(
      meta: _pendingMeta(
        id: idSeed == null
            ? notificationIdForTaskSuggestion(linkedTaskId)
            : notificationIdForTaskSuggestion(idSeed),
        scheduledFor: scheduledFor ?? _now(),
        category: category,
      ),
      linkedTaskId: linkedTaskId,
      suggestionCount: suggestionCount,
      title: title,
      body: body,
    );
    return create(placeholder);
  }

  /// Creates the row [build] describes for the episode [id] — unless a row
  /// with that id already exists, in which case it is left exactly as it is
  /// and `null` is returned.
  ///
  /// **Idempotent by episode**, which is what makes it safe for a producer
  /// that re-derives its verdict on every tick and every write: a plain
  /// upsert would bump `updatedAt`, enqueue an outbox message and re-notify
  /// listeners every single tick — and would resurrect a row the user had
  /// already dismissed, since a create merges content while the three
  /// lifecycle marks stay monotonic. Because the episode key is part of [id],
  /// everything derived from it is already pinned by it; only baked copy
  /// could drift mid-episode, and the next episode picks that up.
  ///
  /// [build] receives the pending [NotificationMeta] — the id, both timestamps,
  /// [scheduledFor], the empty clock — and returns the kind's own variant
  /// around it. It is invoked only when a row is actually written. Retracting
  /// the episodes the new one supersedes is the caller's job — see
  /// [retractOpenRows].
  Future<NotificationEntity?> armEpisode({
    required String id,
    required DateTime scheduledFor,
    required NotificationEntity Function(NotificationMeta meta) build,
    String? category,
  }) async {
    if (await _notificationsDb.notificationById(id) != null) return null;
    return create(
      build(
        _pendingMeta(id: id, scheduledFor: scheduledFor, category: category),
      ),
    );
  }

  /// Deterministic id for the auto-completion row of [dayKey] covering
  /// [linkedHabitIds]: one import that completes three habits yields one
  /// row, and the engine never completes a habit twice on a day, so two rows
  /// for the same day never overlap in habits.
  String notificationIdForHabitAutoCompletion({
    required String dayKey,
    required List<String> linkedHabitIds,
  }) {
    final habits = [...linkedHabitIds]..sort();
    return 'habit-auto-$dayKey-${habits.join('+')}';
  }

  /// Records that the engine checked [linkedHabitIds] off on [dayKey], due
  /// immediately. The scheduler projects it to an OS banner on write; one
  /// import that completes the same batch twice writes one row.
  Future<NotificationEntity?> createHabitAutoCompletion({
    required List<String> linkedHabitIds,
    required String dayKey,
    required String title,
    required String body,
  }) => armEpisode(
    id: notificationIdForHabitAutoCompletion(
      dayKey: dayKey,
      linkedHabitIds: linkedHabitIds,
    ),
    scheduledFor: _now(),
    build: (meta) => NotificationEntity.habitAutoCompleted(
      meta: meta,
      linkedHabitIds: linkedHabitIds,
      dayKey: dayKey,
      title: title,
      body: body,
    ),
  );

  /// Retracts every still-open row of [kind] for [linkedEntityId], sparing
  /// [exceptId] (the episode currently armed).
  ///
  /// Used both to drop superseded episodes — a logged check-in moves the due
  /// day, so the old alarm is about a date that no longer means anything —
  /// and to clear the lot when the subject stops being eligible or is
  /// deleted. Retraction is what cancels the OS-level alert: the scheduler
  /// cancels for any row carrying a lifecycle mark.
  ///
  /// Open means not acted on and not deleted. `seenAt` deliberately does not
  /// disqualify a row the way it does for scheduling: a seen row has already
  /// had its OS alert cancelled, but it is still in the inbox, and a
  /// superseded episode must leave it. Kind-scoped because `forLinkedEntity`
  /// is not: a task row linked to the same id is left alone.
  Future<List<NotificationEntity>> retractOpenRows({
    required String linkedEntityId,
    required String kind,
    String? exceptId,
  }) async {
    final rows = await _notificationsDb.forLinkedEntity(linkedEntityId);
    final retracted = <NotificationEntity>[];
    for (final row in rows) {
      if (row.type != kind || row.id == exceptId) continue;
      if (row.meta.actedOnAt != null || row.meta.deletedAt != null) continue;
      final result = await retract(row.id);
      if (result != null) retracted.add(result);
    }
    return retracted;
  }

  /// The meta a brand-new row carries into [create]: both timestamps at now,
  /// no lifecycle marks, and an empty clock and host for [_create] to fill.
  NotificationMeta _pendingMeta({
    required String id,
    required DateTime scheduledFor,
    String? category,
  }) {
    final now = _now();
    return NotificationMeta(
      id: id,
      createdAt: now,
      updatedAt: now,
      scheduledFor: scheduledFor,
      vectorClock: const VectorClock({}),
      originatingHostId: '',
      category: category,
    );
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

      // A device-local row never leaves this device — see
      // `NotificationEntityFields.isDeviceLocal` for why its marks must not
      // either.
      if (!saved.isDeviceLocal) {
        await _outboxService.enqueueNotification(saved);
      }
      await _scheduler.schedule(saved, now: now);
      _notify(saved, fromSync: false);
      return saved;
    }, commitWhen: (result) => result != null);
  }

  Future<NotificationEntity?> markSeen(String id) {
    return _applyLocalState(id: id, seenAt: _now());
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

  String notificationIdForTaskSuggestion(String linkedTaskId) {
    return _uuid.v5(
      Namespace.nil.value,
      jsonEncode(['taskSuggestion', linkedTaskId]),
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

      if (!updated.isDeviceLocal) {
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
