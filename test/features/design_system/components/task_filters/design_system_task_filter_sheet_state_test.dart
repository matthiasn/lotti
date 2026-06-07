// Property tests for the pure state logic in
// lib/features/design_system/components/task_filters/
// design_system_task_filter_sheet_state.dart (a part-file of
// design_system_task_filter_sheet.dart).
//
// Worked examples for the same API live in
// design_system_task_filter_sheet_test.dart; this file pins the algebraic
// invariants (double-toggle identity, clearAll → appliedCount == 0,
// removeSelection idempotency, JSON round-trips) over generated states.

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';

// ---------------------------------------------------------------------------
// Deterministic scenario built from int seeds
// ---------------------------------------------------------------------------

const List<DesignSystemTaskFilterSection> _sections =
    DesignSystemTaskFilterSection.values;

DesignSystemTaskFilterFieldState _buildField(String prefix, int mask) {
  final options = List.generate(
    3,
    (i) => DesignSystemTaskFilterOption(id: '$prefix-$i', label: '$prefix $i'),
    growable: false,
  );
  return DesignSystemTaskFilterFieldState(
    label: prefix,
    options: options,
    selectedIds: {
      for (var i = 0; i < 3; i++)
        if (mask & (1 << i) != 0) '$prefix-$i',
    },
  );
}

class _FilterStateScenario {
  _FilterStateScenario({
    required this.structureSeed,
    required this.selectionSeed,
    required this.opSeed,
  });

  final int structureSeed;
  final int selectionSeed;
  final int opSeed;

  bool get hasStatus => structureSeed & 1 != 0;
  bool get hasCategory => structureSeed & 2 != 0;
  bool get hasLabel => structureSeed & 4 != 0;
  bool get hasProject => structureSeed & 8 != 0;
  bool get hasAgentFilter => structureSeed & 16 != 0;
  bool get hasSearchMode => structureSeed & 32 != 0;

  /// 0 disables the priority section entirely.
  int get priorityConcreteCount => (structureSeed >> 6) % 4;

  int get toggleCount => (structureSeed >> 8) % 3;

  /// The section the removeSelection property operates on.
  DesignSystemTaskFilterSection get section =>
      _sections[opSeed % _sections.length];

  /// A concrete (non-sentinel) priority id for toggle properties; null when
  /// the priority section is disabled.
  String? get concretePriorityId =>
      priorityConcreteCount == 0 ? null : 'p${opSeed % priorityConcreteCount}';

  /// An option id of [section] — member or non-member depending on opSeed.
  String get removalId {
    final prefix = section.name;
    return '$prefix-${(opSeed >> 3) % 4}'; // index 3 never exists → non-member
  }

  DesignSystemTaskFilterState build() {
    final priorityOptions = priorityConcreteCount == 0
        ? const <DesignSystemTaskFilterOption>[]
        : [
            const DesignSystemTaskFilterOption(
              id: DesignSystemTaskFilterState.allPriorityId,
              label: 'All',
            ),
            for (var i = 0; i < priorityConcreteCount; i++)
              DesignSystemTaskFilterOption(id: 'p$i', label: 'P$i'),
          ];

    final agentOptions = [
      for (var i = 0; i < 3; i++)
        DesignSystemTaskFilterOption(id: 'agent-$i', label: 'Agent $i'),
    ];
    final searchOptions = [
      for (var i = 0; i < 2; i++)
        DesignSystemTaskFilterOption(id: 'mode-$i', label: 'Mode $i'),
    ];

    return DesignSystemTaskFilterState(
      title: 'Filter',
      clearAllLabel: 'Clear all',
      applyLabel: 'Apply',
      sortLabel: 'Sort by',
      sortOptions: const [
        DesignSystemTaskFilterOption(id: 'priority', label: 'Priority'),
        DesignSystemTaskFilterOption(id: 'date', label: 'Date'),
      ],
      selectedSortId: selectionSeed.isEven ? 'priority' : 'date',
      statusField: hasStatus ? _buildField('status', selectionSeed) : null,
      categoryField: hasCategory
          ? _buildField('category', selectionSeed >> 3)
          : null,
      labelField: hasLabel ? _buildField('label', selectionSeed >> 6) : null,
      projectField: hasProject
          ? _buildField('project', selectionSeed >> 9)
          : null,
      priorityLabel: priorityConcreteCount == 0 ? '' : 'Priority',
      priorityOptions: priorityOptions,
      selectedPriorityIds: {
        for (var i = 0; i < priorityConcreteCount; i++)
          if ((selectionSeed >> (12 + i)) & 1 != 0) 'p$i',
      },
      agentFilterLabel: hasAgentFilter ? 'Agent' : '',
      agentFilterOptions: hasAgentFilter
          ? agentOptions
          : const <DesignSystemTaskFilterOption>[],
      selectedAgentFilterId: hasAgentFilter
          ? 'agent-${(selectionSeed >> 16) % 3}'
          : '',
      searchModeLabel: hasSearchMode ? 'Search mode' : '',
      searchModeOptions: hasSearchMode
          ? searchOptions
          : const <DesignSystemTaskFilterOption>[],
      selectedSearchModeId: hasSearchMode
          ? 'mode-${(selectionSeed >> 18) % 2}'
          : '',
      toggles: [
        for (var i = 0; i < toggleCount; i++)
          DesignSystemTaskFilterToggle(
            id: 'toggle-$i',
            label: 'Toggle $i',
            value: (selectionSeed >> (20 + i)) & 1 != 0,
          ),
      ],
    );
  }

