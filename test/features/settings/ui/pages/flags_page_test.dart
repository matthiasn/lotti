import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/settings/ui/pages/flags_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

class MockUserActivityService extends Mock implements UserActivityService {}

class FakeConfigFlag extends Fake implements ConfigFlag {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockJournalDb mockDb;
  late MockUserActivityService mockUserActivityService;
  late MockPersistenceLogic mockPersistenceLogic;
  final mockUpdateNotifications = MockUpdateNotifications();

  setUpAll(() {
    registerFallbackValue(FakeConfigFlag());
  });

  setUp(() async {
    mockDb = MockJournalDb();
    mockUserActivityService = MockUserActivityService();
    mockPersistenceLogic = MockPersistenceLogic();

    when(() => mockUpdateNotifications.updateStream).thenAnswer(
      (_) => Stream<Set<String>>.fromIterable([]),
    );

    when(() => mockDb.watchConfigFlags()).thenAnswer(
      (_) => Stream<Set<ConfigFlag>>.fromIterable([
        {
          const ConfigFlag(
            name: privateFlag,
            description: 'Show private entries?',
            status: true,
          ),
          const ConfigFlag(
            name: enableNotificationsFlag,
            description: 'Enable notifications?',
            status: false,
          ),
          const ConfigFlag(
            name: enableEventsFlag,
            description: 'Enable Events?',
            status: false,
          ),
          const ConfigFlag(
            name: enableDailyOsPageFlag,
            description: 'Enable DailyOS Page?',
            status: true,
          ),
          const ConfigFlag(
            name: enableAiStreamingFlag,
            description: 'Enable AI streaming responses?',
            status: false,
          ),
          const ConfigFlag(
            name: enableAgentsFlag,
            description: 'Enable Agents?',
            status: false,
          ),
          const ConfigFlag(
            name: enableEmbeddingsFlag,
            description: 'Generate Embeddings?',
            status: false,
          ),
          const ConfigFlag(
            name: enableVectorSearchFlag,
            description: 'Enable Vector Search?',
            status: false,
          ),
          const ConfigFlag(
            name: enableWhatsNewFlag,
            description: "Enable What's New feature?",
            status: false,
          ),
          const ConfigFlag(
            name: useOutboxBundlingFlag,
            description: 'Bundle text-only outbox messages',
            status: false,
          ),
          const ConfigFlag(
            name: showSyncActivityIndicatorFlag,
            description: 'Show live sync activity in the sidebar.',
            status: false,
          ),
          const ConfigFlag(
            name: showSidebarWakeQueueFlag,
            description: 'Show the inline Wake Queue in the sidebar.',
            status: false,
          ),
        },
      ]),
    );

    when(() => mockUserActivityService.updateActivity()).thenReturn(null);

    when(
      () => mockPersistenceLogic.setConfigFlag(any()),
    ).thenAnswer((_) async {});

    GetIt.I
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<UserActivityService>(mockUserActivityService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

    ensureThemingServicesRegistered();
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  group('FlagsPage', () {
    testWidgets('renders DesignSystemListItem for each flag', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      // 12 flags in the mock data (8 originals + whats-new +
      // outbox-bundling + sync-activity-indicator + sidebar-wake-queue).
      expect(find.byType(DesignSystemListItem), findsNWidgets(12));
    });

    testWidgets('uses SettingsIcon as leading widget', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsIcon), findsNWidgets(12));
    });

    testWidgets('shows correct title and description for private flag', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FlagsPage));
      expect(find.text(context.messages.configFlagPrivate), findsOneWidget);
      expect(
        find.text(context.messages.configFlagPrivateDescription),
        findsOneWidget,
      );
    });

    testWidgets('shows correct switch state for enabled flag', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FlagsPage));
      final privateFlagItem = find.widgetWithText(
        DesignSystemListItem,
        context.messages.configFlagPrivate,
      );
      final privateFlagSwitch = tester.widget<Switch>(
        find.descendant(of: privateFlagItem, matching: find.byType(Switch)),
      );
      expect(privateFlagSwitch.value, isTrue);
    });

    testWidgets('shows correct switch state for disabled flag', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FlagsPage));
      final notificationsItem = find.widgetWithText(
        DesignSystemListItem,
        context.messages.configFlagEnableNotifications,
      );
      final notificationsSwitch = tester.widget<Switch>(
        find.descendant(
          of: notificationsItem,
          matching: find.byType(Switch),
        ),
      );
      expect(notificationsSwitch.value, isFalse);
    });

    testWidgets('toggles flag when switch is tapped', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FlagsPage));
      final privateFlagItem = find.widgetWithText(
        DesignSystemListItem,
        context.messages.configFlagPrivate,
      );
      await tester.tap(
        find.descendant(of: privateFlagItem, matching: find.byType(Switch)),
      );
      await tester.pump();

      const expectedFlag = ConfigFlag(
        name: privateFlag,
        description: 'Show private entries?',
        status: false,
      );
      verify(() => mockPersistenceLogic.setConfigFlag(expectedFlag)).called(1);
    });

    testWidgets('toggles flag when row is tapped', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FlagsPage));

      // Tap the row itself (not the switch) — the onTap should toggle
      await tester.tap(
        find.text(context.messages.configFlagEnableNotifications),
      );
      await tester.pump();

      const expectedFlag = ConfigFlag(
        name: enableNotificationsFlag,
        description: 'Enable notifications?',
        status: true,
      );
      verify(() => mockPersistenceLogic.setConfigFlag(expectedFlag)).called(1);
    });

    testWidgets('shows correct icons for specific flags', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline_rounded), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.event_rounded), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.bolt_rounded), findsAtLeastNWidgets(1));
      expect(
        find.byIcon(Icons.calendar_today_rounded),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('wraps items in decorated box with border', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DecoratedBox), findsAtLeastNWidgets(1));
      expect(find.byType(ClipRRect), findsAtLeastNWidgets(1));
    });
  });

  group("FlagsPage — What's New flag", () {
    testWidgets('renders the whats-new flag with its localized title', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FlagsPage));
      expect(
        find.text(context.messages.configFlagEnableWhatsNew),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.configFlagEnableWhatsNewDescription),
        findsOneWidget,
      );
    });

    testWidgets('uses the new-releases icon for the whats-new row', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      // The icon is shared with the in-pane What's New tree leaf, so
      // the visual language stays consistent between sidebar and
      // toggle row.
      expect(find.byIcon(Icons.new_releases_outlined), findsAtLeastNWidgets(1));
    });

    testWidgets(
      'renders the outbox-bundling flag with its localized title and '
      'description, plus the archive icon — covers the per-flag arms in '
      '_iconForFlag/_titleForFlag/_subtitleForFlag for the new flag',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(const FlagsPage()),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FlagsPage));
        final bundlingItem = find.widgetWithText(
          DesignSystemListItem,
          context.messages.configFlagUseOutboxBundling,
        );
        await tester.ensureVisible(bundlingItem);
        await tester.pumpAndSettle();
        expect(bundlingItem, findsOneWidget);
        expect(
          find.text(context.messages.configFlagUseOutboxBundlingDescription),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: bundlingItem,
            matching: find.byIcon(Icons.archive_outlined),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('toggle persists the whats-new flag via PersistenceLogic', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FlagsPage));
      final whatsNewItem = find.widgetWithText(
        DesignSystemListItem,
        context.messages.configFlagEnableWhatsNew,
      );
      // The whats-new row sits at the bottom of the 9-row list and
      // is offscreen under the testable wrapper's bounded
      // SingleChildScrollView. `ensureVisible` walks the target's
      // ancestor chain to find the right scrollable and drives the
      // scroll for us — `scrollUntilVisible` can't pick a single
      // scrollable when the page nests several.
      await tester.ensureVisible(whatsNewItem);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: whatsNewItem, matching: find.byType(Switch)),
      );
      await tester.pump();

      const expected = ConfigFlag(
        name: enableWhatsNewFlag,
        description: "Enable What's New feature?",
        status: true,
      );
      verify(() => mockPersistenceLogic.setConfigFlag(expected)).called(1);
    });
  });

  group('FlagsPage — sync activity indicator flag', () {
    testWidgets(
      'renders the sync activity indicator flag with its localized '
      'title, description, and the network-check icon — covers the per-flag '
      'arms in _iconForFlag/_titleForFlag/_subtitleForFlag',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(const FlagsPage()),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FlagsPage));
        final indicatorItem = find.widgetWithText(
          DesignSystemListItem,
          context.messages.configFlagShowSyncActivityIndicator,
        );
        await tester.ensureVisible(indicatorItem);
        await tester.pumpAndSettle();
        expect(indicatorItem, findsOneWidget);
        expect(
          find.text(
            context.messages.configFlagShowSyncActivityIndicatorDescription,
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: indicatorItem,
            matching: find.byIcon(Icons.network_check_rounded),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'toggling persists the sync activity indicator flag via '
      'PersistenceLogic',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(const FlagsPage()),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FlagsPage));
        final indicatorItem = find.widgetWithText(
          DesignSystemListItem,
          context.messages.configFlagShowSyncActivityIndicator,
        );
        await tester.ensureVisible(indicatorItem);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: indicatorItem, matching: find.byType(Switch)),
        );
        await tester.pump();

        const expected = ConfigFlag(
          name: showSyncActivityIndicatorFlag,
          description: 'Show live sync activity in the sidebar.',
          status: true,
        );
        verify(() => mockPersistenceLogic.setConfigFlag(expected)).called(1);
      },
    );
  });

  group('FlagsPage — sidebar wake queue flag', () {
    testWidgets(
      'renders the sidebar wake queue flag with its localized title, '
      'description, and the alarm icon — covers the per-flag arms in '
      '_iconForFlag/_titleForFlag/_subtitleForFlag',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(const FlagsPage()),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FlagsPage));
        final wakesItem = find.widgetWithText(
          DesignSystemListItem,
          context.messages.configFlagShowSidebarWakeQueue,
        );
        await tester.ensureVisible(wakesItem);
        await tester.pumpAndSettle();
        expect(wakesItem, findsOneWidget);
        expect(
          find.text(
            context.messages.configFlagShowSidebarWakeQueueDescription,
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: wakesItem,
            matching: find.byIcon(Icons.alarm_rounded),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'toggling persists the sidebar wake queue flag via PersistenceLogic',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(const FlagsPage()),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FlagsPage));
        final wakesItem = find.widgetWithText(
          DesignSystemListItem,
          context.messages.configFlagShowSidebarWakeQueue,
        );
        await tester.ensureVisible(wakesItem);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: wakesItem, matching: find.byType(Switch)),
        );
        await tester.pump();

        const expected = ConfigFlag(
          name: showSidebarWakeQueueFlag,
          description: 'Show the inline Wake Queue in the sidebar.',
          status: true,
        );
        verify(() => mockPersistenceLogic.setConfigFlag(expected)).called(1);
      },
    );
  });

  group('FlagsPage — search bar', () {
    testWidgets('renders a single DesignSystemSearch above the list', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      // Exactly one search bar — keeps assertions in later tests
      // unambiguous and protects against accidental duplication.
      expect(find.byType(DesignSystemSearch), findsOneWidget);
    });

    testWidgets('uses the localized hint text on the search field', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FlagsPage));
      // Assert via the widget property rather than a text finder —
      // `DesignSystemSearch` paints its hint through multiple Text
      // children (placeholder + measurement) so a `find.text` would
      // be ambiguous.
      final search = tester.widget<DesignSystemSearch>(
        find.byType(DesignSystemSearch),
      );
      expect(search.hintText, context.messages.settingsFlagsSearchHint);
    });

    testWidgets('typing a matching query narrows the list to one row', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FlagsPage));
      // "private" hits only the title/desc of the private flag.
      await tester.enterText(find.byType(DesignSystemSearch), 'private');
      await tester.pumpAndSettle();

      expect(find.byType(DesignSystemListItem), findsOneWidget);
      expect(find.text(context.messages.configFlagPrivate), findsOneWidget);
    });

    testWidgets('search is case-insensitive', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FlagsPage()),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FlagsPage));
      await tester.enterText(find.byType(DesignSystemSearch), 'PRIVATE');
      await tester.pumpAndSettle();

      expect(find.text(context.messages.configFlagPrivate), findsOneWidget);
    });

    testWidgets(
      'a query that matches no flag shows the empty-search message',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(const FlagsPage()),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FlagsPage));
        await tester.enterText(
          find.byType(DesignSystemSearch),
          'no-such-flag-xyz',
        );
        await tester.pumpAndSettle();

        expect(find.byType(DesignSystemListItem), findsNothing);
        expect(
          find.text(context.messages.settingsFlagsEmptySearch),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping the built-in clear button restores the full list',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(const FlagsPage()),
        );
        await tester.pumpAndSettle();

        // Filter down to one row…
        await tester.enterText(find.byType(DesignSystemSearch), 'private');
        await tester.pumpAndSettle();
        expect(find.byType(DesignSystemListItem), findsOneWidget);

        // …then tap the X affordance the search bar exposes when text
        // is present (`Icons.cancel_rounded` inside the trailing
        // clear button). This is the real user path — the textfield's
        // own onChanged path is covered by the empty-query test
        // below.
        final clearIcon = find.byIcon(Icons.cancel_rounded);
        expect(clearIcon, findsOneWidget);
        await tester.tap(clearIcon);
        await tester.pumpAndSettle();

        expect(find.byType(DesignSystemListItem), findsNWidgets(12));
      },
    );

    testWidgets(
      'emptying the textfield from outside also restores the full list',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(const FlagsPage()),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(DesignSystemSearch), 'private');
        await tester.pumpAndSettle();
        expect(find.byType(DesignSystemListItem), findsOneWidget);

        // `enterText('')` exercises the textfield's onChanged path
        // (not the X button) — both must converge on the same
        // "list is restored" outcome.
        await tester.enterText(find.byType(DesignSystemSearch), '');
        await tester.pumpAndSettle();
        expect(find.byType(DesignSystemListItem), findsNWidgets(12));
      },
    );

    testWidgets(
      'a whitespace-only query is treated as empty and shows the full list',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(const FlagsPage()),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(DesignSystemSearch), '   ');
        await tester.pumpAndSettle();

        // Whitespace-trimming inside `filterDisplayedFlags` keeps the
        // list intact rather than producing a "no match" empty state.
        expect(find.byType(DesignSystemListItem), findsNWidgets(12));
      },
    );
  });

  group('FlagsPage — row polish', () {
    testWidgets(
      'rows allow long descriptions to wrap by passing subtitleMaxLines: null',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(const FlagsPage()),
        );
        await tester.pumpAndSettle();

        // Every flag row should opt out of the single-line ellipsis cap.
        // Sampling the first row is enough — the for-loop in `_FlagsList`
        // applies the same prop to every row.
        final firstItem = tester
            .widgetList<DesignSystemListItem>(
              find.byType(DesignSystemListItem),
            )
            .first;
        expect(firstItem.subtitleMaxLines, isNull);
      },
    );

    testWidgets(
      'hovering a row fades the divider beneath it AND beneath the row '
      'above it so the hovered row is never bisected — and `showDivider` '
      "stays stable so layout doesn't shift by 1 px",
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(const FlagsPage()),
        );
        await tester.pumpAndSettle();

        List<DesignSystemListItem> rows() => tester
            .widgetList<DesignSystemListItem>(
              find.byType(DesignSystemListItem),
            )
            .toList();

        bool isFaded(DesignSystemListItem item) =>
            item.dividerColor == Colors.transparent;

        // Idle baseline. `showDivider` is stable for all rows except the
        // last one (no divider beneath the bottom row); no dividers are
        // faded.
        final idleRows = rows();
        expect(
          idleRows.length,
          greaterThanOrEqualTo(3),
          reason: 'test relies on at least 3 flag rows',
        );
        for (final (index, row) in idleRows.indexed) {
          expect(
            row.showDivider,
            index < idleRows.length - 1,
            reason: 'showDivider must be stable across hover state',
          );
          expect(isFaded(row), isFalse, reason: 'no row faded when idle');
        }

        // Drive a synthetic mouse hover onto the second row. Hover events
        // require pointer kind `mouse` — `tester.tap` won't fire
        // `MouseRegion.onEnter`.
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer();
        await gesture.moveTo(
          tester.getCenter(find.byType(DesignSystemListItem).at(1)),
        );
        await tester.pump();

        // Exactly rows 0 and 1 should fade their divider (above and below
        // the hovered row); every other row stays unfaded; `showDivider`
        // is unchanged.
        final hoveredRows = rows();
        for (final (index, row) in hoveredRows.indexed) {
          expect(row.showDivider, index < hoveredRows.length - 1);
          expect(
            isFaded(row),
            index == 0 || index == 1,
            reason: 'only rows 0 and 1 should fade when row 1 is hovered',
          );
        }

        // Move the pointer off the row — fades clear.
        await gesture.moveTo(Offset.zero);
        await tester.pump();
        for (final row in rows()) {
          expect(isFaded(row), isFalse);
        }
      },
    );

    testWidgets(
      'inner list scrolls bridge to UserActivityService — fillRemaining mode '
      'kills the outer ScrollController, so the page must rely on '
      'ScrollNotification to keep activity tracking alive',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(const FlagsPage()),
        );
        await tester.pumpAndSettle();

        // Sanity: no activity reported yet from setting up the page.
        clearInteractions(mockUserActivityService);

        final scrollable = find.descendant(
          of: find.byType(FlagsBody),
          matching: find.byType(SingleChildScrollView),
        );
        await tester.drag(scrollable, const Offset(0, -50));
        await tester.pump();

        verify(
          () => mockUserActivityService.updateActivity(),
        ).called(greaterThan(0));
      },
    );

    testWidgets(
      'search field is OUTSIDE the scrollable region — only the list scrolls',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(const FlagsPage()),
        );
        await tester.pumpAndSettle();

        // The pinned search lives directly under FlagsBody, NOT inside
        // the SingleChildScrollView that owns the list.
        final search = find.byType(DesignSystemSearch);
        final scrollable = find.descendant(
          of: find.byType(FlagsBody),
          matching: find.byType(SingleChildScrollView),
        );
        expect(
          find.descendant(of: scrollable, matching: search),
          findsNothing,
          reason: 'search must stay pinned while the list scrolls',
        );
      },
    );
  });
}
