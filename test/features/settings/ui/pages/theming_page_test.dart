import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

void main() {
  late MockSettingsDb settingsDb;
  late MockJournalDb journalDb;
  late MockLoggingService loggingService;
  late MockUserActivityService userActivityService;
  late MockUpdateNotifications updateNotifications;
  late Map<String, String?> storedSettings;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() {
    GetIt.I.allowReassignment = true;
    storedSettings = <String, String?>{};

    settingsDb = MockSettingsDb();
    journalDb = MockJournalDb();
    loggingService = MockLoggingService();
    userActivityService = MockUserActivityService();
    updateNotifications = MockUpdateNotifications();

    when(() => updateNotifications.updateStream).thenAnswer(
      (_) => const Stream<Set<String>>.empty(),
    );
    when(() => settingsDb.itemByKey(any())).thenAnswer(
      (invocation) async =>
          storedSettings[invocation.positionalArguments.first as String],
    );
    when(
      () => settingsDb.saveSettingsItem(any<String>(), any<String>()),
    ).thenAnswer((invocation) async {
      storedSettings[invocation.positionalArguments[0] as String] =
          invocation.positionalArguments[1] as String;
      return 1;
    });
    when(
      () => journalDb.watchConfigFlag(enableTooltipFlag),
    ).thenAnswer((_) => Stream.value(true));
    when(
      () => loggingService.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});

    GetIt.I
      ..registerSingleton<UpdateNotifications>(updateNotifications)
      ..registerSingleton<SettingsDb>(settingsDb)
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<UserActivityService>(userActivityService)
      ..registerSingleton<LoggingService>(loggingService);
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  Widget buildTestWidget({Locale locale = const Locale('en')}) {
    return ProviderScope(
      child: MaterialApp(
        theme: lottiLightTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(top: 47),
          ),
          child: ThemingPage(),
        ),
      ),
    );
  }

  AppLocalizations l10nFor(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(ThemingPage)))!;

  /// Pump and then unmount the tree. `SliverBoxAdapterPage` wraps its child
  /// in a flutter_animate `.fadeIn()`, which keeps a restart timer alive
  /// past `pumpAndSettle`. Replacing the tree with an empty widget disposes
  /// the animation so the test harness doesn't flag the pending timer.
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  group('ThemingPage', () {
    testWidgets('renders the localized title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text(l10nFor(tester).settingsThemingTitle), findsOneWidget);

      await disposeTree(tester);
    });

    testWidgets(
      'renders exactly the three Light/System/Dark mode segments and '
      'no named-theme picker',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SegmentedButton<ThemeMode>),
            matching: find.byType(Icon),
          ),
          findsNWidgets(3),
        );
        // The legacy named-theme picker used InputDecorator widgets; the
        // simplified page has no such fields.
        expect(find.byType(InputDecorator), findsNothing);

        await disposeTree(tester);
      },
    );

    testWidgets('tapping Light writes ThemeMode.light to settings', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.wb_sunny_outlined));
      await tester.pumpAndSettle();

      verify(
        () => settingsDb.saveSettingsItem(themeModeKey, 'light'),
      ).called(1);

      await disposeTree(tester);
    });

    testWidgets('tapping Dark writes ThemeMode.dark to settings', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.nightlight_outlined));
      await tester.pumpAndSettle();

      verify(
        () => settingsDb.saveSettingsItem(themeModeKey, 'dark'),
      ).called(1);

      await disposeTree(tester);
    });

    testWidgets('after selecting Dark the active dark icon is shown', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Initial state: system, so the dark icon is the outlined variant.
      expect(find.byIcon(Icons.nightlight_outlined), findsOneWidget);
      expect(find.byIcon(Icons.nightlight), findsNothing);

      await tester.tap(find.byIcon(Icons.nightlight_outlined));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.nightlight), findsOneWidget);
      expect(find.byIcon(Icons.nightlight_outlined), findsNothing);

      await disposeTree(tester);
    });
  });
}
