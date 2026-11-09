import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_timeline_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';
import 'package:lotti/providers/service_providers.dart';

/// Which entity a preview is of: its kind and its id.
typedef FrontEntityKey = (FrontEntityKind kind, String id);

/// The live preview of an entity her chat shows a card for, or null when it
/// is gone — deleted, not of the kind named, a day with no plan left — or of
/// a kind with no preview of its own (a project, for now).
///
/// Each refreshes when what it reads changes. A task's comes from
/// [taskPreviewProvider], so a new report, a rename or a status change
/// shows; an event's is the event as stored now; a day's is its plan as the
/// Daily OS keeps it ([currentDraftPlanProvider]).
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
      return null;
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
