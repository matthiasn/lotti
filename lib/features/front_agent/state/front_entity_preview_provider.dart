import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';

/// Which entity a preview is of: its kind and its id.
typedef FrontEntityKey = (FrontDestinationKind kind, String id);

/// The live preview of an entity her chat shows a card for, or null when it
/// is gone — deleted, not of the kind named — or of a kind that has no
/// preview yet.
///
/// A task's comes from [taskPreviewProvider], so it refreshes whenever a
/// notification names the task: a new report, a rename, a status change.
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
    case FrontDestinationKind.task:
      final preview = await ref.watch(taskPreviewProvider(id).future);
      return preview == null ? null : frontTaskPreviewOf(preview);
    // No preview card of their own yet.
    case FrontDestinationKind.project:
    case FrontDestinationKind.goal:
    case FrontDestinationKind.person:
    case FrontDestinationKind.day:
    case FrontDestinationKind.newThing:
    case FrontDestinationKind.journal:
    case FrontDestinationKind.unrouted:
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
  );
}
