part of 'project_repository.dart';

/// Link mutation helpers split out of [ProjectRepository] purely for file
/// size; they run in the same library via `part`, so all private fields
/// remain accessible from the linking section.
extension _ProjectLinkHelpers on ProjectRepository {
  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Atomically soft-deletes an old project link and creates a new one
  /// within a single DB transaction. Notifications and sync enqueuing are
  /// deferred until after the transaction commits.
  Future<bool> _relinkTask({
    required EntryLink oldLink,
    required String projectId,
    required String taskId,
  }) async {
    // Wrap BOTH reservations (delete-link VC + new-link VC) in a single
    // scope so a rolled-back transaction releases both. Nested reservations
    // from [_prepareDeletedLink] attach automatically via the zone-local
    // scope.
    return _vectorClockService.withVcScope<bool>(
      () async {
        final now = DateTime.now();
        final deletedLink = await _prepareDeletedLink(oldLink, now);
        final newLink = EntryLink.project(
          id: uuid.v1(),
          fromId: projectId,
          toId: taskId,
          createdAt: now,
          updatedAt: now,
          vectorClock: await _vectorClockService.getNextVectorClock(),
        );

        // Both writes in one transaction — if either fails, both roll back.
        final success = await _journalDb.transaction(() async {
          final deleteRes = await _journalDb.upsertEntryLink(deletedLink);
          if (deleteRes == 0) return false;
          final insertRes = await _journalDb.upsertEntryLink(newLink);
          return insertRes != 0;
        });

        if (!success) return false;
        await _recordLinkSequence(
          deletedLink,
          subDomain: '_relinkTask.recordDeletedSent',
        );
        await _recordLinkSequence(
          newLink,
          subDomain: '_relinkTask.recordNewSent',
        );

        // Same propagation tagging as [linkTaskToProject]: relinking is a
        // task-link side-effect, not a direct project edit.
        _updateNotifications.notify({
          oldLink.fromId,
          oldLink.toId,
          projectId,
          taskId,
          projectNotification,
          projectEntityUpdateNotification(oldLink.fromId),
          projectEntityUpdateNotification(projectId),
          propagatedNotification(
            projectEntityUpdateNotification(oldLink.fromId),
          ),
          propagatedNotification(projectEntityUpdateNotification(projectId)),
        });
        try {
          await _enqueueLinkSync(deletedLink, SyncEntryStatus.update);
          await _enqueueLinkSync(newLink, SyncEntryStatus.initial);
        } catch (error, stackTrace) {
          getIt<DomainLogger>().error(
            LogDomain.sync,
            error,
            message:
                'outbox enqueue failed after _relinkTask; VCs already committed',
            stackTrace: stackTrace,
            subDomain: '_relinkTask.enqueue',
          );
        }
        return true;
      },
      commitWhen: (ok) => ok,
    );
  }

  Future<bool> _softDeleteLink(EntryLink link) async {
    return _vectorClockService.withVcScope<bool>(
      () async {
        final now = DateTime.now();
        final deleted = await _prepareDeletedLink(link, now);
        final res = await _journalDb.upsertEntryLink(deleted);
        if (res == 0) return false;
        await _recordLinkSequence(
          deleted,
          subDomain: '_softDeleteLink.recordSent',
        );
        // Same propagation tagging as [linkTaskToProject]: unlinking is a
        // task-link side-effect, not a direct project edit.
        _updateNotifications.notify({
          link.fromId,
          link.toId,
          projectNotification,
          projectEntityUpdateNotification(link.fromId),
          propagatedNotification(projectEntityUpdateNotification(link.fromId)),
        });
        try {
          await _enqueueLinkSync(deleted, SyncEntryStatus.update);
        } catch (error, stackTrace) {
          getIt<DomainLogger>().error(
            LogDomain.sync,
            error,
            message:
                'outbox enqueue failed after _softDeleteLink; VC already committed',
            stackTrace: stackTrace,
            subDomain: '_softDeleteLink.enqueue',
          );
        }
        return true;
      },
      commitWhen: (ok) => ok,
    );
  }

  /// Reserves a VC for the soft-deleted link. Callers invoke this inside a
  /// [VectorClockService.withVcScope] so the reservation is bound to the
  /// enclosing write outcome.
  Future<EntryLink> _prepareDeletedLink(EntryLink link, DateTime now) async {
    return link.copyWith(
      deletedAt: now,
      updatedAt: now,
      hidden: true,
      vectorClock: await _vectorClockService.getNextVectorClock(),
    );
  }

  Future<void> _enqueueLinkSync(
    EntryLink link,
    SyncEntryStatus status,
  ) async {
    await getIt<OutboxService>().enqueueMessage(
      SyncMessage.entryLink(
        entryLink: link,
        status: status,
      ),
    );
  }
}
