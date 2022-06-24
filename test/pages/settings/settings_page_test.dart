import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/settings_page.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../widget_test_utils.dart';
import 'mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const n = 111;

  final mockJournalDb = MockJournalDb();

  group('SettingsPage Widget Tests - ', () {
    setUp(() {
      when(mockJournalDb.watchJournalCount)
          .thenAnswer((_) => Stream<int>.fromIterable([n]));

      getIt.registerSingleton<JournalDb>(mockJournalDb);
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

      expect(find.byIcon(MdiIcons.tagOutline), findsOneWidget);
      expect(find.byIcon(Icons.dashboard_customize_outlined), findsOneWidget);
      expect(find.byIcon(Icons.insights), findsOneWidget);
      expect(find.byIcon(MdiIcons.heartOutline), findsOneWidget);
      expect(find.byIcon(MdiIcons.flagOutline), findsOneWidget);
      expect(find.byIcon(MdiIcons.alertRhombusOutline), findsOneWidget);

      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Dashboard Management'), findsOneWidget);
      expect(find.text('Measurable Data Types'), findsOneWidget);
      expect(find.text('Health Import'), findsOneWidget);
      expect(find.text('Config Flags'), findsOneWidget);
      expect(find.text('Advanced Settings'), findsOneWidget);

      verify(mockJournalDb.watchJournalCount).called(1);
    });
  });
}
