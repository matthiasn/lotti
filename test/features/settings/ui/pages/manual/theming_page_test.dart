import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

class MockSettingsDb extends Mock implements SettingsDb {}

class MockJournalDb extends Mock implements JournalDb {}

class MockUserActivityService extends Mock implements UserActivityService {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  late MockSettingsDb mockSettingsDb;
  late MockJournalDb mockJournalDb;
  late MockUserActivityService mockUserActivityService;
  late MockLoggingService mockLoggingService;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() {
    GetIt.I.reset();

    mockSettingsDb = MockSettingsDb();
    mockJournalDb = MockJournalDb();
    mockUserActivityService = MockUserActivityService();
    mockLoggingService = MockLoggingService();

    when(() => mockSettingsDb.itemByKey('theme'))
        .thenAnswer((_) async => 'Grey Law');
    when(() => mockSettingsDb.itemByKey('LIGHT_SCHEME'))
        .thenAnswer((_) async => 'Grey Law');
    when(() => mockSettingsDb.itemByKey('DARK_SCHEMA'))
        .thenAnswer((_) async => 'Grey Law');
    when(() => mockSettingsDb.itemByKey('THEME_MODE'))
        .thenAnswer((_) async => 'system');
    when(() => mockSettingsDb.saveSettingsItem(any(), any()))
        .thenAnswer((_) async => 1);
    when(() => mockSettingsDb.watchSettingsItemByKey(any()))
        .thenAnswer((_) => const Stream.empty());

    when(() => mockJournalDb.watchConfigFlag(enableTooltipFlag))
        .thenAnswer((_) => Stream.value(true));

    when(
      () => mockLoggingService.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) {});

    GetIt.I.registerSingleton<SettingsDb>(mockSettingsDb);
    GetIt.I.registerSingleton<JournalDb>(mockJournalDb);
    GetIt.I.registerSingleton<UserActivityService>(mockUserActivityService);
    GetIt.I.registerSingleton<LoggingService>(mockLoggingService);
  });

  tearDown(() {
    GetIt.I.reset();
  });

  Widget createTestWidget({Locale? locale}) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(top: 47),
          ),
          child: Scaffold(
            body: ThemingPage(),
          ),
        ),
      ),
    );
  }

  group('ThemingPage Widget Tests', () {
    testWidgets('theming page loads and displays theme selection controls',
        (tester) async {
      await tester.pumpWidget(createTestWidget(locale: const Locale('en')));
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
      await tester.pumpWidget(createTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      // Find the segmented button
      final segmentedButton = find.byType(SegmentedButton<ThemeMode>);
      expect(segmentedButton, findsOneWidget);

      // Tap on the light theme segment
      final lightThemeSegment = find.byIcon(Icons.wb_sunny_outlined);
      expect(lightThemeSegment, findsOneWidget);
      await tester.tap(lightThemeSegment);
      await tester.pumpAndSettle();

      // Verify the settings were saved
      verify(() => mockSettingsDb.saveSettingsItem('THEME_MODE', 'light'))
          .called(1);
    });

    testWidgets('light theme selection opens modal and allows theme selection',
        (tester) async {
      await tester.pumpWidget(createTestWidget(locale: const Locale('en')));
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
      await tester.pumpWidget(createTestWidget(locale: const Locale('en')));
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
      await tester.pumpWidget(createTestWidget(locale: const Locale('en')));
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
      await tester.pumpWidget(createTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      // Verify that the segmented button contains icons
      final segmentedButton = find.byType(SegmentedButton<ThemeMode>);
      expect(segmentedButton, findsOneWidget);

      // Verify icons are present within the segmented button
      expect(
        find.descendant(
          of: segmentedButton,
          matching: find.byType(Icon),
        ),
        findsNWidgets(3), // dark, system, light
      );
    });

    testWidgets('theme selection fields are read-only', (tester) async {
      await tester.pumpWidget(createTestWidget(locale: const Locale('en')));
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
