import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/services/checklist_completion_service.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';

/// Builds a deterministic [ChecklistItem] identified by its title. Used by the
/// checklist card and modal tests so each row has predictable text content for
/// search and display assertions without spinning up a real controller.
ChecklistItem buildTestChecklistItem({
  required String id,
  required String title,
  bool isChecked = false,
  bool isArchived = false,
}) {
  final now = DateTime(2025);
  return ChecklistItem(
    meta: Metadata(
      id: id,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
    ),
    data: ChecklistItemData(
      title: title,
      isChecked: isChecked,
      isArchived: isArchived,
      linkedChecklists: const ['checklist-1'],
    ),
  );
}

/// Per-family-instance fake that yields a preset item. Used together with
/// [checklistItemOverridesFor] to populate the item controller family for
/// an entire checklist in a single test call.
class FakeChecklistItemController extends ChecklistItemController {
  FakeChecklistItemController(this._item)
    : super(const (id: 'fake', taskId: null));

  final ChecklistItem? _item;

  @override
  Future<ChecklistItem?> build() async => _item;
}

/// No-op checklist controller — all the tests that use it only exercise row
/// unlink/relink paths indirectly and never actually dismiss a row.
class NoopChecklistController extends ChecklistController {
  NoopChecklistController() : super(const (id: 'fake', taskId: null));

  @override
  Future<Checklist?> build() async => null;

  @override
  Future<void> unlinkItem(String checklistItemId) async {}

  @override
  Future<void> relinkItem(String checklistItemId) async {}
}

/// Returns a [Checklist] from `build` so the modal can read its
/// [ChecklistData.linkedChecklistItems] when it watches the controller.
class FakeChecklistController extends ChecklistController {
  FakeChecklistController({
    required this.itemIds,
    required this.checklistId,
  }) : super((id: checklistId, taskId: null));

  final List<String> itemIds;
  final String checklistId;

  @override
  Future<Checklist?> build() async => buildTestChecklist(
    id: checklistId,
    itemIds: itemIds,
  );

  @override
  Future<void> unlinkItem(String checklistItemId) async {}

  @override
  Future<void> relinkItem(String checklistItemId) async {}
}

/// Builds a deterministic [Checklist] entity for tests. Useful when a test
/// needs the modal to derive its item list from [checklistControllerProvider].
Checklist buildTestChecklist({
  required String id,
  required List<String> itemIds,
  String title = 'Todos',
}) {
  final now = DateTime(2025);
  return Checklist(
    meta: Metadata(
      id: id,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
    ),
    data: ChecklistData(
      title: title,
      linkedChecklistItems: itemIds,
      linkedTasks: const [],
    ),
  );
}

/// Empty completion service — no AI suggestions, no pulse animation.
class NoopChecklistCompletionService extends ChecklistCompletionService {
  NoopChecklistCompletionService();

  @override
  FutureOr<List<ChecklistCompletionSuggestion>> build() async => const [];

  @override
  void clearSuggestion(String itemId) {}
}

/// Produces the full set of Riverpod overrides required to render a checklist
/// card or modal in tests without reaching into real repositories.
///
/// Each item in [items] is wired to a [FakeChecklistItemController] keyed by
/// its `meta.id` + [taskId]. The checklist family defaults to a no-op so
/// rendered rows don't reach out to live services. When [checklistId] is
/// provided, that specific `(checklistId, taskId)` instance is replaced with
/// a [FakeChecklistController] whose `build` exposes the item ids — required
/// for the full-list modal which derives its list from the controller.
List<Override> checklistItemOverridesFor({
  required List<ChecklistItem> items,
  required String taskId,
  String? checklistId,
}) {
  final ids = items.map((i) => i.meta.id).toList();
  return [
    for (final item in items)
      checklistItemControllerProvider((
        id: item.meta.id,
        taskId: taskId,
      )).overrideWith(() => FakeChecklistItemController(item)),
    checklistControllerProvider.overrideWith(NoopChecklistController.new),
    if (checklistId != null)
      checklistControllerProvider((
        id: checklistId,
        taskId: taskId,
      )).overrideWith(
        () => FakeChecklistController(
          itemIds: ids,
          checklistId: checklistId,
        ),
      ),
    checklistCompletionServiceProvider.overrideWith(
      NoopChecklistCompletionService.new,
    ),
  ];
}
