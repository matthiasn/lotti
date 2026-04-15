import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboards_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;
  final mockEntitiesCacheService = MockEntitiesCacheService();

  Future<void> pumpDashboardsPage(
    WidgetTester tester, {
    required List<DashboardDefinition> dashboards,
  }) async {
    mockJournalDb = MockJournalDb();
    when(mockJournalDb.close).thenAnswer((_) async {});
    when(mockJournalDb.getAllDashboards).thenAnswer((_) async => dashboards);

    final mockUpdateNotifications = MockUpdateNotifications();
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => const Stream.empty());

    await getIt.reset();
    getIt
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
    ensureThemingServicesRegistered();

    await tester.pumpWidget(
      makeTestableWidget(
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 1000,
            maxWidth: 1000,
          ),
          child: const DashboardSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  tearDown(getIt.reset);

  group('DashboardSettingsPage', () {
    group('basic rendering', () {
      testWidgets('displays dashboard names', (tester) async {
        await pumpDashboardsPage(
          tester,
          dashboards: [testDashboardConfig, emptyTestDashboardConfig],
        );

        expect(find.text(testDashboardConfig.name), findsOneWidget);
        expect(find.text(emptyTestDashboardConfig.name), findsOneWidget);
      });

      testWidgets('displays description as subtitle when non-empty', (
        tester,
      ) async {
        await pumpDashboardsPage(
          tester,
          dashboards: [testDashboardConfig],
        );

        expect(find.text(testDashboardConfig.description), findsOneWidget);
      });

      testWidgets('displays chevron trailing icon', (tester) async {
        await pumpDashboardsPage(
          tester,
          dashboards: [testDashboardConfig],
        );

        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      });
    });

    group('private indicator', () {
      testWidgets('shows lock icon when private', (tester) async {
        final privateDashboard = testDashboardConfig.copyWith(private: true);
        await pumpDashboardsPage(tester, dashboards: [privateDashboard]);

        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      });

      testWidgets('hides lock icon when not private', (tester) async {
        await pumpDashboardsPage(
          tester,
          dashboards: [testDashboardConfig],
        );

        expect(find.byIcon(Icons.lock_outline), findsNothing);
      });
    });

    group('dividers', () {
      testWidgets('shows dividers between items but not after last', (
        tester,
      ) async {
        await pumpDashboardsPage(
          tester,
          dashboards: [
            testDashboardConfig,
            emptyTestDashboardConfig,
            testDashboardConfig.copyWith(
              name: 'Zeta Dashboard',
              id: 'zeta-id',
            ),
          ],
        );

        final items = find.byType(DesignSystemListItem);
        expect(items, findsNWidgets(3));

        final first = tester.widget<DesignSystemListItem>(items.at(0));
        final second = tester.widget<DesignSystemListItem>(items.at(1));
        final third = tester.widget<DesignSystemListItem>(items.at(2));

        expect(first.showDivider, isTrue);
        expect(second.showDivider, isTrue);
        expect(third.showDivider, isFalse);
      });

      testWidgets('single item has no divider', (tester) async {
        await pumpDashboardsPage(
          tester,
          dashboards: [testDashboardConfig],
        );

        final item = tester.widget<DesignSystemListItem>(
          find.byType(DesignSystemListItem),
        );
        expect(item.showDivider, isFalse);
      });
    });
  });
}
