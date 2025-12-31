import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';

/// Mock ChecklistItemController for widgetbook that always returns a fixed value.
class MockChecklistItemController extends ChecklistItemController {
  MockChecklistItemController(super.params, this._mockValue);

  final ChecklistItem? _mockValue;

  @override
  Future<ChecklistItem?> build() async {
    return _mockValue;
  }
}