  @override
  String toString() =>
      '_FilterStateScenario(structure: $structureSeed, '
      'selection: $selectionSeed, op: $opSeed)';
}

extension _AnyFilterStateScenario on glados.Any {
  glados.Generator<_FilterStateScenario> get filterStateScenario =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 1 << 10),
        glados.IntAnys(this).intInRange(0, 1 << 23),
        glados.IntAnys(this).intInRange(0, 1 << 10),
        (int structureSeed, int selectionSeed, int opSeed) =>
            _FilterStateScenario(
              structureSeed: structureSeed,
              selectionSeed: selectionSeed,
              opSeed: opSeed,
            ),
      );
}

Set<String>? _fieldSelection(
  DesignSystemTaskFilterState state,
  DesignSystemTaskFilterSection section,
) {
  return switch (section) {
    DesignSystemTaskFilterSection.status => state.statusField?.selectedIds,
    DesignSystemTaskFilterSection.category => state.categoryField?.selectedIds,
    DesignSystemTaskFilterSection.label => state.labelField?.selectedIds,
    DesignSystemTaskFilterSection.project => state.projectField?.selectedIds,
  };
}

// ---------------------------------------------------------------------------
// Properties
// ---------------------------------------------------------------------------

void main() {
  glados.Glados<_FilterStateScenario>(
    glados.any.filterStateScenario,
    glados.ExploreConfig(numRuns: 160),
  ).test(
    'double-toggle of a concrete priority id is the identity',
    (scenario) {
      final state = scenario.build();
      final id = scenario.concretePriorityId;
      if (id == null) {
        // No priority section: togglePriority must be a no-op instance-wise.
        expect(state.togglePriority('p0'), same(state));
        return;
      }

      final toggledTwice = state.togglePriority(id).togglePriority(id);
      expect(toggledTwice.selectedPriorityIds, state.selectedPriorityIds);
    },
    tags: 'glados',
  );

  glados.Glados<_FilterStateScenario>(
    glados.any.filterStateScenario,
    glados.ExploreConfig(numRuns: 160),
  ).test(
    'togglePriority(all) and selectPriority semantics',
    (scenario) {
      final state = scenario.build();
      if (scenario.concretePriorityId == null) return;

      // The sentinel always clears the whole selection.
      expect(
        state
            .togglePriority(DesignSystemTaskFilterState.allPriorityId)
            .selectedPriorityIds,
        isEmpty,
      );

      // selectPriority replaces the selection with exactly one id.
      final id = scenario.concretePriorityId!;
      expect(state.selectPriority(id).selectedPriorityIds, {id});
      expect(
        state
            .selectPriority(DesignSystemTaskFilterState.allPriorityId)
            .selectedPriorityIds,
        isEmpty,
      );
    },
    tags: 'glados',
  );

  glados.Glados<_FilterStateScenario>(
    glados.any.filterStateScenario,
    glados.ExploreConfig(numRuns: 160),
  ).test(
    'clearAll always drops appliedCount to zero',
    (scenario) {
      final state = scenario.build();
      final cleared = state.clearAll();

      expect(cleared.appliedCount, 0);
      // And clearing is idempotent.
      expect(cleared.clearAll().appliedCount, 0);
    },
    tags: 'glados',
  );

  glados.Glados<_FilterStateScenario>(
    glados.any.filterStateScenario,
    glados.ExploreConfig(numRuns: 160),
  ).test(
    'removeSelection is idempotent, shrinking, and a no-op for non-members',
    (scenario) {
      final state = scenario.build();
      final section = scenario.section;
      final id = scenario.removalId;

      final once = state.removeSelection(section, id);
      final twice = once.removeSelection(section, id);

      final before = _fieldSelection(state, section);
      final afterOnce = _fieldSelection(once, section);
      final afterTwice = _fieldSelection(twice, section);

      if (before == null) {
        // Section not present: nothing to remove from.
        expect(afterOnce, isNull);
        return;
      }

      // Idempotency and subset.
      expect(afterTwice, afterOnce);
      expect(before.containsAll(afterOnce!), isTrue);
      expect(afterOnce.contains(id), isFalse);
      if (!before.contains(id)) {
        // Removing a non-member changes nothing.
        expect(afterOnce, before);
      } else {
        expect(afterOnce.length, before.length - 1);
      }
    },
    tags: 'glados',
  );

  glados.Glados<_FilterStateScenario>(
    glados.any.filterStateScenario,
    glados.ExploreConfig(numRuns: 160),
  ).test(
    'fromJson(toJson()) preserves every serialized projection',
    (scenario) {
      final state = scenario.build();
      final roundTrip = DesignSystemTaskFilterState.fromJson(state.toJson());

      expect(roundTrip.title, state.title);
      expect(roundTrip.clearAllLabel, state.clearAllLabel);
      expect(roundTrip.applyLabel, state.applyLabel);
      expect(roundTrip.sortLabel, state.sortLabel);
      expect(roundTrip.selectedSortId, state.selectedSortId);
      expect(
        roundTrip.sortOptions.map((o) => o.id),
        state.sortOptions.map((o) => o.id),
      );
      expect(roundTrip.selectedPriorityIds, state.selectedPriorityIds);
      expect(
        roundTrip.priorityOptions.map((o) => o.id),
        state.priorityOptions.map((o) => o.id),
      );
      for (final section in _sections) {
        expect(
          _fieldSelection(roundTrip, section),
          _fieldSelection(state, section),
          reason: section.name,
        );
      }
      expect(roundTrip.agentFilterLabel, state.agentFilterLabel);
      expect(roundTrip.selectedAgentFilterId, state.selectedAgentFilterId);
      expect(roundTrip.selectedSearchModeId, state.selectedSearchModeId);
      expect(
        roundTrip.toggles.map((t) => (t.id, t.value)),
        state.toggles.map((t) => (t.id, t.value)),
      );
      // The derived count survives serialization too.
      expect(roundTrip.appliedCount, state.appliedCount);
    },
    tags: 'glados',
  );

  glados.Glados<_FilterStateScenario>(
    glados.any.filterStateScenario,
    glados.ExploreConfig(numRuns: 160),
  ).test(
    'agent/search/toggle mutations: no-op guards, applied-count boundary, '
    'and double-toggle identity',
    (scenario) {
      final state = scenario.build();
      final reason = '$scenario';

      // selectAgentFilter -----------------------------------------------
      if (!state.hasAgentFilter) {
        expect(
          identical(state.selectAgentFilter('agent-1'), state),
          isTrue,
          reason: reason,
        );
      } else {
        expect(
          identical(
            state.selectAgentFilter(state.selectedAgentFilterId),
            state,
          ),
          isTrue,
          reason: reason,
        );
        final other = state.selectedAgentFilterId == 'agent-1'
            ? 'agent-2'
            : 'agent-1';
        expect(
          state.selectAgentFilter(other).selectedAgentFilterId,
          other,
          reason: reason,
        );

        // appliedCount boundary: the FIRST agent option is the neutral
        // default and never counts; any non-first option adds exactly 1.
        final atFirst = state.selectAgentFilter(
          state.agentFilterOptions.first.id,
        );
        final atNonFirst = state.selectAgentFilter(
          state.agentFilterOptions.last.id,
        );
        expect(
          atNonFirst.appliedCount - atFirst.appliedCount,
          1,
          reason: reason,
        );
      }

      // selectSearchMode ------------------------------------------------
      if (!state.hasSearchMode) {
        expect(
          identical(state.selectSearchMode('mode-1'), state),
          isTrue,
          reason: reason,
        );
      } else {
        expect(
          identical(
            state.selectSearchMode(state.selectedSearchModeId),
            state,
          ),
          isTrue,
          reason: reason,
        );
        final other = state.selectedSearchModeId == 'mode-0'
            ? 'mode-1'
            : 'mode-0';
        final switched = state.selectSearchMode(other);
        expect(switched.selectedSearchModeId, other, reason: reason);
        // Search mode is not a filter: it never affects appliedCount.
        expect(switched.appliedCount, state.appliedCount, reason: reason);
      }

      // toggleValue -----------------------------------------------------
      expect(
        identical(state.toggleValue('nonexistent-toggle'), state),
        isTrue,
        reason: reason,
      );
      for (final toggle in state.toggles) {
        final flipped = state.toggleValue(toggle.id);
        expect(
          flipped.toggles.singleWhere((t) => t.id == toggle.id).value,
          !toggle.value,
          reason: '$reason toggle=${toggle.id}',
        );
        for (final other in state.toggles.where((t) => t.id != toggle.id)) {
          expect(
            flipped.toggles.singleWhere((t) => t.id == other.id).value,
            other.value,
            reason: '$reason untouched=${other.id}',
          );
        }
        final back = flipped.toggleValue(toggle.id);
        expect(
          back.toggles.singleWhere((t) => t.id == toggle.id).value,
          toggle.value,
          reason: '$reason double-toggle=${toggle.id}',
        );
      }
    },
    tags: 'glados',
  );
}
