import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../test_utils.dart';

enum _GeneratedInstanceKindSlot {
  taskAgent,
  projectAgent,
  templateImprover,
  unknown,
  empty,
}

enum _GeneratedEvolutionStatusSlot { active, completed, abandoned }

String _generatedInstanceKind(_GeneratedInstanceKindSlot slot) {
  return switch (slot) {
    _GeneratedInstanceKindSlot.taskAgent => AgentKinds.taskAgent,
    _GeneratedInstanceKindSlot.projectAgent => AgentKinds.projectAgent,
    _GeneratedInstanceKindSlot.templateImprover => AgentKinds.templateImprover,
    _GeneratedInstanceKindSlot.unknown => 'unknown_kind',
    _GeneratedInstanceKindSlot.empty => '',
  };
}

InstanceType? _expectedInstanceType(_GeneratedInstanceKindSlot slot) {
  return switch (slot) {
    _GeneratedInstanceKindSlot.taskAgent => InstanceType.taskAgent,
    _GeneratedInstanceKindSlot.projectAgent => InstanceType.projectAgent,
    _GeneratedInstanceKindSlot.templateImprover =>
      InstanceType.templateImprover,
    _GeneratedInstanceKindSlot.unknown => null,
    _GeneratedInstanceKindSlot.empty => null,
  };
}

EvolutionSessionStatus _generatedEvolutionStatus(
  _GeneratedEvolutionStatusSlot slot,
) {
  return switch (slot) {
    _GeneratedEvolutionStatusSlot.active => EvolutionSessionStatus.active,
    _GeneratedEvolutionStatusSlot.completed => EvolutionSessionStatus.completed,
    _GeneratedEvolutionStatusSlot.abandoned => EvolutionSessionStatus.abandoned,
  };
}

AgentLifecycle _expectedEvolutionLifecycle(_GeneratedEvolutionStatusSlot slot) {
  return switch (slot) {
    _GeneratedEvolutionStatusSlot.active => AgentLifecycle.active,
    _GeneratedEvolutionStatusSlot.completed => AgentLifecycle.dormant,
    _GeneratedEvolutionStatusSlot.abandoned => AgentLifecycle.destroyed,
  };
}

class _GeneratedEvolutionStatusScenario {
  const _GeneratedEvolutionStatusScenario({required this.statusSlots});

  final List<_GeneratedEvolutionStatusSlot> statusSlots;

  @override
  String toString() {
    return '_GeneratedEvolutionStatusScenario(statusSlots: $statusSlots)';
  }
}

extension _AnyGeneratedInstanceViewModelScenario on glados.Any {
  glados.Generator<_GeneratedInstanceKindSlot> get instanceKindSlot =>
      glados.AnyUtils(this).choose(_GeneratedInstanceKindSlot.values);

  glados.Generator<_GeneratedEvolutionStatusSlot> get evolutionStatusSlot =>
      glados.AnyUtils(this).choose(_GeneratedEvolutionStatusSlot.values);

  glados.Generator<_GeneratedEvolutionStatusScenario>
  get evolutionStatusScenario => glados.ListAnys(this)
      .listWithLengthInRange(0, 35, evolutionStatusSlot)
      .map(
        (statusSlots) => _GeneratedEvolutionStatusScenario(
          statusSlots: statusSlots,
        ),
      );
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  Future<List<InstanceVm>> readVms(
    List<Override> overrides, {
    Map<String, AgentTemplateEntity> templatesByAgentId = const {},
    Map<String, SoulDocumentVersionEntity> soulsByTemplateId = const {},
  }) async {
    final templateService = MockAgentTemplateService();
    when(
      () => templateService.getTemplatesForAgents(any<Iterable<String>>()),
    ).thenAnswer((invocation) async {
      final requested =
          (invocation.positionalArguments.single as Iterable<String>).toSet();
      return {
        for (final entry in templatesByAgentId.entries)
          if (requested.contains(entry.key)) entry.key: entry.value,
      };
    });

    final soulService = MockSoulDocumentService();
    when(
      () => soulService.resolveActiveSoulsForTemplates(
        any<Iterable<String>>(),
      ),
    ).thenAnswer((invocation) async {
      final requested =
          (invocation.positionalArguments.single as Iterable<String>).toSet();
      return {
        for (final entry in soulsByTemplateId.entries)
          if (requested.contains(entry.key)) entry.key: entry.value,
      };
    });

    final container = ProviderContainer(
      overrides: [
        agentTemplateServiceProvider.overrideWithValue(templateService),
        soulDocumentServiceProvider.overrideWithValue(soulService),
        ...overrides,
      ],
    );
    try {
      return await container.read(agentInstanceVmsProvider.future);
    } finally {
      container.dispose();
    }
  }

