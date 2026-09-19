import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/settings/ui/pages/advanced/about_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/package_info.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const n = 111;

  group('SettingsPage Widget Tests - ', () {
    setUp(() async {
      mockPackageInfo(version: '2.3.4', buildNumber: '567');
      final mocks = await setUpTestGetIt(
        additionalSetup: () {
          getIt.registerSingleton<UserActivityService>(UserActivityService());
        },
      );
      final mockJournalDb = mocks.journalDb;
      when(mockJournalDb.getJournalCount).thenAnswer((_) async => n);
      when(mockJournalDb.getCountImportFlagEntries).thenAnswer((_) async => 0);
      when(
        () => mockJournalDb.linksForEntryIds(any()),
      ).thenAnswer((_) async => <EntryLink>[]);
      when(
        () => mockJournalDb.getTasksCount(statuses: any(named: 'statuses')),
      ).thenAnswer((_) async => 10);
      ensureThemingServicesRegistered();
    });
    tearDown(tearDownTestGetIt);

    testWidgets('main page is displayed', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
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
      expect(find.text('111'), findsOneWidget);
    });

    testWidgets(
      'body shows the platform version and scrolls itself when hosted in a '
      'bounded pane',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const SizedBox(width: 800, height: 400, child: AboutBody()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('2.3.4 (567)'), findsOneWidget);
        // In a bounded host (the Settings V2 detail pane) the body wraps
        // itself in a scroll view so the cards never overflow.
        expect(
          find.descendant(
            of: find.byType(AboutBody),
            matching: find.byType(SingleChildScrollView),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
