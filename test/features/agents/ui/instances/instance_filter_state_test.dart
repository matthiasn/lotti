import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/instances/instance_filter_state.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';
import 'package:lotti/features/agents/ui/instances/widgets/soul_avatar.dart';
import 'package:lotti/l10n/app_localizations.dart';

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

    test('groupKey=status clusters rows by their AgentLifecycle name', () {
      final rows = [
        _vm(
          id: 'a',
          type: InstanceType.taskAgent,
          status: AgentLifecycle.active,
          updatedAt: DateTime(2026),
        ),
        _vm(
          id: 'b',
          type: InstanceType.taskAgent,
          status: AgentLifecycle.dormant,
          updatedAt: DateTime(2026),
        ),
        _vm(
          id: 'c',
          type: InstanceType.taskAgent,
          status: AgentLifecycle.dormant,
          updatedAt: DateTime(2026),
        ),
      ];

      final result = buildGroupedInstances(
        all: rows,
        state: const InstancesFilterState(
          groupKey: InstancesGroupKey.status,
        ),
        unassignedSoulLabel: 'Unassigned',
      );

      expect(result.groups.map((g) => g.label).toList(), [
        AgentLifecycle.active.name,
        AgentLifecycle.dormant.name,
      ]);
      expect(
        result.groups
            .firstWhere((g) => g.label == AgentLifecycle.dormant.name)
            .items
            .length,
        2,
      );
    });

    test('groupKey=type clusters rows by their InstanceType name', () {
      final rows = [
        _vm(
          id: 'a',
          type: InstanceType.taskAgent,
          status: AgentLifecycle.active,
          updatedAt: DateTime(2026),
        ),
        _vm(
          id: 'b',
          type: InstanceType.evolution,
          status: AgentLifecycle.active,
          updatedAt: DateTime(2026),
        ),
      ];

      final result = buildGroupedInstances(
        all: rows,
        state: const InstancesFilterState(
          groupKey: InstancesGroupKey.type,
        ),
        unassignedSoulLabel: 'Unassigned',
      );

      expect(result.groups.map((g) => g.label).toSet(), {
        InstanceType.taskAgent.name,
        InstanceType.evolution.name,
      });
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

  group('instanceTypeFromAgentKind', () {
    test('maps every documented agent kind onto an InstanceType', () {
      expect(
        instanceTypeFromAgentKind(AgentKinds.taskAgent),
        InstanceType.taskAgent,
      );
      expect(
        instanceTypeFromAgentKind(AgentKinds.projectAgent),
        InstanceType.projectAgent,
      );
      expect(
        instanceTypeFromAgentKind(AgentKinds.templateImprover),
        InstanceType.templateImprover,
      );
    });

    test('unknown kind returns null so the row can be skipped', () {
      expect(instanceTypeFromAgentKind('unknown_kind'), isNull);
    });
  });

  group('label helpers', () {
    late AppLocalizations messages;

    setUpAll(() async {
      WidgetsFlutterBinding.ensureInitialized();
      messages = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('instanceTypeLabel covers every InstanceType arm', () {
      expect(
        instanceTypeLabel(messages, InstanceType.taskAgent),
        messages.agentTemplateKindTaskAgent,
      );
      expect(
        instanceTypeLabel(messages, InstanceType.projectAgent),
        messages.agentTemplateKindProjectAgent,
      );
      expect(
        instanceTypeLabel(messages, InstanceType.templateImprover),
        messages.agentTemplateKindImprover,
      );
      expect(
        instanceTypeLabel(messages, InstanceType.evolution),
        messages.agentInstancesKindEvolution,
      );
    });

    test('agentLifecycleLabel covers every AgentLifecycle arm', () {
      expect(
        agentLifecycleLabel(messages, AgentLifecycle.active),
        messages.agentLifecycleActive,
      );
      expect(
        agentLifecycleLabel(messages, AgentLifecycle.dormant),
        messages.agentLifecycleDormant,
      );
      expect(
        agentLifecycleLabel(messages, AgentLifecycle.destroyed),
        messages.agentLifecycleDestroyed,
      );
      expect(
        agentLifecycleLabel(messages, AgentLifecycle.created),
        messages.agentLifecycleCreated,
      );
    });
  });

  group('SoulAvatar', () {
    testWidgets(
      'whitespace-only label falls back to "?" rather than a blank glyph',
      (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SoulAvatar(label: '   ', hue: 200),
            ),
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

  group('FilterCounts.from', () {
    test('counts types and statuses across the full vm list', () {
      final vms = [
        _vm(
          id: 'a',
          type: InstanceType.taskAgent,
          status: AgentLifecycle.active,
          updatedAt: DateTime(2026),
        ),
        _vm(
          id: 'b',
          type: InstanceType.taskAgent,
          status: AgentLifecycle.dormant,
          updatedAt: DateTime(2026),
        ),
        _vm(
          id: 'c',
          type: InstanceType.evolution,
          status: AgentLifecycle.active,
          updatedAt: DateTime(2026),
        ),
      ];

      final counts = FilterCounts.from(vms, 'Unassigned');

      expect(counts.types[InstanceType.taskAgent], 2);
      expect(counts.types[InstanceType.evolution], 1);
      expect(counts.types[InstanceType.projectAgent], 0);
      expect(counts.statuses[AgentLifecycle.active], 2);
      expect(counts.statuses[AgentLifecycle.dormant], 1);
    });

    test(
      'soul options dedupe by id and surface unassigned label as fallback',
      () {
        final vms = [
          _vm(
            id: 'a',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
            soulId: 'laura',
            soulName: 'Laura',
          ),
          _vm(
            id: 'b',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
            soulId: 'laura',
            soulName: 'Laura',
          ),
          _vm(
            id: 'c',
            type: InstanceType.taskAgent,
            status: AgentLifecycle.active,
            updatedAt: DateTime(2026),
          ),
        ];

        final counts = FilterCounts.from(vms, 'No soul');

        expect(
          counts.soulOptions.map((s) => s.label).toList(),
          ['Laura', 'No soul'],
        );
        expect(counts.soulCounts['laura'], 2);
        expect(counts.soulCounts['__no_soul__'], 1);
      },
    );
  });
}
