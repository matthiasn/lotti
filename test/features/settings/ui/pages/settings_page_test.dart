import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/settings/ui/pages/settings_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

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
    });
    tearDown(getIt.reset);

    testWidgets('main page is displayed with gated cards enabled',
        (tester) async {
      // Enable flags for habits and dashboards
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
          }
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SettingsPage(),
          overrides: [
            journalDbProvider.overrideWithValue(mockJournalDb),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);

      expect(find.text('AI Settings'), findsOneWidget);
      expect(find.text('Habits'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Dashboards'), findsOneWidget);
      expect(find.text('Measurable Types'), findsOneWidget);
      expect(find.text('Theming'), findsOneWidget);
      expect(find.text('Config Flags'), findsOneWidget);
      expect(find.text('Advanced Settings'), findsOneWidget);
    });

    testWidgets('hides Habits when enableHabitsPageFlag is OFF',
        (tester) async {
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
          }
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SettingsPage(),
          overrides: [journalDbProvider.overrideWithValue(mockJournalDb)],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Habits'), findsNothing);
      // Dashboards and Measurables visible when dashboards enabled
      expect(find.text('Dashboards'), findsOneWidget);
      expect(find.text('Measurable Types'), findsOneWidget);
    });

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
          }
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SettingsPage(),
          overrides: [journalDbProvider.overrideWithValue(mockJournalDb)],
        ),
      );

      await tester.pumpAndSettle();

      // Habits still visible when habits enabled
      expect(find.text('Habits'), findsOneWidget);
      // Dashboards and Measurables hidden
      expect(find.text('Dashboards'), findsNothing);
      expect(find.text('Measurable Types'), findsNothing);
    });
  });
}
