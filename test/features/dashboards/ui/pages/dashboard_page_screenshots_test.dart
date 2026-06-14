/// In-context screenshot harness for the dashboard detail page.
///
/// Renders the *real* [DashboardPage] — its pinned header (title + time-span
/// picker + edit-definition link) and the scrolling chart column — with dense
/// (~daily) measurement data fed through the DB mock, so the screenshots show
/// the page exactly as the app builds it: real gutters, real header, real bar
/// widths. No isolated padding, no hand-built card column.
///
/// Two contexts:
///  - desktop: the page rendered in a ~900px detail pane inside a 1280px window
///    (window width drives the desktop header; pane width drives layout — the
///    exact split-pane condition where bars used to overflow).
///  - mobile: the page at a 420px phone width (mobile header, picker below).
///
/// Run: `LOTTI_SCREENSHOT_DIR=/tmp/dash fvm flutter test \
///   test/features/dashboards/ui/pages/dashboard_page_screenshots_test.dart`
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/state/dashboards_page_controller.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboard_page.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';
import '../screenshot_fonts.dart';

const ValueKey<String> _boundaryKey = ValueKey<String>('dashboard-page-shot');
const String _dashboardId = 'demo-dashboard';

final _moodType = MeasurableDataType(
  id: 'demo-mood',
  displayName: 'Mood',
  description: 'Self-reported, 1–10',
  unitName: '',
  createdAt: testEpochDateTime,
  updatedAt: testEpochDateTime,
  vectorClock: null,
  version: 1,
  aggregationType: AggregationType.none,
);

final _stepsType = MeasurableDataType(
  id: 'demo-steps',
  displayName: 'Steps',
  description: '',
  unitName: 'steps',
  createdAt: testEpochDateTime,
  updatedAt: testEpochDateTime,
  vectorClock: null,
  version: 1,
  aggregationType: AggregationType.dailySum,
);

final _typesById = <String, MeasurableDataType>{
  measurableWater.id: measurableWater,
  _moodType.id: _moodType,
  _stepsType.id: _stepsType,
};

final _dashboardConfig = DashboardDefinition(
  items: [
    DashboardMeasurementItem(
      id: measurableWater.id,
      aggregationType: AggregationType.dailySum,
    ),
    DashboardMeasurementItem(id: _moodType.id),
    DashboardMeasurementItem(
      id: _stepsType.id,
      aggregationType: AggregationType.dailySum,
    ),
  ],
  name: 'Body & Mind',
  description: 'Daily hydration, mood and movement.',
  createdAt: testEpochDateTime,
  updatedAt: testEpochDateTime,
  vectorClock: null,
  private: false,
  version: '',
  lastReviewed: testEpochDateTime,
  active: true,
  id: _dashboardId,
  categoryId: categoryMindfulness.id,
);

/// A smooth daily series of [MeasurementEntry] spanning the queried range.
List<JournalEntity> _daily(
  String typeId,
  DateTime start,
  DateTime end,
  double base,
  double amplitude,
) {
  final from = DateTime(start.year, start.month, start.day);
  final days = end.difference(from).inDays;
  return [
    for (var i = 0; i <= days; i++)
      () {
        final at = from.add(Duration(days: i));
        final value =
            base + amplitude * math.sin(i / 6.0) + (i % 7) * (amplitude / 9);
        return MeasurementEntry(
          meta: Metadata(
            id: '$typeId-$i',
            createdAt: at,
            dateFrom: at,
            dateTo: at,
            updatedAt: at,
            starred: false,
            private: false,
          ),
          data: MeasurementData(
            value: value,
            dataTypeId: typeId,
            dateTo: at,
            dateFrom: at,
          ),
        );
      }(),
  ];
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary =
      tester.element(find.byKey(_boundaryKey)).findRenderObject()!
          as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir =
        Platform.environment['LOTTI_SCREENSHOT_DIR'] ??
        p.join('screenshots', 'dashboards');
    final file = File(p.join(dir, '$name.png'));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      byteData!.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
      flush: true,
    );
    stdout.writeln('wrote screenshot: ${file.path}');
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Size window,
  required double paneWidth,
}) async {
  tester.view
    ..physicalSize = window * 2
    ..devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardByIdProvider(_dashboardId).overrideWithValue(_dashboardConfig),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: DesignSystemTheme.dark(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ColoredBox(
          color: DesignSystemTheme.dark().scaffoldBackgroundColor,
          child: Center(
            child: RepaintBoundary(
              key: _boundaryKey,
              child: SizedBox(
                width: paneWidth,
                height: window.height,
                child: const DashboardPage(dashboardId: _dashboardId),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  // Let the provider cascade settle before capturing: the aggregation type
  // resolves, the observations provider re-keys to the resolved aggregation,
  // then fl_chart's ~150ms data-swap animation plays out.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  final captureEnabled =
      Platform.environment.containsKey('LOTTI_SCREENSHOT_DIR') ||
      Platform.environment['LOTTI_CAPTURE_SCREENSHOTS'] == 'true';
  if (!captureEnabled) {
    test('dashboard page screenshot harness (opt-in)', () {}, skip: 'opt-in');
    return;
  }

  setUpAll(() => registerFallbackValue(DateTime(2024)));
  setUpAll(loadScreenshotFonts);

  late MockJournalDb mockJournalDb;
  final mockCache = MockEntitiesCacheService();

  setUp(() async {
    mockJournalDb = MockJournalDb();
    final mockTimeService = MockTimeService();

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(mockJournalDb)
          ..registerSingleton<EntitiesCacheService>(mockCache)
          ..registerSingleton<NavService>(NavService())
          ..registerSingleton<UserActivityService>(UserActivityService())
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
          ..registerSingleton<TimeService>(mockTimeService);
      },
    );

    when(
      () => mockCache.getDashboardById(_dashboardId),
    ).thenReturn(_dashboardConfig);
    when(
      () => mockCache.getDataTypeById(any()),
    ).thenAnswer((inv) => _typesById[inv.positionalArguments.first]);
    when(
      mockTimeService.getStream,
    ).thenAnswer((_) => const Stream<JournalEntity>.empty());

    when(
      () => mockJournalDb.getMeasurementsByType(
        type: any(named: 'type'),
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((inv) async {
      final type = inv.namedArguments[#type] as String;
      final start = inv.namedArguments[#rangeStart] as DateTime;
      final end = inv.namedArguments[#rangeEnd] as DateTime;
      return switch (type) {
        'demo-mood' => _daily(type, start, end, 6, 2),
        'demo-steps' => _daily(type, start, end, 9000, 3500),
        _ => _daily(type, start, end, 1500, 600),
      };
    });
  });

  tearDown(tearDownTestGetIt);

  testWidgets('dashboard page — desktop detail pane (dark)', (tester) async {
    await _pump(
      tester,
      window: const Size(1280, 1400),
      paneWidth: 900,
    );
    expect(find.text('Body & Mind'), findsOneWidget);
    await _capture(tester, '30_dashboard_page_desktop_dark');
  });

  testWidgets('dashboard page — mobile (dark)', (tester) async {
    await _pump(
      tester,
      window: const Size(420, 900),
      paneWidth: 420,
    );
    expect(find.text('Body & Mind'), findsOneWidget);
    await _capture(tester, '31_dashboard_page_mobile_dark');
  });
}
