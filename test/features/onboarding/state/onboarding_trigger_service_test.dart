import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_planner_readiness.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/state/onboarding_rollout.dart';
import 'package:lotti/features/onboarding/state/onboarding_trigger_service.dart';
import 'package:lotti/features/whats_new/model/whats_new_content.dart';
import 'package:lotti/features/whats_new/model/whats_new_release.dart';
import 'package:lotti/features/whats_new/model/whats_new_state.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

/// Fake [WhatsNewController] reporting no unseen release -- the "clear to
/// show the next auto-shown overlay" state.
class _NoUnseenWhatsNewController extends WhatsNewController {
  @override
  Future<WhatsNewState> build() async => const WhatsNewState();
}

/// Fake [WhatsNewController] reporting an unseen release -- blocks any
/// auto-show sequenced behind What's New.
class _UnseenWhatsNewController extends WhatsNewController {
  @override
  Future<WhatsNewState> build() async => WhatsNewState(
    unseenContent: [
      WhatsNewContent(
        release: WhatsNewRelease(
          version: '1.0.0',
          date: DateTime(2024),
          title: 'Test Release',
          folder: 'v1.0.0',
        ),
        headerMarkdown: '# Test',
        sections: const ['Feature 1'],
      ),
    ],
  );
}

void main() {
  group('isOnboardingWelcomeEligible', () {
    // Baseline args representing a fresh install: flag on, no unseen
    // What's New, nothing persisted yet. Each test overrides exactly the
    // input(s) relevant to the branch under test.
    bool eligible({
      bool ftueFlagEnabled = true,
      bool hasUnseenWhatsNew = false,
      bool completed = false,
      bool reachedRealAha = false,
      int shownCount = 0,
      DateTime? firstShownAt,
      DateTime? now,
    }) => isOnboardingWelcomeEligible(
      ftueFlagEnabled: ftueFlagEnabled,
      hasUnseenWhatsNew: hasUnseenWhatsNew,
      completed: completed,
      reachedRealAha: reachedRealAha,
      shownCount: shownCount,
      firstShownAt: firstShownAt,
      now: now ?? DateTime(2024, 1, 15),
    );

    test('is eligible on a fresh install (all defaults)', () {
      expect(eligible(), isTrue);
    });

    test('is not eligible when the FTUE flag is disabled', () {
      expect(eligible(ftueFlagEnabled: false), isFalse);
    });

    test("is not eligible while What's New has unseen content", () {
      expect(eligible(hasUnseenWhatsNew: true), isFalse);
    });

    test('is not eligible once marked completed', () {
      expect(eligible(completed: true), isFalse);
    });

    test('is not eligible once the real aha was reached', () {
      expect(eligible(reachedRealAha: true), isFalse);
    });

    test(
      'is eligible when shown one fewer time than the max',
      () {
        expect(
          eligible(shownCount: onboardingWelcomeMaxShows - 1),
          isTrue,
        );
      },
    );

    test('is not eligible once shown the max number of times', () {
      expect(eligible(shownCount: onboardingWelcomeMaxShows), isFalse);
    });

    test('is not eligible when shown more than the max number of times', () {
      expect(eligible(shownCount: onboardingWelcomeMaxShows + 1), isFalse);
    });

    test(
      'is eligible when never shown before (no first-shown timestamp), '
      'regardless of how far in the future "now" is',
      () {
        expect(
          eligible(now: DateTime(2030)),
          isTrue,
        );
      },
    );

    test(
      'is eligible just under the re-show window from the first show',
      () {
        final firstShownAt = DateTime(2024);
        final justUnder = firstShownAt
            .add(onboardingWelcomeWindow)
            .subtract(const Duration(seconds: 1));
        expect(
          eligible(firstShownAt: firstShownAt, now: justUnder),
          isTrue,
        );
      },
    );

    test(
      'is not eligible exactly at the re-show window boundary',
      () {
        final firstShownAt = DateTime(2024);
        final atWindow = firstShownAt.add(onboardingWelcomeWindow);
        expect(
          eligible(firstShownAt: firstShownAt, now: atWindow),
          isFalse,
        );
      },
    );

    test(
      'is not eligible once the re-show window has elapsed',
      () {
        final firstShownAt = DateTime(2024);
        final wellPast = firstShownAt.add(
          onboardingWelcomeWindow + const Duration(days: 1),
        );
        expect(
          eligible(firstShownAt: firstShownAt, now: wellPast),
          isFalse,
        );
      },
    );
  });

  group('shouldAutoShowOnboarding', () {
    late SettingsDb settingsDb;

    setUp(() async {
      settingsDb = SettingsDb(inMemoryDatabase: true);
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<SettingsDb>()
            ..registerSingleton<SettingsDb>(settingsDb);
        },
      );
    });

    tearDown(() async {
      if (getIt.isRegistered<OnboardingMetricsRepository>()) {
        getIt.unregister<OnboardingMetricsRepository>();
      }
      await settingsDb.close();
      await tearDownTestGetIt();
    });

    ProviderContainer createContainer({
      required bool ftueEnabled,
      bool whatsNewHasUnseen = false,
      bool whatsNewFeatureEnabled = true,
    }) {
      final mockJournalDb = MockJournalDb();
      when(
        () => mockJournalDb.getConfigFlag(enableOnboardingFtueFlag),
      ).thenAnswer((_) async => ftueEnabled);
      when(
        () => mockJournalDb.getConfigFlag(enableWhatsNewFlag),
      ).thenAnswer((_) async => whatsNewFeatureEnabled);

      final container = ProviderContainer(
        overrides: [
          journalDbProvider.overrideWithValue(mockJournalDb),
          whatsNewControllerProvider.overrideWith(
            whatsNewHasUnseen
                ? _UnseenWhatsNewController.new
                : _NoUnseenWhatsNewController.new,
          ),
          // Stand in for an install the rollout has already passed through, so
          // these cases exercise the cadence branches alone. The gate's
          // dependency on the backfill has its own group below.
          onboardingRolloutBackfillProvider.overrideWith((ref) async {}),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('returns false when the FTUE flag is disabled', () async {
      final container = createContainer(ftueEnabled: false);

      final result = await container.read(
        shouldAutoShowOnboardingProvider.future,
      );

      expect(result, isFalse);
    });

    test("returns false while What's New has unseen content", () async {
      final container = createContainer(
        ftueEnabled: true,
        whatsNewHasUnseen: true,
      );

      final result = await container.read(
        shouldAutoShowOnboardingProvider.future,
      );

      expect(result, isFalse);
    });

    test(
      "returns true when What's New has unseen content but the What's New "
      'feature itself is disabled -- unseen content can never be marked '
      'seen if its own modal is never shown, so it must not block the '
      'welcome forever',
      () async {
        final container = createContainer(
          ftueEnabled: true,
          whatsNewHasUnseen: true,
          whatsNewFeatureEnabled: false,
        );

        final result = await container.read(
          shouldAutoShowOnboardingProvider.future,
        );

        expect(result, isTrue);
      },
    );

    test('returns true on a fresh install with nothing persisted', () async {
      final container = createContainer(ftueEnabled: true);

      final result = await container.read(
        shouldAutoShowOnboardingProvider.future,
      );

      expect(result, isTrue);
    });

    test('returns false once marked completed', () async {
      await settingsDb.saveSettingsItem(onboardingWelcomeCompletedKey, 'true');
      final container = createContainer(ftueEnabled: true);

      final result = await container.read(
        shouldAutoShowOnboardingProvider.future,
      );

      expect(result, isFalse);
    });

    test(
      'returns false once the persisted shown count reaches the max',
      () async {
        await settingsDb.saveSettingsItem(
          onboardingWelcomeShownCountKey,
          '$onboardingWelcomeMaxShows',
        );
        final container = createContainer(ftueEnabled: true);

        final result = await container.read(
          shouldAutoShowOnboardingProvider.future,
        );

        expect(result, isFalse);
      },
    );

    test(
      'returns true when the persisted shown count is under the max and '
      'the first-shown timestamp is recent',
      () async {
        await settingsDb.saveSettingsItem(
          onboardingWelcomeShownCountKey,
          '${onboardingWelcomeMaxShows - 1}',
        );
        await settingsDb.saveSettingsItem(
          onboardingWelcomeFirstShownAtKey,
          DateTime.now().toUtc().toIso8601String(),
        );
        final container = createContainer(ftueEnabled: true);

        final result = await container.read(
          shouldAutoShowOnboardingProvider.future,
        );

        expect(result, isTrue);
      },
    );

    test(
      'returns false once the persisted first-shown timestamp is outside '
      'the re-show window',
      () async {
        await settingsDb.saveSettingsItem(
          onboardingWelcomeFirstShownAtKey,
          DateTime.utc(2000).toIso8601String(),
        );
        final container = createContainer(ftueEnabled: true);

        final result = await container.read(
          shouldAutoShowOnboardingProvider.future,
        );

        expect(result, isFalse);
      },
    );

    test(
      'returns true when the onboarding metrics repository is not '
      'registered',
      () async {
        expect(
          getIt.isRegistered<OnboardingMetricsRepository>(),
          isFalse,
        );
        final container = createContainer(ftueEnabled: true);

        final result = await container.read(
          shouldAutoShowOnboardingProvider.future,
        );

        expect(result, isTrue);
      },
    );

    test(
      'returns true when the metrics repository reports the real aha was '
      'not yet reached',
      () async {
        final mockRepo = MockOnboardingMetricsRepository();
        when(mockRepo.funnelState).thenAnswer(
          (_) async => const OnboardingFunnelState.empty(),
        );
        getIt.registerSingleton<OnboardingMetricsRepository>(mockRepo);
        final container = createContainer(ftueEnabled: true);

        final result = await container.read(
          shouldAutoShowOnboardingProvider.future,
        );

        expect(result, isTrue);
      },
    );

    test(
      'returns false when the metrics repository reports the real aha was '
      'reached',
      () async {
        final mockRepo = MockOnboardingMetricsRepository();
        when(mockRepo.funnelState).thenAnswer(
          (_) async => OnboardingFunnelState(
            installFirstSeen: DateTime(2024),
            activeDayBuckets: const [],
            isBaselineCohort: false,
            eventCounts: {OnboardingEventName.realAha.wireName: 1},
          ),
        );
        getIt.registerSingleton<OnboardingMetricsRepository>(mockRepo);
        final container = createContainer(ftueEnabled: true);

        final result = await container.read(
          shouldAutoShowOnboardingProvider.future,
        );

        expect(result, isFalse);
      },
    );

    test(
      'returns true (defensive default) when the metrics repository read '
      'throws',
      () async {
        final mockRepo = MockOnboardingMetricsRepository();
        when(mockRepo.funnelState).thenThrow(Exception('boom'));
        getIt.registerSingleton<OnboardingMetricsRepository>(mockRepo);
        final container = createContainer(ftueEnabled: true);

        final result = await container.read(
          shouldAutoShowOnboardingProvider.future,
        );

        expect(result, isTrue);
      },
    );
  });

  group('OnboardingWelcomeCadence', () {
    late SettingsDb settingsDb;

    setUp(() async {
      settingsDb = SettingsDb(inMemoryDatabase: true);
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<SettingsDb>()
            ..registerSingleton<SettingsDb>(settingsDb);
        },
      );
    });

    tearDown(() async {
      await settingsDb.close();
      await tearDownTestGetIt();
    });

    ProviderContainer createContainer() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return container;
    }

    test(
      'recordShown sets the shown count to 1 and stamps first-shown-at on '
      'the very first call',
      () async {
        final container = createContainer();

        await container
            .read(onboardingWelcomeCadenceProvider.notifier)
            .recordShown();

        expect(
          await settingsDb.itemByKey(onboardingWelcomeShownCountKey),
          '1',
        );
        expect(
          await settingsDb.itemByKey(onboardingWelcomeFirstShownAtKey),
          isNotNull,
        );
      },
    );

    test(
      'recordShown increments an existing shown count without touching '
      'the first-shown-at timestamp',
      () async {
        const firstShownAt = '2024-01-01T00:00:00.000Z';
        await settingsDb.saveSettingsItem(onboardingWelcomeShownCountKey, '2');
        await settingsDb.saveSettingsItem(
          onboardingWelcomeFirstShownAtKey,
          firstShownAt,
        );
        final container = createContainer();

        await container
            .read(onboardingWelcomeCadenceProvider.notifier)
            .recordShown();

        expect(
          await settingsDb.itemByKey(onboardingWelcomeShownCountKey),
          '3',
        );
        expect(
          await settingsDb.itemByKey(onboardingWelcomeFirstShownAtKey),
          firstShownAt,
        );
      },
    );

    test('markCompleted persists the completed flag', () async {
      final container = createContainer();

      await container
          .read(onboardingWelcomeCadenceProvider.notifier)
          .markCompleted();

      expect(
        await settingsDb.itemByKey(onboardingWelcomeCompletedKey),
        'true',
      );
    });

    test(
      'markCompleted refreshes the currently watched welcome gate',
      () async {
        final mockJournalDb = MockJournalDb();
        when(
          () => mockJournalDb.getConfigFlag(enableOnboardingFtueFlag),
        ).thenAnswer((_) async => true);
        when(
          () => mockJournalDb.getConfigFlag(enableWhatsNewFlag),
        ).thenAnswer((_) async => false);
        final container = ProviderContainer(
          overrides: [
            journalDbProvider.overrideWithValue(mockJournalDb),
            whatsNewControllerProvider.overrideWith(
              _NoUnseenWhatsNewController.new,
            ),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          shouldAutoShowOnboardingProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);

        expect(
          await container.read(shouldAutoShowOnboardingProvider.future),
          isTrue,
        );

        await container
            .read(onboardingWelcomeCadenceProvider.notifier)
            .markCompleted();

        expect(
          await container.read(shouldAutoShowOnboardingProvider.future),
          isFalse,
        );
      },
    );
  });

  // Both cadence writes run fire-and-forget from a modal callback, so a
  // The gate must resolve the rollout backfill before it reads the cadence
  // keys: the backfill is what retires the welcome for installs that were
  // already set up when the rollout arrived, so a gate that raced it would
  // flash a provider-setup flow at a configured user on the upgrade launch.
  group('shouldAutoShowOnboarding — rollout backfill sequencing', () {
    late SettingsDb settingsDb;

    setUp(() async {
      settingsDb = SettingsDb(inMemoryDatabase: true);
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<SettingsDb>()
            ..registerSingleton<SettingsDb>(settingsDb);
        },
      );
    });

    tearDown(() async {
      await settingsDb.close();
      await tearDownTestGetIt();
    });

    /// Wires the *real* backfill (no override) on top of a stubbed readiness
    /// signal, so the gate resolves exactly as it does at runtime.
    Future<bool> readGate({required bool providerReady}) {
      final mockJournalDb = MockJournalDb();
      when(
        () => mockJournalDb.getConfigFlag(enableOnboardingFtueFlag),
      ).thenAnswer((_) async => true);
      when(
        () => mockJournalDb.getConfigFlag(enableWhatsNewFlag),
      ).thenAnswer((_) async => false);

      final container = ProviderContainer(
        overrides: [
          journalDbProvider.overrideWithValue(mockJournalDb),
          whatsNewControllerProvider.overrideWith(
            _NoUnseenWhatsNewController.new,
          ),
          dailyOsOnboardingProviderReadyProvider.overrideWith(
            (ref) async => providerReady,
          ),
        ],
      );
      addTearDown(container.dispose);
      return container.read(shouldAutoShowOnboardingProvider.future);
    }

    test(
      'an already-configured install never sees the welcome, even on the very '
      'first gate read after the rollout',
      () async {
        expect(await readGate(providerReady: true), isFalse);
        // The gate observed the backfill's write rather than the empty
        // pre-migration cadence.
        expect(
          await settingsDb.itemByKey(onboardingWelcomeCompletedKey),
          'true',
        );
      },
    );

    test('an un-set-up install still gets the welcome', () async {
      expect(await readGate(providerReady: false), isTrue);
      expect(await settingsDb.itemByKey(onboardingWelcomeCompletedKey), isNull);
    });
  });

  // SettingsDb failure must be logged and swallowed rather than thrown (an
  // unhandled async error would otherwise abort the flow).
  group('OnboardingWelcomeCadence — SettingsDb failures are swallowed', () {
    late MockSettingsDb settingsDb;
    late MockDomainLogger logger;

    setUpAll(() => registerFallbackValue(StackTrace.empty));

    setUp(() async {
      settingsDb = MockSettingsDb();
      logger = MockDomainLogger();
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<SettingsDb>()
            ..registerSingleton<SettingsDb>(settingsDb)
            ..unregister<DomainLogger>()
            ..registerSingleton<DomainLogger>(logger);
        },
      );
    });

    tearDown(tearDownTestGetIt);

    test('recordShown logs and does not throw when the read fails', () async {
      when(() => settingsDb.itemsByKeys(any())).thenThrow(Exception('db down'));
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await expectLater(
        container.read(onboardingWelcomeCadenceProvider.notifier).recordShown(),
        completes,
      );
      verify(
        () => logger.error(
          LogDomain.onboarding,
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'onboardingWelcomeRecordShown',
        ),
      ).called(1);
    });

    test(
      'markOnboardingWelcomeCompleted logs and does not throw when the write '
      'fails',
      () async {
        when(
          () => settingsDb.saveSettingsItem(any(), any()),
        ).thenThrow(Exception('db down'));

        await expectLater(markOnboardingWelcomeCompleted(), completes);
        verify(
          () => logger.error(
            LogDomain.onboarding,
            any(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'onboardingWelcomeMarkCompleted',
          ),
        ).called(1);
      },
    );
  });
}
