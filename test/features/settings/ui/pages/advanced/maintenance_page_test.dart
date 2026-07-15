import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/ui/settings/services/gemini_setup_prompt_service.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/settings/ui/pages/advanced/maintenance_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/debug_overlays.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_helper.dart';
import '../../../../../widget_test_utils.dart';
import '../../../test_utils.dart';

/// A minimal [GeminiSetupPromptService] whose [resetDismissal] records
/// calls without touching any real I/O.
class _FakeGeminiService extends GeminiSetupPromptService {
  int resetDismissalCallCount = 0;

  @override
  Future<bool> build() async => false;

  @override
  Future<void> resetDismissal() async {
    resetDismissalCallCount++;
  }
}

Widget _constrainedMaintenancePage() {
  return ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 1000, maxWidth: 1000),
    child: const MaintenancePage(),
  );
}

void main() {
  group('MaintenancePage - hint reset', () {
    final getItInstance = GetIt.instance;

    setUpAll(() {
      drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() async {
      await getItInstance.reset();
      getItInstance
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
        ..registerSingleton<Maintenance>(Maintenance());
      ensureThemingServicesRegistered();
    });

    tearDown(() async {
      if (getItInstance.isRegistered<JournalDb>()) {
        await getItInstance<JournalDb>().close();
      }
      await getItInstance.reset();
    });

    Future<void> openResetHints(WidgetTester tester) async {
      await tester.pumpWidget(const WidgetTestBench(child: MaintenancePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final resetTitle = find.text('Reset In\u2011App Hints');
      expect(resetTitle, findsOneWidget);
      await tester.tap(resetTitle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('CONFIRM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('shows SnackBar with count: 0', (tester) async {
      SharedPreferences.setMockInitialValues({'other_key': true});
      await openResetHints(tester);
      expect(find.text('Reset zero hints'), findsOneWidget);
    });

    testWidgets('shows SnackBar with count: 1', (tester) async {
      SharedPreferences.setMockInitialValues({
        'seen_tooltip_x': true,
        'random': false,
      });
      await openResetHints(tester);
      expect(find.text('Reset one hint'), findsOneWidget);
    });

    testWidgets('shows SnackBar with count: many', (tester) async {
      SharedPreferences.setMockInitialValues({
        'seen_a': true,
        'seen_b': true,
        'foo': true,
      });
      await openResetHints(tester);
      expect(find.text('Reset 2 hints'), findsOneWidget);
    });
  });

  group('MaintenancePage - database operations', () {
    final mockJournalDb = MockJournalDb();
    final mockNotificationService = MockNotificationService();

    setUp(() {
      when(mockJournalDb.watchConfigFlags).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([]),
      );

      final mockMaintenance = MockMaintenance();
      when(mockMaintenance.deleteEditorDb).thenAnswer((_) async {});
      when(mockMaintenance.deleteSyncDb).thenAnswer((_) async {});
      when(mockMaintenance.deleteAgentDb).thenAnswer((_) async {});

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<Maintenance>(mockMaintenance)
        ..registerSingleton<NotificationService>(mockNotificationService);
      ensureThemingServicesRegistered();
    });

    tearDown(getIt.reset);

    testWidgets('Show onboarding welcome opens the FTUE welcome', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _constrainedMaintenancePage(),
          mediaQueryData: const MediaQueryData(
            size: Size(800, 1200),
            disableAnimations: true,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Show onboarding welcome'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Both welcome CTAs are present — the FTUE welcome step, not some other
      // surface. (The dim modal is transparent, so the maintenance list stays
      // in the tree behind it; asserting its absence would be wrong.)
      expect(find.text('Choose your AI brain'), findsOneWidget);
      expect(find.text('Look around first'), findsOneWidget);
    });

    testWidgets('Onboarding animation gallery pushes the gallery page', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _constrainedMaintenancePage(),
          mediaQueryData: const MediaQueryData(
            size: Size(800, 1200),
            disableAnimations: true,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Onboarding animation gallery'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The gallery page is on top: its title plus the hero-style and step
      // chips that only it renders.
      expect(find.text('Onboarding animations'), findsOneWidget);
      expect(find.text('Constellation'), findsOneWidget);
      expect(find.text('API key'), findsOneWidget);
    });

    testWidgets(
      'Onboarding animation gallery escapes onto the root navigator, not '
      "the nested tab navigator, so it covers the shell's floating bottom "
      'nav instead of leaving it stacked on top (bottomNavSafeNavigatorOf)',
      (tester) async {
        final mockNavService = MockNavService();
        when(() => mockNavService.isDesktopMode).thenReturn(false);
        getIt.registerSingleton<NavService>(mockNavService);
        addTearDown(() {
          if (getIt.isRegistered<NavService>()) {
            getIt.unregister<NavService>();
          }
        });

        final rootNavigatorKey = GlobalKey<NavigatorState>();
        final nestedNavigatorKey = GlobalKey<NavigatorState>();

        // Mirrors the production mobile shell (`AppScreen._buildMobileLayout`):
        // a root MaterialApp navigator whose single page is a Stack holding
        // both the active tab's own nested Navigator (standing in for a
        // Beamer tab delegate — the nearest ancestor `Navigator.of(context)`
        // would find) and a Positioned marker standing in for the floating
        // `DesignSystemBottomNavigationBar`.
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Stack(
              children: [
                Navigator(
                  key: nestedNavigatorKey,
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => _constrainedMaintenancePage(),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Text('BOTTOM_NAV_MARKER'),
                ),
              ],
            ),
            navigatorKey: rootNavigatorKey,
            mediaQueryData: const MediaQueryData(
              size: Size(800, 1200),
              disableAnimations: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(rootNavigatorKey.currentState!.canPop(), isFalse);
        expect(nestedNavigatorKey.currentState!.canPop(), isFalse);
        expect(find.text('BOTTOM_NAV_MARKER').hitTestable(), findsOneWidget);

        await tester.tap(find.text('Onboarding animation gallery'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Onboarding animations'), findsOneWidget);
        // The push landed on the ROOT navigator, above the whole shell —
        // not on the nested tab navigator, which would leave the shell's
        // floating bottom nav bar stacked on top of the gallery.
        expect(rootNavigatorKey.currentState!.canPop(), isTrue);
        expect(nestedNavigatorKey.currentState!.canPop(), isFalse);
        // The marker sits in the same root-navigator page as the nested
        // Navigator: it's still mounted (a covered route isn't removed from
        // the tree), but a real hit test at its location now resolves to the
        // opaque gallery page painted on top of it instead — `hitTestable()`
        // performs that same z-order-aware hit test, so this proves the
        // marker is actually covered from the user's point of view, not just
        // that some push happened somewhere.
        expect(find.text('BOTTOM_NAV_MARKER').hitTestable(), findsNothing);
      },
    );

    testWidgets('page displays expected maintenance options', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(_constrainedMaintenancePage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Delete Logging Database'), findsNothing);
      expect(find.text('Delete Editor Database'), findsOneWidget);
      expect(find.text('Delete Agents Database'), findsOneWidget);
      expect(find.text('Delete Sync Database'), findsNothing);
      expect(find.text('Purge deleted items'), findsAtLeastNWidgets(1));
      expect(
        find.text(
          'Sync tags, measurables, dashboards, habits, categories, AI settings',
        ),
        findsNothing,
      );
      expect(find.text('Recreate full-text index'), findsAtLeastNWidgets(1));
      expect(find.text('Re-sync messages'), findsNothing);
    });

    testWidgets('delete editor database button shows confirmation dialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(_constrainedMaintenancePage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Delete Editor Database'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Are you sure you want to delete Editor Database?'),
        findsOneWidget,
      );
      expect(find.text('YES, DELETE DATABASE'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
    });

    testWidgets(
      'delete editor database button deletes database when confirmed',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(_constrainedMaintenancePage()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Delete Editor Database'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('YES, DELETE DATABASE'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(() => getIt<Maintenance>().deleteEditorDb()).called(1);
      },
    );

    testWidgets('delete agents database button shows confirmation dialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(_constrainedMaintenancePage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Delete Agents Database'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Are you sure you want to delete Agents Database?'),
        findsOneWidget,
      );
      expect(find.text('YES, DELETE DATABASE'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
    });

    testWidgets(
      'delete agents database - confirm calls deleteAgentDb',
      (tester) async {
        // Override deleteAgentDb with a never-completing future so
        // that exit(0) is never reached. This covers lines 121-122
        // (the confirmed branch that invokes the method). Line 123
        // (exit(0)) is inherently untestable in a widget test because
        // it would kill the test process.
        when(
          () => getIt<Maintenance>().deleteAgentDb(),
        ).thenAnswer((_) => Completer<void>().future);

        await tester.pumpWidget(
          makeTestableWidget(_constrainedMaintenancePage()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Delete Agents Database'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('YES, DELETE DATABASE'));
        // One pump drives the modal dismiss and starts the async
        // callback up to the suspended deleteAgentDb await.
        await tester.pump();

        // deleteAgentDb() was invoked (lines 121-122 covered).
        verify(() => getIt<Maintenance>().deleteAgentDb()).called(1);
      },
    );

    testWidgets('purge deleted entries button opens purge modal', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const MaintenancePage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final purgeButton = find.text('Purge deleted items').first;
      expect(purgeButton, findsOneWidget);
      await tester.ensureVisible(purgeButton);
      await tester.tap(purgeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Purge deleted items'), findsAtLeastNWidgets(1));
    });

    testWidgets('recreate fts5 button opens fts5 recreate modal', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const MaintenancePage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final recreateButton = find.text('Recreate full-text index').first;
      expect(recreateButton, findsOneWidget);
      await tester.ensureVisible(recreateButton);
      await tester.tap(recreateButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('YES, RECREATE INDEX'), findsAtLeastNWidgets(1));
    });

    testWidgets(
      'generate embeddings card hidden when pipeline not registered',
      (tester) async {
        // EmbeddingStore is NOT registered in this test group's setUp
        await tester.pumpWidget(
          makeTestableWidget(_constrainedMaintenancePage()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Generate Embeddings'), findsNothing);
      },
    );

    testWidgets(
      'generate embeddings card visible when pipeline is registered',
      (tester) async {
        final mockEmbeddingStore = MockEmbeddingStore();
        getIt.registerSingleton<EmbeddingStore>(mockEmbeddingStore);

        await tester.pumpWidget(
          makeTestableWidget(_constrainedMaintenancePage()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Generate Embeddings'), findsOneWidget);
        expect(
          find.text('Generate embeddings for entries in selected categories'),
          findsOneWidget,
        );
      },
    );

    testWidgets('re-index all embeddings card is not shown', (tester) async {
      final mockEmbeddingStore = MockEmbeddingStore();
      getIt.registerSingleton<EmbeddingStore>(mockEmbeddingStore);

      await tester.pumpWidget(
        makeTestableWidget(_constrainedMaintenancePage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Re-index All Embeddings'), findsNothing);
    });

    testWidgets('uses design system grouped list with chevrons', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(_constrainedMaintenancePage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DesignSystemGroupedList), findsOneWidget);
      // 6 fixed items (EmbeddingStore not registered in this group)
      // plus the diagnostic repaint-rainbow toggle = 7 list items.
      // Only the 8 action rows carry chevrons (incl. the two onboarding/FTUE
      // debug actions); the toggle uses an adaptive Switch as its trailing
      // affordance instead.
      expect(find.byType(DesignSystemListItem), findsNWidgets(9));
      expect(find.byType(SettingsIcon), findsNWidgets(9));
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(8));
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('shows dividers between items but not after last', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(_constrainedMaintenancePage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expectDividersOnAllButLast(tester);
    });

    testWidgets(
      "invokes the repaint-rainbow row's onTap and the Switch's "
      'onChanged callbacks — direct callback invocation rather than '
      'pointer-driven taps so no frame paints with the rainbow overlay '
      'on (which would advance `debugCurrentRepaintColor` and trip '
      '`debugAssertAllRenderVarsUnset`). End-to-end notifier→global '
      'mirroring is covered in `test/services/debug_overlays_test.dart`.',
      (tester) async {
        repaintRainbowEnabled.value = false;
        debugRepaintRainbowEnabled = false;
        addTearDown(() {
          repaintRainbowEnabled.value = false;
          debugRepaintRainbowEnabled = false;
        });

        await tester.pumpWidget(
          makeTestableWidget(_constrainedMaintenancePage()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Switch.onChanged closure on the tile flips the notifier.
        final initialSwitch = tester.widget<Switch>(find.byType(Switch));
        expect(initialSwitch.value, isFalse);
        initialSwitch.onChanged!(true);
        expect(repaintRainbowEnabled.value, isTrue);

        // Reset before any rebuild paints with the overlay on; the
        // ValueListenableBuilder schedules a rebuild, but we don't pump
        // it until after the global is back at default to keep the
        // framework's invariant check happy.
        repaintRainbowEnabled.value = false;
        debugRepaintRainbowEnabled = false;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Row's onTap closure also flips the notifier — exercise it via
        // the same direct-invocation pattern. The DesignSystemListItem
        // wires `onTap` through to its own InkWell, so we resolve the
        // tile widget and call its callback.
        final tile = tester.widget<DesignSystemListItem>(
          find.ancestor(
            of: find.text('Repaint rainbow overlay'),
            matching: find.byType(DesignSystemListItem),
          ),
        );
        tile.onTap!();
        expect(repaintRainbowEnabled.value, isTrue);

        // Final reset before the binding's invariant check.
        repaintRainbowEnabled.value = false;
        debugRepaintRainbowEnabled = false;
      },
    );
  });

  group('MaintenancePage - hover divider fade', () {
    setUp(() {
      final mockJournalDb = MockJournalDb();
      when(mockJournalDb.watchConfigFlags).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([]),
      );

      final mockMaintenance = MockMaintenance();
      when(mockMaintenance.deleteEditorDb).thenAnswer((_) async {});
      when(mockMaintenance.deleteAgentDb).thenAnswer((_) async {});

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<Maintenance>(mockMaintenance)
        ..registerSingleton<NotificationService>(MockNotificationService());
      ensureThemingServicesRegistered();
    });

    tearDown(getIt.reset);

    /// Pumps the desktop body inside a viewport tall enough that every
    /// row — including the bottom repaint-rainbow tile — is on-screen and
    /// therefore hit-testable by a synthetic mouse pointer.
    Future<List<DesignSystemListItem>> pumpBody(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(makeTestableWidget(const MaintenanceBody()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      return tester
          .widgetList<DesignSystemListItem>(find.byType(DesignSystemListItem))
          .toList();
    }

    List<DesignSystemListItem> rows(WidgetTester tester) => tester
        .widgetList<DesignSystemListItem>(find.byType(DesignSystemListItem))
        .toList();

    bool isFaded(DesignSystemListItem item) =>
        item.dividerColor == Colors.transparent;

    /// Drives a synthetic mouse hover onto the row at [index] and returns
    /// the live row list after the resulting rebuild. Hover events require
    /// pointer kind `mouse` — `tester.tap` won't fire the InkWell's
    /// `onHover`.
    Future<TestGesture> hoverRow(WidgetTester tester, int index) async {
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer();
      await gesture.moveTo(
        tester.getCenter(find.byType(DesignSystemListItem).at(index)),
      );
      await tester.pump();
      return gesture;
    }

    /// Asserts the set of rows whose divider is currently faded equals
    /// [expected], and that `showDivider` is stable — true for every row
    /// except the final (rainbow) row, regardless of hover state.
    void expectFadedRows(
      List<DesignSystemListItem> items,
      Set<int> expected,
    ) {
      for (final (index, row) in items.indexed) {
        expect(
          row.showDivider,
          index < items.length - 1,
          reason: 'showDivider must stay stable across hover (row $index)',
        );
        expect(
          isFaded(row),
          expected.contains(index),
          reason: 'row $index faded expectation',
        );
      }
    }

    testWidgets('idle: no divider is faded and showDivider is stable', (
      tester,
    ) async {
      final items = await pumpBody(tester);
      expect(
        items.length,
        greaterThanOrEqualTo(3),
        reason: 'test relies on at least 3 rows',
      );
      expectFadedRows(items, const <int>{});
    });

    testWidgets(
      'hovering a middle row fades the dividers above AND below it',
      (tester) async {
        await pumpBody(tester);
        await hoverRow(tester, 2);

        // Row 2 fades its own bottom divider (below) and row 1 fades its
        // bottom divider (above row 2) — the hovered row is bracketed by
        // invisible hairlines. Nothing else changes.
        expectFadedRows(rows(tester), const {1, 2});
      },
    );

    testWidgets(
      'hovering the first row fades only its own divider (no row above)',
      (tester) async {
        await pumpBody(tester);
        await hoverRow(tester, 0);

        // No index -1 exists, so only row 0's own divider fades.
        expectFadedRows(rows(tester), const {0});
      },
    );

    testWidgets(
      'hovering the last action row fades the divider shared with the '
      'repaint-rainbow tile',
      (tester) async {
        final items = await pumpBody(tester);
        // The last action row sits directly above the rainbow tile (the
        // final row). Hovering it must fade the boundary divider between
        // the two, exactly as between any other pair.
        final lastAction = items.length - 2;
        await hoverRow(tester, lastAction);

        expectFadedRows(rows(tester), {lastAction - 1, lastAction});
      },
    );

    testWidgets(
      'hovering the repaint-rainbow tile fades the divider above it',
      (tester) async {
        final items = await pumpBody(tester);
        // The rainbow tile is the final, dividerless row; hovering it
        // must still fade the last action row's divider so the tile is
        // not visually separated on hover.
        final rainbowIndex = items.length - 1;
        await hoverRow(tester, rainbowIndex);

        expectFadedRows(rows(tester), {rainbowIndex - 1});
      },
    );

    testWidgets('moving the pointer off the row clears every fade', (
      tester,
    ) async {
      await pumpBody(tester);
      final gesture = await hoverRow(tester, 2);
      expect(rows(tester).where(isFaded), isNotEmpty);

      await gesture.moveTo(Offset.zero);
      await tester.pump();
      expectFadedRows(rows(tester), const <int>{});
    });

    testWidgets(
      'moving between rows re-targets the fade to the newly hovered row',
      (tester) async {
        await pumpBody(tester);
        final gesture = await hoverRow(tester, 1);
        expectFadedRows(rows(tester), const {0, 1});

        // Move to a non-adjacent row: the exit from row 1 and the enter
        // onto row 3 leave exactly row 3's pair faded, proving the
        // hovered index is retargeted rather than accumulated.
        await gesture.moveTo(
          tester.getCenter(find.byType(DesignSystemListItem).at(3)),
        );
        await tester.pump();
        expectFadedRows(rows(tester), const {2, 3});
      },
    );
  });

  group('MaintenancePage - Gemini reset', () {
    setUp(() {
      final mockJournalDb = MockJournalDb();
      when(mockJournalDb.watchConfigFlags).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([]),
      );

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<Maintenance>(MockMaintenance());
      ensureThemingServicesRegistered();
    });

    tearDown(getIt.reset);

    testWidgets('cancel does not call resetDismissal', (tester) async {
      final fakeService = _FakeGeminiService();

      await tester.pumpWidget(
        makeTestableWidget(
          _constrainedMaintenancePage(),
          overrides: [
            geminiSetupPromptServiceProvider.overrideWith(
              () => fakeService,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final resetButton = find.text('Reset Gemini Setup Dialog');
      await tester.ensureVisible(resetButton);
      await tester.tap(resetButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Confirmation dialog should be visible.
      expect(
        find.text('This will show the Gemini setup dialog again. Continue?'),
        findsOneWidget,
      );

      await tester.tap(find.text('CANCEL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeService.resetDismissalCallCount, 0);
    });

    testWidgets('confirm calls resetDismissal', (tester) async {
      final fakeService = _FakeGeminiService();

      await tester.pumpWidget(
        makeTestableWidget(
          _constrainedMaintenancePage(),
          overrides: [
            geminiSetupPromptServiceProvider.overrideWith(
              () => fakeService,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final resetButton = find.text('Reset Gemini Setup Dialog');
      await tester.ensureVisible(resetButton);
      await tester.tap(resetButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('This will show the Gemini setup dialog again. Continue?'),
        findsOneWidget,
      );

      // The confirm label for Gemini reset is "RESET" (uppercased from "Reset").
      await tester.tap(find.text('RESET'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeService.resetDismissalCallCount, 1);
    });
  });

  group('MaintenancePage - embeddings modal', () {
    setUp(() {
      final mockJournalDb = MockJournalDb();
      when(mockJournalDb.watchConfigFlags).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([]),
      );

      final mockCacheService = MockEntitiesCacheService();
      when(
        () => mockCacheService.sortedCategories,
      ).thenReturn([]);

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<Maintenance>(MockMaintenance())
        ..registerSingleton<EmbeddingStore>(MockEmbeddingStore())
        ..registerSingleton<EntitiesCacheService>(mockCacheService);
      ensureThemingServicesRegistered();
    });

    tearDown(getIt.reset);

    testWidgets('tapping Generate Embeddings opens the backfill modal', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const MaintenancePage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final generateButton = find.text('Generate Embeddings').first;
      await tester.ensureVisible(generateButton);
      await tester.tap(generateButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The backfill modal shows its confirmation message.
      expect(
        find.text('Select categories to generate embeddings for.'),
        findsOneWidget,
      );
    });
  });
}
