import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/logic/persistence_logic.dart';

/// Batch size for paging through the demo journal's tasks. Small worlds
/// only — the seed fixture plus whatever the user created.
const int _taskPageSize = 200;

/// Points the demo world's content at [profileId] — the bundled inference
/// profile the FTUE setup seeds when the user connects a real provider
/// inside the demo.
///
/// Without this, connecting real AI is a dead end on seeded tasks:
/// `ProfileAutomationResolver.resolveForTask` only consults a task's agent
/// and its own `TaskData.profileId`, and the seeded fixture tasks carry
/// neither (they are written straight into the world, bypassing the task
/// creation path that would inherit a profile). Every skill run would log
/// "no profile configured" and silently do nothing.
///
/// Two writes, both idempotent and both skipping anything the user already
/// configured:
///
/// 1. The seeded category gets [profileId] as its `defaultProfileId` (only
///    when it has none), so standalone entries resolve via
///    `resolveForCategory` and newly created tasks inherit the profile.
/// 2. Every non-deleted task without a `profileId` — the seeded fixtures,
///    plus any task the user created before connecting — is stamped with
///    [profileId] so `resolveForTask` finds it.
///
/// Runs inside the ACTIVE demo generation; [journalDb] and [persistence]
/// are that generation's handles, so nothing here can touch the real world.
Future<void> wireDemoWorldToRealProfile({
  required String profileId,
  required JournalDb journalDb,
  required PersistenceLogic persistence,
}) async {
  final category = await journalDb.getCategoryById(manualDemoCategoryId);
  if (category != null && category.defaultProfileId == null) {
    await persistence.upsertEntityDefinition(
      category.copyWith(defaultProfileId: profileId),
    );
  }

  var offset = 0;
  while (true) {
    final batch = await journalDb.getJournalEntities(
      types: const ['Task'],
      starredStatuses: const [true, false],
      privateStatuses: const [true, false],
      // All flag values — the query filters `flag IN (...)`, and a flagged
      // task still needs its profile stamped.
      flaggedStatuses: [for (final flag in EntryFlag.values) flag.index],
      ids: null,
      limit: _taskPageSize,
      offset: offset,
    );
    for (final task in batch.whereType<Task>()) {
      if (task.meta.deletedAt != null || task.data.profileId != null) {
        continue;
      }
      await persistence.updateTask(
        journalEntityId: task.meta.id,
        taskData: task.data.copyWith(profileId: profileId),
      );
    }
    if (batch.length < _taskPageSize) break;
    offset += _taskPageSize;
  }
}
