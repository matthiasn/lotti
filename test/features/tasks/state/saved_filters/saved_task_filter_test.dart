import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

    glados.Glados2(
      glados.IntAnys(glados.any).intInRange(0, 1 << 12),
      glados.IntAnys(glados.any).intInRange(0, 1 << 10),
      glados.ExploreConfig(numRuns: 160),
    ).test('round-trips generated filters through fromJson/toJson', (
      setBits,
      scalarBits,
    ) {
      Set<String> pick(int shift, List<String> pool) => {
        for (var i = 0; i < pool.length; i++)
          if ((setBits >> (shift + i)) & 1 == 1) pool[i],
      };

      final filter = TasksFilter(
        selectedCategoryIds: pick(0, const ['cat-1', 'cat-2']),
        selectedProjectIds: pick(2, const ['proj-1', 'proj-2']),
        selectedTaskStatuses: pick(4, const ['OPEN', 'BLOCKED', 'DONE']),
        selectedLabelIds: pick(7, const ['lbl-1', 'lbl-2']),
        selectedPriorities: pick(9, const ['P0', 'P1', 'P2']),
        sortOption:
            TaskSortOption.values[scalarBits % TaskSortOption.values.length],
        showCreationDate: (scalarBits >> 2) & 1 == 1,
        showDueDate: (scalarBits >> 3) & 1 == 1,
        showCoverArt: (scalarBits >> 4) & 1 == 1,
        showProjectsHeader: (scalarBits >> 5) & 1 == 1,
        showDistances: (scalarBits >> 6) & 1 == 1,
        agentAssignmentFilter: AgentAssignmentFilter
            .values[(scalarBits >> 7) % AgentAssignmentFilter.values.length],
      );
      final original = SavedTaskFilter(
        id: 'sv-$setBits',
        name: 'Generated $scalarBits',
        filter: filter,
      );

      final restored = SavedTaskFilter.fromJson(original.toJson());

      expect(
        restored,
        original,
        reason: 'setBits=$setBits scalarBits=$scalarBits',
      );
    }, tags: 'glados');

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
