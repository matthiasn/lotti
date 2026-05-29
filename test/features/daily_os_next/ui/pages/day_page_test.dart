import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/daily_os_next_routes.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/refine_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

const _category = DayAgentCategory(
  id: 'cat_focus',
  name: 'Focus',
  colorHex: '0080FF',
);

DraftPlan _drafted({
  DayState state = DayState.drafted,
  String title = 'Deep work',
}) => DraftPlan(
  dayDate: DateTime(2026, 5, 26),
  blocks: const [],
  bands: const [],
  capacityMinutes: 240,
  scheduledMinutes: 120,
  state: state,
  agendaItems: [
    AgendaItem(
      id: 'item_1',
      title: title,
      category: _category,
      linkedBlockIds: const ['blk_1'],
    ),
  ],
);

class _RecordingAgent implements DayAgentInterface {
  DateTime? deletedFor;
  int deleteCount = 0;

  @override
  Future<bool> deletePlanForDate(DateTime date) async {
    deletedFor = date;
    deleteCount++;
    return true;
  }

  // ---- Unused interface members ----
  @override
  Future<CaptureId> submitCapture({
    required String transcript,
    required DateTime capturedAt,
    String? audioId,
  }) async => const CaptureId('cap');

  @override
  Future<DraftPlan?> currentPlanForDate(DateTime date) async => null;

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) async => const [];

  @override
  Future<List<PendingItem>> surfacePendingDecisions({
    DateTime? forDate,
  }) async => const [];

  @override
  Future<ParsedItem> breakCaptureLink(String parsedItemId) async =>
      throw UnimplementedError();

  @override
  Future<TriageResult> applyTriage({
    required String taskId,
    required TriageAction action,
    DateTime? deferTo,
  }) async => TriageResult(taskId: taskId, action: action);

  @override
  Future<DraftPlan> draftDayPlan({
    required CaptureId captureId,
    required List<String> decidedTaskIds,
    required DateTime dayDate,
    List<String> decidedCaptureItemIds = const [],
    List<TimeBlock> calendarBlocks = const [],
    bool Function()? isCancelled,
  }) async => _drafted();

  @override
  Future<List<LearningCard>> summarizeRecentPatterns({
    required DateTime asOf,
    int lookbackDays = 7,
  }) async => const [];

  @override
  Future<PlanDiff> proposePlanDiff({
    required DraftPlan currentPlan,
    required String voiceTranscript,
    bool Function()? isCancelled,
  }) async => PlanDiff(
    id: 'd',
    transcript: voiceTranscript,
    changes: const [],
    updatedPlan: currentPlan,
  );

  @override
  Future<DraftPlan> acceptDiff(PlanDiff diff, {List<int>? itemIndices}) async =>
      diff.updatedPlan;

  @override
  Future<DraftPlan> revertDiff({
    required PlanDiff diff,
    required DraftPlan originalPlan,
    List<int>? itemIndices,
  }) async => originalPlan;

  @override
  Future<DraftPlan> commitDay(DraftPlan plan) async =>
      plan.copyWith(state: DayState.committed);

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
  Future<void> recordReflection({
    required DateTime forDate,
    required String text,
    required ReflectionSource source,
  }) async {}

  @override
  Future<void> recordCarryoverDecision({
    required String taskId,
    required CarryoverAction action,
    DateTime? when,
  }) async {}

  @override
  Future<TomorrowNote> generateTomorrowNote({
    required DateTime forDate,
  }) async => const TomorrowNote(body: '', maturity: 1);

  @override
  Future<List<TaskCorpusItem>> surfaceTaskCorpus({
    TaskCorpusState stateFilter = TaskCorpusState.all,
    String? categoryId,
    String? query,
  }) async => const [];
}

/// Stub the realtime service so CaptureController (built by RefinePage
/// when DayPage pushes it) can dispose cleanly without touching the AI
/// providers during teardown.
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

