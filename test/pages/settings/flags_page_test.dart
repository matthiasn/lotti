import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/pages/settings/flags_page.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockUserActivityService extends Mock implements UserActivityService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockJournalDb mockDb;
  late MockUserActivityService mockUserActivityService;
  final mockUpdateNotifications = MockUpdateNotifications();

  setUp(() async {
    mockDb = MockJournalDb();
    mockUserActivityService = MockUserActivityService();

    when(() => mockUpdateNotifications.updateStream).thenAnswer(
      (_) => Stream<Set<String>>.fromIterable([]),
    );

    when(() => mockDb.watchConfigFlags()).thenAnswer(
      (_) => Stream<Set<ConfigFlag>>.fromIterable([
        {
          const ConfigFlag(
            name: privateFlag,
            description: 'Show private entries?',
            status: true,
          ),
        },
      ]),
    );

    when(() => mockUserActivityService.updateActivity()).thenReturn(null);

    GetIt.I
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<UserActivityService>(mockUserActivityService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  group('FlagsPage Widget Tests - ', () {
    testWidgets('page is displayed', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          ShowCaseWidget(
            builder: (context) => ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 1000,
              ),
              child: const FlagsPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Show private entries?'), findsOneWidget);
    });
  });

  testWidgets('FlagsPage with showcase displays correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ShowCaseWidget(
          builder: (context) => const MediaQuery(
            data: MediaQueryData(size: Size(800, 600)),
            child: FlagsPage(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify the showcase icon is displayed
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

    // Verify the private flag is displayed
    expect(find.text('Show private entries?'), findsOneWidget);

    // Verify the back button is present
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
  });
}
