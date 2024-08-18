import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/advanced/maintenance_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final mockJournalDb = MockJournalDb();

  group('MaintenancePage Widget Tests - ', () {
    setUp(() {
      when(mockJournalDb.watchTaggedCount)
          .thenAnswer((_) => Stream<int>.fromIterable([1]));

      when(
        mockJournalDb.watchConfigFlags,
      ).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([]),
      );

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<Maintenance>(MockMaintenance());
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

      expect(find.text('Delete tagged, n = 1'), findsOneWidget);
      expect(find.text('Delete logging database'), findsOneWidget);
    });
  });
}