Widget _wrap(
  Widget child, {
  List<Override> overrides = const [],
  Size size = const Size(1400, 1200),
  MediaQueryData? mediaQueryData,
}) {
  return ProviderScope(
    overrides: [
      // CapturesPanel watches this; stub to empty so the panel collapses
      // to SizedBox.shrink instead of touching the DB.
      capturesForDateProvider.overrideWith((ref, date) async => const []),
      dailyOsActualTimeBlocksProvider.overrideWith(
        (ref, date) async => const [],
      ),
      // RefinePage builds a CaptureController; stub so it doesn't read
      // the realtime service providers during dispose.
      captureControllerProvider.overrideWith(_stubCapture),
      ...overrides,
    ],
    child: makeTestableWidget2(
      child,
      mediaQueryData: mediaQueryData ?? MediaQueryData(size: size),
    ),
  );
}

Widget _dateStripLike(String label) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: const Icon(Icons.chevron_left_rounded),
        onPressed: () {},
      ),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      IconButton(
        icon: const Icon(Icons.chevron_right_rounded),
        onPressed: () {},
      ),
    ],
  );
}

void _setSurfaceSize(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void _setSurface(WidgetTester tester) {
  _setSurfaceSize(tester, const Size(1400, 1200));
}

void main() {
  tearDown(() {
    nav_service.beamToNamedOverride = null;
  });

  group('DayPage', () {
    testWidgets('default title and AgendaView render, DayTimeline absent', (
      tester,
    ) async {
      _setSurface(tester);
      await tester.pumpWidget(_wrap(DayPage(draft: _drafted())));
      await tester.pump();

      final messages = tester.element(find.byType(DayPage)).messages;
      expect(find.text(messages.dailyOsNextDayTitle), findsOneWidget);
      expect(find.byType(AgendaView), findsOneWidget);
      expect(find.byType(DayTimeline), findsNothing);
    });

    testWidgets('dateStrip widget replaces the default title', (tester) async {
      _setSurface(tester);
      await tester.pumpWidget(
        _wrap(
          DayPage(
            draft: _drafted(),
            dateStrip: const Text('2026-05-26'),
          ),
        ),
      );
      await tester.pump();

      final messages = tester.element(find.byType(DayPage)).messages;
      expect(find.text(messages.dailyOsNextDayTitle), findsNothing);
      expect(find.text('2026-05-26'), findsOneWidget);
    });

    testWidgets('header keeps the plan toggle inline when it fits', (
      tester,
    ) async {
      _setSurfaceSize(tester, const Size(640, 844));
      const label = 'May 31, 2026';
      await tester.pumpWidget(
        _wrap(
          DayPage(
            draft: _drafted(),
            dateStrip: _dateStripLike(label),
          ),
          mediaQueryData: phoneMediaQueryData.copyWith(
            size: const Size(640, 844),
          ),
        ),
      );
      await tester.pump();

      final dateTop = tester.getTopLeft(find.text(label)).dy;
      final dateBottom = tester.getBottomLeft(find.text(label)).dy;
      final toggleTop = tester.getTopLeft(find.byType(PlanViewToggle)).dy;
      final toggleBottom = tester.getBottomLeft(find.byType(PlanViewToggle)).dy;

      expect(toggleTop, lessThan(dateBottom));
      expect(toggleBottom, greaterThan(dateTop));
      expect(tester.takeException(), isNull);
    });

    testWidgets('header moves the plan toggle below only when it cannot fit', (
      tester,
    ) async {
      _setSurfaceSize(tester, phoneMediaQueryData.size);
      const label = 'May 31, 2026';
      await tester.pumpWidget(
        _wrap(
          DayPage(
            draft: _drafted(),
            dateStrip: _dateStripLike(label),
          ),
          mediaQueryData: phoneMediaQueryData,
        ),
      );
      await tester.pump();

      final dateBottom = tester.getBottomLeft(find.text(label)).dy;
      final toggleTop = tester.getTopLeft(find.byType(PlanViewToggle)).dy;

      expect(find.text(label), findsOneWidget);
      expect(toggleTop, greaterThan(dateBottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('toggling the plan view switches Agenda → DayTimeline', (
      tester,
    ) async {
      _setSurface(tester);
      await tester.pumpWidget(_wrap(DayPage(draft: _drafted())));
      await tester.pump();

      expect(find.byType(AgendaView), findsOneWidget);
      expect(find.byType(DayTimeline), findsNothing);

      // Drive the toggle directly; chip tap behavior is covered by
      // PlanViewToggle's focused widget tests.
      final toggle = tester.widget<PlanViewToggle>(find.byType(PlanViewToggle));
      toggle.onChanged(PlanView.day);
      await tester.pump();

      expect(find.byType(AgendaView), findsNothing);
      expect(find.byType(DayTimeline), findsOneWidget);
    });

    testWidgets('drafted footer shows Refine + Lock In CTAs (no Wrap up)', (
      tester,
    ) async {
      _setSurface(tester);
      await tester.pumpWidget(_wrap(DayPage(draft: _drafted())));
      await tester.pump();

      final messages = tester.element(find.byType(DayPage)).messages;
      expect(find.byType(DesignSystemGlassStrip), findsOneWidget);
      expect(find.text(messages.dailyOsNextDayRefineCta), findsOneWidget);
      expect(find.text(messages.dailyOsNextDayLockInCta), findsOneWidget);
      expect(find.text(messages.dailyOsNextDayWrapUpCta), findsNothing);
    });

    testWidgets('committed footer swaps Lock In for Wrap up', (tester) async {
      _setSurface(tester);
      await tester.pumpWidget(
        _wrap(DayPage(draft: _drafted(state: DayState.committed))),
      );
      await tester.pump();

      final messages = tester.element(find.byType(DayPage)).messages;
      expect(find.text(messages.dailyOsNextDayLockInCta), findsNothing);
      expect(find.text(messages.dailyOsNextDayWrapUpCta), findsOneWidget);
      expect(find.text(messages.dailyOsNextDayRefineCta), findsOneWidget);
    });

    testWidgets('syncs displayed agenda when the draft prop changes', (
      tester,
    ) async {
      _setSurface(tester);
      await tester.pumpWidget(_wrap(DayPage(draft: _drafted())));
      await tester.pump();

      expect(find.text('Deep work'), findsOneWidget);
      expect(find.text('Evening meeting'), findsNothing);

      await tester.pumpWidget(
        _wrap(DayPage(draft: _drafted(title: 'Evening meeting'))),
      );
      await tester.pump();

      expect(find.text('Deep work'), findsNothing);
      expect(find.text('Evening meeting'), findsOneWidget);
    });

    testWidgets('mobile footer clears the bottom navigation hit area', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DayPage(draft: _drafted()),
          mediaQueryData: phoneMediaQueryData,
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(DayPage));
      final bottomNavHeight = DesignSystemBottomNavigationBar.occupiedHeight(
        context,
      );
      final messages = context.messages;
      final lockInBottom = tester
          .getBottomLeft(find.text(messages.dailyOsNextDayLockInCta))
          .dy;

      expect(
        lockInBottom,
        lessThan(phoneMediaQueryData.size.height - bottomNavHeight),
      );
      expect(
        tester.getCenter(find.text(messages.dailyOsNextDayRefineCta)),
        isA<Offset>(),
      );
    });

    testWidgets('popup menu exposes Inspect agent + Delete plan items', (
      tester,
    ) async {
      _setSurface(tester);
      await tester.pumpWidget(_wrap(DayPage(draft: _drafted())));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final messages = tester.element(find.byType(DayPage)).messages;
      expect(
        find.text(messages.dailyOsNextDayMenuInspectAgent),
        findsOneWidget,
      );
      expect(find.text(messages.dailyOsNextDayMenuDeletePlan), findsOneWidget);
    });

    testWidgets(
      'Delete plan flow: confirm dialog → confirm calls agent with day date',
      (tester) async {
        _setSurface(tester);
        final agent = _RecordingAgent();
        final draft = _drafted();
        await tester.pumpWidget(
          _wrap(
            DayPage(draft: draft),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.more_vert_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final messages = tester.element(find.byType(DayPage)).messages;
        await tester.tap(find.text(messages.dailyOsNextDayMenuDeletePlan));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          find.text(messages.dailyOsNextDayDeleteDialogTitle),
          findsOneWidget,
        );
        await tester.tap(
          find.text(messages.dailyOsNextDayDeleteDialogConfirm),
        );
        await tester.pump();
        await tester.pump();

        expect(agent.deleteCount, 1);
        expect(agent.deletedFor, draft.dayDate);
      },
    );

    testWidgets(
      'header back IconButton pops the navigator (no dateStrip)',
      (tester) async {
        _setSurface(tester);
        final agent = _RecordingAgent();
        var popped = false;
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => DayPage(draft: _drafted()),
                      ),
                    );
                    popped = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 200));

        // The header shows a back button only when there's no dateStrip;
        // the popup-menu's more_vert icon stays in place.
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        expect(popped, isTrue);
        expect(find.byType(DayPage), findsNothing);
      },
    );

    testWidgets(
      'tapping Refine opens the modal over the current day page',
      (tester) async {
        _setSurface(tester);
        final agent = _RecordingAgent();
        final draft = _drafted();
        await tester.pumpWidget(
          _wrap(
            DayPage(draft: draft),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump();

        final messages = tester.element(find.byType(DayPage)).messages;
        await tester.tap(find.text(messages.dailyOsNextDayRefineCta));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byType(DayPage), findsOneWidget);
        expect(find.byType(RefineModalContent), findsOneWidget);
        expect(find.text(messages.dailyOsNextRefineTitle), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Lock In beams to the DailyOS commit route',
      (tester) async {
        _setSurface(tester);
        final agent = _RecordingAgent();
        String? route;
        nav_service.beamToNamedOverride = (path) => route = path;
        final draft = _drafted();
        await tester.pumpWidget(
          _wrap(
            DayPage(draft: draft),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump();

        final messages = tester.element(find.byType(DayPage)).messages;
        await tester.tap(find.text(messages.dailyOsNextDayLockInCta));
        await tester.pump();

        expect(
          route,
          dailyOsNextRoutePath(DailyOsNextRouteTarget.commit, draft.dayDate),
        );
        expect(find.byType(DayPage), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Wrap up beams to the DailyOS shutdown route',
      (tester) async {
        _setSurface(tester);
        final agent = _RecordingAgent();
        String? route;
        nav_service.beamToNamedOverride = (path) => route = path;
        final draft = _drafted(state: DayState.committed);
        await tester.pumpWidget(
          _wrap(
            DayPage(draft: draft),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump();

        final messages = tester.element(find.byType(DayPage)).messages;
        await tester.tap(find.text(messages.dailyOsNextDayWrapUpCta));
        await tester.pump();

        expect(
          route,
          dailyOsNextRoutePath(DailyOsNextRouteTarget.shutdown, draft.dayDate),
        );
        expect(find.byType(DayPage), findsOneWidget);
      },
    );

    testWidgets('Delete plan dialog Cancel does not call the agent', (
      tester,
    ) async {
      _setSurface(tester);
      final agent = _RecordingAgent();
      await tester.pumpWidget(
        _wrap(
          DayPage(draft: _drafted()),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final messages = tester.element(find.byType(DayPage)).messages;
      await tester.tap(find.text(messages.dailyOsNextDayMenuDeletePlan));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text(messages.dailyOsNextDayDeleteDialogCancel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(agent.deleteCount, 0);
      expect(
        find.text(messages.dailyOsNextDayDeleteDialogTitle),
        findsNothing,
      );
    });
  });
}
