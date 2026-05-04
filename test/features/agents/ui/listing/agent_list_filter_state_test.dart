import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_filter_state.dart';
import 'package:lotti/features/agents/ui/listing/widgets/soul_avatar.dart';

AgentListRowData _row({
  required String id,
  required String title,
  required DateTime sortAt,
  String? subtitle,
  AgentListLeading? leading,
  List<AgentListPill> pills = const [],
}) {
  return AgentListRowData(
    id: id,
    title: title,
    subtitle: subtitle,
    leading: leading,
    pills: pills,
    sortAt: sortAt,
    searchKey: '$title $id ${subtitle ?? ''}'.toLowerCase(),
  );
}

AgentListFilterAxis _typeAxis({
  required Map<String, int> counts,
}) {
  return AgentListFilterAxis(
    id: 'type',
    sectionLabel: 'Type',
    options: counts.entries
        .map(
          (e) => AgentListFilterOption(id: e.key, label: e.key, count: e.value),
        )
        .toList(),
  );
}

AgentListGroupAxis _flatAxis(String id, String label) {
  return AgentListGroupAxis(
    id: id,
    label: label,
    buildGroups: (rows) => [
      AgentListGroup(id: 'all', label: 'All', items: rows),
    ],
  );
}

AgentListSortAxis _recentAxis() {
  return AgentListSortAxis(
    id: 'recent',
    label: 'Recent',
    compare: (a, b) => b.sortAt.compareTo(a.sortAt),
  );
}

AgentListSortAxis _nameAxis() {
  return AgentListSortAxis(
    id: 'name',
    label: 'Name',
    compare: (a, b) {
      final by = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      if (by != 0) return by;
      return a.id.compareTo(b.id);
    },
  );
}

