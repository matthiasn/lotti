import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/services/db_notification.dart';

import '../test_utils.dart';

void main() {
  group('pendingRitualReviewProvider', () {
    test('filters and returns the first active session', () async {
      final completedSession = makeTestEvolutionSession(
        id: 'evo-completed',
        status: EvolutionSessionStatus.completed,
      );
      final activeSession = makeTestEvolutionSession(
        id: 'evo-active',
        sessionNumber: 2,
      );

      final container = ProviderContainer(
        overrides: [
          evolutionSessionsProvider(kTestTemplateId).overrideWith(
            (ref) async => <AgentDomainEntity>[
              completedSession,
              activeSession,
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        pendingRitualReviewProvider(kTestTemplateId).future,
      );

      expect(result, isNotNull);
      expect(result, isA<EvolutionSessionEntity>());
      final session = result! as EvolutionSessionEntity;
      expect(session.id, 'evo-active');
      expect(session.status, EvolutionSessionStatus.active);
    });

    test('returns null when all sessions are completed or abandoned', () async {
      final container = ProviderContainer(
        overrides: [
          evolutionSessionsProvider(kTestTemplateId).overrideWith(
            (ref) async => <AgentDomainEntity>[
              makeTestEvolutionSession(
                id: 'evo-1',
                status: EvolutionSessionStatus.completed,
              ),
              makeTestEvolutionSession(
                id: 'evo-2',
                sessionNumber: 2,
                status: EvolutionSessionStatus.abandoned,
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        pendingRitualReviewProvider(kTestTemplateId).future,
      );

      expect(result, isNull);
    });

    test('returns null when session list is empty', () async {
      final container = ProviderContainer(
        overrides: [
          evolutionSessionsProvider(kTestTemplateId).overrideWith(
            (ref) async => <AgentDomainEntity>[],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        pendingRitualReviewProvider(kTestTemplateId).future,
      );

      expect(result, isNull);
    });

    test('ignores non-EvolutionSessionEntity items', () async {
      final activeSession = makeTestEvolutionSession(
        id: 'evo-active',
      );
      // An EvolutionNoteEntity is NOT an EvolutionSessionEntity, so the
      // whereType filter should skip it.
      final note = makeTestEvolutionNote(id: 'note-1');

      final container = ProviderContainer(
        overrides: [
          evolutionSessionsProvider(kTestTemplateId).overrideWith(
            (ref) async => <AgentDomainEntity>[note, activeSession],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        pendingRitualReviewProvider(kTestTemplateId).future,
      );

      expect(result, isNotNull);
      expect(result, isA<EvolutionSessionEntity>());
      expect((result! as EvolutionSessionEntity).id, 'evo-active');
    });
  });

  group('templatesPendingReviewProvider', () {
    test('collects distinct template IDs from active sessions', () async {
      final container = ProviderContainer(
        overrides: [
          agentUpdateStreamProvider(agentNotification).overrideWith(
            (ref) => const Stream<Set<String>>.empty(),
          ),
          allEvolutionSessionsProvider.overrideWith(
            (ref) async => <AgentDomainEntity>[
              makeTestEvolutionSession(
                id: 'evo-1',
                templateId: 'template-A',
              ),
              makeTestEvolutionSession(
                id: 'evo-2',
                templateId: 'template-B',
                sessionNumber: 2,
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result =
          await container.read(templatesPendingReviewProvider.future);

      expect(result, {'template-A', 'template-B'});
    });

    test('ignores completed and abandoned sessions', () async {
      final container = ProviderContainer(
        overrides: [
          agentUpdateStreamProvider(agentNotification).overrideWith(
            (ref) => const Stream<Set<String>>.empty(),
          ),
          allEvolutionSessionsProvider.overrideWith(
            (ref) async => <AgentDomainEntity>[
              makeTestEvolutionSession(
                id: 'evo-1',
                templateId: 'template-A',
                status: EvolutionSessionStatus.completed,
              ),
              makeTestEvolutionSession(
                id: 'evo-2',
                templateId: 'template-B',
                sessionNumber: 2,
                status: EvolutionSessionStatus.abandoned,
              ),
              makeTestEvolutionSession(
                id: 'evo-3',
                templateId: 'template-C',
                sessionNumber: 3,
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result =
          await container.read(templatesPendingReviewProvider.future);

      expect(result, {'template-C'});
    });

    test('returns empty set when no active sessions', () async {
      final container = ProviderContainer(
        overrides: [
          agentUpdateStreamProvider(agentNotification).overrideWith(
            (ref) => const Stream<Set<String>>.empty(),
          ),
          allEvolutionSessionsProvider.overrideWith(
            (ref) async => <AgentDomainEntity>[
              makeTestEvolutionSession(
                id: 'evo-1',
                status: EvolutionSessionStatus.completed,
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result =
          await container.read(templatesPendingReviewProvider.future);

      expect(result, isEmpty);
    });

    test('deduplicates when multiple active sessions share a template',
        () async {
      final container = ProviderContainer(
        overrides: [
          agentUpdateStreamProvider(agentNotification).overrideWith(
            (ref) => const Stream<Set<String>>.empty(),
          ),
          allEvolutionSessionsProvider.overrideWith(
            (ref) async => <AgentDomainEntity>[
              makeTestEvolutionSession(
                id: 'evo-1',
                templateId: 'template-A',
              ),
              makeTestEvolutionSession(
                id: 'evo-2',
                templateId: 'template-A',
                sessionNumber: 2,
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result =
          await container.read(templatesPendingReviewProvider.future);

      expect(result, hasLength(1));
      expect(result, contains('template-A'));
    });
  });

  group('evolutionSessionStatsProvider', () {
    test('correctly aggregates stats from mixed session statuses', () async {
      final sessions = <AgentDomainEntity>[
        makeTestEvolutionSession(
          id: 'evo-1',
          status: EvolutionSessionStatus.completed,
        ),
        makeTestEvolutionSession(
          id: 'evo-2',
          sessionNumber: 2,
          status: EvolutionSessionStatus.completed,
        ),
        makeTestEvolutionSession(
          id: 'evo-3',
          sessionNumber: 3,
          status: EvolutionSessionStatus.abandoned,
        ),
        makeTestEvolutionSession(
          id: 'evo-4',
          sessionNumber: 4,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          agentUpdateStreamProvider(kTestTemplateId).overrideWith(
            (ref) => const Stream<Set<String>>.empty(),
          ),
          evolutionSessionsProvider(kTestTemplateId).overrideWith(
            (ref) async => sessions,
          ),
        ],
      );
      addTearDown(container.dispose);

      final stats = await container.read(
        evolutionSessionStatsProvider(kTestTemplateId).future,
      );

      expect(stats.totalSessions, 4);
      expect(stats.completedCount, 2);
      expect(stats.abandonedCount, 1);
      expect(stats.approvalRate, 0.5);
    });

    test('returns zero approvalRate when no sessions exist', () async {
      final container = ProviderContainer(
        overrides: [
          agentUpdateStreamProvider(kTestTemplateId).overrideWith(
            (ref) => const Stream<Set<String>>.empty(),
          ),
          evolutionSessionsProvider(kTestTemplateId).overrideWith(
            (ref) async => <AgentDomainEntity>[],
          ),
        ],
      );
      addTearDown(container.dispose);

      final stats = await container.read(
        evolutionSessionStatsProvider(kTestTemplateId).future,
      );

      expect(stats.totalSessions, 0);
      expect(stats.completedCount, 0);
      expect(stats.abandonedCount, 0);
      expect(stats.approvalRate, 0.0);
    });
  });
}
