import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';
import 'package:lotti/providers/service_providers.dart';

/// Which entity a preview is of: its kind and its id.
typedef FrontEntityKey = (FrontEntityKind kind, String id);

/// The live preview of an entity her chat shows a card for, or null when it
/// is gone — deleted, or not of the kind named.
///
/// Both refresh whenever a notification names the entity. A task's comes
/// from [taskPreviewProvider], so a new report, a rename or a status change
/// shows; an event's is the event as stored now.
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
  );
}
