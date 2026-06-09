import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';

import '../test_utils.dart';

/// Deterministic dedupe scenario: a pool of change sets where some share
/// pending fingerprints (racing wakes), some are fully resolved, and
/// createdAt varies by seed.
class ChangeSetDedupeScenario {
  ChangeSetDedupeScenario(int count, int seed) {
    sets = [
      for (var i = 0; i < count; i++)
        makeTestChangeSet(
          id: 'cs-$i',
          createdAt: kAgentTestDate.add(Duration(minutes: (seed + i) % 60)),
          items: [
            ChangeItem(
              toolName: 'update_task_estimate',
              // Only a few distinct arg shapes so fingerprints collide.
              args: {'minutes': 30 * ((seed + i) % 3 + 1)},
              humanSummary: 'estimate',
              // Every third set is fully resolved (confirmed item).
              status: (seed + i) % 3 == 0
                  ? ChangeItemStatus.confirmed
                  : ChangeItemStatus.pending,
            ),
          ],
        ),
    ];
  }

  late final List<AgentDomainEntity> sets;
}

extension AnyChangeSetDedupe on glados.Any {
  glados.Generator<ChangeSetDedupeScenario> get changeSetDedupeScenario =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 12),
        glados.IntAnys(this).intInRange(0, 1 << 16),
        ChangeSetDedupeScenario.new,
      );
}
