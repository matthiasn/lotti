import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/settings/ui/pages/settings_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
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

    testWidgets('main page is displayed', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const SettingsPage(),
          ),
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
  });
}
