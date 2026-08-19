import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  late MockSettingsDb mockSettingsDb;
  late MockJournalDb mockJournalDb;
  late MockUserActivityService mockUserActivityService;
  late MockDomainLogger mockLoggingService;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() {
    GetIt.I.reset();

    mockSettingsDb = MockSettingsDb();
    mockJournalDb = MockJournalDb();
    mockUserActivityService = MockUserActivityService();
    mockLoggingService = MockDomainLogger();

    final mockUpdateNotifications = MockUpdateNotifications();
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => const Stream.empty());

    when(
      () => mockSettingsDb.itemByKey('THEME_MODE'),
    ).thenAnswer((_) async => 'system');
    when(
      () => mockSettingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);
    when(
      () => mockJournalDb.watchConfigFlag(enableTooltipFlag),
    ).thenAnswer((_) => Stream.value(true));

    when(
      () => mockLoggingService.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});

    GetIt.I.registerSingleton<UpdateNotifications>(mockUpdateNotifications);
    GetIt.I.registerSingleton<SettingsDb>(mockSettingsDb);
    GetIt.I.registerSingleton<JournalDb>(mockJournalDb);
    GetIt.I.registerSingleton<UserActivityService>(mockUserActivityService);
    GetIt.I.registerSingleton<DomainLogger>(mockLoggingService);
  });

  tearDown(() {
    GetIt.I.reset();
  });

  Widget createTestWidget({Locale? locale}) {
    return ProviderScope(
      child: MaterialApp(
        theme: resolveTestTheme(ThemeData.light()),
        darkTheme: resolveTestTheme(ThemeData.dark()),
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
    testWidgets('theming page shows the title and the mode toggle only', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ThemingPage)),
      )!;

      // Verify the page title is displayed (localized)
      expect(find.text(l10n.settingsThemingTitle), findsOneWidget);

      // Verify the segmented button for theme mode is present
      expect(find.byType(DsSegmentedToggle<ThemeMode>), findsOneWidget);

      // The FlexColorScheme pickers are gone: mode is the only preference,
      // so no scheme-name fields may render.
      expect(find.byType(InputDecorator), findsNothing);
    });

    testWidgets('theme mode segmented button changes theme mode', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      // Find the segmented button
      final segmentedButton = find.byType(DsSegmentedToggle<ThemeMode>);
      expect(segmentedButton, findsOneWidget);

      // Tap on the light theme segment
      final lightThemeSegment = find.byIcon(LottiIcons.day);
      expect(lightThemeSegment, findsOneWidget);
      await tester.tap(lightThemeSegment);
      await tester.pumpAndSettle();

      // Verify the settings were saved
      verify(
        () => mockSettingsDb.saveSettingsItem('THEME_MODE', 'light'),
      ).called(1);
    });

    testWidgets('theme mode segments show correct icons', (tester) async {
      await tester.pumpWidget(createTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      // Verify that the segmented button contains icons
      final segmentedButton = find.byType(DsSegmentedToggle<ThemeMode>);
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
  });
}
