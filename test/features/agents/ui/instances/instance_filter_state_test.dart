import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/instances/instance_filter_state.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';

InstanceVm _vm({
  required String id,
  required InstanceType type,
  required AgentLifecycle status,
  required DateTime updatedAt,
  String name = 'Row',
  String? soulId,
  String? soulName,
}) {
  return InstanceVm(
    id: id,
    displayName: name,
    type: type,
    status: status,
    updatedAt: updatedAt,
    soulId: soulId,
    soulName: soulName,
    searchKey: '$name $id ${soulName ?? ''}'.toLowerCase(),
  );
}

void main() {
  group('buildGroupedInstances', () {
    test(
      'groups by soul descending by member count, then within-group sort',
      () {
        final rows = [
          _vm(
            id: 'i1',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
            soulId: 'iris',
            soulName: 'Iris',
          ),
          _vm(
            id: 'l1',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026, 1, 5),
            soulId: 'laura',
            soulName: 'Laura',
          ),
          _vm(
            id: 'l2',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.dormant,
            updatedAt: DateTime(2026, 1, 3),
            soulId: 'laura',
            soulName: 'Laura',
          ),
        ];

        final result = buildGroupedInstances(
          all: rows,
          state: const InstancesFilterState(),
          unassignedSoulLabel: 'Unassigned',
        );

        expect(result.totalBeforeFilter, 3);
        expect(result.totalAfterFilter, 3);
        expect(result.groups.map((g) => g.label).toList(), ['Laura', 'Iris']);
        // Within Laura, recent-first.
        expect(result.groups.first.items.map((i) => i.id).toList(), [
          'l1',
          'l2',
        ]);
      },
    );

    test('search lowercases and matches the precomputed searchKey', () {
      final rows = [
        _vm(
          id: 'a',
          name: 'Alpha',
          type: InstanceType.taskAgent,
          status: AgentLifecycle.active,
          updatedAt: DateTime(2026),
        ),
        _vm(
          id: 'b',
          name: 'Bravo',
          type: InstanceType.taskAgent,
          status: AgentLifecycle.active,
          updatedAt: DateTime(2026, 1, 2),
        ),
      ];

      final result = buildGroupedInstances(
        all: rows,
        state: const InstancesFilterState(search: 'AL'),
        unassignedSoulLabel: 'Unassigned',
      );

      expect(result.totalBeforeFilter, 2);
      expect(result.totalAfterFilter, 1);
      expect(
        result.groups.expand((g) => g.items).map((i) => i.id).toList(),
        ['a'],
      );
    });

    test('multi-select type filter ORs within axis', () {
      final rows = [
        _vm(
          id: 't',
          type: InstanceType.taskAgent,
          status: AgentLifecycle.active,
          updatedAt: DateTime(2026),
        ),
        _vm(
          id: 'p',
          type: InstanceType.projectAgent,
          status: AgentLifecycle.active,
          updatedAt: DateTime(2026),
        ),
        _vm(
          id: 'e',
          type: InstanceType.evolution,
          status: AgentLifecycle.active,
          updatedAt: DateTime(2026),
        ),
      ];

      final result = buildGroupedInstances(
        all: rows,
        state: const InstancesFilterState(
          types: {InstanceType.taskAgent, InstanceType.evolution},
        ),
        unassignedSoulLabel: 'Unassigned',
      );

      expect(
        result.groups.expand((g) => g.items).map((i) => i.id).toSet(),
        {'t', 'e'},
      );
    });

    test('sort=name uses lower-cased displayName then id tie-break', () {
      final rows = [
        _vm(
          id: 'b',
          name: 'beta',
          type: InstanceType.taskAgent,
          status: AgentLifecycle.active,
          updatedAt: DateTime(2026),
        ),
        _vm(
          id: 'a2',
          name: 'Alpha',
          type: InstanceType.taskAgent,
          status: AgentLifecycle.active,
          updatedAt: DateTime(2026),
        ),
        _vm(
          id: 'a1',
          name: 'Alpha',
          type: InstanceType.taskAgent,
          status: AgentLifecycle.active,
          updatedAt: DateTime(2026),
        ),
      ];

      final result = buildGroupedInstances(
        all: rows,
        state: const InstancesFilterState(sortKey: InstancesSortKey.name),
        unassignedSoulLabel: 'Unassigned',
      );

      expect(
        result.groups.expand((g) => g.items).map((i) => i.id).toList(),
        ['a1', 'a2', 'b'],
      );
    });

    test('rows without a soul fall under the unassigned label', () {
      final rows = [
        _vm(
          id: 'orphan',
          type: InstanceType.taskAgent,
          status: AgentLifecycle.active,
          updatedAt: DateTime(2026),
        ),
      ];

      final result = buildGroupedInstances(
        all: rows,
        state: const InstancesFilterState(),
        unassignedSoulLabel: 'No soul',
      );

      expect(result.groups.single.label, 'No soul');
    });
  });

  group('hueForSeed', () {
    test('returns a stable value in [0, 360) for the same seed', () {
      final h1 = hueForSeed('Laura');
      final h2 = hueForSeed('Laura');
      expect(h1, h2);
      expect(h1, inInclusiveRange(0, 359));
    });

    test('returns 0 for an empty seed', () {
      expect(hueForSeed(''), 0);
    });
  });
}