void main() {
  group('buildGroupedAgentList', () {
    test('search lowercases and matches the precomputed searchKey', () {
      final rows = [
        _row(id: 'a', title: 'Alpha', sortAt: DateTime(2026)),
        _row(id: 'b', title: 'Bravo', sortAt: DateTime(2026, 1, 2)),
      ];

      final result = buildGroupedAgentList(
        all: rows,
        state: const AgentListFilterState(
          groupAxisId: 'all',
          sortAxisId: 'recent',
          search: 'AL',
        ),
        filterAxes: const [],
        groupAxes: [_flatAxis('all', 'All')],
        sortAxes: [_recentAxis()],
        axisMatcher: (_, _, _) => true,
      );

      expect(result.totalBeforeFilter, 2);
      expect(result.totalAfterFilter, 1);
      expect(
        result.groups.expand((g) => g.items).map((r) => r.id).toList(),
        ['a'],
      );
    });

    test('multi-select axis filter ORs within axis (via matcher)', () {
      final rows = [
        _row(id: 't', title: 'Task one', sortAt: DateTime(2026)),
        _row(id: 'p', title: 'Project one', sortAt: DateTime(2026)),
        _row(id: 'e', title: 'Evolution one', sortAt: DateTime(2026)),
      ];

      final hints = <String, String>{
        't': 'task',
        'p': 'project',
        'e': 'evolution',
      };

      final result = buildGroupedAgentList(
        all: rows,
        state: const AgentListFilterState(
          groupAxisId: 'all',
          sortAxisId: 'recent',
          selectionsByAxis: {
            'type': {'task', 'evolution'},
          },
        ),
        filterAxes: [
          _typeAxis(counts: const {'task': 1, 'project': 1, 'evolution': 1}),
        ],
        groupAxes: [_flatAxis('all', 'All')],
        sortAxes: [_recentAxis()],
        axisMatcher: (axisId, selected, row) =>
            axisId != 'type' || selected.contains(hints[row.id]),
      );

      expect(
        result.groups.expand((g) => g.items).map((r) => r.id).toSet(),
        {'t', 'e'},
      );
    });

    test('sort=name uses lower-cased title then id tie-break', () {
      final rows = [
        _row(id: 'b', title: 'beta', sortAt: DateTime(2026)),
        _row(id: 'a2', title: 'Alpha', sortAt: DateTime(2026)),
        _row(id: 'a1', title: 'Alpha', sortAt: DateTime(2026)),
      ];

      final result = buildGroupedAgentList(
        all: rows,
        state: const AgentListFilterState(
          groupAxisId: 'all',
          sortAxisId: 'name',
        ),
        filterAxes: const [],
        groupAxes: [_flatAxis('all', 'All')],
        sortAxes: [_nameAxis()],
        axisMatcher: (_, _, _) => true,
      );

      expect(
        result.groups.expand((g) => g.items).map((r) => r.id).toList(),
        ['a1', 'a2', 'b'],
      );
    });

    test('selecting an unknown sort axis falls back to the first axis', () {
      final rows = [
        _row(id: 'a', title: 'Alpha', sortAt: DateTime(2026, 1, 2)),
        _row(id: 'b', title: 'Bravo', sortAt: DateTime(2026)),
      ];

      final result = buildGroupedAgentList(
        all: rows,
        state: const AgentListFilterState(
          groupAxisId: 'all',
          sortAxisId: 'unknown',
        ),
        filterAxes: const [],
        groupAxes: [_flatAxis('all', 'All')],
        sortAxes: [_recentAxis()],
        axisMatcher: (_, _, _) => true,
      );
      expect(
        result.groups.single.items.map((r) => r.id).toList(),
        ['a', 'b'],
      );
    });
  });

  group('AgentListFilterState', () {
    test('toggleOption flips an option in the right axis', () {
      const s = AgentListFilterState(groupAxisId: 'all', sortAxisId: 'recent');
      final s1 = s.toggleOption('type', 'task');
      expect(s1.selectionsFor('type'), {'task'});
      final s2 = s1.toggleOption('type', 'task');
      expect(s2.selectionsFor('type'), <String>{});
      final s3 = s1.toggleOption('status', 'active');
      expect(s3.selectionsFor('type'), {'task'});
      expect(s3.selectionsFor('status'), {'active'});
    });

    test('clearAxis empties one axis without touching the others', () {
      final s = const AgentListFilterState(
        groupAxisId: 'all',
        sortAxisId: 'recent',
      ).toggleOption('type', 'task').toggleOption('status', 'active');
      final cleared = s.clearAxis('type');
      expect(cleared.selectionsFor('type'), isEmpty);
      expect(cleared.selectionsFor('status'), {'active'});
    });

    test('clearAll wipes search + every axis', () {
      final s = const AgentListFilterState(
        groupAxisId: 'all',
        sortAxisId: 'recent',
        search: 'foo',
      ).toggleOption('type', 'task').toggleOption('status', 'active');
      final cleared = s.clearAll();
      expect(cleared.isAnyFilterActive, isFalse);
      expect(cleared.search, '');
    });

    test('activeFilterCount counts each selection plus search-when-set', () {
      const empty = AgentListFilterState(
        groupAxisId: 'all',
        sortAxisId: 'recent',
      );
      expect(empty.activeFilterCount, 0);
      final loaded = empty
          .toggleOption('type', 'task')
          .toggleOption('type', 'evolution')
          .toggleOption('status', 'active')
          .copyWith(search: 'q');
      expect(loaded.activeFilterCount, 4);
    });

    test('whitespace-only search is treated as empty', () {
      const s = AgentListFilterState(
        groupAxisId: 'all',
        sortAxisId: 'recent',
        search: '   ',
      );
      expect(s.hasSearch, isFalse);
      expect(s.isAnyFilterActive, isFalse);
      expect(s.activeFilterCount, 0);
    });
  });

  group('hueForSeed', () {
    test('returns a stable value in [0, 360) for the same seed', () {
      expect(hueForSeed('Laura'), hueForSeed('Laura'));
      expect(hueForSeed('Laura'), inInclusiveRange(0, 359));
    });

    test('returns 0 for an empty seed', () {
      expect(hueForSeed(''), 0);
    });
  });

  group('SoulAvatar', () {
    testWidgets(
      'whitespace-only label falls back to "?" rather than a blank glyph',
      (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: SoulAvatar(label: '   ', hue: 200)),
          ),
        );
        expect(find.text('?'), findsOneWidget);
      },
    );

    testWidgets('non-empty label uses its first character (uppercased)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: SoulAvatar(label: 'laura', hue: 142)),
        ),
      );
      expect(find.text('L'), findsOneWidget);
    });
  });
}
