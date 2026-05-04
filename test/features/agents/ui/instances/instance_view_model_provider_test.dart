import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';

import '../../test_utils.dart';

void main() {
  Future<List<InstanceVm>> readVms(List<Override> overrides) async {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    return container.read(agentInstanceVmsProvider.future);
  }

  test('hydrates a task agent with its template + soul + name', () async {
    final agent = makeTestIdentity(
      id: 'agent-1',
      agentId: 'agent-1',
      displayName: 'Task Laura',
      kind: 'task_agent',
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

    final vms = await readVms([
      allAgentInstancesProvider.overrideWith(
        (ref) async => [agent],
      ),
      allEvolutionSessionsProvider.overrideWith(
        (ref) async => <AgentDomainEntity>[],
      ),
      templateForAgentProvider.overrideWith((ref, _) async => template),
      soulForTemplateProvider.overrideWith((ref, _) async => soulVersion),
      allSoulDocumentsProvider.overrideWith((ref) async => [soulDoc]),
    ]);

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
      templateForAgentProvider.overrideWith((ref, _) async => null),
      soulForTemplateProvider.overrideWith((ref, _) async => null),
      allSoulDocumentsProvider.overrideWith(
        (ref) async => <AgentDomainEntity>[],
      ),
    ]);

    expect(vms, isEmpty);
  });

  test('evolution sessions map status onto the lifecycle axis', () async {
    final activeSession = makeTestEvolutionSession(
      id: 'evo-active',
      sessionNumber: 1,
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
      templateForAgentProvider.overrideWith((ref, _) async => null),
      soulForTemplateProvider.overrideWith((ref, _) async => null),
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
}
