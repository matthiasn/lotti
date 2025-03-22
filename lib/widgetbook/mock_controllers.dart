import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';

class MockChecklistItemControllerProvider extends ChecklistItemController {
  MockChecklistItemControllerProvider({
    required this.value,
  });

  final Future<ChecklistItem?> value;

  @override
  Future<ChecklistItem?> build({
    required String id,
    required String? taskId,
  }) {
    return value;
  }

  @override
  Future<ChecklistItem?> get future => value;
}