  test('hydrates a task agent with its template + soul + name', () async {
    final agent = makeTestIdentity(
      id: 'agent-1',
      agentId: 'agent-1',
      displayName: 'Task Laura',
      updatedAt: DateTime(2026, 5, 4, 10),
    );
    final template = makeTestTemplate(
      id: 'tpl-laura',
      agentId: 'tpl-laura',
      displayName: 'Laura template',
    );
    final soulVersion = makeTestSoulDocumentVersion(
      id: 'sv-laura',
      agentId: 'soul-laura',
    );
    final soulDoc = makeTestSoulDocument(
      id: 'soul-laura',
      agentId: 'soul-laura',
      displayName: 'Laura',
    );

    final vms = await readVms(
      [
        allAgentInstancesProvider.overrideWith(
          (ref) async => [agent],
        ),
        allEvolutionSessionsProvider.overrideWith(
          (ref) async => <AgentDomainEntity>[],
        ),
        allSoulDocumentsProvider.overrideWith((ref) async => [soulDoc]),
      ],
      templatesByAgentId: {
        'agent-1': template,
      },
      soulsByTemplateId: {
        'tpl-laura': soulVersion,
      },
    );

    expect(vms, hasLength(1));
    final vm = vms.single;
    expect(vm.id, 'agent-1');
    expect(vm.displayName, 'Task Laura');
    expect(vm.type, InstanceType.taskAgent);
    expect(vm.status, AgentLifecycle.active);
    expect(vm.templateId, 'tpl-laura');
    expect(vm.templateName, 'Laura template');
    expect(vm.soulId, 'soul-laura');
    expect(vm.soulName, 'Laura');
    expect(vm.searchKey, contains('laura'));
  });

  test('agents with an unknown kind are skipped', () async {
    final agent = makeTestIdentity(
      id: 'agent-x',
      agentId: 'agent-x',
      displayName: 'Mystery Agent',
      kind: 'unknown_kind',
    );

    final vms = await readVms([
      allAgentInstancesProvider.overrideWith((ref) async => [agent]),
      allEvolutionSessionsProvider.overrideWith(
        (ref) async => <AgentDomainEntity>[],
      ),
      allSoulDocumentsProvider.overrideWith(
        (ref) async => <AgentDomainEntity>[],
      ),
    ]);

    expect(vms, isEmpty);
  });

  test('evolution sessions map status onto the lifecycle axis', () async {
    final activeSession = makeTestEvolutionSession(
      id: 'evo-active',
    );
    final completedSession = makeTestEvolutionSession(
      id: 'evo-done',
      sessionNumber: 2,
      status: EvolutionSessionStatus.completed,
    );
    final abandonedSession = makeTestEvolutionSession(
      id: 'evo-gone',
      sessionNumber: 3,
      status: EvolutionSessionStatus.abandoned,
    );

    final vms = await readVms([
      allAgentInstancesProvider.overrideWith(
        (ref) async => <AgentDomainEntity>[],
      ),
      allEvolutionSessionsProvider.overrideWith(
        (ref) async => [activeSession, completedSession, abandonedSession],
      ),
    ]);

    expect(vms, hasLength(3));
    final byId = {for (final v in vms) v.id: v};
    expect(byId['evo-active']!.status, AgentLifecycle.active);
    expect(byId['evo-done']!.status, AgentLifecycle.dormant);
    expect(byId['evo-gone']!.status, AgentLifecycle.destroyed);
    // sessionNumber drives the row's localized title.
    expect(byId['evo-active']!.sessionNumber, 1);
    // Evolution rows leave displayName blank — the row widget builds the
    // localized title from sessionNumber.
    expect(byId['evo-active']!.displayName, isEmpty);
  });

  glados.Glados(
    glados.any.instanceKindSlot,
    glados.ExploreConfig(numRuns: 120),
  ).test('maps generated agent kind ids to instance types', (kindSlot) {
    expect(
      instanceTypeFromAgentKind(_generatedInstanceKind(kindSlot)),
      equals(_expectedInstanceType(kindSlot)),
      reason: '$kindSlot',
    );
  }, tags: 'glados');

  glados.Glados(
    glados.any.evolutionStatusScenario,
    glados.ExploreConfig(numRuns: 160),
  ).test('maps generated evolution statuses onto lifecycle rows', (
    scenario,
  ) async {
    final sessions = [
      for (final (index, statusSlot) in scenario.statusSlots.indexed)
        makeTestEvolutionSession(
          id: 'evo-$index',
          sessionNumber: index + 1,
          status: _generatedEvolutionStatus(statusSlot),
        ),
    ];

    final vms = await readVms([
      allAgentInstancesProvider.overrideWith(
        (ref) async => <AgentDomainEntity>[],
      ),
      allEvolutionSessionsProvider.overrideWith((ref) async => sessions),
    ]);

    expect(vms, hasLength(scenario.statusSlots.length));
    for (final (index, statusSlot) in scenario.statusSlots.indexed) {
      final vm = vms[index];
      expect(vm.id, 'evo-$index', reason: '$scenario');
      expect(vm.type, InstanceType.evolution, reason: '$scenario');
      expect(vm.status, _expectedEvolutionLifecycle(statusSlot));
      expect(vm.sessionNumber, index + 1);
      expect(vm.displayName, isEmpty);
      expect(vm.searchKey, contains('evolution'));
      expect(vm.searchKey, contains('${index + 1}'));
      expect(vm.searchKey, contains('evo-$index'));
    }
  }, tags: 'glados');
}
