import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/settings/ui/pages/advanced/maintenance_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final mockJournalDb = MockJournalDb();
  final mockNotificationService = MockNotificationService();

  group('MaintenancePage Widget Tests - ', () {
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
    });
    tearDown(getIt.reset);

    testWidgets('page is displayed', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const MaintenancePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Delete Logging Database'), findsOneWidget);
      expect(find.text('Delete Editor Database'), findsOneWidget);
      expect(find.text('Delete Sync Database'), findsOneWidget);
      expect(
          find.text('Sync tags, measurables, dashboards, habits, categories'),
          findsAtLeastNWidgets(1));
      expect(find.text('Purge deleted items'), findsAtLeastNWidgets(1));
      expect(find.text('Purge audio models'), findsAtLeastNWidgets(1));
      expect(find.text('Recreate full-text index'), findsAtLeastNWidgets(1));
      expect(find.text('Re-sync messages'), findsAtLeastNWidgets(1));
    });

    testWidgets('delete logging database button shows confirmation dialog',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const MaintenancePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the delete logging database button
      final deleteButton = find.text('Delete Logging Database');
      expect(deleteButton, findsOneWidget);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      // Verify that the confirmation dialog is shown
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
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const MaintenancePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the delete logging database button
      final deleteButton = find.text('Delete Logging Database');
      expect(deleteButton, findsOneWidget);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      // Tap the 'YES, DELETE DATABASE' button in the confirmation dialog
      await tester.tap(find.text('YES, DELETE DATABASE'));
      await tester.pumpAndSettle();

      // Verify that the database was deleted
      verify(() => getIt<Maintenance>().deleteLoggingDb()).called(1);
    });

    testWidgets('delete editor database button shows confirmation dialog',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const MaintenancePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final deleteButton = find.text('Delete Editor Database');
      expect(deleteButton, findsOneWidget);
      await tester.tap(deleteButton);
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
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const MaintenancePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final deleteButton = find.text('Delete Editor Database');
      expect(deleteButton, findsOneWidget);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('YES, DELETE DATABASE'));
      await tester.pumpAndSettle();

      verify(() => getIt<Maintenance>().deleteEditorDb()).called(1);
    });

    testWidgets('delete sync database button shows confirmation dialog',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const MaintenancePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final deleteButton = find.text('Delete Sync Database');
      expect(deleteButton, findsOneWidget);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(
        find.text('Are you sure you want to delete Sync Database?'),
        findsOneWidget,
      );
      expect(find.text('YES, DELETE DATABASE'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
    });

    testWidgets('delete sync database button deletes database when confirmed',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const MaintenancePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final deleteButton = find.text('Delete Sync Database');
      expect(deleteButton, findsOneWidget);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('YES, DELETE DATABASE'));
      await tester.pumpAndSettle();

      verify(() => getIt<Maintenance>().deleteSyncDb()).called(1);
    });

    testWidgets('sync definitions button opens sync modal', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const MaintenancePage(),
        ),
      );

      await tester.pumpAndSettle();

      final syncButton = find
          .text('Sync tags, measurables, dashboards, habits, categories')
          .first;
      expect(syncButton, findsOneWidget);
      await tester.ensureVisible(syncButton);
      await tester.tap(syncButton);
      await tester.pumpAndSettle();

      expect(
          find.text('Sync tags, measurables, dashboards, habits, categories'),
          findsAtLeastNWidgets(1));
    });

    testWidgets('purge deleted entries button opens purge modal',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const MaintenancePage(),
        ),
      );

      await tester.pumpAndSettle();

      final purgeButton = find.text('Purge deleted items').first;
      expect(purgeButton, findsOneWidget);
      await tester.ensureVisible(purgeButton);
      await tester.tap(purgeButton);
      await tester.pumpAndSettle();

      expect(find.text('Purge deleted items'), findsAtLeastNWidgets(1));
    });

    testWidgets('purge audio models button opens audio purge modal',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const MaintenancePage(),
        ),
      );

      await tester.pumpAndSettle();

      final purgeButton = find.text('Purge audio models').first;
      expect(purgeButton, findsOneWidget);
      await tester.ensureVisible(purgeButton);
      await tester.tap(purgeButton);
      await tester.pumpAndSettle();

      expect(find.text('Purge audio models'), findsAtLeastNWidgets(1));
    });

    testWidgets('recreate fts5 button opens fts5 recreate modal',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const MaintenancePage(),
        ),
      );

      await tester.pumpAndSettle();

      final recreateButton = find.text('Recreate full-text index').first;
      expect(recreateButton, findsOneWidget);
      await tester.ensureVisible(recreateButton);
      await tester.tap(recreateButton);
      await tester.pumpAndSettle();

      expect(find.text('Recreate full-text index'), findsAtLeastNWidgets(1));
    });

    testWidgets('re-sync button opens re-sync modal', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const MaintenancePage(),
        ),
      );

      await tester.pumpAndSettle();

      final resyncButton = find.text('Re-sync messages').first;
      expect(resyncButton, findsOneWidget);
      await tester.ensureVisible(resyncButton);
      await tester.tap(resyncButton);
      await tester.pumpAndSettle();

      expect(find.text('Re-sync messages'), findsAtLeastNWidgets(1));
    });
  });
}
