import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/blocs/theming/theming_cubit.dart';
import 'package:lotti/blocs/theming/theming_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

class MockSettingsDb extends Mock implements SettingsDb {}

class MockJournalDb extends Mock implements JournalDb {}

class MockUserActivityService extends Mock implements UserActivityService {}

// TestThemingCubit for synchronous state
class TestThemingCubit extends ThemingCubit {
  TestThemingCubit(ThemingState initialState) : super() {
    emit(initialState);
  }
}

void main() {
  late MockSettingsDb mockSettingsDb;
  late MockJournalDb mockJournalDb;
  late MockUserActivityService mockUserActivityService;

  setUp(() {
    // Reset GetIt before each test
    GetIt.I.reset();

    // Create mocks
    mockSettingsDb = MockSettingsDb();
    mockJournalDb = MockJournalDb();
    mockUserActivityService = MockUserActivityService();

    // Set up default mock behaviors
    when(() => mockSettingsDb.itemByKey('theme'))
        .thenAnswer((_) async => 'Grey Law');
    when(() => mockSettingsDb.itemByKey('LIGHT_SCHEME'))
        .thenAnswer((_) async => 'Grey Law');
    when(() => mockSettingsDb.itemByKey('DARK_SCHEMA'))
        .thenAnswer((_) async => 'Grey Law');
    when(() => mockSettingsDb.itemByKey('THEME_MODE'))
        .thenAnswer((_) async => 'dark');
    when(() => mockSettingsDb.saveSettingsItem(any(), any()))
        .thenAnswer((_) async => 1);

    when(() => mockJournalDb.watchConfigFlag(enableTooltipFlag))
        .thenAnswer((_) => Stream.value(true));

    // Register dependencies in GetIt
    GetIt.I.registerSingleton<SettingsDb>(mockSettingsDb);
    GetIt.I.registerSingleton<JournalDb>(mockJournalDb);
    GetIt.I.registerSingleton<UserActivityService>(mockUserActivityService);
  });

  tearDown(() {
    // Clean up cubit

    // Reset GetIt after each test
    GetIt.I.reset();
  });

  Widget createTestWidget({required ThemingCubit cubit, Locale? locale}) {
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(top: 47),
        ),
        child: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const ThemingPage(),
          ),
        ),
      ),
    );
  }

  group('ThemingPage Widget Tests', () {
    testWidgets('theming page loads and displays theme selection controls',
        (tester) async {
      final cubit = ThemingCubit();
      await tester.pumpWidget(
          createTestWidget(locale: const Locale('en'), cubit: cubit));
      await tester.pumpAndSettle();

      final l10n =
          AppLocalizations.of(tester.element(find.byType(ThemingPage)))!;

      // Verify the page title is displayed (localized)
      expect(find.text(l10n.settingsThemingTitle), findsOneWidget);

      // Verify the segmented button for theme mode is present
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);

      // Verify the theme selection text fields are present
      expect(find.byType(TextField), findsNWidgets(2));

      // Verify the theme selection labels are present (localized)
      expect(find.text(l10n.settingThemingLight), findsOneWidget);
      expect(find.text(l10n.settingThemingDark), findsOneWidget);
    });

    testWidgets('theme mode segmented button changes theme mode',
        (tester) async {
      final cubit = ThemingCubit();
      await tester.pumpWidget(
          createTestWidget(locale: const Locale('en'), cubit: cubit));
      await tester.pumpAndSettle();

      // Find the segmented button
      final segmentedButton = find.byType(SegmentedButton<ThemeMode>);
      expect(segmentedButton, findsOneWidget);

      // Tap on the light theme segment
      final lightThemeSegment = find.byIcon(Icons.wb_sunny_outlined);
      expect(lightThemeSegment, findsOneWidget);
      await tester.tap(lightThemeSegment);
      await tester.pumpAndSettle();

      // Verify the cubit was called with the light theme mode
      verify(() => mockSettingsDb.saveSettingsItem('THEME_MODE', 'light'))
          .called(1);
    });

    testWidgets('light theme selection opens modal and allows theme selection',
        (tester) async {
      final cubit = ThemingCubit();
      await tester.pumpWidget(
          createTestWidget(locale: const Locale('en'), cubit: cubit));
      await tester.pumpAndSettle();

      final l10n =
          AppLocalizations.of(tester.element(find.byType(ThemingPage)))!;

      // Find and tap the light theme text field by label
      final lightThemeField =
          find.widgetWithText(TextField, l10n.settingThemingLight);
      expect(lightThemeField, findsOneWidget);
      await tester.tap(lightThemeField);
      await tester.pumpAndSettle();

      // Verify the modal is shown
      expect(find.byType(BottomSheet), findsOneWidget);

      // Verify theme options are displayed in the modal
      expect(find.text('Material'), findsOneWidget);
      expect(find.text('Grey Law'), findsAtLeastNWidgets(1));
      expect(find.text('Deep Blue'), findsOneWidget);

      // Select a different theme from the modal
      await tester.tap(find.text('Material').last);
      await tester.pumpAndSettle();

      // Verify the modal is closed and the theme was saved
      expect(find.byType(BottomSheet), findsNothing);
      verify(() => mockSettingsDb.saveSettingsItem('LIGHT_SCHEME', 'Material'))
          .called(1);
    });

    testWidgets('dark theme selection opens modal and allows theme selection',
        (tester) async {
      final cubit = ThemingCubit();
      await tester.pumpWidget(
          createTestWidget(locale: const Locale('en'), cubit: cubit));
      await tester.pumpAndSettle();

      final l10n =
          AppLocalizations.of(tester.element(find.byType(ThemingPage)))!;

      // Find and tap the dark theme text field by label
      final darkThemeField =
          find.widgetWithText(TextField, l10n.settingThemingDark);
      expect(darkThemeField, findsOneWidget);
      await tester.tap(darkThemeField);
      await tester.pumpAndSettle();

      // Verify the modal is shown
      expect(find.byType(BottomSheet), findsOneWidget);

      // Verify theme options are displayed in the modal
      expect(find.text('Material'), findsOneWidget);
      expect(find.text('Grey Law'), findsAtLeastNWidgets(1));
      expect(find.text('Deep Blue'), findsOneWidget);

      // Select a different theme from the modal
      await tester.tap(find.text('Deep Blue').last);
      await tester.pumpAndSettle();

      // Verify the modal is closed and the theme was saved
      expect(find.byType(BottomSheet), findsNothing);
      verify(() => mockSettingsDb.saveSettingsItem('DARK_SCHEMA', 'Deep Blue'))
          .called(1);
    });

    testWidgets('theme selection modal can be dismissed', (tester) async {
      final cubit = ThemingCubit();
      await tester.pumpWidget(
          createTestWidget(locale: const Locale('en'), cubit: cubit));
      await tester.pumpAndSettle();

      final l10n =
          AppLocalizations.of(tester.element(find.byType(ThemingPage)))!;
      final lightThemeField =
          find.widgetWithText(TextField, l10n.settingThemingLight);
      await tester.tap(lightThemeField);
      await tester.pumpAndSettle();

      // Verify the modal is shown
      expect(find.byType(BottomSheet), findsOneWidget);

      // Dismiss the modal by tapping outside
      await tester.tapAt(const Offset(100, 100));
      await tester.pumpAndSettle();

      // Verify the modal is closed
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('theme mode segments show correct icons', (tester) async {
      final cubit = TestThemingCubit(
        ThemingState(
          enableTooltips: true,
          darkTheme: ThemeData.dark(),
          darkThemeName: 'Grey Law',
          lightTheme: ThemeData.light(),
          lightThemeName: 'Grey Law',
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pumpWidget(
          createTestWidget(locale: const Locale('en'), cubit: cubit));
      await tester.pumpAndSettle();

      bool iconWithCodepoint(Widget widget, int codepoint) =>
          widget is Icon && widget.icon?.codePoint == codepoint;

      // Check for the actual icons rendered by codepoint
      expect(find.byWidgetPredicate((w) => iconWithCodepoint(w, 0xE15E)),
          findsOneWidget); // dark
      expect(find.byWidgetPredicate((w) => iconWithCodepoint(w, 0xE42E)),
          findsOneWidget); // system
      expect(find.byWidgetPredicate((w) => iconWithCodepoint(w, 0xE367)),
          findsOneWidget); // ?
      expect(find.byWidgetPredicate((w) => iconWithCodepoint(w, 0xF4BC)),
          findsOneWidget); // light
    });

    testWidgets('theme selection fields are read-only', (tester) async {
      final cubit = ThemingCubit();
      await tester.pumpWidget(
          createTestWidget(locale: const Locale('en'), cubit: cubit));
      await tester.pumpAndSettle();

      // Find the text fields
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      // Verify they are read-only
      for (final element in textFields.evaluate()) {
        final textField = element.widget as TextField;
        expect(textField.readOnly, isTrue);
      }
    });
  });
}
