import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';

void main() {
  group('DesignSystemTaskFilterState new fields', () {
    test('selectAgentFilter updates selectedAgentFilterId', () {
      final state = DesignSystemTaskFilterState(
        title: 'T',
        clearAllLabel: 'C',
        applyLabel: 'A',
        agentFilterOptions: const [
          DesignSystemTaskFilterOption(id: 'all', label: 'All'),
          DesignSystemTaskFilterOption(id: 'hasAgent', label: 'Has'),
        ],
        selectedAgentFilterId: 'all',
      );

      final updated = state.selectAgentFilter('hasAgent');
      expect(updated.selectedAgentFilterId, 'hasAgent');

      // No-op when same value
      expect(state.selectAgentFilter('all'), same(state));

      // No-op when no options
      final noOptions = state.copyWith(
        agentFilterOptions: const [],
      );
      expect(noOptions.selectAgentFilter('hasAgent'), same(noOptions));
    });

    test('selectSearchMode updates selectedSearchModeId', () {
      final state = DesignSystemTaskFilterState(
        title: 'T',
        clearAllLabel: 'C',
        applyLabel: 'A',
        searchModeOptions: const [
          DesignSystemTaskFilterOption(id: 'fullText', label: 'Full'),
          DesignSystemTaskFilterOption(id: 'vector', label: 'Vector'),
        ],
        selectedSearchModeId: 'fullText',
      );

      final updated = state.selectSearchMode('vector');
      expect(updated.selectedSearchModeId, 'vector');

      expect(state.selectSearchMode('fullText'), same(state));

      final noOptions = state.copyWith(searchModeOptions: const []);
      expect(noOptions.selectSearchMode('vector'), same(noOptions));
    });

    test('toggleValue flips toggle and ignores unknown IDs', () {
      final state = DesignSystemTaskFilterState(
        title: 'T',
        clearAllLabel: 'C',
        applyLabel: 'A',
        toggles: const [
          DesignSystemTaskFilterToggle(id: 'a', label: 'A', value: false),
          DesignSystemTaskFilterToggle(id: 'b', label: 'B', value: true),
        ],
      );

      final toggled = state.toggleValue('a');
      expect(toggled.toggles[0].value, isTrue);
      expect(toggled.toggles[1].value, isTrue);

      expect(state.toggleValue('unknown'), same(state));
    });

    test('removeSelection works for project section', () {
      final state = DesignSystemTaskFilterState(
        title: 'T',
        clearAllLabel: 'C',
        applyLabel: 'A',
        projectField: const DesignSystemTaskFilterFieldState(
          label: 'P',
          options: [
            DesignSystemTaskFilterOption(id: 'p1', label: 'P1'),
            DesignSystemTaskFilterOption(id: 'p2', label: 'P2'),
          ],
          selectedIds: {'p1', 'p2'},
        ),
      );

      final removed = state.removeSelection(
        DesignSystemTaskFilterSection.project,
        'p1',
      );
      expect(removed.projectField!.selectedIds, {'p2'});
    });

    test('clearAll also clears project field and agent filter', () {
      final state = DesignSystemTaskFilterState(
        title: 'T',
        clearAllLabel: 'C',
        applyLabel: 'A',
        projectField: const DesignSystemTaskFilterFieldState(
          label: 'P',
          options: [DesignSystemTaskFilterOption(id: 'p1', label: 'P1')],
          selectedIds: {'p1'},
        ),
        agentFilterOptions: const [
          DesignSystemTaskFilterOption(id: 'all', label: 'All'),
          DesignSystemTaskFilterOption(id: 'hasAgent', label: 'Has'),
        ],
        selectedAgentFilterId: 'hasAgent',
      );

      final cleared = state.clearAll();
      expect(cleared.projectField!.selectedIds, isEmpty);
      expect(cleared.selectedAgentFilterId, 'all');
    });

    test('appliedCount includes project selections and agent filter', () {
      final state = DesignSystemTaskFilterState(
        title: 'T',
        clearAllLabel: 'C',
        applyLabel: 'A',
        projectField: const DesignSystemTaskFilterFieldState(
          label: 'P',
          options: [
            DesignSystemTaskFilterOption(id: 'p1', label: 'P1'),
            DesignSystemTaskFilterOption(id: 'p2', label: 'P2'),
          ],
          selectedIds: {'p1', 'p2'},
        ),
        agentFilterOptions: const [
          DesignSystemTaskFilterOption(id: 'all', label: 'All'),
          DesignSystemTaskFilterOption(id: 'hasAgent', label: 'Has'),
        ],
        selectedAgentFilterId: 'hasAgent',
      );

      // 2 projects + 1 agent filter = 3
      expect(state.appliedCount, 3);
    });

    test('appliedCount excludes agent filter when at default', () {
      final state = DesignSystemTaskFilterState(
        title: 'T',
        clearAllLabel: 'C',
        applyLabel: 'A',
        agentFilterOptions: const [
          DesignSystemTaskFilterOption(id: 'all', label: 'All'),
          DesignSystemTaskFilterOption(id: 'hasAgent', label: 'Has'),
        ],
        selectedAgentFilterId: 'all',
      );

      expect(state.appliedCount, 0);
    });

    test('round-trips new fields through JSON', () {
      final state = DesignSystemTaskFilterState(
        title: 'T',
        clearAllLabel: 'C',
        applyLabel: 'A',
        projectField: const DesignSystemTaskFilterFieldState(
          label: 'Project',
          options: [DesignSystemTaskFilterOption(id: 'p1', label: 'P1')],
          selectedIds: {'p1'},
        ),
        agentFilterLabel: 'Agent',
        agentFilterOptions: const [
          DesignSystemTaskFilterOption(id: 'all', label: 'All'),
        ],
        selectedAgentFilterId: 'all',
        searchModeLabel: 'Search',
        searchModeOptions: const [
          DesignSystemTaskFilterOption(id: 'fullText', label: 'Full'),
        ],
        selectedSearchModeId: 'fullText',
        toggles: const [
          DesignSystemTaskFilterToggle(id: 'x', label: 'X', value: true),
        ],
      );

      final roundTrip = DesignSystemTaskFilterState.fromJson(state.toJson());

      expect(roundTrip.hasProjectField, isTrue);
      expect(roundTrip.projectField!.selectedIds, {'p1'});
      expect(roundTrip.agentFilterLabel, 'Agent');
      expect(roundTrip.selectedAgentFilterId, 'all');
      expect(roundTrip.searchModeLabel, 'Search');
      expect(roundTrip.selectedSearchModeId, 'fullText');
      expect(roundTrip.toggles, hasLength(1));
      expect(roundTrip.toggles[0].id, 'x');
      expect(roundTrip.toggles[0].value, isTrue);
    });
  });

  group('DesignSystemTaskFilterToggle', () {
    test('round-trips through JSON', () {
      const toggle = DesignSystemTaskFilterToggle(
        id: 'show',
        label: 'Show it',
        value: true,
      );

      final roundTrip = DesignSystemTaskFilterToggle.fromJson(toggle.toJson());
      expect(roundTrip.id, 'show');
      expect(roundTrip.label, 'Show it');
      expect(roundTrip.value, isTrue);
    });

    test('defaults value to false when missing from JSON', () {
      final toggle = DesignSystemTaskFilterToggle.fromJson(const {
        'id': 'x',
        'label': 'X',
      });
      expect(toggle.value, isFalse);
    });

    test('copyWith updates value', () {
      const toggle = DesignSystemTaskFilterToggle(
        id: 'a',
        label: 'A',
        value: false,
      );
      final updated = toggle.copyWith(value: true);
      expect(updated.value, isTrue);
      expect(updated.id, 'a');
    });
  });
}
