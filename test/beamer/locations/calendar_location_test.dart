import 'dart:async';
import 'dart:io';

import 'package:beamer/beamer.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/calendar_location.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/pages/daily_os_page.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/capture_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/commit_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/daily_os_next_root.dart';
import 'package:lotti/features/daily_os_next/ui/pages/refine_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/shutdown_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../features/daily_os/ui/widgets/time_history_header/test_helpers.dart'
    as daily_os;
import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

class _MockBuildContext extends Mock implements BuildContext {}

const _category = DayAgentCategory(
  id: 'cat_focus',
  name: 'Focus',
  colorHex: '0080FF',
);

DraftPlan _drafted() => DraftPlan(
  dayDate: DateTime(2026, 5, 26),
  blocks: const [],
  bands: const [],
  capacityMinutes: 240,
  scheduledMinutes: 60,
  agendaItems: const [
    AgendaItem(
      id: 'item_1',
      title: 'Deep work',
      category: _category,
      linkedBlockIds: ['blk_1'],
    ),
  ],
);

CaptureController _stubCapture() {
  final recorder = MockAudioRecorderRepository();
  final transcriber = MockAudioTranscriptionService();
  final realtime = MockRealtimeTranscriptionService();
  when(realtime.dispose).thenAnswer((_) async {});
  when(realtime.resolveRealtimeConfig).thenAnswer((_) async => null);
  when(recorder.stopRecording).thenAnswer((_) async {});
  return CaptureController(
    recorder: recorder,
    transcriber: transcriber,
    realtimeService: realtime,
    docDir: Directory.systemTemp.createTempSync,
    persistAudio: (_) async => null,
    now: () => DateTime(2026, 5, 26, 9),
  );
}

class _RouteDayAgent extends MockDayAgent {
  _RouteDayAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        draftLatency: Duration.zero,
        summarizeLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 26, 18),
      );

  @override
  Future<
    ({
      List<CompletedItem> completed,
      List<CarryoverItem> carryover,
      ShutdownMetrics metrics,
    })
  >
  surfaceShutdownData({required DateTime forDate}) async => (
    completed: const <CompletedItem>[],
    carryover: const <CarryoverItem>[],
    metrics: const ShutdownMetrics(
      focusMinutes: 0,
      flowSessions: 0,
      contextSwitches: 0,
      contextSwitchesWeekAvg: 0,
      energyScore: 0,
      energyDeltaVsWeek: 0,
    ),
  );

  @override
  Future<TomorrowNote> generateTomorrowNote({required DateTime forDate}) async {
    return const TomorrowNote(body: '', maturity: 1);
  }
}

MockDayAgent _stubDayAgent() {
  return _RouteDayAgent();
}

class _SeededPreferencesController extends DailyOsPreferencesController {
  @override
  DailyOsPreferences build() => DailyOsPreferences();
}

Widget _routeChildFor(String path, BuildContext context) {
  final routeInformation = RouteInformation(uri: Uri.parse(path));
  final location = CalendarLocation(routeInformation);
  final beamState = BeamState.fromRouteInformation(routeInformation);
  final pages = location.buildPages(context, beamState);
  return pages.last.child;
}

Widget _wrapRouteChild(
  Widget child, {
  required List<Override> overrides,
}) {
  return ProviderScope(
    overrides: [
      captureControllerProvider.overrideWith(_stubCapture),
      dailyOsPreferencesControllerProvider.overrideWith(
        _SeededPreferencesController.new,
      ),
      dayAgentProvider.overrideWith((ref) => _stubDayAgent()),
      ...overrides,
    ],
    child: makeTestableWidget2(child),
  );
}

