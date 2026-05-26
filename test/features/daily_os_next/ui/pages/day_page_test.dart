import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

const _category = DayAgentCategory(
  id: 'cat_focus',
  name: 'Focus',
  colorHex: '0080FF',
);

DraftPlan _drafted({DayState state = DayState.drafted}) => DraftPlan(
  dayDate: DateTime(2026, 5, 26),
  blocks: const [],
  bands: const [],
  capacityMinutes: 240,
  scheduledMinutes: 120,
  state: state,
  agendaItems: const [
    AgendaItem(
      id: 'item_1',
      title: 'Deep work',
      category: _category,
      linkedBlockIds: ['blk_1'],
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

Widget _wrap(
  Widget child, {
  List<Override> overrides = const [],
  Size size = const Size(1400, 1200),
}) {
  return ProviderScope(
    overrides: [
      // CapturesPanel watches this; stub to empty so the panel collapses
      // to SizedBox.shrink instead of touching the DB.
      capturesForDateProvider.overrideWith((ref, date) async => const []),
      ...overrides,
    ],
    child: makeTestableWidget2(
      child,
      mediaQueryData: MediaQueryData(size: size),
    ),
  );
}

void _setSurface(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1400, 1200)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
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

    testWidgets('toggling the plan view switches Agenda → DayTimeline', (
      tester,
    ) async {
      _setSurface(tester);
      await tester.pumpWidget(_wrap(DayPage(draft: _drafted())));
      await tester.pump();

      expect(find.byType(AgendaView), findsOneWidget);
      expect(find.byType(DayTimeline), findsNothing);

      // Drive the toggle directly; tapping its rendered chips is brittle
      // because the toggle is in the AppBar actions slot.
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
