import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/advanced/maintenance_page.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

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
  });
}
