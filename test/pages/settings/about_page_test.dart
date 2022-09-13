import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/about_page.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const n = 111;

  final mockJournalDb = MockJournalDb();

  group('SettingsPage Widget Tests - ', () {
    setUp(() {
      when(mockJournalDb.watchJournalCount)
          .thenAnswer((_) => Stream<int>.fromIterable([n]));

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<ThemesService>(ThemesService(watch: false));
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
            child: const AboutPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('About Lotti'), findsOneWidget);
      expect(find.text('Entries count: 111'), findsOneWidget);
    });
  });
}
