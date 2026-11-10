import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_timeline_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';

/// Which entity a preview is of: its kind and its id.
typedef FrontEntityKey = (FrontEntityKind kind, String id);

/// The live preview of an entity her chat shows a card for, or null when it
/// is gone — deleted, not of the kind named, a day with no plan left.
///
/// Each refreshes when what it reads changes. A task's comes from
/// [taskPreviewProvider], so a new report, a rename or a status change
/// shows; an event's is the event as stored now; a project's is re-read when
/// it or any of its tasks changes, since a task finishing changes its
/// counts; a person's when they or a check-in about them does; a day's is
/// its plan as the Daily OS keeps it ([currentDraftPlanProvider]).
final FutureProviderFamily<FrontEntityPreview?, FrontEntityKey>
frontEntityPreviewProvider = FutureProvider.autoDispose
    .family<FrontEntityPreview?, FrontEntityKey>(
      frontEntityPreview,
      name: 'frontEntityPreviewProvider',
    );

Future<FrontEntityPreview?> frontEntityPreview(
  Ref ref,
  FrontEntityKey key,
) async {
  final (kind, id) = key;
  switch (kind) {
    case FrontEntityKind.task:
      final preview = await ref.watch(taskPreviewProvider(id).future);
      return preview == null ? null : frontTaskPreviewOf(preview);
    case FrontEntityKind.event:
      ref.watch(agentUpdateStreamProvider(id));
      final event = await ref.watch(journalDbProvider).journalEntityById(id);
      if (event is! JournalEvent || event.meta.deletedAt != null) return null;
      return FrontEventPreview(event);
    case FrontEntityKind.dayPlan:
      final day = DateTime.tryParse(id);
      if (day == null) return null;
      final plan = await ref.watch(currentDraftPlanProvider(day).future);
      final blocks = [
        for (final block in plan?.blocks ?? const <TimeBlock>[])
          // What the day holds: never the gaps between, nor what was let go.
          if (block.type != TimeBlockType.buffer &&
              block.state != TimeBlockState.dropped)
            FrontPlanBlock(
              title: block.title,
              start: block.start,
              end: block.end,
              state: block.state,
              taskId: block.taskId,
            ),
      ]..sort((a, b) => a.start.compareTo(b.start));
      if (blocks.isEmpty) return null;
      return FrontDayPlanPreview(day: day, blocks: blocks);
    case FrontEntityKind.project:
      // Listening before the reads: a change that lands while they run is
      // not lost. The project's tasks join once they are known.
      final watched = <String>{id};
      final updates = ref
          .watch(updateNotificationsProvider)
          .updateStream
          .listen((ids) {
            if (ids.any(watched.contains)) ref.invalidateSelf();
          });
      ref.onDispose(updates.cancel);
      final project = await ref.watch(journalDbProvider).journalEntityById(id);
      if (project is! ProjectEntry || project.meta.deletedAt != null) {
        return null;
      }
      final tasks = await ref
          .watch(projectRepositoryProvider)
          .getTasksForProject(id);
      watched.addAll(tasks.map((task) => task.meta.id));
      return FrontProjectPreview(
        project: project,
        totalTaskCount: tasks.length,
        // Done, as the project's own page counts it.
        completedTaskCount: tasks
            .where((task) => task.data.status is TaskDone)
            .length,
      );
    case FrontEntityKind.person:
      // A check-in about them names them too.
      ref.watch(agentUpdateStreamProvider(id));
      final db = ref.watch(journalDbProvider);
      final person = await db.journalEntityById(id);
      if (person is! RelationshipEntry || person.meta.deletedAt != null) {
        return null;
      }
      final checkIns = await db.getCheckInsForRelationship(id);
      return FrontPersonPreview(
        person: person,
        lastCheckIn: checkIns.firstOrNull,
      );
  }
}

/// The glance-level fields of [preview], as a task's card draws them.
FrontTaskPreview frontTaskPreviewOf(TaskPreview preview) {
  final task = preview.task;
  return FrontTaskPreview(
    entityId: task.meta.id,
    title: task.data.title,
    status: task.data.status,
    oneLiner: preview.oneLiner,
    due: task.data.due,
    estimate: task.data.estimate,
    categoryId: task.meta.categoryId,
    coverArtId: task.data.coverArtId,
    coverArtCropX: task.data.coverArtCropX,
    priority: task.data.priority,
  );
}
