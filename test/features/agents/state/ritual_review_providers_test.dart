import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';

import '../test_utils.dart';

void main() {
  group('pendingRitualReviewProvider', () {
    test('returns active session when one exists', () async {
      final activeSession = makeTestEvolutionSession();

      final container = ProviderContainer(
        overrides: [
          pendingRitualReviewProvider.overrideWith(
            (ref, templateId) async => activeSession,
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
      expect(session.status, EvolutionSessionStatus.active);
    });

    test('returns null when no active session', () async {
      final container = ProviderContainer(
        overrides: [
          pendingRitualReviewProvider.overrideWith(
            (ref, templateId) async => null,
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        pendingRitualReviewProvider(kTestTemplateId).future,
      );

      expect(result, isNull);
    });
  });

  group('templatesPendingReviewProvider', () {
    test('returns set of template IDs with active sessions', () async {
      final container = ProviderContainer(
        overrides: [
          templatesPendingReviewProvider.overrideWith(
            (ref) async => {'template-A'},
          ),
        ],
      );
      addTearDown(container.dispose);

      final result =
          await container.read(templatesPendingReviewProvider.future);
      expect(result, {'template-A'});
    });

    test('returns distinct template IDs for multiple active sessions',
        () async {
      final container = ProviderContainer(
        overrides: [
          templatesPendingReviewProvider.overrideWith(
            (ref) async => {'template-A', 'template-B'},
          ),
        ],
      );
      addTearDown(container.dispose);

      final result =
          await container.read(templatesPendingReviewProvider.future);
      expect(result, hasLength(2));
      expect(result, contains('template-A'));
      expect(result, contains('template-B'));
    });

    test('returns empty set when no active sessions', () async {
      final container = ProviderContainer(
        overrides: [
          templatesPendingReviewProvider.overrideWith(
            (ref) async => <String>{},
          ),
        ],
      );
      addTearDown(container.dispose);

      final result =
          await container.read(templatesPendingReviewProvider.future);
      expect(result, isEmpty);
    });
  });

  group('evolutionSessionStatsProvider', () {
    test('computes aggregate stats correctly', () async {
      final sessions = [
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
          evolutionSessionsProvider(kTestTemplateId).overrideWith(
            (ref) async => sessions.cast<AgentDomainEntity>(),
          ),
          evolutionSessionStatsProvider.overrideWith(
            (ref, templateId) async {
              final total = sessions.length;
              final completed = sessions
                  .where(
                    (s) => s.status == EvolutionSessionStatus.completed,
                  )
                  .length;
              final abandoned = sessions
                  .where(
                    (s) => s.status == EvolutionSessionStatus.abandoned,
                  )
                  .length;
              return EvolutionSessionStats(
                totalSessions: total,
                completedCount: completed,
                abandonedCount: abandoned,
                approvalRate: completed / total,
              );
            },
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

    test('handles empty sessions', () async {
      final container = ProviderContainer(
        overrides: [
          evolutionSessionStatsProvider.overrideWith(
            (ref, templateId) async => const EvolutionSessionStats(
              totalSessions: 0,
              completedCount: 0,
              abandonedCount: 0,
              approvalRate: 0,
            ),
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
