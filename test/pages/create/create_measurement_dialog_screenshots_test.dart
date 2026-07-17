/// Deterministic manual captures for the production measurement workflow.
///
/// The route opens from the real add action on a Sardines consumed dashboard
/// chart, then captures the filled editor plus both parts of the observed-at
/// page across mobile/desktop and light/dark themes.
///
/// Run: `LOTTI_SCREENSHOT_DIR=/tmp/measure fvm flutter test \
///   test/pages/create/create_measurement_dialog_screenshots_test.dart`
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/state/measurables_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_measurables_chart.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../features/daily_os_next/screenshot_harness.dart';
import '../../helpers/manual_demo_world.dart';
import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

const _measurableId = 'manual-sardines-consumed';
final _rangeStart = DateTime(2026, 6, 18);
final _rangeEnd = DateTime(2026, 7, 18);

String _t(String en, String de) => manualScreenshotText(en: en, de: de);

AppLocalizations _messages(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(MeasurablesBarChart)))!;

final MeasurableDataType _sardinesConsumed = MeasurableDataType(
  id: _measurableId,
  displayName: _t('Sardines consumed', 'Verzehrte Sardinen'),
  description: _t(
    'Daily fish consumption across the orbital habitat.',
    'Täglicher Fischverbrauch im orbitalen Habitat.',
  ),
  unitName: _t('sardines', 'Sardinen'),
  createdAt: manualDemoNow.subtract(const Duration(days: 120)),
  updatedAt: manualDemoNow,
  vectorClock: null,
  version: 1,
  aggregationType: AggregationType.dailySum,
  favorite: true,
);

List<Observation> _dashboardObservations() => [
  for (var day = 0; day < 30; day++)
    Observation(
      _rangeStart.add(Duration(days: day)),
      62 + (day % 6) * 5 + (day.isEven ? 8 : 0),
    ),
];

List<MeasurementEntry> _recentMeasurements() {
  MeasurementEntry entry(String id, num value, DateTime observedAt) =>
      MeasurementEntry(
        meta: Metadata(
          id: id,
          createdAt: observedAt,
          dateFrom: observedAt,
          dateTo: observedAt,
          updatedAt: observedAt,
          starred: false,
          private: false,
        ),
        data: MeasurementData(
          value: value,
          dataTypeId: _measurableId,
          dateTo: observedAt,
          dateFrom: observedAt,
        ),
      );

  return [
    entry('sardines-84', 84, manualDemoNow.subtract(const Duration(days: 1))),
    entry('sardines-79', 79, manualDemoNow.subtract(const Duration(days: 2))),
    entry('sardines-92', 92, manualDemoNow.subtract(const Duration(days: 3))),
  ];
}

List<Override> _chartOverrides() => [
  measurableDataTypeControllerProvider(_measurableId).overrideWithBuild(
    (ref, notifier) => _sardinesConsumed,
  ),
  aggregationTypeControllerProvider((
    measurableDataTypeId: _measurableId,
    dashboardDefinedAggregationType: null,
  )).overrideWithBuild((ref, notifier) => AggregationType.dailySum),
  measurableObservationsControllerProvider((
    measurableDataTypeId: _measurableId,
    rangeStart: _rangeStart,
    rangeEnd: _rangeEnd,
    dashboardDefinedAggregationType: AggregationType.dailySum,
  )).overrideWithBuild((ref, notifier) => _dashboardObservations()),
];

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required ScreenshotDevice device,
  required Brightness brightness,
}) async {
  applyScreenshotDevice(tester, device);
  await tester.pumpWidget(
    RepaintBoundary(
      key: screenshotBoundaryKey,
      child: ProviderScope(
        overrides: _chartOverrides(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.dark
              ? DesignSystemTheme.dark()
              : DesignSystemTheme.light(),
          locale: manualScreenshotLocale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final tokens = context.designTokens;
              return Scaffold(
                backgroundColor: tokens.colors.background.level01,
                body: SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(tokens.spacing.step5),
                    child: MeasurablesBarChart(
                      measurableDataTypeId: _measurableId,
                      rangeStart: _rangeStart,
                      rangeEnd: _rangeEnd,
                      enableCreate: true,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await settleFrames(tester, 10);
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'measurement manual screenshot harness (opt-in)',
      () {},
      skip: 'Set LOTTI_SCREENSHOT_DIR to capture manual screenshots.',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);

  setUp(() async {
    final journalDb = mockJournalDbWithMeasurableTypes([_sardinesConsumed]);
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(journalDb)
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic());
      },
    );
    when(
      () => journalDb.getMeasurementsByType(
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
        type: _measurableId,
      ),
    ).thenAnswer((_) async => _recentMeasurements());
  });

  tearDown(tearDownTestGetIt);

  for (final device in [miniDevice, desktopDevice]) {
    final viewport = device.isPhone ? 'mobile' : 'desktop';
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = brightness.name;
      testWidgets('$viewport measurement capture — $theme', (tester) async {
        await _pumpDashboard(
          tester,
          device: device,
          brightness: brightness,
        );
        expect(
          find.text(_t('Sardines consumed', 'Verzehrte Sardinen')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.add_rounded), findsOneWidget);

        await withClock(Clock.fixed(manualDemoNow), () async {
          await tester.tap(find.byIcon(Icons.add_rounded));
          await settleFrames(tester, 10);
        });
        expect(
          find.text(_t('Sardines consumed', 'Verzehrte Sardinen')),
          findsWidgets,
        );

        await tester.enterText(
          find.byKey(const Key('measurement_value_field')),
          '84',
        );
        final comment = _t(
          'Dinner shift after the Europa cargo docked',
          'Abendschicht nach dem Andocken der Europa-Fracht',
        );
        await tester.enterText(
          find.byKey(const Key('measurement_comment_field')),
          comment,
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await settleFrames(tester, 4);
        expect(find.text('84'), findsOneWidget);
        expect(
          find.text(comment),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'measurement_capture_editor_${viewport}_$theme',
          subdir: 'manual',
        );

        await tester.tap(find.byKey(const Key('measurement_observed_at')));
        await settleFrames(tester, 10);
        expect(
          find.text(_messages(tester).addMeasurementDateLabel),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'measurement_capture_date_${viewport}_$theme',
          subdir: 'manual',
        );

        final modalScrollView = find.byType(CustomScrollView).last;
        final scrollable = find.descendant(
          of: modalScrollView,
          matching: find.byType(Scrollable),
        );
        final scrollableState = tester.state<ScrollableState>(
          scrollable.first,
        );
        scrollableState.position.jumpTo(
          scrollableState.position.maxScrollExtent,
        );
        await settleFrames(tester, 4);
        expect(
          find.byKey(const ValueKey('measurement-time-section')),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'measurement_capture_time_${viewport}_$theme',
          subdir: 'manual',
        );
      });
    }
  }
}
