import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/nudges/model/nudge_banner_entry.dart';
import 'package:lotti/features/nudges/model/nudge_entity_view.dart';
import 'package:lotti/features/nudges/state/nudge_banner_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

NudgeBannerEntry _entry(
  String id, {
  NudgeBannerKind kind = NudgeBannerKind.goal,
  DateTime? activatedAt,
}) => (
  nudge: NudgeEntityView.of(
    kind == NudgeBannerKind.goal
        ? AgentDomainEntity.goalNudge(
            id: id,
            agentId: 'goal-$id',
            status: NudgeStatus.active,
            brief: const NudgeBrief(
              headline: 'h',
              tone: NudgeTone.nudge,
              animation: NudgeBannerAnimation.steady,
            ),
            briefDigest: id,
            createdAt: DateTime.utc(2026, 8, 10),
            updatedAt: DateTime.utc(2026, 8, 10),
            vectorClock: null,
            activatedAt: activatedAt,
          )
        : AgentDomainEntity.relationshipNudge(
            id: id,
            agentId: 'relationship-$id',
            status: NudgeStatus.active,
            brief: const NudgeBrief(
              headline: 'h',
              tone: NudgeTone.nudge,
              animation: NudgeBannerAnimation.steady,
            ),
            briefDigest: id,
            createdAt: DateTime.utc(2026, 8, 10),
            updatedAt: DateTime.utc(2026, 8, 10),
            vectorClock: null,
            activatedAt: activatedAt,
          ),
  )!,
  subjectTitle: id,
  kind: kind,
  tapRoute: '/route/$id',
);

void main() {
  setUpAll(registerAllFallbackValues);

  group('activeNudgeBannersProvider', () {
    test('with no registered sources (the default) it is empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(activeNudgeBannersProvider, (_, _) {});
      addTearDown(sub.close);
      expect(container.read(nudgeBannerSourcesProvider), isEmpty);
      expect(container.read(activeNudgeBannersProvider), isEmpty);
    });

    test("a single source's order passes through untouched", () async {
      final source = FutureProvider<List<NudgeBannerEntry>>(
        (ref) async => [_entry('b'), _entry('a')],
      );
      final container = ProviderContainer(
        overrides: [
          nudgeBannerSourcesProvider.overrideWithValue([source]),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(activeNudgeBannersProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(source.future);
      expect(
        container.read(activeNudgeBannersProvider).map((e) => e.nudge.id),
        ['b', 'a'],
        reason:
            'sources are newest-first already; one kind must not be '
            're-sorted into a different order than its own provider chose',
      );
    });

    test('multiple kinds merge newest-first across sources, and a source '
        'still loading contributes nothing', () async {
      final goals = FutureProvider<List<NudgeBannerEntry>>(
        (ref) async => [
          _entry('goal-old', activatedAt: DateTime.utc(2026, 8, 11)),
        ],
      );
      final relationships = FutureProvider<List<NudgeBannerEntry>>(
        (ref) async => [
          _entry(
            'relationship-new',
            kind: NudgeBannerKind.relationship,
            activatedAt: DateTime.utc(2026, 8, 12),
          ),
        ],
      );
      final never = FutureProvider<List<NudgeBannerEntry>>(
        // Unresolved: represents a kind whose projection is still loading.
        (ref) => Completer<List<NudgeBannerEntry>>().future,
      );
      final container = ProviderContainer(
        overrides: [
          nudgeBannerSourcesProvider.overrideWithValue([
            goals,
            relationships,
            never,
          ]),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(activeNudgeBannersProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(goals.future);
      await container.read(relationships.future);
      expect(
        container.read(activeNudgeBannersProvider).map((e) => e.nudge.id),
        ['relationship-new', 'goal-old'],
      );
    });

    test(
      'invalidateNudgeBannerSources recomputes every registered source',
      () async {
        var builds = 0;
        final source = FutureProvider<List<NudgeBannerEntry>>((ref) async {
          builds++;
          return const [];
        });
        final container = ProviderContainer(
          overrides: [
            nudgeBannerSourcesProvider.overrideWithValue([source]),
          ],
        );
        addTearDown(container.dispose);
        final sub = container.listen(activeNudgeBannersProvider, (_, _) {});
        addTearDown(sub.close);
        await container.read(source.future);
        expect(builds, 1);

        invalidateNudgeBannerSources(container);
        await container.read(source.future);
        expect(builds, 2);
      },
    );
  });

  group('LocallySnoozedNudgeDeadlines', () {
    test('stores a future deadline, ignores a past one, and removes itself '
        'on time', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final sub = container.listen(
          locallySnoozedNudgeDeadlinesProvider,
          (_, _) {},
        );
        addTearDown(sub.close);
        final notifier = container.read(
          locallySnoozedNudgeDeadlinesProvider.notifier,
        );
        final now = clock.now();

        notifier.add('past', 1, now.subtract(const Duration(minutes: 1)));
        expect(container.read(locallySnoozedNudgeDeadlinesProvider), isEmpty);

        notifier.add('ad-1', 2, now.add(const Duration(minutes: 30)));
        expect(container.read(locallySnoozedNudgeDeadlinesProvider), {
          'ad-1': (
            activation: 2,
            until: now.add(const Duration(minutes: 30)),
          ),
        });

        async.elapse(const Duration(minutes: 31));
        expect(
          container.read(locallySnoozedNudgeDeadlinesProvider),
          isEmpty,
          reason: 'each deadline removes itself when it lapses',
        );
      });
    });
  });

  group('nudgeExposureFlushProvider', () {
    test('a failing exposure flush is contained and logged — never an '
        'uncaught async error from a disposed banner', () async {
      final repository = MockAgentRepository();
      final syncService = MockAgentSyncService();
      final logger = MockDomainLogger();
      when(
        () => repository.getEntity('ad-err'),
      ).thenAnswer((_) async => throw StateError('db closed mid-dispose'));
      when(
        () => logger.error(
          any(),
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
          message: any(named: 'message'),
        ),
      ).thenReturn(null);
      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(repository),
          agentSyncServiceProvider.overrideWithValue(syncService),
          domainLoggerProvider.overrideWithValue(logger),
        ],
      );
      addTearDown(container.dispose);

      container.read(nudgeExposureFlushProvider)(
        'ad-err',
        const Duration(seconds: 1),
      );
      await pumpEventQueue();

      verify(
        () => logger.error(
          any(),
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'nudgeExposure',
          message: any(named: 'message', that: contains('ad-err')),
        ),
      ).called(1);
    });
  });
}
