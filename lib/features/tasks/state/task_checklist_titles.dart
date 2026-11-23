import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/logic/repositories/checklist_repository.dart';

/// The titles of a task's active checklist items — neither deleted nor
/// archived — as [checklistTitleKey]s; null until the task and every one of
/// its checklists and items have loaded, so a partial set never offers to add
/// an item the checklist already holds.
///
/// Composed from the task's checklist and item controllers, so it changes the
/// moment an item is added, renamed or removed, wherever that happened.
final ProviderFamily<Set<String>?, String> taskChecklistTitleKeysProvider =
    Provider.autoDispose.family<Set<String>?, String>((ref, taskId) {
      final entry = ref.watch(entryControllerProvider(taskId)).value?.entry;
      if (entry is! Task) return null;
      final keys = <String>{};
      for (final checklistId in entry.data.checklistIds ?? const <String>[]) {
        final checklistState = ref.watch(
          checklistControllerProvider((id: checklistId, taskId: taskId)),
        );
        if (!checklistState.hasValue) return null;
        for (final itemId
            in checklistState.value?.data.linkedChecklistItems ??
                const <String>[]) {
          final itemState = ref.watch(
            checklistItemControllerProvider((id: itemId, taskId: taskId)),
          );
          if (!itemState.hasValue) return null;
          final item = itemState.value;
          if (item == null || item.isDeleted || item.data.isArchived) continue;
          keys.add(checklistTitleKey(item.data.title));
        }
      }
      return keys;
    });

/// [text] as a checklist item title: the words of inline Markdown — a
/// link's text, a code span's and an emphasis's content without their marks —
/// on one line. Only paired marks go: `foo_bar` and a lone `*` stay.
String plainChecklistTitle(String text) {
  // A destination may hold one level of balanced parentheses.
  var plain = text
      .replaceAllMapped(
        RegExp(r'\[([^\]]*)\]\((?:[^()\s]|\([^()\s]*\))*\)'),
        (m) => m.group(1)!,
      )
      .replaceAllMapped(RegExp('`([^`]*)`'), (m) => m.group(1)!)
      // One line first, so emphasis that wraps a line break is found.
      .replaceAll(RegExp(r'\s+'), ' ');
  // Until nothing changes, so nested emphasis such as `**__x__**` comes out
  // as `x`, and the title keys the same before and after it is stored.
  for (var previous = ''; previous != plain;) {
    previous = plain;
    plain = plain
        .replaceAllMapped(
          RegExp(r'(\*\*|__)(?=\S)(.+?)(?<=\S)\1'),
          (m) => m.group(2)!,
        )
        .replaceAllMapped(
          RegExp(r'(?<![\w*])([*_])(?=\S)(.+?)(?<=\S)\1(?![\w*])'),
          (m) => m.group(2)!,
        );
  }
  return plain.trim();
}

/// What two titles must share to be the same to-do: the plain words, in
/// lower case, without closing punctuation.
String checklistTitleKey(String text) => plainChecklistTitle(
  text,
).toLowerCase().replaceAll(RegExp(r'[.!:;]+$'), '');

/// Adds [text] as an open item to [task]'s first checklist, or to a new
/// checklist when it has none. Returns whether an item was written.
Future<bool> addTodoToTaskChecklist(
  ChecklistRepository repository, {
  required Task task,
  required String text,
}) async {
  final title = plainChecklistTitle(text);
  if (title.isEmpty) return false;
  final checklistId = task.data.checklistIds?.firstOrNull;
  if (checklistId == null) {
    final created = await repository.createChecklist(
      taskId: task.id,
      items: [
        ChecklistItemData(title: title, isChecked: false, linkedChecklists: []),
      ],
    );
    // A checklist without the item would be a silent failure.
    return created.checklist != null && created.createdItems.isNotEmpty;
  }
  final item = await repository.addItemToChecklist(
    checklistId: checklistId,
    title: title,
    isChecked: false,
    categoryId: task.meta.categoryId,
  );
  return item != null;
}
