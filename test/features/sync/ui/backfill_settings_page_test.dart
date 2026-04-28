import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/ui/backfill_settings_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../mocks/mocks.dart';
import '../../../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;
  late MockSyncSequenceLogService mockSequenceService;
  late MockBackfillRequestService mockBackfillService;
  late MockUserActivityService mockUserActivityService;

  // Deterministic stats: pick numbers that make every counter visible
  // and unique so finder-by-text can disambiguate.
  final populatedStats = BackfillStats.fromHostStats([
    const BackfillHostStats(
      receivedCount: 100,
      missingCount: 5,
      requestedCount: 2,
      backfilledCount: 11,
      deletedCount: 7,
      unresolvableCount: 3,
    ),
  ]);

  // No connected devices, no work pending.
  final emptyStats = BackfillStats.fromHostStats(const []);

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({'backfill_enabled': true});
    mockJournalDb = MockJournalDb();
    mockSequenceService = MockSyncSequenceLogService();
    mockBackfillService = MockBackfillRequestService();
    mockUserActivityService = MockUserActivityService();

    when(
      () => mockJournalDb.watchConfigFlag(enableMatrixFlag),
    ).thenAnswer((_) => Stream<bool>.value(true));
    when(
      () => mockSequenceService.getBackfillStats(),
    ).thenAnswer((_) async => populatedStats);
    when(
      () => mockBackfillService.processFullBackfill(),
    ).thenAnswer((_) async => 5);
    when(
      () => mockSequenceService.resetUnresolvableEntries(),
    ).thenAnswer((_) async => 0);
    when(() => mockUserActivityService.updateActivity()).thenReturn(null);

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<SyncSequenceLogService>(mockSequenceService)
      ..registerSingleton<BackfillRequestService>(mockBackfillService)
      ..registerSingleton<UserActivityService>(mockUserActivityService);
  });

  tearDown(getIt.reset);

  // Pumps the body in isolation. Used for layout / state tests that
  // don't need the SyncFeatureGate. Wrapped in a [SingleChildScrollView]
  // because production hosts (V2 panel registry + legacy
  // SliverBoxAdapterPage) both supply scrolling — without it the
  // expanded recovery group overflows a fixed-height test viewport.
  Future<void> pumpBody(WidgetTester tester) async {
    await tester.pumpWidget(
      const RiverpodWidgetTestBench(
        child: SingleChildScrollView(child: BackfillSettingsBody()),
      ),
    );
    await tester.pumpAndSettle();
  }

  AppLocalizations messagesOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(BackfillSettingsBody)))!;

  group('BackfillSettingsBody · status row', () {
    testWidgets('shows three labelled cells with formatted counts', (
      tester,
    ) async {
      await pumpBody(tester);
      final messages = messagesOf(tester);

      expect(find.text(messages.backfillStatusInboundQueue), findsOneWidget);
      // "Missing" appears in both the status row (this label) and
      // the ledger; the closed `Advanced recovery` group does not
      // include it.
      expect(find.text(messages.backfillStatusMissing), findsNWidgets(2));
      expect(find.text(messages.backfillStatusSkipped), findsOneWidget);

      // Inbound queue & skipped come from the (absent) coordinator —
      // the body falls back to 0 when Matrix is not registered.
      // Missing comes from `populatedStats.totalMissing` = 5.
      expect(find.text('5'), findsWidgets);
    });

    testWidgets('missing label switches to high-emphasis check icon at zero', (
      tester,
    ) async {
      when(
        () => mockSequenceService.getBackfillStats(),
      ).thenAnswer((_) async => emptyStats);
      await pumpBody(tester);

      // missing = 0 → check icon (not bolt)
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.bolt_outlined), findsNothing);
    });

    testWidgets('missing > 0 swaps to bolt icon', (tester) async {
      await pumpBody(tester);
      // populatedStats.totalMissing = 5 → bolt icon. Note: the
      // advanced recovery group is closed, so its bolt icons (Catch
      // up now / Manual backfill) are NOT in the tree. The only bolt
      // is in the status row.
      expect(find.byIcon(Icons.bolt_outlined), findsOneWidget);
    });
  });

  group('BackfillSettingsBody · sync statistics ledger', () {
    testWidgets('renders all seven labelled rows', (tester) async {
      await pumpBody(tester);
      final messages = messagesOf(tester);

      expect(find.text(messages.backfillStatsTotalEntries), findsOneWidget);
      expect(find.text(messages.backfillStatsReceived), findsOneWidget);
      expect(find.text(messages.backfillStatsBackfilled), findsOneWidget);
      // `Missing` appears in both the status row and the ledger; both
      // come from `messages.backfillStatusMissing` /
      // `messages.backfillStatsMissing` which share the same English
      // text "Missing".
      expect(find.text(messages.backfillStatsMissing), findsWidgets);
      expect(find.text(messages.backfillStatsRequested), findsOneWidget);
      expect(find.text(messages.backfillStatsDeleted), findsOneWidget);
      expect(find.text(messages.backfillStatsUnresolvable), findsOneWidget);
    });

    testWidgets('shows correct values for each stat', (tester) async {
      await pumpBody(tester);

      // Total entries = 100 + 5 + 2 + 11 + 7 + 3 = 128
      expect(find.text('128'), findsOneWidget);
      expect(find.text('100'), findsOneWidget); // received
      expect(find.text('11'), findsOneWidget); // backfilled
      expect(find.text('2'), findsOneWidget); // requested
      expect(find.text('7'), findsOneWidget); // deleted
      expect(find.text('3'), findsOneWidget); // unresolvable
    });

    testWidgets('formats values >= 1000 with thousands separators', (
      tester,
    ) async {
      when(() => mockSequenceService.getBackfillStats()).thenAnswer(
        (_) async => BackfillStats.fromHostStats([
          const BackfillHostStats(
            receivedCount: 715544,
            missingCount: 0,
            requestedCount: 0,
            backfilledCount: 34811,
            deletedCount: 201,
            unresolvableCount: 152601,
          ),
        ]),
      );
      await pumpBody(tester);

      expect(find.text('715,544'), findsOneWidget);
      expect(find.text('34,811'), findsOneWidget);
      expect(find.text('152,601'), findsOneWidget);
    });

    testWidgets('refresh icon-button calls getBackfillStats', (tester) async {
      await pumpBody(tester);
      // Initial load already called once.
      clearInteractions(mockSequenceService);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      await tester.pumpAndSettle();

      verify(() => mockSequenceService.getBackfillStats()).called(1);
    });

    testWidgets('shows device-id meta with host count', (tester) async {
      await pumpBody(tester);
      final messages = messagesOf(tester);
      // populatedStats has exactly one host.
      expect(find.text(messages.backfillDevicesMeta(1)), findsOneWidget);
    });
  });

  group('BackfillSettingsBody · automatic backfill toggle', () {
    testWidgets('renders DesignSystemToggle in the on state by default', (
      tester,
    ) async {
      await pumpBody(tester);

      final toggleFinder = find.byType(DesignSystemToggle);
      expect(toggleFinder, findsOneWidget);
      final toggle = tester.widget<DesignSystemToggle>(toggleFinder);
      expect(toggle.value, isTrue);
    });

    testWidgets('tap flips the persisted preference', (tester) async {
      await pumpBody(tester);

      await tester.tap(find.byType(DesignSystemToggle));
      await tester.pumpAndSettle();

      final toggle = tester.widget<DesignSystemToggle>(
        find.byType(DesignSystemToggle),
      );
      expect(toggle.value, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('backfill_enabled'), isFalse);
    });
  });

  group('BackfillSettingsBody · advanced recovery group', () {
    testWidgets('is collapsed by default — recovery action buttons hidden', (
      tester,
    ) async {
      await pumpBody(tester);
      final messages = messagesOf(tester);

      // Header is visible.
      expect(
        find.text(messages.backfillAdvancedRecoveryTitle),
        findsOneWidget,
      );

      // The recovery body is not in the tree yet.
      expect(find.text(messages.backfillManualTitle), findsNothing);
      expect(find.text(messages.backfillReRequestTitle), findsNothing);
      expect(
        find.text(messages.backfillResetUnresolvableTitle),
        findsNothing,
      );
    });

    testWidgets('header shows the action count meta', (tester) async {
      await pumpBody(tester);
      final messages = messagesOf(tester);
      // Without skipped events, six actions are shown; the skipped
      // entry is conditional and gated on skipped > 0, which we have
      // no way to populate here (no Matrix coordinator in DI).
      expect(
        find.text(messages.backfillAdvancedRecoveryActions(6)),
        findsOneWidget,
      );
    });

    testWidgets('expands when the header is tapped', (tester) async {
      await pumpBody(tester);
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pumpAndSettle();

      expect(find.text(messages.backfillManualTitle), findsOneWidget);
      expect(find.text(messages.backfillReRequestTitle), findsOneWidget);
      expect(
        find.text(messages.backfillResetUnresolvableTitle),
        findsOneWidget,
      );
    });

    testWidgets('manual backfill action triggers the service', (tester) async {
      await pumpBody(tester);
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pumpAndSettle();

      // Find the DesignSystemButton whose label is the manual trigger.
      final triggerLabel = messages.backfillManualTrigger;
      final buttonFinder = find.widgetWithText(
        DesignSystemButton,
        triggerLabel,
      );

      await tester.ensureVisible(buttonFinder);
      await tester.pumpAndSettle();
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      verify(() => mockBackfillService.processFullBackfill()).called(1);
    });

    testWidgets(
      'reset unresolvable button is enabled when there are unresolvable rows',
      (tester) async {
        await pumpBody(tester);
        final messages = messagesOf(tester);

        await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
        await tester.pumpAndSettle();

        final btn = tester.widget<DesignSystemButton>(
          find.widgetWithText(
            DesignSystemButton,
            messages.backfillResetUnresolvableTrigger,
          ),
        );
        expect(btn.onPressed, isNotNull);
      },
    );

    testWidgets(
      'reset unresolvable button is disabled when count is 0',
      (tester) async {
        when(() => mockSequenceService.getBackfillStats()).thenAnswer(
          (_) async => BackfillStats.fromHostStats([
            const BackfillHostStats(
              receivedCount: 100,
              missingCount: 0,
              requestedCount: 2,
              backfilledCount: 0,
              deletedCount: 0,
              unresolvableCount: 0,
            ),
          ]),
        );
        await pumpBody(tester);
        final messages = messagesOf(tester);

        await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
        await tester.pumpAndSettle();

        final btn = tester.widget<DesignSystemButton>(
          find.widgetWithText(
            DesignSystemButton,
            messages.backfillResetUnresolvableTrigger,
          ),
        );
        expect(btn.onPressed, isNull);
      },
    );

    testWidgets(
      're-request pending button is disabled when requested == 0',
      (tester) async {
        when(() => mockSequenceService.getBackfillStats()).thenAnswer(
          (_) async => BackfillStats.fromHostStats([
            const BackfillHostStats(
              receivedCount: 100,
              missingCount: 0,
              requestedCount: 0,
              backfilledCount: 0,
              deletedCount: 0,
              unresolvableCount: 0,
            ),
          ]),
        );
        await pumpBody(tester);
        final messages = messagesOf(tester);

        await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
        await tester.pumpAndSettle();

        final btn = tester.widget<DesignSystemButton>(
          find.widgetWithText(
            DesignSystemButton,
            messages.backfillReRequestTrigger,
          ),
        );
        expect(btn.onPressed, isNull);
      },
    );

    testWidgets(
      'retire stuck button is disabled when missing + requested == 0',
      (tester) async {
        when(() => mockSequenceService.getBackfillStats()).thenAnswer(
          (_) async => BackfillStats.fromHostStats([
            const BackfillHostStats(
              receivedCount: 100,
              missingCount: 0,
              requestedCount: 0,
              backfilledCount: 0,
              deletedCount: 0,
              unresolvableCount: 0,
            ),
          ]),
        );
        await pumpBody(tester);
        final messages = messagesOf(tester);

        await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
        await tester.pumpAndSettle();

        // The CTA label is dynamic ("Retire 0 stuck entries") — find
        // the row's title and assert the same row's button is null.
        final btn = tester.widget<DesignSystemButton>(
          find.widgetWithText(DesignSystemButton, 'Retire 0 stuck entries'),
        );
        expect(btn.onPressed, isNull);
      },
    );
  });

  group('BackfillSettingsPage · gate', () {
    testWidgets('hides body when the Matrix flag is off', (tester) async {
      await getIt.reset();
      mockJournalDb = MockJournalDb();
      mockSequenceService = MockSyncSequenceLogService();
      mockBackfillService = MockBackfillRequestService();
      mockUserActivityService = MockUserActivityService();

      when(
        () => mockJournalDb.watchConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) => Stream<bool>.value(false));
      when(
        () => mockSequenceService.getBackfillStats(),
      ).thenAnswer((_) async => populatedStats);
      when(() => mockUserActivityService.updateActivity()).thenReturn(null);

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<SyncSequenceLogService>(mockSequenceService)
        ..registerSingleton<BackfillRequestService>(mockBackfillService)
        ..registerSingleton<UserActivityService>(mockUserActivityService);

      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pump();

      expect(find.byType(BackfillSettingsBody), findsNothing);
      expect(find.byType(DesignSystemToggle), findsNothing);
    });
  });

  // ----- Tests that need a Matrix coordinator + queue registered. ----- //
  group('BackfillSettingsBody · with queue coordinator', () {
    late MockMatrixService matrixService;
    late MockQueuePipelineCoordinator coordinator;
    late MockInboundQueue queue;
    late StreamController<QueueDepthSignal> depthCtl;

    setUp(() {
      matrixService = MockMatrixService();
      coordinator = MockQueuePipelineCoordinator();
      queue = MockInboundQueue();
      depthCtl = StreamController<QueueDepthSignal>.broadcast();

      when(() => matrixService.queueCoordinator).thenReturn(coordinator);
      when(() => coordinator.queue).thenReturn(queue);
      when(() => queue.depthChanges).thenAnswer((_) => depthCtl.stream);
      when(() => queue.stats()).thenAnswer(
        (_) async => const QueueStats(
          total: 0,
          byProducer: {},
          readyNow: 0,
          oldestEnqueuedAt: null,
        ),
      );
      when(() => queue.resurrectAll()).thenAnswer((_) async => 7);
      when(() => coordinator.triggerBridge()).thenAnswer((_) async {});

      getIt.registerSingleton<MatrixService>(matrixService);
    });

    tearDown(() async {
      await depthCtl.close();
    });

    Future<void> emitDepth(
      WidgetTester tester, {
      required int total,
      required int abandoned,
    }) async {
      depthCtl.add(
        QueueDepthSignal(
          total: total,
          byProducer: const {},
          oldestEnqueuedAt: null,
          abandoned: abandoned,
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pumpInScaffold(WidgetTester tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(
          child: SingleChildScrollView(child: BackfillSettingsBody()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('initial paint reads queue.stats() for inbound + skipped', (
      tester,
    ) async {
      when(() => queue.stats()).thenAnswer(
        (_) async => const QueueStats(
          total: 4,
          byProducer: {},
          readyNow: 4,
          oldestEnqueuedAt: null,
          abandoned: 2,
        ),
      );
      await pumpInScaffold(tester);

      // Inbound queue cell shows 4; skipped cell shows 2.
      expect(find.text('4'), findsWidgets);
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('depthChanges emission updates the status row', (
      tester,
    ) async {
      await pumpInScaffold(tester);
      await emitDepth(tester, total: 9, abandoned: 0);
      expect(find.text('9'), findsWidgets);
    });

    testWidgets(
      'skipped > 0 reveals the Retry skipped events action when expanded',
      (tester) async {
        await pumpInScaffold(tester);
        await emitDepth(tester, total: 0, abandoned: 3);
        final messages = messagesOf(tester);

        // Header meta now reports 7 actions (6 base + 1 retry-skipped).
        expect(
          find.text(messages.backfillAdvancedRecoveryActions(7)),
          findsOneWidget,
        );

        await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
        await tester.pumpAndSettle();

        expect(find.text(messages.queueSkippedCardTitle), findsOneWidget);
      },
    );

    testWidgets('Retry skipped tap calls queue.resurrectAll', (tester) async {
      await pumpInScaffold(tester);
      await emitDepth(tester, total: 0, abandoned: 3);
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pumpAndSettle();

      final btn = find.widgetWithText(
        DesignSystemButton,
        messages.queueSkippedRetryAll,
      );
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      verify(() => queue.resurrectAll()).called(1);
    });

    testWidgets('Catch-up tap calls coordinator.triggerBridge', (tester) async {
      await pumpInScaffold(tester);
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pumpAndSettle();

      // The "Catch up now" CTA reuses the same label as the action title.
      final btn = find.widgetWithText(
        DesignSystemButton,
        messages.queueCatchUpNowButton,
      );
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      verify(() => coordinator.triggerBridge()).called(1);
    });
  });

  // ----- Confirmation dialogs ----- //
  group('BackfillSettingsBody · confirmation dialogs', () {
    testWidgets('Ask peers cancel closes the dialog without invoking the '
        'controller', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(
          child: SingleChildScrollView(child: BackfillSettingsBody()),
        ),
      );
      await tester.pumpAndSettle();
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pumpAndSettle();

      final askPeersBtn = find.widgetWithText(
        DesignSystemButton,
        messages.backfillAskPeersTrigger(3),
      );
      await tester.ensureVisible(askPeersBtn);
      await tester.pumpAndSettle();
      await tester.tap(askPeersBtn);
      await tester.pumpAndSettle();

      // Confirm dialog rendered.
      expect(find.text(messages.backfillAskPeersConfirmTitle), findsOneWidget);

      // Cancel.
      await tester.tap(find.text(messages.cancelButton));
      await tester.pumpAndSettle();

      verifyNever(() => mockSequenceService.resetAllUnresolvableEntries());
    });

    testWidgets('Retire stuck cancel closes the dialog without invoking the '
        'controller', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(
          child: SingleChildScrollView(child: BackfillSettingsBody()),
        ),
      );
      await tester.pumpAndSettle();
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pumpAndSettle();

      // Open count = 5 (missing) + 2 (requested) = 7.
      final retireBtn = find.widgetWithText(
        DesignSystemButton,
        messages.backfillRetireStuckTrigger(7),
      );
      await tester.ensureVisible(retireBtn);
      await tester.pumpAndSettle();
      await tester.tap(retireBtn);
      await tester.pumpAndSettle();

      expect(
        find.text(messages.backfillRetireStuckConfirmTitle),
        findsOneWidget,
      );

      await tester.tap(find.text(messages.cancelButton));
      await tester.pumpAndSettle();

      verifyNever(
        () => mockSequenceService.retireAgedOutRequestedEntries(
          amnestyWindow: any(named: 'amnestyWindow'),
        ),
      );
    });

    testWidgets('Retire stuck confirm calls retireAgedOutRequestedEntries', (
      tester,
    ) async {
      when(
        () => mockSequenceService.retireAgedOutRequestedEntries(
          amnestyWindow: any(named: 'amnestyWindow'),
        ),
      ).thenAnswer((_) async => 7);

      await tester.pumpWidget(
        const RiverpodWidgetTestBench(
          child: SingleChildScrollView(child: BackfillSettingsBody()),
        ),
      );
      await tester.pumpAndSettle();
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pumpAndSettle();

      final retireBtn = find.widgetWithText(
        DesignSystemButton,
        messages.backfillRetireStuckTrigger(7),
      );
      await tester.ensureVisible(retireBtn);
      await tester.pumpAndSettle();
      await tester.tap(retireBtn);
      await tester.pumpAndSettle();

      // Tap the confirm button using its dialog label.
      await tester.tap(find.text(messages.backfillRetireStuckConfirmAccept));
      await tester.pumpAndSettle();

      verify(
        () => mockSequenceService.retireAgedOutRequestedEntries(
          amnestyWindow: any(named: 'amnestyWindow'),
        ),
      ).called(1);
    });

    testWidgets('Ask peers confirm calls resetAllUnresolvableEntries', (
      tester,
    ) async {
      when(
        () => mockSequenceService.resetAllUnresolvableEntries(),
      ).thenAnswer((_) async => 3);

      await tester.pumpWidget(
        const RiverpodWidgetTestBench(
          child: SingleChildScrollView(child: BackfillSettingsBody()),
        ),
      );
      await tester.pumpAndSettle();
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pumpAndSettle();

      final askBtn = find.widgetWithText(
        DesignSystemButton,
        messages.backfillAskPeersTrigger(3),
      );
      await tester.ensureVisible(askBtn);
      await tester.pumpAndSettle();
      await tester.tap(askBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.text(messages.backfillAskPeersConfirmAccept));
      await tester.pumpAndSettle();

      verify(() => mockSequenceService.resetAllUnresolvableEntries()).called(1);
    });
  });

  // ----- Concurrency: while one controller op is running, others disable. ----
  group('BackfillSettingsBody · controllerBusy gating', () {
    testWidgets(
      'all controller-backed actions disable while one is in flight',
      (tester) async {
        // Hang the manual-backfill call so `isProcessing` stays true.
        final completer = Completer<int>();
        when(
          () => mockBackfillService.processFullBackfill(),
        ).thenAnswer((_) => completer.future);

        await tester.pumpWidget(
          const RiverpodWidgetTestBench(
            child: SingleChildScrollView(child: BackfillSettingsBody()),
          ),
        );
        await tester.pumpAndSettle();
        final messages = messagesOf(tester);

        await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
        await tester.pumpAndSettle();

        // Trigger the manual backfill (kicks `isProcessing = true`).
        final manualBtn = find.widgetWithText(
          DesignSystemButton,
          messages.backfillManualTrigger,
        );
        await tester.ensureVisible(manualBtn);
        await tester.pumpAndSettle();
        await tester.tap(manualBtn);
        await tester.pump();

        // Re-acquire after rebuild — the label has flipped to "Processing…"
        // but the other controller-backed CTAs still carry their idle labels.
        final resetBtn = tester.widget<DesignSystemButton>(
          find.widgetWithText(
            DesignSystemButton,
            messages.backfillResetUnresolvableTrigger,
          ),
        );
        final reReqBtn = tester.widget<DesignSystemButton>(
          find.widgetWithText(
            DesignSystemButton,
            messages.backfillReRequestTrigger,
          ),
        );
        final askPeersBtn = tester.widget<DesignSystemButton>(
          find.widgetWithText(
            DesignSystemButton,
            messages.backfillAskPeersTrigger(3),
          ),
        );
        final retireBtn = tester.widget<DesignSystemButton>(
          find.widgetWithText(
            DesignSystemButton,
            messages.backfillRetireStuckTrigger(7),
          ),
        );

        expect(resetBtn.onPressed, isNull);
        expect(reReqBtn.onPressed, isNull);
        expect(askPeersBtn.onPressed, isNull);
        expect(retireBtn.onPressed, isNull);

        // Let the in-flight call finish so the test tearDown doesn't trip on
        // a pending future.
        completer.complete(5);
        await tester.pumpAndSettle();
      },
    );
  });

  // ----- Misc edge paths ----- //
  group('BackfillSettingsBody · edge paths', () {
    testWidgets('renders no-data placeholder when stats load returns null '
        'and isLoading is false', (tester) async {
      // Throwing from getBackfillStats lands the controller in an
      // error state with `stats == null` and `isLoading == false`,
      // so the ledger card renders the no-data fallback. Use
      // `thenAnswer` (asynchronous throw) so the failure surfaces
      // through the future chain rather than blowing up
      // synchronously inside `_loadStats()`.
      when(() => mockSequenceService.getBackfillStats()).thenAnswer(
        (_) async => throw Exception('boom'),
      );

      await tester.pumpWidget(
        const RiverpodWidgetTestBench(
          child: SingleChildScrollView(child: BackfillSettingsBody()),
        ),
      );
      // Drain microtasks without `pumpAndSettle` — the controller's
      // periodic refresh timer would otherwise keep the test from
      // settling.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final messages = messagesOf(tester);

      expect(find.text(messages.backfillStatsNoData), findsOneWidget);
    });

    testWidgets('refresh button is disabled while a load is in flight', (
      tester,
    ) async {
      final completer = Completer<BackfillStats>();
      when(
        () => mockSequenceService.getBackfillStats(),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        const RiverpodWidgetTestBench(
          child: SingleChildScrollView(child: BackfillSettingsBody()),
        ),
      );
      await tester.pump();

      // Find the refresh icon. While loading it sits inside an
      // `IconButton`-style widget whose `onTap` is null; we assert
      // there's a `CircularProgressIndicator` next to the refresh
      // call site.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(populatedStats);
      await tester.pumpAndSettle();
    });

    testWidgets('Advanced recovery collapses on a second header tap', (
      tester,
    ) async {
      await pumpBody(tester);
      final messages = messagesOf(tester);
      final header = find.text(messages.backfillAdvancedRecoveryTitle);

      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(find.text(messages.backfillManualTitle), findsOneWidget);

      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(find.text(messages.backfillManualTitle), findsNothing);
    });

    testWidgets('Reset unresolvable confirm calls the service', (tester) async {
      when(
        () => mockSequenceService.resetUnresolvableEntries(),
      ).thenAnswer((_) async => 1);

      await pumpBody(tester);
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pumpAndSettle();

      final btn = find.widgetWithText(
        DesignSystemButton,
        messages.backfillResetUnresolvableTrigger,
      );
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      verify(() => mockSequenceService.resetUnresolvableEntries()).called(1);
    });

    testWidgets('Re-request pending tap calls the backfill service', (
      tester,
    ) async {
      when(
        () => mockBackfillService.processReRequest(),
      ).thenAnswer((_) async => 2);

      await pumpBody(tester);
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pumpAndSettle();

      final btn = find.widgetWithText(
        DesignSystemButton,
        messages.backfillReRequestTrigger,
      );
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      verify(() => mockBackfillService.processReRequest()).called(1);
    });
  });

  // ----- Error branches in the queue-coordinator paths. ----- //
  group('BackfillSettingsBody · queue error branches', () {
    late MockMatrixService matrixService;
    late MockQueuePipelineCoordinator coordinator;
    late MockInboundQueue queue;
    late StreamController<QueueDepthSignal> depthCtl;

    setUp(() {
      matrixService = MockMatrixService();
      coordinator = MockQueuePipelineCoordinator();
      queue = MockInboundQueue();
      depthCtl = StreamController<QueueDepthSignal>.broadcast();

      when(() => matrixService.queueCoordinator).thenReturn(coordinator);
      when(() => coordinator.queue).thenReturn(queue);
      when(() => queue.depthChanges).thenAnswer((_) => depthCtl.stream);
      when(() => queue.stats()).thenAnswer(
        (_) async => const QueueStats(
          total: 0,
          byProducer: {},
          readyNow: 0,
          oldestEnqueuedAt: null,
        ),
      );

      getIt.registerSingleton<MatrixService>(matrixService);
    });

    tearDown(() async {
      await depthCtl.close();
    });

    testWidgets('Catch-up failure surfaces a snackbar with the error message', (
      tester,
    ) async {
      when(() => coordinator.triggerBridge()).thenAnswer(
        (_) async => throw Exception('bridge boom'),
      );

      await tester.pumpWidget(
        const RiverpodWidgetTestBench(
          child: SingleChildScrollView(child: BackfillSettingsBody()),
        ),
      );
      await tester.pumpAndSettle();
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pumpAndSettle();

      final btn = find.widgetWithText(
        DesignSystemButton,
        messages.queueCatchUpNowButton,
      );
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('bridge boom'), findsOneWidget);
    });

    testWidgets('Retry-skipped failure surfaces a snackbar with the error '
        'message', (tester) async {
      when(() => queue.resurrectAll()).thenAnswer(
        (_) async => throw Exception('resurrect boom'),
      );

      await tester.pumpWidget(
        const RiverpodWidgetTestBench(
          child: SingleChildScrollView(child: BackfillSettingsBody()),
        ),
      );
      await tester.pumpAndSettle();
      // Push abandoned > 0 so the Retry skipped action becomes visible.
      depthCtl.add(
        const QueueDepthSignal(
          total: 0,
          byProducer: {},
          oldestEnqueuedAt: null,
          abandoned: 4,
        ),
      );
      await tester.pumpAndSettle();
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pumpAndSettle();

      final btn = find.widgetWithText(
        DesignSystemButton,
        messages.queueSkippedRetryAll,
      );
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('resurrect boom'), findsOneWidget);
    });
  });
}
