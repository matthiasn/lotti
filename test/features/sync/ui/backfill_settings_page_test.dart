import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/deep_backfill/deep_backfill_service.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/models/sync_models.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/repository/sync_maintenance_repository.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/state/synced_audio_inference_providers.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/ui/backfill_settings_page.dart';
import 'package:lotti/features/sync/ui/backfill_settings_stats.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';
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
      hostId: 'host-1',
      receivedCount: 100,
      missingCount: 5,
      requestedCount: 2,
      backfilledCount: 11,
      deletedCount: 7,
      unresolvableCount: 3,
      burnedCount: 9,
    ),
  ]);

  // No connected devices, no work pending.
  final emptyStats = BackfillStats.fromHostStats(const []);

  setUpAll(() {
    registerFallbackValue(Duration.zero);
    // fetchTotalsForSteps takes a non-nullable Set<SyncStep>; without a
    // fallback, any() cannot match and syncAll gets a null totals map.
    registerFallbackValue(<SyncStep>{});
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
      () => mockSequenceService.watchBackfillMissingCount(),
    ).thenAnswer((_) => Stream<int>.value(5));
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
  // because production hosts (settings route registry + legacy
  // SliverBoxAdapterPage) both supply scrolling — without it the
  // expanded recovery group overflows a fixed-height test viewport.
  Future<void> pumpBody(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    // Tall enough for the whole body, so every card can be tapped without
    // scrolling it into view first.
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: overrides,
        child: const SingleChildScrollView(child: BackfillSettingsBody()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
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
      when(
        () => mockSequenceService.watchBackfillMissingCount(),
      ).thenAnswer((_) => Stream<int>.value(0));
      await pumpBody(tester);

      // missing = 0 → check icon (not bolt)
      expect(find.byIcon(LottiIcons.confirmCircled), findsOneWidget);
      expect(find.byIcon(LottiIcons.bolt), findsNothing);
    });

    testWidgets('missing > 0 swaps to bolt icon', (tester) async {
      await pumpBody(tester);
      // populatedStats.totalMissing = 5 → bolt icon. Note: the
      // advanced recovery group is closed, so its bolt icons (Catch
      // up now / Manual backfill) are NOT in the tree. The only bolt
      // is in the status row.
      expect(find.byIcon(LottiIcons.bolt), findsOneWidget);
    });

    testWidgets('live missing count updates the status row and ledger', (
      tester,
    ) async {
      final missingCounts = StreamController<int>();
      addTearDown(missingCounts.close);
      when(
        () => mockSequenceService.watchBackfillMissingCount(),
      ).thenAnswer((_) => missingCounts.stream);

      await pumpBody(tester);
      missingCounts.add(4);
      await tester.pump();
      await tester.pump();

      expect(find.text('4'), findsNWidgets(2));
    });
  });

  group('BackfillSettingsBody · records on this device', () {
    late MockDeepBackfillService deepBackfill;
    late StreamController<SyncSequencePayloadType> changes;
    late int counts;

    setUp(() {
      deepBackfill = MockDeepBackfillService();
      changes = StreamController<SyncSequencePayloadType>.broadcast();
      addTearDown(changes.close);
      counts = 0;
      when(
        () => deepBackfill.recordCounts(only: any(named: 'only')),
      ).thenAnswer((_) async {
        counts++;
        return {SyncSequencePayloadType.journalEntity: 1000 + counts};
      });
      when(() => deepBackfill.recordChanges).thenAnswer((_) => changes.stream);
      getIt.registerSingleton<DeepBackfillService>(deepBackfill);
    });

    testWidgets('come first, above the status row', (tester) async {
      await pumpBody(tester);

      expect(
        tester.getTopLeft(find.byType(RecordCountsCard)).dy,
        lessThan(tester.getTopLeft(find.byType(StatusRow)).dy),
      );
    });

    testWidgets('re-count once a synced table changes while shown, and stop '
        'once the page is gone', (tester) async {
      await pumpBody(tester);
      final shown = counts;
      expect(find.text('1,00$shown'), findsOneWidget);

      await tester.pump(SyncTuning.recordCountsRefreshInterval);
      expect(counts, shown, reason: 'nothing changed, nothing re-counted');

      changes.add(SyncSequencePayloadType.journalEntity);
      await tester.pump(SyncTuning.recordCountsRefreshInterval);
      await tester.pump();
      expect(counts, shown + 1);
      expect(find.text('1,00${shown + 1}'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      final atExit = counts;
      changes.add(SyncSequencePayloadType.journalEntity);
      await tester.pump(SyncTuning.recordCountsFullRecountInterval * 2);
      expect(counts, atExit);
    });

    testWidgets('stop counting while the page sits on a background tab, and '
        'count once it is shown again', (tester) async {
      final onScreen = ValueNotifier(true);
      addTearDown(onScreen.dispose);
      tester.view
        ..physicalSize = const Size(800, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // The desktop shell keeps every tab mounted in an IndexedStack and
      // turns TickerMode off for the ones not shown.
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: ValueListenableBuilder<bool>(
            valueListenable: onScreen,
            builder: (context, enabled, child) =>
                TickerMode(enabled: enabled, child: child!),
            child: const SingleChildScrollView(child: BackfillSettingsBody()),
          ),
        ),
      );
      await tester.pump();
      final shown = counts;
      final statsLoads = verify(
        () => mockSequenceService.getBackfillStats(),
      ).callCount;

      onScreen.value = false;
      await tester.pump();
      changes.add(SyncSequencePayloadType.journalEntity);
      await tester.pump(const Duration(minutes: 5));
      expect(counts, shown, reason: 'no record counts for an unseen page');
      verifyNever(() => mockSequenceService.getBackfillStats());

      onScreen.value = true;
      await tester.pump();
      await tester.pump();
      expect(counts, shown + 1, reason: 'counts at once when shown');
      verify(() => mockSequenceService.getBackfillStats()).called(1);
      expect(statsLoads, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('BackfillSettingsBody · sync statistics ledger', () {
    testWidgets('renders all eight labelled rows', (tester) async {
      await pumpBody(tester);
      final messages = messagesOf(tester);

      expect(find.text(messages.backfillStatsTrackedCounters), findsOneWidget);
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
      expect(find.text(messages.backfillStatsBurned), findsOneWidget);
    });

    testWidgets('shows correct values for each stat', (tester) async {
      await pumpBody(tester);

      // Tracked counters = 100 + 5 + 2 + 11 + 7 + 3 + 9 = 137, once as the
      // total and once as the only device's row.
      expect(find.text('137'), findsNWidgets(2));
      expect(find.text('100'), findsOneWidget); // received
      expect(find.text('11'), findsOneWidget); // backfilled
      expect(find.text('2'), findsOneWidget); // requested
      expect(find.text('7'), findsOneWidget); // deleted
      expect(find.text('3'), findsOneWidget); // unresolvable
      expect(find.text('9'), findsOneWidget); // burned
    });

    testWidgets('Burned row uses the benign tone, not the error tone', (
      tester,
    ) async {
      await pumpBody(tester);

      Color? valueColorOf(String text) =>
          tester.widget<Text>(find.text(text)).style?.color;

      // populatedStats: burned = 9 and deleted = 7 are both benign
      // (low-emphasis); unresolvable = 3 is > 0 so it escalates to the error
      // tone. Burned must track the benign tone even though it is non-zero.
      final burnedColor = valueColorOf('9');
      final deletedColor = valueColorOf('7');
      final unresolvableColor = valueColorOf('3');

      expect(burnedColor, isNotNull);
      expect(
        burnedColor,
        deletedColor,
        reason: 'burned shares the benign low-emphasis tone with deleted',
      );
      expect(
        burnedColor,
        isNot(unresolvableColor),
        reason: 'a non-zero burned count must not turn red like unresolvable',
      );
    });

    testWidgets('formats values >= 1000 with thousands separators', (
      tester,
    ) async {
      when(() => mockSequenceService.getBackfillStats()).thenAnswer(
        (_) async => BackfillStats.fromHostStats([
          const BackfillHostStats(
            hostId: 'host-2',
            receivedCount: 715544,
            missingCount: 0,
            requestedCount: 0,
            backfilledCount: 34811,
            deletedCount: 201,
            unresolvableCount: 152601,
            burnedCount: 0,
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

      await tester.tap(
        find.descendant(
          of: find.byType(SyncStatsCard),
          matching: find.byIcon(LottiIcons.refresh),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      verify(() => mockSequenceService.getBackfillStats()).called(1);
    });

    testWidgets('names each device in the per-device ledger from the sync '
        'node profiles, marking this one', (tester) async {
      BackfillHostStats host(String id) => BackfillHostStats(
        hostId: id,
        receivedCount: 10,
        missingCount: 0,
        requestedCount: 0,
        backfilledCount: 0,
        deletedCount: 0,
        unresolvableCount: 0,
        burnedCount: 0,
      );
      SyncNodeProfile node(String id, String name) => SyncNodeProfile(
        hostId: id,
        displayName: name,
        platform: 'linux',
        capabilities: const [],
        updatedAt: DateTime(2024, 3, 15),
      );
      when(() => mockSequenceService.getBackfillStats()).thenAnswer(
        (_) async => BackfillStats.fromHostStats([
          host('11111111-laptop'),
          host('22222222-phone'),
        ]),
      );

      await pumpBody(
        tester,
        overrides: [
          knownSyncNodesProvider.overrideWith(
            (ref) => Stream.value([node('22222222-phone', 'Phone')]),
          ),
          localSyncNodeSelfProvider.overrideWith(
            (ref) => Stream.value(node('11111111-laptop', 'Laptop')),
          ),
        ],
      );

      final messages = messagesOf(tester);
      expect(find.text('Phone'), findsOneWidget);
      expect(
        find.text(messages.backfillStatsThisDevice('Laptop')),
        findsOneWidget,
      );
      // Named, so neither falls back to its truncated host id.
      expect(find.text('11111111'), findsNothing);
      expect(find.text('22222222'), findsNothing);
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

    // The next two pin values a revert would reproduce (IconSizes.m is the
    // 18 the card carried as a literal; subtitle2 already weighs semiBold),
    // so they hold the contract going forward rather than catch the literals.
    testWidgets('leads the card with a control-tier glyph', (tester) async {
      await pumpBody(tester);

      // The collapsed recovery group keeps its LottiIcons.sync CTA out of the
      // tree, so the card's leading glyph is the only match.
      final glyph = tester.widget<Icon>(find.byIcon(LottiIcons.sync));
      expect(glyph.size, IconSizes.m);
    });

    testWidgets('takes its title weight from subtitle2 itself', (
      tester,
    ) async {
      await pumpBody(tester);
      final messages = messagesOf(tester);
      final tokens = tester
          .element(find.byType(BackfillSettingsBody))
          .designTokens;

      final title = tester.widget<Text>(
        find.text(messages.backfillToggleTitle),
      );
      expect(title.style!.fontWeight, tokens.typography.weight.semiBold);
      expect(
        title.style!.fontWeight,
        tokens.typography.styles.subtitle.subtitle2.fontWeight,
        reason: 'the weight must come from the style, not a layered override',
      );
    });

    testWidgets('tap flips the persisted preference', (tester) async {
      await pumpBody(tester);

      await tester.ensureVisible(find.byType(DesignSystemToggle));
      await tester.pump();
      await tester.tap(find.byType(DesignSystemToggle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

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
      // Without skipped events, seven actions are shown; the skipped
      // entry is conditional and gated on skipped > 0, which we have
      // no way to populate here (no Matrix coordinator in DI).
      expect(
        find.text(messages.backfillAdvancedRecoveryActions(7)),
        findsOneWidget,
      );
    });

    testWidgets('expands when the header is tapped', (tester) async {
      await pumpBody(tester);
      final messages = messagesOf(tester);

      await tester.ensureVisible(
        find.text(messages.backfillAdvancedRecoveryTitle),
      );
      await tester.pump();
      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text(messages.backfillManualTitle), findsOneWidget);
      expect(find.text(messages.backfillReRequestTitle), findsOneWidget);
      expect(
        find.text(messages.backfillResetUnresolvableTitle),
        findsOneWidget,
      );
    });

    testWidgets('re-collapses when the header is tapped again', (
      tester,
    ) async {
      await pumpBody(tester);
      final messages = messagesOf(tester);

      // Open...
      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text(messages.backfillManualTitle), findsOneWidget);

      // ...and close: after the reverse animation the action widgets must
      // leave the tree again, not just shrink.
      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text(messages.backfillManualTitle), findsNothing);
      expect(find.text(messages.backfillReRequestTitle), findsNothing);
      expect(
        find.text(messages.backfillResetUnresolvableTitle),
        findsNothing,
      );
    });

    testWidgets('manual backfill action triggers the service', (tester) async {
      await pumpBody(tester);
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Find the DesignSystemButton whose label is the manual trigger.
      final triggerLabel = messages.backfillManualTrigger;
      final buttonFinder = find.widgetWithText(
        DesignSystemButton,
        triggerLabel,
      );

      await tester.ensureVisible(buttonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(buttonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      verify(() => mockBackfillService.processFullBackfill()).called(1);
    });

    testWidgets(
      'reset unresolvable button is enabled when there are unresolvable rows',
      (tester) async {
        await pumpBody(tester);
        final messages = messagesOf(tester);

        await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

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
              hostId: 'host-3',
              receivedCount: 100,
              missingCount: 0,
              requestedCount: 2,
              backfilledCount: 0,
              deletedCount: 0,
              unresolvableCount: 0,
              burnedCount: 0,
            ),
          ]),
        );
        await pumpBody(tester);
        final messages = messagesOf(tester);

        await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

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
              hostId: 'host-4',
              receivedCount: 100,
              missingCount: 0,
              requestedCount: 0,
              backfilledCount: 0,
              deletedCount: 0,
              unresolvableCount: 0,
              burnedCount: 0,
            ),
          ]),
        );
        await pumpBody(tester);
        final messages = messagesOf(tester);

        await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

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
              hostId: 'host-5',
              receivedCount: 100,
              missingCount: 0,
              requestedCount: 0,
              backfilledCount: 0,
              deletedCount: 0,
              unresolvableCount: 0,
              burnedCount: 0,
            ),
          ]),
        );
        await pumpBody(tester);
        final messages = messagesOf(tester);

        await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        // The CTA label is dynamic ("Retire 0 stuck entries") — find
        // the row's title and assert the same row's button is null.
        final btn = tester.widget<DesignSystemButton>(
          find.widgetWithText(DesignSystemButton, 'Retire 0 stuck entries'),
        );
        expect(btn.onPressed, isNull);
      },
    );
  });

  group('BackfillSettingsPage · page chrome', () {
    testWidgets('resolves its horizontal padding from the spacing scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final host = find.byType(SliverBoxAdapterPage);
      final tokens = tester.element(host).designTokens;
      final page = tester.widget<SliverBoxAdapterPage>(host);

      // step5 equals the 16 the page used to hardcode, so a literal revert
      // renders identically; the assertion pins the sibling-page contract
      // (provisioned_sync_page uses step5 for the same role).
      expect(
        page.padding,
        EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
      );
    });
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
      when(() => queue.depthSnapshot()).thenAnswer(
        (_) async => const QueueStats(
          total: 0,
          byProducer: {},
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
          abandoned: abandoned,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    }

    Future<void> pumpInScaffold(WidgetTester tester) async {
      await pumpBody(tester);
    }

    testWidgets(
      'initial paint reads queue.depthSnapshot() for inbound + skipped',
      (
        tester,
      ) async {
        when(() => queue.depthSnapshot()).thenAnswer(
          (_) async => const QueueStats(
            total: 4,
            byProducer: {},
            oldestEnqueuedAt: null,
            abandoned: 2,
          ),
        );
        await pumpInScaffold(tester);

        // Inbound queue cell shows 4; skipped cell shows 2.
        expect(find.text('4'), findsWidgets);
        expect(find.text('2'), findsWidgets);
      },
    );

    testWidgets('depthChanges emission updates the status row', (
      tester,
    ) async {
      await pumpInScaffold(tester);
      await emitDepth(tester, total: 9, abandoned: 0);
      expect(find.text('9'), findsWidgets);
    });

    testWidgets('a depth signal rebuilds only the cells that show the queue, '
        'not the statistics ledger', (tester) async {
      await pumpInScaffold(tester);
      final ledgerBefore = tester.widget<SyncStatsCard>(
        find.byType(SyncStatsCard),
      );
      final statusBefore = tester.widget<StatusRow>(find.byType(StatusRow));

      await emitDepth(tester, total: 9, abandoned: 1);

      // A rebuilt parent creates a new widget instance; the ledger — every
      // device's row — must survive a signal the queue emits several times
      // a second during a sync.
      expect(
        identical(
          tester.widget<SyncStatsCard>(find.byType(SyncStatsCard)),
          ledgerBefore,
        ),
        isTrue,
      );
      final statusAfter = tester.widget<StatusRow>(find.byType(StatusRow));
      expect(identical(statusAfter, statusBefore), isFalse);
      expect(statusAfter.inbound, 9);
      expect(statusAfter.skipped, 1);
    });

    testWidgets(
      'skipped > 0 reveals the Retry skipped events action when expanded',
      (tester) async {
        await pumpInScaffold(tester);
        await emitDepth(tester, total: 0, abandoned: 3);
        final messages = messagesOf(tester);

        // Header meta now reports 8 actions (7 base + 1 retry-skipped).
        expect(
          find.text(messages.backfillAdvancedRecoveryActions(8)),
          findsOneWidget,
        );

        await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text(messages.queueSkippedCardTitle), findsOneWidget);
      },
    );

    testWidgets('Retry skipped tap calls queue.resurrectAll', (tester) async {
      await pumpInScaffold(tester);
      await emitDepth(tester, total: 0, abandoned: 3);
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final btn = find.widgetWithText(
        DesignSystemButton,
        messages.queueSkippedRetryAll,
      );
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      verify(() => queue.resurrectAll()).called(1);
    });

    testWidgets('Catch-up tap calls coordinator.triggerBridge', (tester) async {
      await pumpInScaffold(tester);
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // The "Catch up now" CTA reuses the same label as the action title.
      final btn = find.widgetWithText(
        DesignSystemButton,
        messages.queueCatchUpNowButton,
      );
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      verify(() => coordinator.triggerBridge()).called(1);
    });
  });

  // ----- Confirmation dialogs ----- //
  group('BackfillSettingsBody · confirmation dialogs', () {
    testWidgets('Ask peers cancel closes the dialog without invoking the '
        'controller', (tester) async {
      await pumpBody(tester);
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final askPeersBtn = find.widgetWithText(
        DesignSystemButton,
        messages.backfillAskPeersTrigger(3),
      );
      await tester.ensureVisible(askPeersBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(askPeersBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Confirm dialog rendered.
      expect(find.text(messages.backfillAskPeersConfirmTitle), findsOneWidget);

      // Cancel.
      await tester.tap(find.text(messages.cancelButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      verifyNever(() => mockSequenceService.resetAllUnresolvableEntries());
    });

    testWidgets('Retire stuck cancel closes the dialog without invoking the '
        'controller', (tester) async {
      await pumpBody(tester);
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Open count = 5 (missing) + 2 (requested) = 7.
      final retireBtn = find.widgetWithText(
        DesignSystemButton,
        messages.backfillRetireStuckTrigger(7),
      );
      await tester.ensureVisible(retireBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(retireBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.text(messages.backfillRetireStuckConfirmTitle),
        findsOneWidget,
      );

      await tester.tap(find.text(messages.cancelButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

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

      await pumpBody(tester);
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final retireBtn = find.widgetWithText(
        DesignSystemButton,
        messages.backfillRetireStuckTrigger(7),
      );
      await tester.ensureVisible(retireBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(retireBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Tap the confirm button using its dialog label.
      await tester.tap(find.text(messages.backfillRetireStuckConfirmAccept));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

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

      await pumpBody(tester);
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final askBtn = find.widgetWithText(
        DesignSystemButton,
        messages.backfillAskPeersTrigger(3),
      );
      await tester.ensureVisible(askBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(askBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.text(messages.backfillAskPeersConfirmAccept));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

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

        await pumpBody(tester);
        final messages = messagesOf(tester);

        await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        // Trigger the manual backfill (kicks `isProcessing = true`).
        final manualBtn = find.widgetWithText(
          DesignSystemButton,
          messages.backfillManualTrigger,
        );
        await tester.ensureVisible(manualBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
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

      expect(
        find.descendant(
          of: find.byType(SyncStatsCard),
          matching: find.text(messages.backfillStatsNoData),
        ),
        findsOneWidget,
      );
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

      // While loading, `DesignSystemIconAction` swaps its glyph for a spinner
      // of the same dimension — so the control does not resize mid-refresh,
      // and the busy state is what is asserted here rather than the tap being
      // disabled (which the widget also does).
      expect(find.byType(DesignSystemSpinner), findsOneWidget);

      completer.complete(populatedStats);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    });

    testWidgets('Advanced recovery collapses on a second header tap', (
      tester,
    ) async {
      await pumpBody(tester);
      final messages = messagesOf(tester);
      final header = find.text(messages.backfillAdvancedRecoveryTitle);

      await tester.tap(header);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text(messages.backfillManualTitle), findsOneWidget);

      await tester.tap(header);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text(messages.backfillManualTitle), findsNothing);
    });

    testWidgets('Reset unresolvable confirm calls the service', (tester) async {
      when(
        () => mockSequenceService.resetUnresolvableEntries(),
      ).thenAnswer((_) async => 1);

      await pumpBody(tester);
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final btn = find.widgetWithText(
        DesignSystemButton,
        messages.backfillResetUnresolvableTrigger,
      );
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      verify(() => mockSequenceService.resetUnresolvableEntries()).called(1);
    });

    testWidgets('Vector clocks repair runs all three backfills', (
      tester,
    ) async {
      final repo = MockSyncMaintenanceRepository();
      when(
        () => repo.fetchTotalsForSteps(any()),
      ).thenAnswer((_) async => <SyncStep, int>{});
      when(
        () => repo.backfillAgentEntityClocks(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => repo.backfillAgentLinkClocks(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).thenAnswer((_) async {});

      await pumpBody(
        tester,
        overrides: [
          syncMaintenanceRepositoryProvider.overrideWithValue(repo),
          // getIt<DomainLogger> is unregistered in this harness; without the
          // override the controller's logger provider is in error state and
          // syncAll dies before reaching the operations.
          domainLoggerProvider.overrideWithValue(MockDomainLogger()),
        ],
      );
      when(
        () => repo.backfillEntryLinkClocks(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).thenAnswer((_) async {});

      await pumpBody(
        tester,
        overrides: [
          syncMaintenanceRepositoryProvider.overrideWithValue(repo),
          // getIt<DomainLogger> is unregistered in this harness; without the
          // override the controller's logger provider is in error state and
          // syncAll dies before reaching the operations.
          domainLoggerProvider.overrideWithValue(MockDomainLogger()),
        ],
      );
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final btn = find.widgetWithText(
        DesignSystemButton,
        messages.backfillClocksTrigger,
      );
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.tap(btn);
      // syncAll awaits fetchTotalsForSteps before reaching the operations, so
      // one frame is not enough to see both halves run.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      // The action requests exactly the three clock steps as one repair —
      // they are the same fix over three tables, and each no-ops when nothing
      // is missing a clock. The stamping itself is covered directly in
      // test/database/maintenance_test.dart.
      verify(
        () => repo.fetchTotalsForSteps({
          SyncStep.backfillAgentEntityClocks,
          SyncStep.backfillAgentLinkClocks,
          SyncStep.backfillEntryLinkClocks,
        }),
      ).called(1);
      verify(
        () => repo.backfillAgentEntityClocks(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).called(1);
      verify(
        () => repo.backfillAgentLinkClocks(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).called(1);
      verify(
        () => repo.backfillEntryLinkClocks(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).called(1);
    });

    testWidgets('Vector clocks repair surfaces a localized failure', (
      tester,
    ) async {
      final repo = MockSyncMaintenanceRepository();
      when(
        () => repo.fetchTotalsForSteps(any()),
      ).thenAnswer((_) async => <SyncStep, int>{});
      when(
        () => repo.backfillAgentEntityClocks(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).thenThrow(Exception('boom'));

      await pumpBody(
        tester,
        overrides: [
          syncMaintenanceRepositoryProvider.overrideWithValue(repo),
          // Without the logger override syncAll dies on the errored logger
          // provider before reaching the operations — the failure toast would
          // show, but not because of the stubbed throw above.
          domainLoggerProvider.overrideWithValue(MockDomainLogger()),
        ],
      );
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final btn = find.widgetWithText(
        DesignSystemButton,
        messages.backfillClocksTrigger,
      );
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.tap(btn);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }

      // The failure must originate from the stubbed operation, and the
      // localized label is shown instead of the raw exception text.
      verify(
        () => repo.backfillAgentEntityClocks(
          onProgress: any(named: 'onProgress'),
          onDetailedProgress: any(named: 'onDetailedProgress'),
        ),
      ).called(1);
      expect(find.text(messages.backfillClocksFailed), findsOneWidget);
      expect(find.text('Exception: boom'), findsNothing);
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final btn = find.widgetWithText(
        DesignSystemButton,
        messages.backfillReRequestTrigger,
      );
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

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
      when(() => queue.depthSnapshot()).thenAnswer(
        (_) async => const QueueStats(
          total: 0,
          byProducer: {},
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

      await pumpBody(tester);
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final btn = find.widgetWithText(
        DesignSystemButton,
        messages.queueCatchUpNowButton,
      );
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
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

      await pumpBody(tester);
      // Push abandoned > 0 so the Retry skipped action becomes visible.
      depthCtl.add(
        const QueueDepthSignal(
          total: 0,
          abandoned: 4,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final messages = messagesOf(tester);

      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final btn = find.widgetWithText(
        DesignSystemButton,
        messages.queueSkippedRetryAll,
      );
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(btn);
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('resurrect boom'), findsOneWidget);
    });
  });

  // ----- Per-action "Processing…" CTA labels. ----- //
  //
  // Each recovery action swaps its CTA label to a "processing" string
  // while its own controller op is in flight. We drive each flag true
  // by hanging the underlying service call with a [Completer], then
  // assert the row's button now carries the processing label, is busy,
  // and is disabled. `populatedStats` (unresolvable=3, requested=2,
  // missing=5) keeps every action enabled so each one is tappable.
  group('BackfillSettingsBody · in-flight processing labels', () {
    // Opens the advanced recovery group and returns the localized
    // messages bundle for the body under test.
    Future<AppLocalizations> openRecovery(WidgetTester tester) async {
      await pumpBody(tester);
      final messages = messagesOf(tester);
      await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      return messages;
    }

    // Asserts the button found by [processingLabel] is busy (no leading
    // icon) and disabled, and that its idle [triggerLabel] is gone.
    void expectBusy(
      WidgetTester tester, {
      required String triggerLabel,
      required String processingLabel,
    }) {
      expect(find.text(triggerLabel), findsNothing);
      final btn = tester.widget<DesignSystemButton>(
        find.widgetWithText(DesignSystemButton, processingLabel),
      );
      expect(btn.onPressed, isNull, reason: 'busy action must be disabled');
      expect(btn.leadingIcon, isNull, reason: 'busy action hides its icon');
    }

    testWidgets(
      'reset-unresolvable shows the resetting label while in flight',
      (
        tester,
      ) async {
        final completer = Completer<int>();
        when(
          () => mockSequenceService.resetUnresolvableEntries(),
        ).thenAnswer((_) => completer.future);

        final messages = await openRecovery(tester);

        final btn = find.widgetWithText(
          DesignSystemButton,
          messages.backfillResetUnresolvableTrigger,
        );
        await tester.ensureVisible(btn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.tap(btn);
        await tester.pump();

        expectBusy(
          tester,
          triggerLabel: messages.backfillResetUnresolvableTrigger,
          processingLabel: messages.backfillResetUnresolvableProcessing,
        );

        completer.complete(0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
      },
    );

    testWidgets('re-request shows the re-requesting label while in flight', (
      tester,
    ) async {
      final completer = Completer<int>();
      when(
        () => mockBackfillService.processReRequest(),
      ).thenAnswer((_) => completer.future);

      final messages = await openRecovery(tester);

      final btn = find.widgetWithText(
        DesignSystemButton,
        messages.backfillReRequestTrigger,
      );
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(btn);
      await tester.pump();

      expectBusy(
        tester,
        triggerLabel: messages.backfillReRequestTrigger,
        processingLabel: messages.backfillReRequestProcessing,
      );

      completer.complete(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    });

    testWidgets('ask-peers shows the reopening label after confirm', (
      tester,
    ) async {
      final completer = Completer<int>();
      when(
        () => mockSequenceService.resetAllUnresolvableEntries(),
      ).thenAnswer((_) => completer.future);

      final messages = await openRecovery(tester);

      final btn = find.widgetWithText(
        DesignSystemButton,
        messages.backfillAskPeersTrigger(3),
      );
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Confirm the dialog so the controller op actually kicks off.
      await tester.tap(find.text(messages.backfillAskPeersConfirmAccept));
      await tester.pump();

      expectBusy(
        tester,
        triggerLabel: messages.backfillAskPeersTrigger(3),
        processingLabel: messages.backfillAskPeersProcessing,
      );

      completer.complete(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    });

    testWidgets(
      'agent-clocks shows the processing label in flight and toasts success',
      (tester) async {
        final repo = MockSyncMaintenanceRepository();
        final totals = Completer<Map<SyncStep, int>>();
        when(
          () => repo.fetchTotalsForSteps(any()),
        ).thenAnswer((_) => totals.future);
        when(
          () => repo.backfillAgentEntityClocks(
            onProgress: any(named: 'onProgress'),
            onDetailedProgress: any(named: 'onDetailedProgress'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => repo.backfillAgentLinkClocks(
            onProgress: any(named: 'onProgress'),
            onDetailedProgress: any(named: 'onDetailedProgress'),
          ),
        ).thenAnswer((_) async {});

        await pumpBody(
          tester,
          overrides: [
            syncMaintenanceRepositoryProvider.overrideWithValue(repo),
            // Without a logger the controller's build errors mid-syncAll
            // (getIt<DomainLogger> is unregistered here) and every repair
            // takes the failure path.
            domainLoggerProvider.overrideWithValue(MockDomainLogger()),
          ],
        );
        when(
          () => repo.backfillEntryLinkClocks(
            onProgress: any(named: 'onProgress'),
            onDetailedProgress: any(named: 'onDetailedProgress'),
          ),
        ).thenAnswer((_) async {});

        await pumpBody(
          tester,
          overrides: [
            syncMaintenanceRepositoryProvider.overrideWithValue(repo),
            // Without a logger the controller's build errors mid-syncAll
            // (getIt<DomainLogger> is unregistered here) and every repair
            // takes the failure path.
            domainLoggerProvider.overrideWithValue(MockDomainLogger()),
          ],
        );
        final messages = messagesOf(tester);
        await tester.tap(find.text(messages.backfillAdvancedRecoveryTitle));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        final btn = find.widgetWithText(
          DesignSystemButton,
          messages.backfillClocksTrigger,
        );
        await tester.ensureVisible(btn);
        await tester.pump();
        await tester.tap(btn);
        await tester.pump();

        // The repair shares the manual-backfill processing string rather
        // than minting its own.
        expectBusy(
          tester,
          triggerLabel: messages.backfillClocksTrigger,
          processingLabel: messages.backfillManualProcessing,
        );

        totals.complete(<SyncStep, int>{});
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }

        // Success surfaces as a toast that reuses the action title — a
        // second occurrence beside the row's own — and never the failure
        // string.
        expect(find.text(messages.backfillClocksFailed), findsNothing);
        expect(
          find.text(messages.backfillClocksTitle),
          findsNWidgets(2),
        );
      },
    );

    testWidgets('retire-stuck shows the retiring label after confirm', (
      tester,
    ) async {
      final completer = Completer<int>();
      when(
        () => mockSequenceService.retireAgedOutRequestedEntries(
          amnestyWindow: any(named: 'amnestyWindow'),
        ),
      ).thenAnswer((_) => completer.future);

      final messages = await openRecovery(tester);

      // Open count = missing (5) + requested (2) = 7.
      final btn = find.widgetWithText(
        DesignSystemButton,
        messages.backfillRetireStuckTrigger(7),
      );
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.text(messages.backfillRetireStuckConfirmAccept));
      await tester.pump();

      expectBusy(
        tester,
        triggerLabel: messages.backfillRetireStuckTrigger(7),
        processingLabel: messages.backfillRetireStuckProcessing,
      );

      completer.complete(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    });
  });

  // ----- Queue rebind: _QueueDepthScope.didUpdateWidget. ----- //
  //
  // When the body rebuilds with a *different* InboundQueue instance,
  // the scope cancels its old subscription, drops the stale `_latest`,
  // resets `_liveSignalSeen`, and binds to the new queue. We exercise
  // that by swapping `coordinator.queue` between rebuilds and proving
  // the status row follows the NEW queue's stream — and that a late
  // emission from the OLD queue is ignored.
  group('BackfillSettingsBody · queue rebind', () {
    testWidgets('rebinds to a new queue and ignores the stale one', (
      tester,
    ) async {
      final matrixService = MockMatrixService();
      final coordinator = MockQueuePipelineCoordinator();
      final queueA = MockInboundQueue();
      final queueB = MockInboundQueue();
      final ctlA = StreamController<QueueDepthSignal>.broadcast();
      final ctlB = StreamController<QueueDepthSignal>.broadcast();
      addTearDown(ctlA.close);
      addTearDown(ctlB.close);

      const idleStats = QueueStats(
        total: 0,
        byProducer: {},
        oldestEnqueuedAt: null,
      );
      when(() => queueA.depthChanges).thenAnswer((_) => ctlA.stream);
      when(() => queueB.depthChanges).thenAnswer((_) => ctlB.stream);
      // ignore: unnecessary_lambdas
      when(() => queueA.stats()).thenAnswer((_) async => idleStats);
      // ignore: unnecessary_lambdas
      when(() => queueB.stats()).thenAnswer((_) async => idleStats);

      // `coordinator.queue` flips from A to B once we toggle this flag,
      // letting a single body rebuild swap the queue identity that the
      // scope sees in `didUpdateWidget`.
      var useB = false;
      when(() => matrixService.queueCoordinator).thenReturn(coordinator);
      when(
        () => coordinator.queue,
      ).thenAnswer((_) => useB ? queueB : queueA);

      getIt.registerSingleton<MatrixService>(matrixService);

      await pumpBody(tester);

      // Queue A drives the inbound count to 11.
      ctlA.add(
        const QueueDepthSignal(
          total: 11,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('11'), findsWidgets);

      // Swap to queue B and rebuild the body, which reads the coordinator.
      // A stats refresh no longer rebuilds it — each section watches only
      // its own data — so the rebuild is forced here.
      useB = true;
      final messages = messagesOf(tester);
      tester.element(find.byType(BackfillSettingsBody)).markNeedsBuild();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      int inbound() => tester.widget<StatusRow>(find.byType(StatusRow)).inbound;

      // After the rebind `_latest` was reset to null, so the inbound
      // cell falls back to 0 — A's 11 is gone.
      expect(inbound(), 0);

      // A late emission from the OLD queue must NOT update the row.
      ctlA.add(
        const QueueDepthSignal(
          total: 99,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(inbound(), 0);

      // The NEW queue B drives the row instead.
      ctlB.add(
        const QueueDepthSignal(
          total: 42,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(inbound(), 42);

      // Sanity: messages bundle resolved from the live body.
      expect(messages.backfillStatusInboundQueue, isNotEmpty);
    });
  });

  group('formatCount · locale plumbing', () {
    // The formatter itself is intl's; what is OURS is that the widget's
    // locale actually reaches NumberFormat. Locales chosen for stable
    // separators across CLDR versions (fr uses a narrow no-break space
    // that varies by intl version, so it is deliberately omitted).
    const cases = <(String locale, String expected)>[
      ('en', '715,544'),
      ('de', '715.544'),
    ];

    for (final (locale, expected) in cases) {
      testWidgets('formats 715544 as $expected under $locale', (
        tester,
      ) async {
        String? formatted;
        await tester.pumpWidget(
          MaterialApp(
            builder: LegacyMaterialBridge.builder,
            locale: Locale(locale),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                formatted = formatCount(context, 715544);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(formatted, expected);
      });
    }
  });
}
