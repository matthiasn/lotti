import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';

class MockChecklistItemControllerProvider extends ChecklistItemController {
  MockChecklistItemControllerProvider({
    required this.itemsMap,
  });

  final Map<String, ChecklistItem?> itemsMap;

  @override
  Future<ChecklistItem?> build(ChecklistItemParams arg) async {
    return itemsMap[arg.id];
  }
}
