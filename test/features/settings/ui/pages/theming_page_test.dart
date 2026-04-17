import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  late TestGetItMocks mocks;
  late MockUserActivityService userActivityService;
  late MockLoggingService loggingService;
  late Map<String, String?> storedSettings;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() async {
    storedSettings = <String, String?>{};
    userActivityService = MockUserActivityService();
    loggingService = MockLoggingService();
    stubLoggingService(loggingService);

    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt.allowReassignment = true;
        getIt
          ..unregister<LoggingService>()
          ..registerSingleton<LoggingService>(loggingService)
          ..registerSingleton<UserActivityService>(userActivityService);
      },
    );

    when(() => mocks.settingsDb.itemByKey(any())).thenAnswer(
      (invocation) async =>
          storedSettings[invocation.positionalArguments.first as String],
    );
    when(
      () => mocks.settingsDb.saveSettingsItem(any<String>(), any<String>()),
    ).thenAnswer((invocation) async {
      storedSettings[invocation.positionalArguments[0] as String] =
          invocation.positionalArguments[1] as String;
      return 1;
    });
    when(
      () => mocks.journalDb.watchConfigFlag(enableTooltipFlag),
    ).thenAnswer((_) => Stream.value(true));
  });

  tearDown(tearDownTestGetIt);

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
      await tester.pumpWidget(makeTestableWidgetNoScroll(const ThemingPage()));
      await tester.pumpAndSettle();

      expect(find.text(l10nFor(tester).settingsThemingTitle), findsOneWidget);

      await disposeTree(tester);
    });

    testWidgets(
      'renders exactly the three Light/System/Dark mode segments and '
      'no named-theme picker',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(const ThemingPage()),
        );
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
      await tester.pumpWidget(makeTestableWidgetNoScroll(const ThemingPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.wb_sunny_outlined));
      await tester.pumpAndSettle();

      verify(
        () => mocks.settingsDb.saveSettingsItem(themeModeKey, 'light'),
      ).called(1);

      await disposeTree(tester);
    });

    testWidgets('tapping Dark writes ThemeMode.dark to settings', (
      tester,
    ) async {
      await tester.pumpWidget(makeTestableWidgetNoScroll(const ThemingPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.nightlight_outlined));
      await tester.pumpAndSettle();

      verify(
        () => mocks.settingsDb.saveSettingsItem(themeModeKey, 'dark'),
      ).called(1);

      await disposeTree(tester);
    });

    testWidgets('after selecting Dark the active dark icon is shown', (
      tester,
    ) async {
      await tester.pumpWidget(makeTestableWidgetNoScroll(const ThemingPage()));
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
