import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/advanced_settings_page.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../widget_test_utils.dart';
import 'mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const n = 111;

  final mockSyncDatabase = MockSyncDatabase();

  group('SettingsPage Widget Tests - ', () {
    setUp(() {
      when(mockSyncDatabase.watchOutboxCount)
          .thenAnswer((_) => Stream<int>.fromIterable([n]));

      getIt.registerSingleton<SyncDatabase>(mockSyncDatabase);
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
            child: const AdvancedSettingsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Advanced Settings'), findsOneWidget);

      expect(find.text('Sync Assistant'), findsOneWidget);
      expect(find.text('Sync Outbox'), findsOneWidget);
      expect(find.text('Sync Conflicts'), findsOneWidget);
      expect(find.text('Logs'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);

      expect(find.byIcon(Icons.sync), findsOneWidget);
      expect(find.byIcon(MdiIcons.mailboxOutline), findsOneWidget);
      expect(find.byIcon(MdiIcons.emoticonConfusedOutline), findsOneWidget);
      expect(find.byIcon(MdiIcons.informationOutline), findsOneWidget);
      expect(find.byIcon(MdiIcons.broom), findsOneWidget);

      // Check outbox badge count
      expect(find.text('$n'), findsOneWidget);

      verify(mockSyncDatabase.watchOutboxCount).called(1);
    });
  });
}
