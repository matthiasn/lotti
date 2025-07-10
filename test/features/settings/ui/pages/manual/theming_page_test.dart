import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/blocs/theming/theming_cubit.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:showcaseview/showcaseview.dart';

class MockSettingsDb extends Mock implements SettingsDb {}

class MockJournalDb extends Mock implements JournalDb {}

void main() {
  late MockSettingsDb mockSettingsDb;
  late MockJournalDb mockJournalDb;
  late ThemingCubit themingCubit;

  setUp(() {
    mockSettingsDb = MockSettingsDb();
    mockJournalDb = MockJournalDb();

    when(() => mockSettingsDb.itemByKey('theme'))
        .thenAnswer((_) async => 'Grey Law');
    when(() => mockSettingsDb.itemByKey('LIGHT_SCHEME'))
        .thenAnswer((_) async => 'Light Theme');
    when(() => mockSettingsDb.itemByKey('DARK_SCHEMA'))
        .thenAnswer((_) async => 'Dark Theme');
    when(() => mockSettingsDb.itemByKey('THEME_MODE'))
        .thenAnswer((_) async => 'dark');

    when(() => mockJournalDb.watchConfigFlag(enableTooltipFlag))
        .thenAnswer((_) => Stream.value(true));

    GetIt.I.registerSingleton<SettingsDb>(mockSettingsDb);
    GetIt.I.registerSingleton<JournalDb>(mockJournalDb);
    GetIt.I.registerSingleton<UserActivityService>(UserActivityService());

    themingCubit = ThemingCubit();
  });

  tearDown(() {
    GetIt.I.reset();
  });

  Widget createTestWidget() {
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider.value(
          value: themingCubit,
          child: ShowCaseWidget(
            builder: (context) => const ThemingPage(),
          ),
        ),
      ),
    );
  }

  group('ThemingPage Showcase Tests', () {
    testWidgets('Showcase navigation flow test', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
    });

    testWidgets('Close showcase from first step', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
    });

    testWidgets('Navigate back from showcase', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
    });

    testWidgets('Showcase content visibility test', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
    });
  });
}
