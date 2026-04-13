import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/settings/ui/pages/settings_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/features/whats_new/model/whats_new_state.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/features/whats_new/ui/whats_new_indicator.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// Test controller that returns empty state (no infinite animation).
class _TestWhatsNewController extends WhatsNewController {
  @override
  Future<WhatsNewState> build() async => const WhatsNewState();
}

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

      await _pumpSettingsPage(tester, mockJournalDb);

      expect(find.text('Settings'), findsOneWidget);

      expect(find.text('AI Settings'), findsOneWidget);
      expect(find.text('Habits'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Dashboards'), findsOneWidget);
      expect(find.text('Measurable Types'), findsOneWidget);
      expect(find.text('Theming'), findsOneWidget);
      expect(find.text('Config Flags'), findsOneWidget);
      expect(find.text('Advanced Settings'), findsOneWidget);
    });

    testWidgets('renders DesignSystemListItem components with dividers', (
      tester,
    ) async {
      when(mockJournalDb.watchConfigFlags).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([<ConfigFlag>{}]),
      );

      await _pumpSettingsPage(tester, mockJournalDb);

      // Core items always visible: AI, Categories, Labels, Theming, Flags, Advanced
      expect(find.byType(DesignSystemListItem), findsNWidgets(6));
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

      await _pumpSettingsPage(tester, mockJournalDb);

      expect(find.text('Sync Settings'), findsOneWidget);
    });

    testWidgets('hides Habits when enableHabitsPageFlag is OFF', (
      tester,
    ) async {
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

      await _pumpSettingsPage(tester, mockJournalDb);

      expect(find.text('Habits'), findsNothing);
      // Dashboards and Measurables visible when dashboards enabled
      expect(find.text('Dashboards'), findsOneWidget);
      expect(find.text('Measurable Types'), findsOneWidget);
    });

    testWidgets('shows Agents card when enableAgentsFlag is ON', (
      tester,
    ) async {
      when(mockJournalDb.watchConfigFlags).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableAgentsFlag,
              description: 'Enable Agents?',
              status: true,
            ),
          },
        ]),
      );

      await _pumpSettingsPage(tester, mockJournalDb);

      expect(find.text('Agents'), findsOneWidget);
      // Subtitle verifies the full card structure rendered, not just the title.
      expect(
        find.text('Templates, instances, and monitoring'),
        findsOneWidget,
      );
    });

    testWidgets('hides Agents card when enableAgentsFlag is OFF', (
      tester,
    ) async {
      when(mockJournalDb.watchConfigFlags).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([<ConfigFlag>{}]),
      );

      await _pumpSettingsPage(tester, mockJournalDb);

      expect(find.text('Agents'), findsNothing);
      // Subtitle also absent when the flag is off.
      expect(
        find.text('Templates, instances, and monitoring'),
        findsNothing,
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

        await _pumpSettingsPage(tester, mockJournalDb);

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

        await _pumpSettingsPage(tester, mockJournalDb);

        expect(find.text("What's New"), findsNothing);
        expect(find.byType(WhatsNewIndicator), findsNothing);
      },
    );

    testWidgets(
      'hides Dashboards and Measurable Types when enableDashboardsPageFlag is OFF',
      (tester) async {
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

        await _pumpSettingsPage(tester, mockJournalDb);

        // Habits still visible when habits enabled
        expect(find.text('Habits'), findsOneWidget);
        // Dashboards and Measurables hidden
        expect(find.text('Dashboards'), findsNothing);
        expect(find.text('Measurable Types'), findsNothing);
      },
    );
  });

  group('SettingsPage desktop layout', () {
    late MockSettingsDb mockSettingsDb;
    late NavService navService;
    late MockJournalDb desktopMockDb;

    setUp(() {
      desktopMockDb = MockJournalDb();
      mockSettingsDb = MockSettingsDb();

      when(desktopMockDb.getJournalCount).thenAnswer((_) async => 0);
      when(desktopMockDb.watchConfigFlags).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([<ConfigFlag>{}]),
      );
      when(
        () => desktopMockDb.watchConfigFlag(any()),
      ).thenAnswer((_) => Stream.value(false));
      when(() => mockSettingsDb.itemByKey(any())).thenAnswer(
        (_) async => null,
      );
      when(
        () => mockSettingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);

      navService = NavService(
        journalDb: desktopMockDb,
        settingsDb: mockSettingsDb,
      )..isDesktopMode = true;

      getIt
        ..registerSingleton<JournalDb>(desktopMockDb)
        ..registerSingleton<NavService>(navService)
        ..registerSingleton<UserActivityService>(UserActivityService());

      ensureThemingServicesRegistered();
    });

    tearDown(() async {
      await navService.dispose();
      await getIt.reset();
    });

    testWidgets('uses ValueListenableBuilder on desktop layout', (
      tester,
    ) async {
      navService.desktopSelectedSettingsRoute.value = (
        path: '/settings/ai',
        pathParameters: <String, String>{},
        queryParameters: <String, String>{},
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SettingsPage(),
          theme: DesignSystemTheme.light(),
          mediaQueryData: const MediaQueryData(size: Size(1200, 900)),
          overrides: [
            journalDbProvider.overrideWithValue(desktopMockDb),
            whatsNewControllerProvider.overrideWith(
              _TestWhatsNewController.new,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // The list items should render on desktop
      expect(find.byType(DesignSystemListItem), findsWidgets);
    });
  });
}

Future<void> _pumpSettingsPage(
  WidgetTester tester,
  MockJournalDb mockJournalDb,
) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      const SettingsPage(),
      theme: DesignSystemTheme.light(),
      overrides: [
        journalDbProvider.overrideWithValue(mockJournalDb),
        whatsNewControllerProvider.overrideWith(
          _TestWhatsNewController.new,
        ),
      ],
    ),
  );

  await tester.pumpAndSettle();
}
