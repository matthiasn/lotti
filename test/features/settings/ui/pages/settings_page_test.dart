import 'dart:async';

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/settings/ui/pages/settings_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/features/whats_new/ui/whats_new_indicator.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import 'settings_page_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const n = 111;

  final mockJournalDb = MockJournalDb();

  group('SettingsPage Widget Tests - ', () {
    setUp(() {
      when(mockJournalDb.getJournalCount).thenAnswer((_) async => n);

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<UserActivityService>(UserActivityService());

      // Ensure ThemingController dependencies are registered
      ensureThemingServicesRegistered();
    });
    tearDown(getIt.reset);

    testWidgets('main page is displayed with gated cards enabled', (
      tester,
    ) async {
      when(mockJournalDb.watchConfigFlags).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableHabitsPageFlag,
              description: 'Enable Habits Page?',
              status: true,
            ),
            const ConfigFlag(
              name: enableDashboardsPageFlag,
              description: 'Enable Dashboards Page?',
              status: true,
            ),
          },
        ]),
      );

      await hPumpSettingsPage(tester, mockJournalDb);

      expect(find.text('Settings'), findsOneWidget);

      expect(find.text('AI Settings'), findsOneWidget);
      // Habits / Categories / Dashboards / Measurables / Flags moved
      // off the root list — they live behind Definitions / Advanced.
      expect(find.text('Habits'), findsNothing);
      expect(find.text('Categories'), findsNothing);
      expect(find.text('Dashboards'), findsNothing);
      expect(find.text('Measurable Types'), findsNothing);
      expect(find.text('Definitions'), findsOneWidget);
      expect(find.text('Theming'), findsOneWidget);
      expect(find.text('Config Flags'), findsNothing);
      expect(find.text('Advanced Settings'), findsOneWidget);
    });

    testWidgets('renders DesignSystemListItem components with dividers', (
      tester,
    ) async {
      when(mockJournalDb.watchConfigFlags).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([<ConfigFlag>{}]),
      );

      await hPumpSettingsPage(tester, mockJournalDb);

      // Core items always visible: AI, Agents, Definitions, Theming, Advanced.
      expect(find.byType(DesignSystemListItem), findsNWidgets(5));
    });

    testWidgets('shows Sync tile when Matrix flag is ON', (tester) async {
      when(mockJournalDb.watchConfigFlags).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableHabitsPageFlag,
              description: 'Enable Habits Page?',
              status: true,
            ),
            const ConfigFlag(
              name: enableDashboardsPageFlag,
              description: 'Enable Dashboards Page?',
              status: true,
            ),
            const ConfigFlag(
              name: enableMatrixFlag,
              description: 'Enable Matrix?',
              status: true,
            ),
          },
        ]),
      );

      await hPumpSettingsPage(tester, mockJournalDb);

      expect(find.text('Sync Settings'), findsOneWidget);
    });

    testWidgets(
      'root list always shows Definitions regardless of habits flag',
      (tester) async {
        // Habits / Dashboards toggles no longer affect the root list —
        // their gating moved into DefinitionsPage. The root entry for
        // Definitions is unconditional.
        when(mockJournalDb.watchConfigFlags).thenAnswer(
          (_) => Stream<Set<ConfigFlag>>.fromIterable([
            {
              const ConfigFlag(
                name: enableHabitsPageFlag,
                description: 'Enable Habits Page?',
                status: false,
              ),
              const ConfigFlag(
                name: enableDashboardsPageFlag,
                description: 'Enable Dashboards Page?',
                status: true,
              ),
            },
          ]),
        );

        await hPumpSettingsPage(tester, mockJournalDb);

        expect(find.text('Habits'), findsNothing);
        expect(find.text('Dashboards'), findsNothing);
        expect(find.text('Measurable Types'), findsNothing);
        expect(find.text('Definitions'), findsOneWidget);
      },
    );

    testWidgets('shows Agents card', (tester) async {
      await hPumpSettingsPage(tester, mockJournalDb);

      expect(find.text('Agents'), findsOneWidget);
      // Subtitle verifies the full card structure rendered, not just the title.
      expect(
        find.text('Templates, instances, and monitoring'),
        findsOneWidget,
      );
    });

    testWidgets(
      "shows What's New card and indicator when enableWhatsNewFlag is ON",
      (tester) async {
        when(mockJournalDb.watchConfigFlags).thenAnswer(
          (_) => Stream<Set<ConfigFlag>>.fromIterable([
            {
              const ConfigFlag(
                name: enableWhatsNewFlag,
                description: "Enable What's New feature?",
                status: true,
              ),
            },
          ]),
        );

        await hPumpSettingsPage(tester, mockJournalDb);

        // Settings card with title and subtitle
        expect(find.text("What's New"), findsOneWidget);
        expect(
          find.text('See the latest updates and features'),
          findsOneWidget,
        );
        // The WhatsNewIndicator is rendered in the app bar actions
        expect(find.byType(WhatsNewIndicator), findsOneWidget);
      },
    );

    testWidgets(
      "hides What's New card and indicator when enableWhatsNewFlag is OFF",
      (tester) async {
        when(mockJournalDb.watchConfigFlags).thenAnswer(
          (_) => Stream<Set<ConfigFlag>>.fromIterable([<ConfigFlag>{}]),
        );

        await hPumpSettingsPage(tester, mockJournalDb);

        expect(find.text("What's New"), findsNothing);
        expect(find.byType(WhatsNewIndicator), findsNothing);
      },
    );

    testWidgets(
      'tapping the Definitions row beams to /settings/definitions',
      (tester) async {
        // Wraps SettingsPage in a Beamer so the onTap closure
        // (`context.beamToNamed('/settings/definitions')`) executes
        // and we can read the resulting URL back from the delegate.
        when(mockJournalDb.watchConfigFlags).thenAnswer(
          (_) => Stream<Set<ConfigFlag>>.fromIterable([<ConfigFlag>{}]),
        );

        final delegate = BeamerDelegate(
          locationBuilder: RoutesLocationBuilder(
            routes: <String, Widget Function(BuildContext, BeamState, Object?)>{
              '/': (_, _, _) => const SettingsPage(),
              '/settings/definitions': (_, _, _) => const SizedBox.shrink(),
              '/settings/ai': (_, _, _) => const SizedBox.shrink(),
              '/settings/theming': (_, _, _) => const SizedBox.shrink(),
              '/settings/advanced': (_, _, _) => const SizedBox.shrink(),
            },
          ).call,
        );

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            BeamerProvider(
              routerDelegate: delegate,
              child: const SettingsPage(),
            ),
            theme: DesignSystemTheme.light(),
            overrides: [
              journalDbProvider.overrideWithValue(mockJournalDb),
              whatsNewControllerProvider.overrideWith(
                TestWhatsNewController.new,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(SettingsPage));
        await tester.tap(
          find.text(context.messages.settingsDefinitionsTitle),
        );
        await tester.pumpAndSettle();

        expect(
          delegate.configuration.uri.toString(),
          '/settings/definitions',
        );
      },
    );

    testWidgets(
      'root list still shows Definitions when dashboards flag is OFF',
      (tester) async {
        // Dashboards gating moved into DefinitionsPage. Toggling the
        // dashboards flag does not affect what's at the root level —
        // Definitions stays put because Categories / Labels /
        // Measurables are unconditional.
        when(mockJournalDb.watchConfigFlags).thenAnswer(
          (_) => Stream<Set<ConfigFlag>>.fromIterable([
            {
              const ConfigFlag(
                name: enableHabitsPageFlag,
                description: 'Enable Habits Page?',
                status: true,
              ),
              const ConfigFlag(
                name: enableDashboardsPageFlag,
                description: 'Enable Dashboards Page?',
                status: false,
              ),
            },
          ]),
        );

        await hPumpSettingsPage(tester, mockJournalDb);

        expect(find.text('Definitions'), findsOneWidget);
        expect(find.text('Habits'), findsNothing);
        expect(find.text('Dashboards'), findsNothing);
        expect(find.text('Measurable Types'), findsNothing);
      },
    );

    // -----------------------------------------------------------------------
    // Parameterised navigation-tap tests: every always-visible row must beam
    // to its declared route.  Lines 48, 56, 88, 96 in the source.
    // -----------------------------------------------------------------------
    for (final (rowTitle, expectedRoute) in [
      ('AI Settings', '/settings/ai'),
      ('Agents', '/settings/agents'),
      ('Theming', '/settings/theming'),
      ('Advanced Settings', '/settings/advanced'),
    ]) {
      testWidgets(
        'tapping "$rowTitle" row beams to $expectedRoute',
        (tester) async {
          when(mockJournalDb.watchConfigFlags).thenAnswer(
            (_) => Stream<Set<ConfigFlag>>.fromIterable([<ConfigFlag>{}]),
          );

          final delegate = hMakeBeamerDelegate();

          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              BeamerProvider(
                routerDelegate: delegate,
                child: const SettingsPage(),
              ),
              theme: DesignSystemTheme.light(),
              overrides: [
                journalDbProvider.overrideWithValue(mockJournalDb),
                whatsNewControllerProvider.overrideWith(
                  TestWhatsNewController.new,
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();

          await tester.ensureVisible(find.text(rowTitle));
          await tester.tap(find.text(rowTitle));
          await tester.pumpAndSettle();

          expect(
            delegate.configuration.uri.toString(),
            expectedRoute,
            reason: '"$rowTitle" tap should beam to $expectedRoute',
          );
        },
      );
    }

    // Line 66: Sync row (Matrix-flag gated) beams to /settings/sync.
    testWidgets(
      'tapping "Sync Settings" row beams to /settings/sync',
      (tester) async {
        when(mockJournalDb.watchConfigFlags).thenAnswer(
          (_) => Stream<Set<ConfigFlag>>.fromIterable([
            {
              const ConfigFlag(
                name: enableMatrixFlag,
                description: 'Enable Matrix?',
                status: true,
              ),
            },
          ]),
        );

        final delegate = hMakeBeamerDelegate();

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            BeamerProvider(
              routerDelegate: delegate,
              child: const SettingsPage(),
            ),
            theme: DesignSystemTheme.light(),
            overrides: [
              journalDbProvider.overrideWithValue(mockJournalDb),
              whatsNewControllerProvider.overrideWith(
                TestWhatsNewController.new,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Sync Settings'));
        await tester.tap(find.text('Sync Settings'));
        await tester.pumpAndSettle();

        expect(
          delegate.configuration.uri.toString(),
          '/settings/sync',
        );
      },
    );

    // Lines 40 + 127: tapping the What's New list row and the AppBar
    // indicator both call WhatsNewModal.show which opens the "all caught
    // up" modal (the test controller returns an empty WhatsNewState, so
    // unseenContent is empty → _showEmptyModal branch is taken).
    testWidgets(
      "tapping What's New list row opens the modal (line 40)",
      (tester) async {
        when(mockJournalDb.watchConfigFlags).thenAnswer(
          (_) => Stream<Set<ConfigFlag>>.fromIterable([
            {
              const ConfigFlag(
                name: enableWhatsNewFlag,
                description: "Enable What's New?",
                status: true,
              ),
            },
          ]),
        );

        await hPumpSettingsPage(tester, mockJournalDb);

        await tester.ensureVisible(find.text("What's New"));
        await tester.tap(find.text("What's New"));
        // Use pump instead of pumpAndSettle: the modal uses animations that
        // may not settle immediately; two frames are enough to confirm the
        // modal content appeared.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // The "all caught up" modal content confirms WhatsNewModal.show ran.
        expect(find.text("You're all caught up!"), findsOneWidget);
      },
    );

    testWidgets(
      "tapping AppBar What's New indicator opens the modal (line 127)",
      (tester) async {
        when(mockJournalDb.watchConfigFlags).thenAnswer(
          (_) => Stream<Set<ConfigFlag>>.fromIterable([
            {
              const ConfigFlag(
                name: enableWhatsNewFlag,
                description: "Enable What's New?",
                status: true,
              ),
            },
          ]),
        );

        await hPumpSettingsPage(tester, mockJournalDb);

        // The GestureDetector wrapping WhatsNewIndicator sits inside the
        // SliverAppBar flexibleSpace.  The FlexibleSpaceBar sets
        // IgnorePointer on the background/foreground layers when fully
        // expanded, so regular tap() and tapAt() are intercepted by the
        // header's IgnorePointer nodes.  Invoke the onTap callback directly
        // by calling _element.onTap on the located GestureDetector element.
        final element = tester.element(
          find
              .ancestor(
                of: find.byType(WhatsNewIndicator),
                matching: find.byType(GestureDetector),
              )
              .first,
        );
        final widget = element.widget as GestureDetector;
        widget.onTap?.call();
        // Pump microtasks: WhatsNewModal.show is async and awaits the
        // provider future before opening the modal.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text("You're all caught up!"), findsOneWidget);
      },
    );
  });
}
