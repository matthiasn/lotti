import 'package:lotti/classes/checklist_item_data.dart';

/// Mock checklist items using the real data model for Widgetbook showcases.
///
/// These use the same [ChecklistItemData] freezed class as the main app
/// to ensure a smooth transition when integrating with real controllers.
class ChecklistMockData {
  ChecklistMockData._();

  static const checklistTitle = 'Todos';

  static List<ChecklistItemData> items() => [
    const ChecklistItemData(
      title: 'Fix payment status update bug',
      isChecked: false,
      linkedChecklists: ['checklist-1'],
      id: 'item-1',
    ),
    const ChecklistItemData(
      title: 'Fix handover status update bug',
      isChecked: false,
      linkedChecklists: ['checklist-1'],
      id: 'item-2',
    ),
  ];
}
