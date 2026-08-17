import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/nudges/model/nudge_banner_entry.dart';
import 'package:lotti/features/nudges/service/nudge_interactions.dart';
import 'package:lotti/services/domain_logging.dart';

/// The user's side of the banner contract: snooze, dismiss for today, rate,
/// and account for exposure — one service for every nudge kind.
final nudgeInteractionsProvider = Provider<NudgeInteractions>(
  (ref) => NudgeInteractions(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
  ),
  name: 'nudgeInteractionsProvider',
);

/// The per-kind banner sources, registered in `app_bootstrap.dart` (the
/// `agentWakeRunnersProvider` merge pattern): each contributing feature owns
/// a provider producing its ACTIVE banners newest-first, and this substrate
/// never imports a feature. Empty by default so tests and headless
/// containers need no override.
final Provider<List<FutureProvider<List<NudgeBannerEntry>>>>
nudgeBannerSourcesProvider =
    Provider<List<FutureProvider<List<NudgeBannerEntry>>>>(
      (_) => const [],
      name: 'nudgeBannerSourcesProvider',
    );

/// Every kind's active banners, merged. Single-source containers (the
/// current fleet: goals only) pass their source's order through untouched;
/// a multi-kind merge re-sorts newest-first, matching the per-source
/// contract. Each source's retained value survives its own background
/// refresh (`.value` on a reloading FutureProvider), so the dock never
/// flashes empty on sync.
final Provider<List<NudgeBannerEntry>> activeNudgeBannersProvider =
    Provider.autoDispose<List<NudgeBannerEntry>>(
      (ref) {
        final sources = ref.watch(nudgeBannerSourcesProvider);
        final entries = [
          for (final source in sources) ...?ref.watch(source).value,
        ];
        if (sources.length > 1) {
          entries.sort(
            (a, b) => (b.nudge.activatedAt ?? b.nudge.createdAt).compareTo(
              a.nudge.activatedAt ?? a.nudge.createdAt,
            ),
          );
        }
        return entries;
      },
      name: 'activeNudgeBannersProvider',
    );

/// Invalidates every registered banner source — the post-interaction
/// refresh. Interaction writes go through the sync service (which
/// deliberately does not notify), so the UI handlers call this after
/// visibility/rating actions.
void invalidateNudgeBannerSources(ProviderContainer container) {
  container.read(nudgeBannerSourcesProvider).forEach(container.invalidate);
}

/// Snooze deadlines learned from a just-committed chat wake before the async
/// active-banner projection has reloaded. Banner surfaces subtract these ids
/// from retained data, so a background refresh cannot flash the old active row
/// throughout its quiet interval. Each deadline removes itself on time.
typedef NudgeBannerLocalSuppression = ({int activation, DateTime until});

class LocallySnoozedNudgeDeadlines
    extends Notifier<Map<String, NudgeBannerLocalSuppression>> {
  final _timers = <String, Timer>{};

  @override
  Map<String, NudgeBannerLocalSuppression> build() {
    ref.onDispose(() {
      for (final timer in _timers.values) {
        timer.cancel();
      }
    });
    return const {};
  }

  void add(String id, int activation, DateTime until) {
    final now = clock.now();
    if (!until.isAfter(now)) {
      // A quiet interval that is already over still supersedes whatever
      // echo came before it: a "Dismiss for today" that captured midnight
      // before the transaction but committed after returns an expired
      // deadline AND cleared the durable snooze — leaving the old echo in
      // place would keep the banner hidden from the dock on this device
      // until a deadline the durable state no longer knows.
      final timer = _timers.remove(id)?..cancel();
      if (timer != null || state.containsKey(id)) {
        state = Map.of(state)..remove(id);
      }
      return;
    }
    _timers[id]?.cancel();
    state = {...state, id: (activation: activation, until: until)};
    _timers[id] = Timer(until.difference(now), () {
      _timers.remove(id);
      state = Map.of(state)..remove(id);
    });
  }
}

final NotifierProvider<
  LocallySnoozedNudgeDeadlines,
  Map<String, NudgeBannerLocalSuppression>
>
locallySnoozedNudgeDeadlinesProvider =
    NotifierProvider<
      LocallySnoozedNudgeDeadlines,
      Map<String, NudgeBannerLocalSuppression>
    >(
      LocallySnoozedNudgeDeadlines.new,
      name: 'locallySnoozedNudgeDeadlinesProvider',
    );

/// Fire-and-forget exposure flush, captured by the banner's tracker
/// while its element is live and safe to call from `dispose`.
typedef NudgeInteractionsFlush =
    void Function(String nudgeId, Duration visibleFor);

final nudgeExposureFlushProvider = Provider<NudgeInteractionsFlush>(
  (ref) {
    final interactions = ref.watch(nudgeInteractionsProvider);
    final logger = ref.watch(domainLoggerProvider);
    return (nudgeId, visibleFor) {
      // The dispose path cannot await this, so a persistence failure must
      // be contained here — logged, never an uncaught async error.
      unawaited(
        interactions.recordExposure(nudgeId, visibleFor: visibleFor).catchError(
          (Object e, StackTrace st) {
            logger.error(
              LogDomain.agentRuntime,
              e,
              stackTrace: st,
              subDomain: 'nudgeExposure',
              message: 'exposure flush for $nudgeId was not persisted',
            );
          },
        ),
      );
    };
  },
  name: 'nudgeExposureFlushProvider',
);
