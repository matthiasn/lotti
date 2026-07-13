import 'dart:async';
import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    show AiConfigRepository;
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_trigger_service.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';
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

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_data/ai_config_factories.dart';
import '../../agents/test_data/entity_factories.dart';
import '../../agents/test_data/template_factories.dart';

/// Fake [WhatsNewController] reporting no unseen release — the "clear to show
/// the next auto-shown overlay" state.
class _NoUnseenWhatsNewController extends WhatsNewController {
  @override
  Future<WhatsNewState> build() async => const WhatsNewState();
}

/// Fake [WhatsNewController] reporting an unseen release — blocks any
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
  setUpAll(registerAllFallbackValues);

  group('isDailyOsOnboardingEligible', () {
    // Baseline args: a genuinely new Daily OS user on today's empty surface
    // with a ready provider and nothing persisted. Each test overrides only
    // the input(s) relevant to the branch under test.
    bool eligible({
      bool dailyOsOnboardingFlagEnabled = true,
      bool hasUnseenWhatsNew = false,
      bool welcomeStillOwed = false,
      bool selectedDateIsToday = true,
      bool todayHasActivePlan = false,
      bool hasEverHadPlan = false,
      bool providerReady = true,
      bool completed = false,
      int shownCount = 0,
      DateTime? firstShownAt,
      DateTime? now,
    }) => isDailyOsOnboardingEligible(
      dailyOsOnboardingFlagEnabled: dailyOsOnboardingFlagEnabled,
      hasUnseenWhatsNew: hasUnseenWhatsNew,
      welcomeStillOwed: welcomeStillOwed,
      selectedDateIsToday: selectedDateIsToday,
      todayHasActivePlan: todayHasActivePlan,
      hasEverHadPlan: hasEverHadPlan,
      providerReady: providerReady,
      completed: completed,
      shownCount: shownCount,
      firstShownAt: firstShownAt,
      now: now ?? DateTime(2026, 7, 10, 12),
    );

    test('is true for a fresh, ready, today-scoped candidate', () {
      expect(eligible(), isTrue);
    });

    test("false while What's New still has unseen content", () {
      expect(eligible(hasUnseenWhatsNew: true), isFalse);
    });

    test('false while the general FTUE welcome is still owed', () {
      expect(eligible(welcomeStillOwed: true), isFalse);
    });

    test('false when the Daily OS onboarding flag is off', () {
      expect(eligible(dailyOsOnboardingFlagEnabled: false), isFalse);
    });

    test('false when the selected date is not today', () {
      expect(eligible(selectedDateIsToday: false), isFalse);
    });

    test('false when today already has an active plan', () {
      expect(eligible(todayHasActivePlan: true), isFalse);
    });

    test('false when a plan has ever existed (even on another day)', () {
      expect(eligible(hasEverHadPlan: true), isFalse);
    });

    test('false when no usable provider/profile is configured', () {
      expect(eligible(providerReady: false), isFalse);
    });

    test('false once the walkthrough is completed', () {
      expect(eligible(completed: true), isFalse);
    });

    test('false when the shown count reaches the max', () {
      expect(eligible(shownCount: dailyOsOnboardingMaxShows), isFalse);
    });

    test('true while the shown count is under the max', () {
      expect(eligible(shownCount: dailyOsOnboardingMaxShows - 1), isTrue);
    });

    test('true when the first-shown timestamp is null', () {
      // Explicit null documents the never-shown branch under test.
      // ignore: avoid_redundant_argument_values
      expect(eligible(firstShownAt: null), isTrue);
    });

    test('true just inside the grace window', () {
      final now = DateTime(2026, 7, 10, 12);
      final firstShown = now
          .subtract(dailyOsOnboardingWindow)
          .add(const Duration(minutes: 1));
      expect(eligible(firstShownAt: firstShown, now: now), isTrue);
    });

    test('false exactly at the grace-window boundary', () {
      final now = DateTime(2026, 7, 10, 12);
      final firstShown = now.subtract(dailyOsOnboardingWindow);
      expect(eligible(firstShownAt: firstShown, now: now), isFalse);
    });

    test('false well past the grace window', () {
      final now = DateTime(2026, 7, 10, 12);
      final firstShown = now.subtract(const Duration(days: 30));
      expect(eligible(firstShownAt: firstShown, now: now), isFalse);
    });
  });

  group('dailyOsOnboardingProviderReadyProvider', () {
    late MockAiConfigRepository aiConfigRepository;
    late MockAgentRepository agentRepository;
    late MockAgentTemplateService templateService;
    late MockProfileResolver profileResolver;
    late AgentTemplateEntity template;
    late AgentTemplateVersionEntity version;

    setUp(() async {
      aiConfigRepository = MockAiConfigRepository();
      agentRepository = MockAgentRepository();
      templateService = MockAgentTemplateService();
      profileResolver = MockProfileResolver();
      template = makeTestTemplate(
        id: dayAgentTemplateId,
        agentId: dayAgentTemplateId,
        kind: AgentTemplateKind.dayAgent,
      );
      version = makeTestTemplateVersion(agentId: dayAgentTemplateId);

      await setUpTestGetIt(
        additionalSetup: () {
          getIt.registerSingleton<AiConfigRepository>(aiConfigRepository);
        },
      );

      when(
        () => agentRepository.getEntity(dailyOsPlannerAgentId),
      ).thenAnswer((_) async => null);
      when(
        () => templateService.getTemplate(dayAgentTemplateId),
      ).thenAnswer((_) async => template);
      when(
        () => templateService.getActiveVersion(dayAgentTemplateId),
      ).thenAnswer((_) async => version);
    });

    tearDown(tearDownTestGetIt);

    Future<bool> readReady({required ResolvedProfile? resolvedProfile}) {
      when(
        () => aiConfigRepository.watchConfigsByType(
          AiConfigType.inferenceProvider,
        ),
      ).thenAnswer((_) => Stream.value([testLocalInferenceProvider()]));
      when(
        () => aiConfigRepository.watchConfigsByType(AiConfigType.model),
      ).thenAnswer((_) => Stream.value(const []));
      when(
        () => aiConfigRepository.watchConfigsByType(
          AiConfigType.inferenceProfile,
        ),
      ).thenAnswer((_) => Stream.value(const []));
      when(
        () => profileResolver.resolve(
          agentConfig: any(named: 'agentConfig'),
          template: template,
          version: version,
        ),
      ).thenAnswer((_) async => resolvedProfile);

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(agentRepository),
          agentTemplateServiceProvider.overrideWithValue(templateService),
          profileResolverProvider.overrideWithValue(profileResolver),
        ],
      );
      addTearDown(container.dispose);
      container.listen(
        dailyOsOnboardingProviderReadyProvider,
        (_, _) {},
      );
      return container.read(dailyOsOnboardingProviderReadyProvider.future);
    }

    test('true when the exact planner thinking route resolves', () async {
      final resolvedProfile = ResolvedProfile(
        thinkingModelId: 'models/gemini-3-flash-preview',
        thinkingProvider: testInferenceProvider(),
      );

      expect(
        await readReady(resolvedProfile: resolvedProfile),
        isTrue,
      );
      verify(
        () => profileResolver.resolve(
          agentConfig: AgentConfig(modelId: template.modelId),
          template: template,
          version: version,
        ),
      ).called(1);
    });

    test('false when a configured provider cannot serve the planner', () async {
      expect(await readReady(resolvedProfile: null), isFalse);
    });

    test(
      'existing planner resolves its assigned template and config',
      () async {
        const plannerConfig = AgentConfig(profileId: 'planner-profile');
        final planner = makeTestIdentity(
          id: dailyOsPlannerAgentId,
          agentId: dailyOsPlannerAgentId,
          kind: 'day_agent',
          config: plannerConfig,
        );
        final assignedTemplate = makeTestTemplate(
          id: 'assigned-day-template',
          agentId: 'assigned-day-template',
          kind: AgentTemplateKind.dayAgent,
        );
        final assignedVersion = makeTestTemplateVersion(
          agentId: assignedTemplate.id,
        );
        final resolvedProfile = ResolvedProfile(
          thinkingModelId: 'models/gemini-3-flash-preview',
          thinkingProvider: testInferenceProvider(),
        );
        when(
          () => agentRepository.getEntity(dailyOsPlannerAgentId),
        ).thenAnswer((_) async => planner);
        when(
          () => templateService.getTemplateForAgent(dailyOsPlannerAgentId),
        ).thenAnswer((_) async => assignedTemplate);
        when(
          () => templateService.getActiveVersion(assignedTemplate.id),
        ).thenAnswer((_) async => assignedVersion);
        when(
          () => profileResolver.resolve(
            agentConfig: plannerConfig,
            template: assignedTemplate,
            version: assignedVersion,
          ),
        ).thenAnswer((_) async => resolvedProfile);

        expect(
          await hasResolvableDailyOsPlannerThinkingRoute(
            agentRepository: agentRepository,
            templateService: templateService,
            profileResolver: profileResolver,
          ),
          isTrue,
        );
        verify(
          () => profileResolver.resolve(
            agentConfig: plannerConfig,
            template: assignedTemplate,
            version: assignedVersion,
          ),
        ).called(1);
      },
    );

    test('false when the seeded day-agent template is unavailable', () async {
      when(
        () => templateService.getTemplate(dayAgentTemplateId),
      ).thenAnswer((_) async => null);

      expect(
        await hasResolvableDailyOsPlannerThinkingRoute(
          agentRepository: agentRepository,
          templateService: templateService,
          profileResolver: profileResolver,
        ),
        isFalse,
      );
      verifyNever(
        () => profileResolver.resolve(
          agentConfig: any(named: 'agentConfig'),
          template: any(named: 'template'),
          version: any(named: 'version'),
        ),
      );
    });
  });

  group('shouldAutoShowDailyOsOnboarding', () {
    late SettingsDb settingsDb;
    final fixedNow = DateTime(2026, 7, 10, 12);
    final today = DateTime(2026, 7, 10);

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

    ProviderContainer createContainer({
      bool onboardingEnabled = true,
      bool providerReady = true,
      bool welcomeStillOwed = false,
      bool useRealWelcomeGate = false,
      bool whatsNewUnseen = false,
      int everPlanCount = 0,
      DraftPlan? todayPlan,
    }) {
      final mockJournalDb = MockJournalDb();
      when(
        () => mockJournalDb.getConfigFlag(dailyOsOnboardingEnabledFlag),
      ).thenAnswer((_) async => onboardingEnabled);
      // What's New only blocks when its feature is on AND it has unseen
      // content (mirrors the general FTUE welcome's own guard).
      when(
        () => mockJournalDb.getConfigFlag(enableWhatsNewFlag),
      ).thenAnswer((_) async => whatsNewUnseen);
      when(
        () => mockJournalDb.getConfigFlag(enableOnboardingFtueFlag),
      ).thenAnswer((_) async => true);

      final mockAgentRepo = MockAgentRepository();
      when(
        () => mockAgentRepo.countEntitiesByAgentAndType(
          agentId: any(named: 'agentId'),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async => everPlanCount);

      final container = ProviderContainer(
        overrides: [
          journalDbProvider.overrideWithValue(mockJournalDb),
          agentRepositoryProvider.overrideWithValue(mockAgentRepo),
          currentDraftPlanProvider.overrideWith((ref, date) async => todayPlan),
          dailyOsOnboardingProviderReadyProvider.overrideWith(
            (ref) async => providerReady,
          ),
          whatsNewControllerProvider.overrideWith(
            whatsNewUnseen
                ? _UnseenWhatsNewController.new
                : _NoUnseenWhatsNewController.new,
          ),
          // The general FTUE welcome's own gate, resolved directly so this
          // test does not re-plumb the welcome's dependencies.
          if (!useRealWelcomeGate)
            shouldAutoShowOnboardingProvider.overrideWith(
              (ref) async => welcomeStillOwed,
            ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<bool> read(ProviderContainer container) => withClock(
      Clock.fixed(fixedNow),
      () => container.read(shouldAutoShowDailyOsOnboardingProvider.future),
    );

    test('true on a fresh, ready, today-scoped candidate', () async {
      final container = createContainer();
      expect(await read(container), isTrue);
    });

    test('false when the Daily OS onboarding flag is off', () async {
      final container = createContainer(onboardingEnabled: false);
      expect(await read(container), isFalse);
    });

    test('false while the general FTUE welcome is still owed', () async {
      final container = createContainer(welcomeStillOwed: true);
      expect(await read(container), isFalse);
    });

    test('re-evaluates after the general FTUE welcome completes', () async {
      final container = createContainer(useRealWelcomeGate: true);

      await withClock(Clock.fixed(fixedNow), () async {
        final subscription = container.listen(
          shouldAutoShowDailyOsOnboardingProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);

        expect(
          await container.read(
            shouldAutoShowDailyOsOnboardingProvider.future,
          ),
          isFalse,
        );

        await container
            .read(onboardingWelcomeCadenceProvider.notifier)
            .markCompleted();

        expect(
          await container.read(
            shouldAutoShowDailyOsOnboardingProvider.future,
          ),
          isTrue,
        );
      });
    });

    test("false while What's New has unseen content", () async {
      final container = createContainer(whatsNewUnseen: true);
      expect(await read(container), isFalse);
    });

    test('false when the selected date is not today', () async {
      final container = createContainer();
      container
          .read(dailyOsNextSelectedDateProvider.notifier)
          .select(today.subtract(const Duration(days: 3)));
      expect(await read(container), isFalse);
    });

    test('false when today already has an active plan', () async {
      final container = createContainer(
        todayPlan: DraftPlan.emptyForDay(today),
      );
      expect(await read(container), isFalse);
    });

    test('false when a plan has ever existed (soft-deleted counts)', () async {
      final container = createContainer(everPlanCount: 1);
      expect(await read(container), isFalse);
    });

    test('false when the provider readiness seam is not ready', () async {
      final container = createContainer(providerReady: false);
      expect(await read(container), isFalse);
    });

    test('false once completion is persisted', () async {
      await settingsDb.saveSettingsItem(
        dailyOsOnboardingCompletedKey,
        'true',
      );
      final container = createContainer();
      expect(await read(container), isFalse);
    });

    test('false once the persisted shown count reaches the max', () async {
      await settingsDb.saveSettingsItem(
        dailyOsOnboardingShownCountKey,
        '$dailyOsOnboardingMaxShows',
      );
      final container = createContainer();
      expect(await read(container), isFalse);
    });

    test(
      'true when the shown count is under the max and the first-shown '
      'timestamp is recent',
      () async {
        await settingsDb.saveSettingsItem(
          dailyOsOnboardingShownCountKey,
          '${dailyOsOnboardingMaxShows - 1}',
        );
        await settingsDb.saveSettingsItem(
          dailyOsOnboardingFirstShownAtKey,
          fixedNow.toUtc().toIso8601String(),
        );
        final container = createContainer();
        expect(await read(container), isTrue);
      },
    );

    test('false when the first-shown timestamp is past the window', () async {
      await settingsDb.saveSettingsItem(
        dailyOsOnboardingShownCountKey,
        '1',
      );
      await settingsDb.saveSettingsItem(
        dailyOsOnboardingFirstShownAtKey,
        fixedNow.subtract(const Duration(days: 30)).toUtc().toIso8601String(),
      );
      final container = createContainer();
      expect(await read(container), isFalse);
    });
  });

  group('DailyOsOnboardingCadence', () {
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
      'recordShown sets the count to 1 and stamps first-shown-at on the '
      'first call',
      () async {
        final container = createContainer();
        final fixedNow = DateTime.utc(2026, 7, 10, 12);

        await withClock(
          Clock.fixed(fixedNow),
          () => container
              .read(dailyOsOnboardingCadenceProvider.notifier)
              .recordShown(),
        );

        expect(
          await settingsDb.itemByKey(dailyOsOnboardingShownCountKey),
          '1',
        );
        expect(
          await settingsDb.itemByKey(dailyOsOnboardingFirstShownAtKey),
          fixedNow.toIso8601String(),
        );
      },
    );

    test(
      'recordShown increments an existing count without touching '
      'first-shown-at',
      () async {
        const firstShownAt = '2026-07-01T00:00:00.000Z';
        await settingsDb.saveSettingsItem(dailyOsOnboardingShownCountKey, '2');
        await settingsDb.saveSettingsItem(
          dailyOsOnboardingFirstShownAtKey,
          firstShownAt,
        );
        final container = createContainer();

        await container
            .read(dailyOsOnboardingCadenceProvider.notifier)
            .recordShown();

        expect(
          await settingsDb.itemByKey(dailyOsOnboardingShownCountKey),
          '3',
        );
        expect(
          await settingsDb.itemByKey(dailyOsOnboardingFirstShownAtKey),
          firstShownAt,
        );
      },
    );

    test('markCompleted persists the completed flag', () async {
      final container = createContainer();

      await container
          .read(dailyOsOnboardingCadenceProvider.notifier)
          .markCompleted();

      expect(
        await settingsDb.itemByKey(dailyOsOnboardingCompletedKey),
        'true',
      );
    });
  });

  // Both cadence writes run fire-and-forget from a callback, so a SettingsDb
  // failure must be logged and swallowed rather than thrown.
  group('DailyOsOnboardingCadence — SettingsDb failures are swallowed', () {
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
        container.read(dailyOsOnboardingCadenceProvider.notifier).recordShown(),
        completes,
      );
      verify(
        () => logger.error(
          LogDomain.onboarding,
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'dailyOsOnboardingRecordShown',
        ),
      ).called(1);
    });

    test(
      'markDailyOsOnboardingCompleted logs and does not throw when the write '
      'fails',
      () async {
        when(
          () => settingsDb.saveSettingsItem(any(), any()),
        ).thenThrow(Exception('db down'));

        await expectLater(markDailyOsOnboardingCompleted(), completes);
        verify(
          () => logger.error(
            LogDomain.onboarding,
            any(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'dailyOsOnboardingMarkCompleted',
          ),
        ).called(1);
      },
    );
  });
}
