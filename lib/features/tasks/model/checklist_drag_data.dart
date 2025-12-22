/// Typed data classes for checklist drag-and-drop operations.
///
/// These replace untyped `Map<String, dynamic>` with type-safe classes,
/// eliminating runtime type casting errors and improving code clarity.
library;

/// Base class for checklist drag data.
sealed class ChecklistDragData {
  const ChecklistDragData();

  /// Converts the drag data to a map for use with super_drag_and_drop.
  Map<String, dynamic> toMap();

  /// Attempts to parse drag data from a map.
  ///
  /// Returns `null` if the data cannot be parsed.
  static ChecklistDragData? fromMap(Object? data) {
    if (data is! Map || data.isEmpty) {
      return null;
    }

    // Check for existing item drag
    if (data['checklistItemId'] != null && data['checklistId'] != null) {
      return ExistingItemDragData(
        checklistItemId: data['checklistItemId'] as String,
        checklistId: data['checklistId'] as String,
      );
    }

    // Check for new item drag
    if (data['checklistItemTitle'] != null) {
      return NewItemDragData(
        title: data['checklistItemTitle'] as String,
        isChecked: data['checklistItemStatus'] as bool? ?? false,
      );
    }

    return null;
  }
}

/// Drag data for an existing checklist item being moved.
class ExistingItemDragData extends ChecklistDragData {
  const ExistingItemDragData({
    required this.checklistItemId,
    required this.checklistId,
  });

  /// The ID of the checklist item being dragged.
  final String checklistItemId;

  /// The ID of the checklist the item is being dragged from.
  final String checklistId;

  @override
  Map<String, dynamic> toMap() => {
        'checklistItemId': checklistItemId,
        'checklistId': checklistId,
      };
}

/// Drag data for creating a new checklist item from a drag.
class NewItemDragData extends ChecklistDragData {
  const NewItemDragData({
    required this.title,
    this.isChecked = false,
  });

  /// The title for the new checklist item.
  final String title;

  /// Whether the new item should be checked.
  final bool isChecked;

  @override
  Map<String, dynamic> toMap() => {
        'checklistItemTitle': title,
        'checklistItemStatus': isChecked,
      };
}
