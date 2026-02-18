import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/settings/ui/pages/advanced/maintenance_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_helper.dart';
import '../../../../../widget_test_utils.dart';

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
      await tester.pumpAndSettle();

      final resetTitle = find.text('Reset In\u2011App Hints');
      expect(resetTitle, findsOneWidget);
      await tester.tap(resetTitle);
      await tester.pumpAndSettle();

      await tester.tap(find.text('CONFIRM'));
      await tester.pumpAndSettle();
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
      when(mockJournalDb.getTaggedCount).thenAnswer((_) async => 1);
      when(mockJournalDb.watchConfigFlags).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([]),
      );

      final mockMaintenance = MockMaintenance();
      when(mockMaintenance.deleteLoggingDb).thenAnswer((_) async {});
      when(mockMaintenance.deleteEditorDb).thenAnswer((_) async {});
      when(mockMaintenance.deleteSyncDb).thenAnswer((_) async {});

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<Maintenance>(mockMaintenance)
        ..registerSingleton<NotificationService>(mockNotificationService);
      ensureThemingServicesRegistered();
    });

    tearDown(getIt.reset);

    testWidgets('page displays expected maintenance options', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(_constrainedMaintenancePage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete Logging Database'), findsOneWidget);
      expect(find.text('Delete Editor Database'), findsOneWidget);
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

    testWidgets('delete logging database button shows confirmation dialog',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(_constrainedMaintenancePage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Logging Database'));
      await tester.pumpAndSettle();

      expect(
        find.text('Are you sure you want to delete Logging Database?'),
        findsOneWidget,
      );
      expect(find.text('YES, DELETE DATABASE'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
    });

    testWidgets(
        'delete logging database button deletes database when confirmed',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(_constrainedMaintenancePage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Logging Database'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('YES, DELETE DATABASE'));
      await tester.pumpAndSettle();

      verify(() => getIt<Maintenance>().deleteLoggingDb()).called(1);
    });

    testWidgets('delete editor database button shows confirmation dialog',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(_constrainedMaintenancePage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Editor Database'));
      await tester.pumpAndSettle();

      expect(
        find.text('Are you sure you want to delete Editor Database?'),
        findsOneWidget,
      );
      expect(find.text('YES, DELETE DATABASE'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
    });

    testWidgets('delete editor database button deletes database when confirmed',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(_constrainedMaintenancePage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Editor Database'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('YES, DELETE DATABASE'));
      await tester.pumpAndSettle();

      verify(() => getIt<Maintenance>().deleteEditorDb()).called(1);
    });

    testWidgets('purge deleted entries button opens purge modal',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const MaintenancePage()),
      );
      await tester.pumpAndSettle();

      final purgeButton = find.text('Purge deleted items').first;
      expect(purgeButton, findsOneWidget);
      await tester.ensureVisible(purgeButton);
      await tester.tap(purgeButton);
      await tester.pumpAndSettle();

      expect(find.text('Purge deleted items'), findsAtLeastNWidgets(1));
    });

    testWidgets('recreate fts5 button opens fts5 recreate modal',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const MaintenancePage()),
      );
      await tester.pumpAndSettle();

      final recreateButton = find.text('Recreate full-text index').first;
      expect(recreateButton, findsOneWidget);
      await tester.ensureVisible(recreateButton);
      await tester.tap(recreateButton);
      await tester.pumpAndSettle();

      expect(find.text('YES, RECREATE INDEX'), findsAtLeastNWidgets(1));
    });
  });
}
