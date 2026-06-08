import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';
import 'change_set_providers_test_helpers.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository mockRepository;

  setUp(() {
    mockRepository = MockAgentRepository();
  });

  /// Builds the standard project-agent container: projectAgent override,
  /// repository override, and (when [agent] + [updateController] are given)
  /// the agent-update stream override. Optionally keeps [listenTo] alive
  /// and registers all disposals via addTearDown.
  ProviderContainer createProjectAgentContainer({
    required String projectId,
    AgentDomainEntity? agent,
    StreamController<Set<String>>? updateController,
    ProviderListenable<Object?>? listenTo,
  }) {
    final container = ProviderContainer(
      overrides: [
        projectAgentProvider(projectId).overrideWith((ref) async => agent),
        agentRepositoryProvider.overrideWithValue(mockRepository),
        if (agent != null && updateController != null)
          agentUpdateStreamProvider(agent.agentId).overrideWith(
            (ref) => updateController.stream,
          ),
      ],
    );
    addTearDown(container.dispose);
    if (listenTo != null) {
      final sub = container.listen(listenTo, (_, _) {});
      addTearDown(sub.close);
    }
    return container;
  }

  group('_deduplicateChangeSets (via projectPendingChangeSetsProvider)', () {
    Future<List<AgentDomainEntity>> fetchDeduped(
      List<ChangeSetEntity> rawSets,
    ) async {
      final agent = makeTestIdentity();
      final updateController = StreamController<Set<String>>.broadcast();
      addTearDown(updateController.close);

      when(
        () => mockRepository.getPendingChangeSets(
          agent.agentId,
          taskId: 'project-ded',
        ),
      ).thenAnswer((_) async => rawSets);

      final container = createProjectAgentContainer(
        projectId: 'project-ded',
        agent: agent,
        updateController: updateController,
        listenTo: projectPendingChangeSetsProvider('project-ded'),
      );

      return container.read(
        projectPendingChangeSetsProvider('project-ded').future,
      );
    }

    test(
      'passes through a single change set without deduplication',
      () async {
        final cs = makeTestChangeSet(id: 'cs-single');
        final result = await fetchDeduped([cs]);

        expect(result, hasLength(1));
        expect(result.first, isA<ChangeSetEntity>());
      },
    );

    test(
      'two change sets with identical pending-item fingerprints — keeps only the newer one',
      () async {
        const item = ChangeItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 60},
          humanSummary: 'Set estimate',
        );
        final older = makeTestChangeSet(
          id: 'cs-older',
          createdAt: DateTime(2024, 3, 15, 9),
          items: const [item],
        );
        final newer = makeTestChangeSet(
          id: 'cs-newer',
          createdAt: DateTime(2024, 3, 15, 11),
          items: const [item],
        );

        final result = await fetchDeduped([older, newer]);

        expect(result, hasLength(1));
        expect(result.first.id, 'cs-newer');
      },
    );

    test(
      'deduplication also keeps newer when older is encountered second',
      () async {
        const item = ChangeItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 60},
          humanSummary: 'Set estimate',
        );
        final older = makeTestChangeSet(
          id: 'cs-older2',
          createdAt: DateTime(2024, 3, 15, 8),
          items: const [item],
        );
        final newer = makeTestChangeSet(
          id: 'cs-newer2',
          createdAt: DateTime(2024, 3, 15, 12),
          items: const [item],
        );

        // Pass newer first so the older entity arrives after the seen map
        // already has an entry — exercises the isAfter branch going false.
        final result = await fetchDeduped([newer, older]);

        expect(result, hasLength(1));
        expect(result.first.id, 'cs-newer2');
      },
    );

    test(
      'two change sets with different fingerprints are both preserved',
      () async {
        final cs1 = makeTestChangeSet(
          id: 'cs-fp-a',
          items: const [
            ChangeItem(
              toolName: 'update_task_estimate',
              args: {'minutes': 30},
              humanSummary: 'Set 30 min',
            ),
          ],
        );
        final cs2 = makeTestChangeSet(
          id: 'cs-fp-b',
          items: const [
            ChangeItem(
              toolName: 'update_task_status',
              args: {'status': 'done'},
              humanSummary: 'Mark done',
            ),
          ],
        );

        final result = await fetchDeduped([cs1, cs2]);

        expect(result, hasLength(2));
        expect(result.map((e) => e.id), containsAll(['cs-fp-a', 'cs-fp-b']));
      },
    );

    test(
      'fully-resolved change set (no pending items) is keyed by entity id and not collapsed with another resolved set',
      () async {
        // Both sets have no pending items → empty fingerprint → keyed by id.
        final resolved1 = makeTestChangeSet(
          id: 'cs-res-1',
          items: const [
            ChangeItem(
              toolName: 'update_task_estimate',
              args: {'minutes': 30},
              humanSummary: 'Confirmed',
              status: ChangeItemStatus.confirmed,
            ),
          ],
        );
        final resolved2 = makeTestChangeSet(
          id: 'cs-res-2',
          items: const [
            ChangeItem(
              toolName: 'update_task_status',
              args: {'status': 'done'},
              humanSummary: 'Confirmed',
              status: ChangeItemStatus.confirmed,
            ),
          ],
        );

        final result = await fetchDeduped([resolved1, resolved2]);

        // Neither set is dropped because they each have unique entity IDs.
        expect(result, hasLength(2));
        expect(
          result.map((e) => e.id),
          containsAll(['cs-res-1', 'cs-res-2']),
        );
      },
    );

    test(
      'three change sets: two duplicates and one unique — keeps newest duplicate and the unique',
      () async {
        const dupItem = ChangeItem(
          toolName: 'add_checklist_item',
          args: {'text': 'Write tests'},
          humanSummary: 'Add item',
        );
        final dup1 = makeTestChangeSet(
          id: 'cs-dup-1',
          createdAt: DateTime(2024, 3, 15, 7),
          items: const [dupItem],
        );
        final dup2 = makeTestChangeSet(
          id: 'cs-dup-2',
          createdAt: DateTime(2024, 3, 15, 10),
          items: const [dupItem],
        );
        final unique = makeTestChangeSet(
          id: 'cs-unique',
          items: const [
            ChangeItem(
              toolName: 'update_task_status',
              args: {'status': 'in_progress'},
              humanSummary: 'Move to in-progress',
            ),
          ],
        );

        final result = await fetchDeduped([dup1, dup2, unique]);

        expect(result, hasLength(2));
        final ids = result.map((e) => e.id).toSet();
        expect(ids, contains('cs-dup-2'));
        expect(ids, contains('cs-unique'));
        expect(ids, isNot(contains('cs-dup-1')));
      },
    );
  });

  group('deduplicateChangeSets properties', () {
    glados.Glados(
      glados.any.changeSetDedupeScenario,
      glados.ExploreConfig(numRuns: 150),
    ).test('dedupe invariants hold for generated racing change sets', (
      scenario,
    ) {
      final input = scenario.sets;
      final output = deduplicateChangeSets(input);

      // Never grows, and idempotent.
      expect(output.length, lessThanOrEqualTo(input.length));
      final second = deduplicateChangeSets(output);
      expect(
        second.map((e) => e.id).toSet(),
        output.map((e) => e.id).toSet(),
      );

      // Fully-resolved sets (no pending items) are never collapsed.
      final resolvedIn = input
          .whereType<ChangeSetEntity>()
          .where(
            (cs) => !cs.items.any((i) => i.status == ChangeItemStatus.pending),
          )
          .map((e) => e.id)
          .toSet();
      final outIds = output.map((e) => e.id).toSet();
      expect(outIds.containsAll(resolvedIn), isTrue, reason: '$resolvedIn');

      // For every surviving set with pending items, no other input set with
      // the same pending fingerprint is newer.
      String keyOf(ChangeSetEntity cs) =>
          (cs.items
                  .where((i) => i.status == ChangeItemStatus.pending)
                  .map(ChangeItem.fingerprint)
                  .toList()
                ..sort())
              .join('|');
      for (final survivor in output.whereType<ChangeSetEntity>()) {
        final key = keyOf(survivor);
        if (key.isEmpty) continue;
        for (final other in input.whereType<ChangeSetEntity>()) {
          if (keyOf(other) == key) {
            expect(
              other.createdAt.isAfter(survivor.createdAt),
              isFalse,
              reason: 'newer duplicate ${other.id} should have won',
            );
          }
        }
      }
    }, tags: 'glados');
  });
}