void main() {
  group('CalendarLocation.buildPages', () {
    late _MockBuildContext mockBuildContext;

    setUp(() {
      mockBuildContext = _MockBuildContext();
    });

    test('exposes the calendar path patterns', () {
      final location = CalendarLocation(
        RouteInformation(uri: Uri.parse('/calendar')),
      );
      expect(location.pathPatterns, [
        '/calendar',
        '/calendar/set-time-blocks',
        '/calendar/refine/:date',
        '/calendar/commit/:date',
        '/calendar/shutdown/:date',
      ]);
    });

    test('builds a single CalendarRoot page for /calendar', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/calendar'));
      final location = CalendarLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(mockBuildContext, beamState);
      expect(pages.length, 1);
      expect(pages[0].key, isA<ValueKey<String>>());
      // The child branches between the current and next-gen Daily OS
      // surfaces at runtime — see [CalendarRoot] for the flag wiring.
      // Widget-level branching is covered separately in the
      // CalendarRoot widget test.
      expect(pages[0].child, isA<CalendarRoot>());
    });

    test('pushes the set-time-blocks page on the nested route', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/calendar/set-time-blocks'),
      );
      final location = CalendarLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(mockBuildContext, beamState);
      expect(pages.length, 2);
      expect(pages[0].child, isA<CalendarRoot>());
    });

    test('pushes DailyOS Next refine route as a nested page', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/calendar/refine/2026-05-26'),
      );
      final location = CalendarLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(mockBuildContext, beamState);
      expect(pages.length, 2);
      expect(pages[0].child, isA<CalendarRoot>());
      expect(
        pages[1].key,
        const ValueKey<String>('daily_os_next_refine_2026-05-26'),
      );
    });

    for (final path in [
      '/calendar/review/2026-05-26',
      '/calendar/refine/not-a-date',
    ]) {
      test('ignores invalid DailyOS Next route $path', () {
        final routeInformation = RouteInformation(uri: Uri.parse(path));
        final location = CalendarLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(routeInformation);
        final pages = location.buildPages(mockBuildContext, beamState);
        expect(pages.length, 1);
        expect(pages.single.child, isA<CalendarRoot>());
      });
    }

    testWidgets('DailyOS route loading page exposes back navigation', (
      tester,
    ) async {
      final pendingPlan = Completer<DraftPlan?>();
      await tester.pumpWidget(
        _wrapRouteChild(
          _routeChildFor('/calendar/refine/2026-05-26', mockBuildContext),
          overrides: [
            currentDraftPlanProvider.overrideWith(
              (ref, date) => pendingPlan.future,
            ),
          ],
        ),
      );
      await tester.pump();

      final messages = tester.element(find.byType(Scaffold)).messages;
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byTooltip(messages.dailyOsNextDayBack), findsOneWidget);

      await tester.tap(find.byTooltip(messages.dailyOsNextDayBack));
      await tester.pump();
    });

    testWidgets('DailyOS route error page exposes back navigation', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapRouteChild(
          _routeChildFor('/calendar/refine/2026-05-26', mockBuildContext),
          overrides: [
            currentDraftPlanProvider.overrideWith(
              (ref, date) => Future<DraftPlan?>.error(StateError('boom')),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      final messages = tester.element(find.byType(Scaffold)).messages;
      expect(find.textContaining('boom'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byTooltip(messages.dailyOsNextDayBack), findsOneWidget);
    });

    testWidgets('DailyOS route falls back to capture when no plan exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapRouteChild(
          _routeChildFor('/calendar/refine/2026-05-26', mockBuildContext),
          overrides: [
            currentDraftPlanProvider.overrideWith((ref, date) async => null),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CapturePage), findsOneWidget);
      expect(find.byType(RefinePage), findsNothing);
    });

    testWidgets('DailyOS route resolves refine target with the current plan', (
      tester,
    ) async {
      final draft = _drafted();
      await tester.pumpWidget(
        _wrapRouteChild(
          _routeChildFor('/calendar/refine/2026-05-26', mockBuildContext),
          overrides: [
            currentDraftPlanProvider.overrideWith((ref, date) async => draft),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      final messages = tester.element(find.byType(RefinePage)).messages;
      expect(find.byType(RefinePage), findsOneWidget);
      expect(find.text(messages.dailyOsNextRefineTitle), findsOneWidget);
    });

    testWidgets('DailyOS route resolves commit target with the current plan', (
      tester,
    ) async {
      final draft = _drafted();
      await tester.pumpWidget(
        _wrapRouteChild(
          _routeChildFor('/calendar/commit/2026-05-26', mockBuildContext),
          overrides: [
            currentDraftPlanProvider.overrideWith((ref, date) async => draft),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CommitPage), findsOneWidget);
      expect(find.text('Deep work'), findsOneWidget);
    });

    testWidgets('DailyOS route resolves shutdown target for the date', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapRouteChild(
          _routeChildFor('/calendar/shutdown/2026-05-26', mockBuildContext),
          overrides: [
            currentDraftPlanProvider.overrideWith(
              (ref, date) async => _drafted(),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(ShutdownPage), findsOneWidget);
    });
  });

  group('CalendarRoot flag branching', () {
    late MockJournalDb mockJournalDb;

    setUp(() async {
      final mocks = await setUpTestGetIt();
      mockJournalDb = mocks.journalDb;
      // Registers EntitiesCacheService + theming services so the legacy
      // DailyOsPage subtree can build on the `false` branch.
      daily_os.setUpEntitiesCacheService();
    });

    tearDown(() async {
      daily_os.tearDownEntitiesCacheService();
      await tearDownTestGetIt();
    });

    // Overrides the legacy DailyOsPage data providers so its full widget
    // tree renders without hitting the database. Mirrors the override set
    // used by the dedicated DailyOsPage widget test.
    List<Override> dailyOsPageOverrides() => [
      dailyOsSelectedDateProvider.overrideWith(
        () => daily_os.TestDailyOsSelectedDate(daily_os.testDate),
      ),
      timeHistoryHeaderControllerProvider.overrideWith(
        () => daily_os.TestTimeHistoryController(
          daily_os.createTestHistoryData(),
        ),
      ),
      unifiedDailyOsDataControllerProvider(
        date: daily_os.testDate,
      ).overrideWith(
        () => daily_os.TestUnifiedController(daily_os.createUnifiedData()),
      ),
      dayBudgetStatsProvider(date: daily_os.testDate).overrideWith(
        (ref) async => const DayBudgetStats(
          totalPlanned: Duration.zero,
          totalRecorded: Duration.zero,
          budgetCount: 0,
          overBudgetCount: 0,
        ),
      ),
      activeFocusCategoryIdProvider.overrideWith((ref) => Stream.value(null)),
      runningTimerCategoryIdProvider.overrideWithValue(null),
    ];

    Future<void> pumpCalendarRoot(
      WidgetTester tester, {
      required Stream<bool> flagStream,
      List<Override> overrides = const [],
    }) async {
      when(
        () => mockJournalDb.watchConfigFlag(dailyOsNextEnabledFlag),
      ).thenAnswer((_) => flagStream);

      await withClock(Clock.fixed(DateTime(2026, 1, 15)), () async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides,
            child: makeTestableWidget2(const CalendarRoot()),
          ),
        );
      });
    }

    testWidgets(
      'renders the legacy DailyOsPage when the next flag is disabled',
      (tester) async {
        await pumpCalendarRoot(
          tester,
          // Never emits, so the StreamBuilder stays on initialData == false.
          flagStream: const Stream<bool>.empty(),
          overrides: dailyOsPageOverrides(),
        );
        await tester.pump();

        expect(find.byType(DailyOsPage), findsOneWidget);
        expect(find.byType(DailyOsNextRoot), findsNothing);
      },
    );

    testWidgets('switches to DailyOsNextRoot when the next flag is enabled', (
      tester,
    ) async {
      // Keep the next-gen surface on its lightweight loading shell so the
      // assertion targets the branch selection, not DayPage's data deps.
      final pendingPlan = Completer<DraftPlan?>();
      await pumpCalendarRoot(
        tester,
        flagStream: Stream<bool>.value(true),
        overrides: [
          currentDraftPlanProvider.overrideWith(
            (ref, date) => pendingPlan.future,
          ),
        ],
      );
      // Let the StreamBuilder receive the `true` value.
      await tester.pump();

      expect(find.byType(DailyOsNextRoot), findsOneWidget);
      expect(find.byType(DailyOsPage), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('re-evaluates the branch when the flag stream emits', (
      tester,
    ) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);
      final pendingPlan = Completer<DraftPlan?>();
      await pumpCalendarRoot(
        tester,
        flagStream: controller.stream,
        overrides: [
          ...dailyOsPageOverrides(),
          currentDraftPlanProvider.overrideWith(
            (ref, date) => pendingPlan.future,
          ),
        ],
      );
      await tester.pump();

      // initialData == false -> legacy surface.
      expect(find.byType(DailyOsPage), findsOneWidget);
      expect(find.byType(DailyOsNextRoot), findsNothing);

      controller.add(true);
      await tester.pump();

      expect(find.byType(DailyOsNextRoot), findsOneWidget);
      expect(find.byType(DailyOsPage), findsNothing);
    });
  });
}
