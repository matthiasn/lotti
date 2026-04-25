import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';

void main() {
  group('SavedTaskFilter JSON', () {
    test('round-trips a populated filter through fromJson/toJson', () {
      const original = SavedTaskFilter(
        id: 'sv-abc',
        name: 'Blocked or on hold',
        filter: TasksFilter(
          selectedCategoryIds: {'cat-1'},
          selectedTaskStatuses: {'BLOCKED', 'ON_HOLD'},
          selectedPriorities: {'P1'},
          sortOption: TaskSortOption.byDueDate,
          showCreationDate: true,
          showDueDate: false,
          agentAssignmentFilter: AgentAssignmentFilter.hasAgent,
        ),
      );

      final restored = SavedTaskFilter.fromJson(original.toJson());

      expect(restored, original);
    });

    test('preserves id, name, and filter equality across encode/decode', () {
      const original = SavedTaskFilter(
        id: 'sv-1',
        name: 'In progress · P0–P1',
        filter: TasksFilter(
          selectedTaskStatuses: {'IN_PROGRESS'},
          selectedPriorities: {'P0', 'P1'},
        ),
      );

      final restored = SavedTaskFilter.fromJson(original.toJson());

      expect(restored.id, 'sv-1');
      expect(restored.name, 'In progress · P0–P1');
      expect(restored.filter.selectedPriorities, {'P0', 'P1'});
      expect(restored.filter.selectedTaskStatuses, {'IN_PROGRESS'});
    });
  });
}
