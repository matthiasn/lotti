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
import 'package:lotti/widgets/settings/config_flag_card.dart';
import 'package:mocktail/mocktail.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../mocks/mocks.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockUserActivityService extends Mock implements UserActivityService {}

Future<String> getLocalizedText(
  WidgetTester tester,
  String Function(AppLocalizations) getter,
) async {
  final localizations =
      await AppLocalizations.delegate.load(const Locale('en'));
  return getter(localizations);
}

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
    testWidgets('displays flags when available', (tester) async {
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream.value({
          const ConfigFlag(
            name: privateFlag,
            description: 'Show private entries?',
            status: true,
          ),
          const ConfigFlag(
            name: attemptEmbedding,
            description: 'Enable embedding?',
            status: false,
          ),
        }),
      );

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

      final privateText = await getLocalizedText(
        tester,
        (l10n) => l10n.configFlagPrivate,
      );

      expect(find.text(privateText), findsOneWidget);
      expect(find.text('Enable embedding?'), findsOneWidget);
    });

    testWidgets('displays empty state when no flags', (tester) async {
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream.value({}),
      );

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

      expect(find.byType(ConfigFlagCard), findsNothing);
    });
  });

  testWidgets('FlagsPage with showcase displays correctly', (tester) async {
    when(() => mockDb.watchConfigFlags()).thenAnswer(
      (_) => Stream.value({
        const ConfigFlag(
          name: privateFlag,
          description: 'Show private entries?',
          status: true,
        ),
      }),
    );

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

    // Verify the showcase AppBar is displayed with the info icon in the title
    final appBar = find.byType(AppBar).first;
    expect(appBar, findsOneWidget);
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

    // Verify the private flag is displayed
    expect(find.text('Show private entries?'), findsOneWidget);

    // Verify the back button is present in the AppBar
    final backButton = find.descendant(
      of: appBar,
      matching: find.byIcon(Icons.chevron_left),
    );
    expect(backButton, findsOneWidget);
  });
}
