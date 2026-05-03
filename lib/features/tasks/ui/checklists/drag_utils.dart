import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

/// Creates a [DragItem] for a checklist item.
///
/// The drag item contains:
/// - Local data with `checklistItemId` and `checklistId` for internal use
/// - Plain text representation of the title for external drop targets
DragItem createChecklistItemDragItem({
  required String itemId,
  required String checklistId,
  required String title,
}) {
  return DragItem(
    localData: {
      'checklistItemId': itemId,
      'checklistId': checklistId,
    },
  )..add(Formats.plainText(title));
}

/// Handles a drop event on a checklist item.
///
/// Extracts the dropped item data and calls the checklist notifier
/// to perform the drop operation with position information.
///
/// Returns `true` if the drop was handled, `false` otherwise.
Future<bool> handleChecklistItemDrop({
  required PerformDropEvent event,
  required ChecklistController checklistNotifier,
  required int targetIndex,
  required String targetItemId,
}) async {
  if (event.session.items.isEmpty) {
    return false;
  }

  final droppedItem = event.session.items.first;
  final localData = droppedItem.localData;

  if (localData == null) {
    return false;
  }

  await checklistNotifier.dropChecklistItem(
    localData,
    targetIndex: targetIndex,
    targetItemId: targetItemId,
  );

  return true;
}

/// Creates a styled container for dragged items in checklists.
///
/// Matches the inner [ReorderableListView]'s proxy decorator: a level-02
/// elevation surface with rounded corners and no border, so the dragged row
/// reads as a lifted version of itself rather than a special boxed object.
Widget buildDragDecorator(BuildContext context, Widget child) {
  final tokens = context.designTokens;
  return Material(
    elevation: 4,
    borderRadius: BorderRadius.circular(8),
    color: tokens.colors.background.level02,
    child: child,
  );
}
