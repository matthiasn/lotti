import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/onboarding/onboarding_sync_service.dart';
import 'package:lotti/features/sync/repository/sync_maintenance_repository.dart';
import 'package:lotti/features/sync/services/historical_sync_service.dart';
import 'package:lotti/features/sync/ui/re_sync_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

// ignore_for_file: avoid_redundant_argument_values

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHistoricalSyncService mockHistoricalSyncService;
  late MockSyncMaintenanceRepository mockSyncMaintenanceRepository;
  late MockDomainLogger mockLogging;

  ReSyncResult partialResult({Future<void> Function()? retryAction}) =>
      ReSyncResult(
        succeeded: 2,
        failures: [
          ReSyncFailure(
            phase: ReSyncPhase.agentEntities,
            itemType: ReSyncItemType.agentEntity,
            itemId: 'agent-bad',
            error: StateError('invalid agent row'),
            stackTrace: StackTrace.empty,
            retryAction: retryAction ?? () async {},
            logger: mockLogging,
          ),
        ],
      );

  List<Override> modalOverrides() => [
    historicalSyncServiceProvider.overrideWithValue(
      mockHistoricalSyncService,
    ),
    syncMaintenanceRepositoryProvider.overrideWithValue(
      mockSyncMaintenanceRepository,
    ),
  ];

  Future<void> pumpModal(
    WidgetTester tester, {
    OnboardingSyncTarget? onboardingTarget,
    OnboardingSyncService? onboardingSyncService,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        ReSyncModalContent(
          onboardingTarget: onboardingTarget,
          onboardingSyncService: onboardingSyncService,
        ),
        overrides: modalOverrides(),
      ),
    );
    await tester.pump();
  }

  Future<void> openOnboardingModal(
    WidgetTester tester, {
    required OnboardingSyncTarget target,
    OnboardingSyncService? onboardingSyncService,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => unawaited(
              ReSyncModal.show(
                context,
                onboardingTarget: target,
                onboardingSyncService: onboardingSyncService,
              ),
            ),
            child: const Text('Open onboarding'),
          ),
        ),
        overrides: modalOverrides(),
      ),
    );

    await tester.tap(find.text('Open onboarding'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ReSyncModalContent), findsOneWidget);
  }

  Future<void> selectPreset(
    WidgetTester tester,
    ReSyncRangePreset preset,
  ) async {
    tester
        .widget<DsSegmentedToggle<ReSyncRangePreset>>(
          find.byType(DsSegmentedToggle<ReSyncRangePreset>),
        )
        .onChanged(preset);
    await tester.pump();
  }

  Future<void> pickCustomDate(
    WidgetTester tester, {
    required Key fieldKey,
    required DateTime date,
  }) async {
    await tester.tap(find.byKey(fieldKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final calendar = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    calendar.onDateChanged(date);
    await tester.pump();
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Done').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    mockLogging = MockDomainLogger();
    when(
      () => mockLogging.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) {});
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(mockLogging);
      },
    );
    mockHistoricalSyncService = MockHistoricalSyncService();
    mockSyncMaintenanceRepository = MockSyncMaintenanceRepository();
    when(
      () => mockSyncMaintenanceRepository.backfillAgentEntityClocks(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockSyncMaintenanceRepository.backfillAgentLinkClocks(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockHistoricalSyncService.reSyncInterval(
        start: any(named: 'start'),
        end: any(named: 'end'),
        includeJournalEntities: any(named: 'includeJournalEntities'),
        includeAgentEntities: any(named: 'includeAgentEntities'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async => ReSyncResult.empty);
  });

  tearDown(tearDownTestGetIt);

  testWidgets('defaults to All and hides custom date fields', (
    tester,
  ) async {
    await pumpModal(tester);

    expect(find.text('All'), findsWidgets);
    expect(find.text('Last 30 days'), findsWidgets);
    expect(find.text('Custom'), findsWidgets);
    expect(find.byKey(const Key('reSyncStartDate')), findsNothing);
    expect(find.byKey(const Key('reSyncEndDate')), findsNothing);
  });

  testWidgets(
    'entity choices use compact full-row targets with trailing checkboxes',
    (tester) async {
      await pumpModal(tester);

      for (final (key, label) in [
        (
          const Key('reSyncJournalEntitiesCheckbox'),
          'Journal entities',
        ),
        (
          const Key('reSyncAgentEntitiesCheckbox'),
          'Agent entities',
        ),
      ]) {
        final row = find.byKey(key);
        final checkbox = find.descendant(
          of: row,
          matching: find.byType(DesignSystemCheckbox),
        );
        final text = find.descendant(
          of: row,
          matching: find.text(label),
        );

        expect(
          tester.widget<DesignSystemSelectionRow>(row).type,
          DesignSystemSelectionRowType.multiSelect,
        );
        expect(tester.getSize(row).height, TapTargets.minimum);
        expect(
          tester.getCenter(checkbox).dx,
          greaterThan(tester.getCenter(text).dx),
        );
      }
    },
  );

  testWidgets('starts re-sync with the selected custom interval', (
    tester,
  ) async {
    await pumpModal(tester);
    await selectPreset(tester, ReSyncRangePreset.custom);

    final start = DateTime(2024, 1, 1);
    final end = DateTime(2024, 1, 2);
    await pickCustomDate(
      tester,
      fieldKey: const Key('reSyncStartDate'),
      date: start,
    );
    await pickCustomDate(
      tester,
      fieldKey: const Key('reSyncEndDate'),
      date: end,
    );

    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();

    verify(
      () => mockHistoricalSyncService.reSyncInterval(
        start: start,
        end: DateTime(2024, 1, 3),
        includeJournalEntities: true,
        includeAgentEntities: true,
        onProgress: any(named: 'onProgress'),
      ),
    ).called(1);
  });

  testWidgets('All sends the complete historical interval', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 7, 27, 12);

    await withClock(Clock.fixed(now), () async {
      await pumpModal(tester);
      await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
      await tester.pump();
    });

    verify(
      () => mockHistoricalSyncService.reSyncInterval(
        start: reSyncEverythingStart,
        end: now,
        includeJournalEntities: true,
        includeAgentEntities: true,
        onProgress: any(named: 'onProgress'),
      ),
    ).called(1);
  });

  testWidgets(
    'initial onboarding installs suppression before staging full history',
    (tester) async {
      const target = OnboardingSyncTarget(
        userId: '@alice:example.com',
        deviceId: 'PHONE',
      );
      const round = OutboundOnboardingRound(
        roundId: 'round-1',
        senderHostId: 'desktop-host',
        target: target,
        coverageUpperBounds: {'desktop-host': 99},
      );
      final onboarding = MockOnboardingSyncService();
      when(
        () => onboarding.beginOutbound(target),
      ).thenAnswer((_) async => round);
      when(
        () => onboarding.completeOutbound(round),
      ).thenAnswer((_) async {});

      await pumpModal(
        tester,
        onboardingTarget: target,
        onboardingSyncService: onboarding,
      );
      await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
      await tester.pump();

      verifyInOrder([
        () => onboarding.beginOutbound(target),
        () => mockHistoricalSyncService.reSyncInterval(
          start: reSyncEverythingStart,
          end: any(named: 'end'),
          includeJournalEntities: true,
          includeAgentEntities: true,
          onProgress: any(named: 'onProgress'),
        ),
        () => onboarding.completeOutbound(round),
      ]);
    },
  );

  testWidgets('partial onboarding keeps suppression until retry succeeds', (
    tester,
  ) async {
    const target = OnboardingSyncTarget(
      userId: '@alice:example.com',
      deviceId: 'PHONE',
    );
    const round = OutboundOnboardingRound(
      roundId: 'round-1',
      senderHostId: 'desktop-host',
      target: target,
      coverageUpperBounds: {'desktop-host': 99},
    );
    final onboarding = MockOnboardingSyncService();
    when(
      () => onboarding.beginOutbound(target),
    ).thenAnswer((_) async => round);
    when(
      () => onboarding.completeOutbound(round),
    ).thenAnswer((_) async {});
    var retryCalls = 0;
    final partial = partialResult(
      retryAction: () async {
        retryCalls++;
      },
    );
    when(
      () => mockHistoricalSyncService.reSyncInterval(
        start: any(named: 'start'),
        end: any(named: 'end'),
        includeJournalEntities: any(named: 'includeJournalEntities'),
        includeAgentEntities: any(named: 'includeAgentEntities'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async => partial);

    await pumpModal(
      tester,
      onboardingTarget: target,
      onboardingSyncService: onboarding,
    );
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();

    verify(() => onboarding.beginOutbound(target)).called(1);
    verifyNever(() => onboarding.completeOutbound(round));
    expect(find.byKey(const Key('reSyncRetryFailures')), findsOneWidget);

    await tester.tap(find.byKey(const Key('reSyncRetryFailures')));
    await tester.pump();

    expect(retryCalls, 1);
    verify(() => onboarding.completeOutbound(round)).called(1);
    expect(find.byKey(const Key('reSyncComplete')), findsOneWidget);
  });

  testWidgets('retry infrastructure failure aborts onboarding', (
    tester,
  ) async {
    const target = OnboardingSyncTarget(
      userId: '@alice:example.com',
      deviceId: 'PHONE',
    );
    const round = OutboundOnboardingRound(
      roundId: 'round-1',
      senderHostId: 'desktop-host',
      target: target,
      coverageUpperBounds: {'desktop-host': 99},
    );
    final onboarding = MockOnboardingSyncService();
    when(
      () => onboarding.beginOutbound(target),
    ).thenAnswer((_) async => round);
    when(() => onboarding.abortOutbound(round)).thenAnswer((_) async {});
    when(
      () => mockHistoricalSyncService.reSyncInterval(
        start: any(named: 'start'),
        end: any(named: 'end'),
        includeJournalEntities: any(named: 'includeJournalEntities'),
        includeAgentEntities: any(named: 'includeAgentEntities'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer(
      (_) async => partialResult(
        retryAction: () async => throw StateError('retry failed'),
      ),
    );
    when(
      () => mockLogging.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
        message: any<String?>(named: 'message'),
      ),
    ).thenAnswer((invocation) {
      if (invocation.namedArguments[#subDomain] == 'reSyncInterval.item') {
        throw StateError('retry logging failed');
      }
    });

    await pumpModal(
      tester,
      onboardingTarget: target,
      onboardingSyncService: onboarding,
    );
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reSyncRetryFailures')));
    await tester.pump();

    verify(() => onboarding.abortOutbound(round)).called(1);
    verify(
      () => mockLogging.error(
        LogDomain.sync,
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: 'reSyncMessagesRetry',
      ),
    ).called(1);
    expect(find.byKey(const Key('reSyncFailed')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('partial target sync does not start onboarding suppression', (
    tester,
  ) async {
    const target = OnboardingSyncTarget(
      userId: '@alice:example.com',
      deviceId: 'PHONE',
    );
    final onboarding = MockOnboardingSyncService();
    when(
      () => onboarding.releaseInboundPreflight(target),
    ).thenAnswer((_) async {});
    await pumpModal(
      tester,
      onboardingTarget: target,
      onboardingSyncService: onboarding,
    );
    await selectPreset(tester, ReSyncRangePreset.last30Days);
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();

    verifyInOrder([
      () => onboarding.releaseInboundPreflight(target),
      () => mockHistoricalSyncService.reSyncInterval(
        start: any(named: 'start'),
        end: any(named: 'end'),
        includeJournalEntities: true,
        includeAgentEntities: true,
        onProgress: any(named: 'onProgress'),
      ),
    ]);
    verifyNever(() => onboarding.beginOutbound(target));
  });

  testWidgets('closing onboarding history releases an unused preflight', (
    tester,
  ) async {
    const target = OnboardingSyncTarget(
      userId: '@alice:example.com',
      deviceId: 'PHONE',
    );
    final onboarding = MockOnboardingSyncService();
    when(
      () => onboarding.releaseInboundPreflight(target),
    ).thenAnswer((_) async {});
    getIt.registerSingleton<OnboardingSyncService>(onboarding);

    await openOnboardingModal(tester, target: target);
    Navigator.of(tester.element(find.byType(ReSyncModalContent))).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(() => onboarding.releaseInboundPreflight(target)).called(1);
    expect(find.byType(ReSyncModalContent), findsNothing);
  });

  testWidgets('started onboarding is not released again on dismissal', (
    tester,
  ) async {
    const target = OnboardingSyncTarget(
      userId: '@alice:example.com',
      deviceId: 'PHONE',
    );
    const round = OutboundOnboardingRound(
      roundId: 'round-1',
      senderHostId: 'desktop-host',
      target: target,
      coverageUpperBounds: {'desktop-host': 99},
    );
    final onboarding = MockOnboardingSyncService();
    when(
      () => onboarding.beginOutbound(target),
    ).thenAnswer((_) async => round);
    when(
      () => onboarding.completeOutbound(round),
    ).thenAnswer((_) async {});

    await openOnboardingModal(
      tester,
      target: target,
      onboardingSyncService: onboarding,
    );
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();
    expect(find.byKey(const Key('reSyncComplete')), findsOneWidget);

    Navigator.of(tester.element(find.byType(ReSyncModalContent))).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(() => onboarding.beginOutbound(target)).called(1);
    verify(() => onboarding.completeOutbound(round)).called(1);
    verifyNever(() => onboarding.releaseInboundPreflight(target));
    expect(find.byType(ReSyncModalContent), findsNothing);
  });

  testWidgets('dismissing partial onboarding aborts its active barrier', (
    tester,
  ) async {
    const target = OnboardingSyncTarget(
      userId: '@alice:example.com',
      deviceId: 'PHONE',
    );
    const round = OutboundOnboardingRound(
      roundId: 'round-1',
      senderHostId: 'desktop-host',
      target: target,
      coverageUpperBounds: {'desktop-host': 99},
    );
    final onboarding = MockOnboardingSyncService();
    when(
      () => onboarding.beginOutbound(target),
    ).thenAnswer((_) async => round);
    when(() => onboarding.abortOutbound(round)).thenAnswer((_) async {});
    when(
      () => mockHistoricalSyncService.reSyncInterval(
        start: any(named: 'start'),
        end: any(named: 'end'),
        includeJournalEntities: any(named: 'includeJournalEntities'),
        includeAgentEntities: any(named: 'includeAgentEntities'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async => partialResult());

    await openOnboardingModal(
      tester,
      target: target,
      onboardingSyncService: onboarding,
    );
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();
    expect(find.byKey(const Key('reSyncRetryFailures')), findsOneWidget);

    Navigator.of(tester.element(find.byType(ReSyncModalContent))).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(() => onboarding.abortOutbound(round)).called(1);
    verifyNever(() => onboarding.completeOutbound(round));
    verifyNever(() => onboarding.releaseInboundPreflight(target));
    expect(find.byType(ReSyncModalContent), findsNothing);
  });

  testWidgets(
    'dismissal while history is staging never completes onboarding',
    (tester) async {
      const target = OnboardingSyncTarget(
        userId: '@alice:example.com',
        deviceId: 'PHONE',
      );
      const round = OutboundOnboardingRound(
        roundId: 'round-1',
        senderHostId: 'desktop-host',
        target: target,
        coverageUpperBounds: {'desktop-host': 99},
      );
      final onboarding = MockOnboardingSyncService();
      final staging = Completer<ReSyncResult>();
      when(
        () => onboarding.beginOutbound(target),
      ).thenAnswer((_) async => round);
      when(() => onboarding.abortOutbound(round)).thenAnswer((_) async {});
      when(
        () => onboarding.completeOutbound(round),
      ).thenAnswer((_) async {});
      when(
        () => mockHistoricalSyncService.reSyncInterval(
          start: any(named: 'start'),
          end: any(named: 'end'),
          includeJournalEntities: any(named: 'includeJournalEntities'),
          includeAgentEntities: any(named: 'includeAgentEntities'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) => staging.future);

      await openOnboardingModal(
        tester,
        target: target,
        onboardingSyncService: onboarding,
      );
      await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
      await tester.pump();

      Navigator.of(tester.element(find.byType(ReSyncModalContent))).pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      staging.complete(ReSyncResult.empty);
      await tester.pump();

      verify(() => onboarding.abortOutbound(round)).called(1);
      verifyNever(() => onboarding.completeOutbound(round));
      expect(find.byType(ReSyncModalContent), findsNothing);
    },
  );

  testWidgets('dismissal while retrying never completes onboarding', (
    tester,
  ) async {
    const target = OnboardingSyncTarget(
      userId: '@alice:example.com',
      deviceId: 'PHONE',
    );
    const round = OutboundOnboardingRound(
      roundId: 'round-1',
      senderHostId: 'desktop-host',
      target: target,
      coverageUpperBounds: {'desktop-host': 99},
    );
    final onboarding = MockOnboardingSyncService();
    final retry = Completer<void>();
    when(
      () => onboarding.beginOutbound(target),
    ).thenAnswer((_) async => round);
    when(() => onboarding.abortOutbound(round)).thenAnswer((_) async {});
    when(
      () => onboarding.completeOutbound(round),
    ).thenAnswer((_) async {});
    when(
      () => mockHistoricalSyncService.reSyncInterval(
        start: any(named: 'start'),
        end: any(named: 'end'),
        includeJournalEntities: any(named: 'includeJournalEntities'),
        includeAgentEntities: any(named: 'includeAgentEntities'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer(
      (_) async => partialResult(retryAction: () => retry.future),
    );

    await openOnboardingModal(
      tester,
      target: target,
      onboardingSyncService: onboarding,
    );
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reSyncRetryFailures')));
    await tester.pump();

    Navigator.of(tester.element(find.byType(ReSyncModalContent))).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    retry.complete();
    await tester.pump();

    verify(() => onboarding.abortOutbound(round)).called(1);
    verifyNever(() => onboarding.completeOutbound(round));
    expect(find.byType(ReSyncModalContent), findsNothing);
  });

  testWidgets('failed onboarding Begin keeps dismissal cleanup armed', (
    tester,
  ) async {
    const target = OnboardingSyncTarget(
      userId: '@alice:example.com',
      deviceId: 'PHONE',
    );
    final onboarding = MockOnboardingSyncService();
    when(
      () => onboarding.beginOutbound(target),
    ).thenThrow(StateError('Begin was not queued'));
    when(
      () => onboarding.releaseInboundPreflight(target),
    ).thenAnswer((_) async {});

    await openOnboardingModal(
      tester,
      target: target,
      onboardingSyncService: onboarding,
    );
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();
    expect(find.byKey(const Key('reSyncFailed')), findsOneWidget);

    Navigator.of(tester.element(find.byType(ReSyncModalContent))).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(() => onboarding.beginOutbound(target)).called(1);
    verify(() => onboarding.releaseInboundPreflight(target)).called(1);
    expect(find.byType(ReSyncModalContent), findsNothing);
  });

  testWidgets('logs a failed preflight release when onboarding is dismissed', (
    tester,
  ) async {
    const target = OnboardingSyncTarget(
      userId: '@alice:example.com',
      deviceId: 'PHONE',
    );
    final onboarding = MockOnboardingSyncService();
    when(
      () => onboarding.releaseInboundPreflight(target),
    ).thenThrow(StateError('release failed'));

    await openOnboardingModal(
      tester,
      target: target,
      onboardingSyncService: onboarding,
    );
    Navigator.of(tester.element(find.byType(ReSyncModalContent))).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(
      () => mockLogging.error(
        LogDomain.sync,
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: 'reSyncOnboardingRelease',
      ),
    ).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding failure still attempts the aborted end barrier', (
    tester,
  ) async {
    const target = OnboardingSyncTarget(
      userId: '@alice:example.com',
      deviceId: 'PHONE',
    );
    const round = OutboundOnboardingRound(
      roundId: 'round-1',
      senderHostId: 'desktop-host',
      target: target,
      coverageUpperBounds: {'desktop-host': 99},
    );
    final onboarding = MockOnboardingSyncService();
    when(
      () => onboarding.beginOutbound(target),
    ).thenAnswer((_) async => round);
    when(
      () => onboarding.abortOutbound(round),
    ).thenAnswer((_) async => throw Exception('end enqueue failed'));
    when(
      () => mockHistoricalSyncService.reSyncInterval(
        start: any(named: 'start'),
        end: any(named: 'end'),
        includeJournalEntities: any(named: 'includeJournalEntities'),
        includeAgentEntities: any(named: 'includeAgentEntities'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async => throw Exception('history staging failed'));

    await pumpModal(
      tester,
      onboardingTarget: target,
      onboardingSyncService: onboarding,
    );
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();

    verify(() => onboarding.abortOutbound(round)).called(1);
    expect(find.byKey(const Key('reSyncFailed')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Last 30 days sends a deterministic 30-day interval', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 7, 27, 12);

    await withClock(Clock.fixed(now), () async {
      await pumpModal(tester);
      await selectPreset(tester, ReSyncRangePreset.last30Days);
      expect(find.byType(CalendarDatePicker), findsNothing);
      await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
      await tester.pump();
    });

    verify(
      () => mockHistoricalSyncService.reSyncInterval(
        start: now.subtract(const Duration(days: 30)),
        end: now,
        includeJournalEntities: true,
        includeAgentEntities: true,
        onProgress: any(named: 'onProgress'),
      ),
    ).called(1);
  });

  testWidgets('Custom rejects a range whose start is not before its end', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime(2026, 8, 5)), () async {
      await pumpModal(tester);
      await selectPreset(tester, ReSyncRangePreset.custom);
      await pickCustomDate(
        tester,
        fieldKey: const Key('reSyncStartDate'),
        date: DateTime(2026, 7, 28),
      );
      await pickCustomDate(
        tester,
        fieldKey: const Key('reSyncEndDate'),
        date: DateTime(2026, 7, 27),
      );
    });

    expect(find.byKey(const Key('reSyncInvalidRangeError')), findsOneWidget);
    expect(
      tester
          .widget<DesignSystemButton>(
            find.widgetWithText(DesignSystemButton, 'Start'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('Start waits in the modal and reports per-phase progress', (
    tester,
  ) async {
    final completer = Completer<ReSyncResult>();
    when(
      () => mockHistoricalSyncService.reSyncInterval(
        start: any(named: 'start'),
        end: any(named: 'end'),
        includeJournalEntities: any(named: 'includeJournalEntities'),
        includeAgentEntities: any(named: 'includeAgentEntities'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((invocation) {
      final onProgress =
          invocation.namedArguments[#onProgress] as ReSyncProgressCallback;
      onProgress(
        const ReSyncProgress(
          phase: ReSyncPhase.journalEntities,
          processed: 12,
          total: 25,
          isComplete: false,
        ),
      );
      return completer.future;
    });

    await pumpModal(tester);
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();

    expect(find.byKey(const Key('reSyncProgress')), findsOneWidget);
    expect(find.byKey(const Key('reSyncComplete')), findsNothing);
    expect(find.text('12 / 25'), findsOneWidget);

    completer.complete(ReSyncResult.empty);
    await tester.pump();

    expect(find.byKey(const Key('reSyncComplete')), findsOneWidget);
  });

  testWidgets('completed phase reports its count and completion state', (
    tester,
  ) async {
    final completer = Completer<ReSyncResult>();
    when(
      () => mockHistoricalSyncService.reSyncInterval(
        start: any(named: 'start'),
        end: any(named: 'end'),
        includeJournalEntities: any(named: 'includeJournalEntities'),
        includeAgentEntities: any(named: 'includeAgentEntities'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((invocation) {
      final onProgress =
          invocation.namedArguments[#onProgress] as ReSyncProgressCallback;
      onProgress(
        const ReSyncProgress(
          phase: ReSyncPhase.journalEntities,
          processed: 12,
          total: 12,
          isComplete: true,
        ),
      );
      return completer.future;
    });

    await pumpModal(tester);
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();

    expect(find.byKey(const Key('reSyncProgress')), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('12 / 12'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);

    completer.complete(ReSyncResult.empty);
    await tester.pump();
  });

  testWidgets('caps live progress at 100 percent when totals grow stale', (
    tester,
  ) async {
    final completer = Completer<ReSyncResult>();
    when(
      () => mockHistoricalSyncService.reSyncInterval(
        start: any(named: 'start'),
        end: any(named: 'end'),
        includeJournalEntities: any(named: 'includeJournalEntities'),
        includeAgentEntities: any(named: 'includeAgentEntities'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((invocation) {
      final onProgress =
          invocation.namedArguments[#onProgress] as ReSyncProgressCallback;
      onProgress(
        const ReSyncProgress(
          phase: ReSyncPhase.journalEntities,
          processed: 2,
          total: 1,
          isComplete: false,
        ),
      );
      return completer.future;
    });

    await pumpModal(tester);
    await tester.tap(find.byKey(const Key('reSyncAgentEntitiesCheckbox')));
    await tester.pump();
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();

    expect(find.text('100%'), findsOneWidget);
    expect(find.text('200%'), findsNothing);

    completer.complete(ReSyncResult.empty);
    await tester.pump();
  });

  testWidgets('failure stays in the modal and can be retried', (tester) async {
    var attempts = 0;
    when(
      () => mockHistoricalSyncService.reSyncInterval(
        start: any(named: 'start'),
        end: any(named: 'end'),
        includeJournalEntities: any(named: 'includeJournalEntities'),
        includeAgentEntities: any(named: 'includeAgentEntities'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) throw Exception('enqueue failed');
      return ReSyncResult.empty;
    });

    await pumpModal(tester);
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();

    expect(find.byKey(const Key('reSyncFailed')), findsOneWidget);
    expect(find.byKey(const Key('reSyncComplete')), findsNothing);
    expect(
      tester
          .widget<DesignSystemButton>(
            find.widgetWithText(DesignSystemButton, 'Start'),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();

    expect(attempts, 2);
    expect(find.byKey(const Key('reSyncFailed')), findsNothing);
    expect(find.byKey(const Key('reSyncComplete')), findsOneWidget);
  });

  testWidgets('partial result names failed rows and retries only those rows', (
    tester,
  ) async {
    var retryCalls = 0;
    final retryCompleter = Completer<void>();
    final partial = partialResult(
      retryAction: () {
        retryCalls++;
        return retryCompleter.future;
      },
    );
    when(
      () => mockHistoricalSyncService.reSyncInterval(
        start: any(named: 'start'),
        end: any(named: 'end'),
        includeJournalEntities: any(named: 'includeJournalEntities'),
        includeAgentEntities: any(named: 'includeAgentEntities'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async => partial);

    await pumpModal(tester);
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();

    expect(find.text('2 of 3 messages queued'), findsOneWidget);
    expect(find.textContaining('Agent entity: agent-bad'), findsOneWidget);
    expect(find.byKey(const Key('reSyncRetryFailures')), findsOneWidget);

    await tester.tap(find.byKey(const Key('reSyncRetryFailures')));
    await tester.pump();

    expect(retryCalls, 1);
    expect(find.text('0 / 1'), findsOneWidget);

    retryCompleter.complete();
    await tester.pump();

    expect(find.text('Messages queued'), findsOneWidget);
    expect(find.byKey(const Key('reSyncFailureDetails')), findsNothing);
    verify(
      () => mockHistoricalSyncService.reSyncInterval(
        start: any(named: 'start'),
        end: any(named: 'end'),
        includeJournalEntities: any(named: 'includeJournalEntities'),
        includeAgentEntities: any(named: 'includeAgentEntities'),
        onProgress: any(named: 'onProgress'),
      ),
    ).called(1);
  });

  testWidgets('uses the localized maintenance label as the modal title', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ReSyncModal.show(context),
            child: const Text('Open'),
          ),
        ),
        overrides: [
          historicalSyncServiceProvider.overrideWithValue(
            mockHistoricalSyncService,
          ),
          syncMaintenanceRepositoryProvider.overrideWithValue(
            mockSyncMaintenanceRepository,
          ),
        ],
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Message history'), findsWidgets);
    expect(find.text('Re-sync messages'), findsNothing);

    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();
    expect(find.byKey(const Key('reSyncComplete')), findsOneWidget);

    await tester.tap(find.widgetWithText(DesignSystemButton, 'Done'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(ReSyncModalContent), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets(
    'unchecking agent entities excludes agent entities',
    (tester) async {
      await pumpModal(tester);

      await tester.tap(find.byKey(const Key('reSyncAgentEntitiesCheckbox')));
      await tester.pump();
      await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
      await tester.pump();

      verify(
        () => mockHistoricalSyncService.reSyncInterval(
          start: any(named: 'start'),
          end: any(named: 'end'),
          includeJournalEntities: true,
          includeAgentEntities: false,
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'unchecking journal entities excludes journal entities',
    (tester) async {
      await pumpModal(tester);

      await tester.tap(find.byKey(const Key('reSyncJournalEntitiesCheckbox')));
      await tester.pump();
      await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
      await tester.pump();

      verify(
        () => mockHistoricalSyncService.reSyncInterval(
          start: any(named: 'start'),
          end: any(named: 'end'),
          includeJournalEntities: false,
          includeAgentEntities: true,
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
    },
  );

  testWidgets('Start disables when neither entity type is selected', (
    tester,
  ) async {
    await pumpModal(tester);

    await tester.tap(find.byKey(const Key('reSyncJournalEntitiesCheckbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reSyncAgentEntitiesCheckbox')));
    await tester.pump();

    expect(
      tester
          .widget<DesignSystemButton>(
            find.widgetWithText(DesignSystemButton, 'Start'),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.byKey(const Key('reSyncSelectAtLeastOneError')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('reSyncJournalEntitiesCheckbox')));
    await tester.pump();

    expect(
      tester
          .widget<DesignSystemButton>(
            find.widgetWithText(DesignSystemButton, 'Start'),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      find.byKey(const Key('reSyncSelectAtLeastOneError')),
      findsNothing,
    );
  });
}
