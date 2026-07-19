import 'dart:async';
import 'dart:io';

import 'package:beamer/beamer.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/beamer/locations/calendar_location.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/daily_os_next_routes.dart';
import 'package:lotti/features/daily_os_next/ui/pages/capture_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/commit_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/daily_os_next_root.dart';
import 'package:lotti/features/daily_os_next/ui/pages/refine_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/shutdown_page.dart';
import 'package:lotti/features/insights/ui/time_analysis_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

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
  final transcriber = MockAudioTranscriptionService();
  final realtime = MockRealtimeTranscriptionService();
  when(realtime.resolveRealtimeConfig).thenAnswer((_) async => null);
  return CaptureController(
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
        '/calendar/time',
        '/calendar/refine/:date',
        '/calendar/commit/:date',
        '/calendar/shutdown/:date',
      ]);
    });

    test(
      'pushes the full-screen Time Analysis page on /calendar/time and '
      'mirrors the route into desktopShowTimeAnalysis',
      () async {
        final navService = MockNavService();
        final showTimeAnalysis = ValueNotifier<bool>(false);
        final showAiImpact = ValueNotifier<bool>(true);
        when(
          () => navService.desktopShowTimeAnalysis,
        ).thenReturn(showTimeAnalysis);
        when(
          () => navService.desktopShowAiImpact,
        ).thenReturn(showAiImpact);
        // Shared harness owns the GetIt lifecycle; NavService rides its
        // additionalSetup extension point.
        await setUpTestGetIt(
          additionalSetup: () {
            getIt.registerSingleton<NavService>(navService);
          },
        );
        addTearDown(tearDownTestGetIt);
        addTearDown(showTimeAnalysis.dispose);
        addTearDown(showAiImpact.dispose);

        final routeInformation = RouteInformation(
          uri: Uri.parse('/calendar/time'),
        );
        final location = CalendarLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(routeInformation);
        final pages = location.buildPages(mockBuildContext, beamState);

        expect(pages.length, 2);
        expect(pages[0].child, isA<CalendarRoot>());
        expect(pages[1].child, isA<TimeAnalysisPage>());
        expect(showTimeAnalysis.value, isTrue);
        expect(showAiImpact.value, isFalse);

        // Navigating back to the root clears the highlight.
        final rootInformation = RouteInformation(uri: Uri.parse('/calendar'));
        CalendarLocation(rootInformation).buildPages(
          mockBuildContext,
          BeamState.fromRouteInformation(rootInformation),
        );
        expect(showTimeAnalysis.value, isFalse);
      },
    );

    test('builds a single CalendarRoot page for /calendar', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/calendar'));
      final location = CalendarLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(mockBuildContext, beamState);
      expect(pages.length, 1);
      expect(pages[0].key, isA<ValueKey<String>>());
      // The DailyOsNextRoot mount itself is covered in the
      // CalendarRoot widget test below.
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

    glados.Glados3(
      glados.AnyUtils(glados.any).choose(const ['calendar', 'cal', 'journal']),
      glados.AnyUtils(glados.any).choose(const [
        'refine',
        'commit',
        'shutdown',
        'review',
        'REFINE',
        '',
      ]),
      glados.AnyUtils(glados.any).choose(const [
        '2026-05-26',
        '2026-12-31',
        '2026-13-40',
        'not-a-date',
        '20260526',
        '',
      ]),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'daily-os nested page appears iff the URI is a valid '
      '(calendar, target, ISO date) triple',
      (first, second, third) {
        final uri = Uri.parse('/$first/$second/$third');
        final routeInformation = RouteInformation(uri: uri);
        final location = CalendarLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(routeInformation);
        final pages = location.buildPages(mockBuildContext, beamState);
        final reason = 'uri=$uri';

        // Oracle mirroring the route contract.
        final segments = uri.pathSegments;
        final targetValid =
            segments.length == 3 &&
            segments.first == 'calendar' &&
            DailyOsNextRouteTarget.values.any((t) => t.name == segments[1]);
        final date = segments.length == 3
            ? parseDailyOsNextRouteDate(segments[2])
            : null;
        final expectDailyOsPage = targetValid && date != null;

        expect(pages.first.child, isA<CalendarRoot>(), reason: reason);
        if (expectDailyOsPage) {
          expect(pages, hasLength(2), reason: reason);
          expect(
            pages[1].key,
            ValueKey<String>('daily_os_next_${segments[1]}_${segments[2]}'),
            reason: reason,
          );
        } else {
          expect(pages, hasLength(1), reason: reason);
        }
      },
      tags: 'glados',
    );

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

  group('CalendarRoot', () {
    setUp(() async {
      await setUpTestGetIt();
    });

    tearDown(tearDownTestGetIt);

    testWidgets('mounts the agentic DailyOS surface', (tester) async {
      // Keep the next-gen surface on its lightweight loading shell so the
      // assertion targets the mount, not DayPage's data deps.
      final pendingPlan = Completer<DraftPlan?>();
      await withClock(Clock.fixed(DateTime(2026, 1, 15)), () async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentDraftPlanProvider.overrideWith(
                (ref, date) => pendingPlan.future,
              ),
            ],
            child: makeTestableWidget2(const CalendarRoot()),
          ),
        );
      });
      await tester.pump();

      expect(find.byType(DailyOsNextRoot), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
