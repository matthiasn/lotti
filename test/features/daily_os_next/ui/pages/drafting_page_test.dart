import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/drafting_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/drafting_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/learning_cards.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/skeleton_agenda.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

const _category = DayAgentCategory(
  id: 'cat_focus',
  name: 'Focus',
  colorHex: '0080FF',
);

DraftPlan _readyPlan() => DraftPlan(
  dayDate: DateTime(2026, 5, 26),
  blocks: const [],
  bands: const [],
  capacityMinutes: 240,
  scheduledMinutes: 0,
  agendaItems: const [
    AgendaItem(
      id: 'a',
      title: 'Deep work',
      category: _category,
      linkedBlockIds: ['blk_1'],
    ),
  ],
);

LearningCard _card({String id = 'lc', String overline = 'YESTERDAY'}) =>
    LearningCard(
      id: id,
      overline: overline,
      summary: 'You shipped 3 things.',
      bullets: const [
        LearningBullet(
          text: 'Carry forward: design polish',
          tone: LearningBulletTone.info,
        ),
      ],
    );

class _FakeAgent implements DayAgentInterface {
  _FakeAgent({
    Completer<List<LearningCard>>? learnings,
    Completer<DraftPlan>? draft,
  }) : learnings = learnings ?? Completer<List<LearningCard>>(),
       draft = draft ?? Completer<DraftPlan>();

  Completer<List<LearningCard>> learnings;
  Completer<DraftPlan> draft;
  CaptureId? capturedCaptureId;
  List<String>? capturedTaskIds;
  List<String>? capturedCaptureItemIds;
  DateTime? capturedDate;

  @override
  Future<List<LearningCard>> summarizeRecentPatterns({
    required DateTime asOf,
    int lookbackDays = 7,
  }) => learnings.future;

  @override
  Future<DraftPlan> draftDayPlan({
    required CaptureId captureId,
    required List<String> decidedTaskIds,
    required DateTime dayDate,
    List<String> decidedCaptureItemIds = const [],
    List<TimeBlock> calendarBlocks = const [],
    bool Function()? isCancelled,
  }) {
    capturedCaptureId = captureId;
    capturedTaskIds = decidedTaskIds;
    capturedCaptureItemIds = decidedCaptureItemIds;
    capturedDate = dayDate;
    return draft.future;
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
  Future<bool> deletePlanForDate(DateTime date) async => true;

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

class _ThrowingDraftAgent extends _FakeAgent {
  @override
  Future<DraftPlan> draftDayPlan({
    required CaptureId captureId,
    required List<String> decidedTaskIds,
    required DateTime dayDate,
    List<String> decidedCaptureItemIds = const [],
    List<TimeBlock> calendarBlocks = const [],
    bool Function()? isCancelled,
  }) {
    throw StateError('drafting unavailable');
  }
}

DraftingPage _page({
  bool returnToRootOnReady = false,
}) => DraftingPage(
  captureId: const CaptureId('cap_x'),
  decidedTaskIds: const ['task_1'],
  decidedCaptureItemIds: const ['parsed_1'],
  dayDate: DateTime(2026, 5, 26),
  returnToRootOnReady: returnToRootOnReady,
);

Widget _wrap(
  Widget child, {
  required _FakeAgent agent,
  List<Override> overrides = const [],
  Size size = const Size(1280, 1200),
}) {
  return ProviderScope(
    overrides: [
      dayAgentProvider.overrideWithValue(agent),
      // DayPage builds CapturesPanel which reads this provider; stub so
      // the panel collapses to SizedBox.shrink and the day-agent service
      // chain is never touched.
      capturesForDateProvider.overrideWith((ref, _) async => const []),
      ...overrides,
    ],
    child: makeTestableWidget2(
      child,
      mediaQueryData: MediaQueryData(size: size),
    ),
  );
}

void _setSurface(WidgetTester tester, [Size size = const Size(1280, 1200)]) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('DraftingPage', () {
    testWidgets('initial loading state shows a CircularProgressIndicator', (
      tester,
    ) async {
      _setSurface(tester);
      final agent = _FakeAgent();
      await tester.pumpWidget(_wrap(_page(), agent: agent));
      // No pump that runs microtasks → controller's build() still pending.
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets(
      'once learnings resolve: skeleton + header + learning cards render',
      (tester) async {
        _setSurface(tester);
        final agent = _FakeAgent();
        await tester.pumpWidget(_wrap(_page(), agent: agent));
        await tester.pump();

        agent.learnings.complete([_card()]);
        await tester.pump();
        await tester.pump();

        final messages = tester.element(find.byType(DraftingPage)).messages;
        expect(find.text(messages.dailyOsNextDraftingHeader), findsOneWidget);
        expect(find.byType(SkeletonAgenda), findsOneWidget);
        expect(find.byType(LearningCardsColumn), findsOneWidget);
        expect(find.text('YESTERDAY'), findsOneWidget);
      },
    );

    testWidgets('keeps drafting body during provider refreshes', (
      tester,
    ) async {
      _setSurface(tester);
      final agent = _FakeAgent();
      await tester.pumpWidget(_wrap(_page(), agent: agent));
      await tester.pump();

      agent.learnings.complete([_card()]);
      await tester.pump();
      await tester.pump();

      final messages = tester.element(find.byType(DraftingPage)).messages;
      expect(find.text(messages.dailyOsNextDraftingHeader), findsOneWidget);
      expect(find.byType(SkeletonAgenda), findsOneWidget);
      expect(find.text('YESTERDAY'), findsOneWidget);

      agent.learnings = Completer<List<LearningCard>>();
      addTearDown(() {
        if (!agent.learnings.isCompleted) agent.learnings.complete(const []);
      });
      ProviderScope.containerOf(
        tester.element(find.byType(DraftingPage)),
      ).invalidate(
        draftingControllerProvider(
          DraftingParams(
            captureId: const CaptureId('cap_x'),
            decidedTaskIds: const ['task_1'],
            decidedCaptureItemIds: const ['parsed_1'],
            dayDate: DateTime(2026, 5, 26),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(messages.dailyOsNextDraftingHeader), findsOneWidget);
      expect(find.byType(SkeletonAgenda), findsOneWidget);
      expect(find.text('YESTERDAY'), findsOneWidget);
    });

    testWidgets('learnings failure renders an empty cards column gracefully', (
      tester,
    ) async {
      _setSurface(tester);
      final agent = _FakeAgent();
      await tester.pumpWidget(_wrap(_page(), agent: agent));
      await tester.pump();

      agent.learnings.completeError('learnings broke');
      await tester.pump();
      await tester.pump();

      // Page still renders the skeleton + header, just no cards content.
      final messages = tester.element(find.byType(DraftingPage)).messages;
      expect(find.text(messages.dailyOsNextDraftingHeader), findsOneWidget);
      expect(find.byType(SkeletonAgenda), findsOneWidget);
      // The learning cards column either isn't built or renders no cards.
      expect(find.text('YESTERDAY'), findsNothing);
    });

    testWidgets('initial controller failure renders localized error copy', (
      tester,
    ) async {
      _setSurface(tester);
      await tester.pumpWidget(_wrap(_page(), agent: _ThrowingDraftAgent()));
      await tester.pump();
      await tester.pump();

      final messages = tester.element(find.byType(DraftingPage)).messages;
      expect(find.text(messages.dailyOsNextGenericError), findsOneWidget);
      expect(find.textContaining('drafting unavailable'), findsNothing);
    });

    testWidgets('narrow layout (< 900) stacks left + right in a Column', (
      tester,
    ) async {
      _setSurface(tester, const Size(600, 1400));
      final agent = _FakeAgent();
      await tester.pumpWidget(
        _wrap(_page(), agent: agent, size: const Size(600, 1400)),
      );
      await tester.pump();

      agent.learnings.complete([_card()]);
      await tester.pump();
      await tester.pump();

      // Both sections rendered in vertical column.
      expect(find.byType(SkeletonAgenda), findsOneWidget);
      expect(find.byType(LearningCardsColumn), findsOneWidget);
    });

    testWidgets(
      'draft resolution (returnToRootOnReady=false) pushReplacements to DayPage',
      (tester) async {
        _setSurface(tester);
        final agent = _FakeAgent();
        await tester.pumpWidget(_wrap(_page(), agent: agent));
        await tester.pump();

        agent.learnings.complete([_card()]);
        await tester.pump();
        await tester.pump();

        agent.draft.complete(_readyPlan());
        // ref.listen + post-frame callback + new route transition.
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(DayPage), findsOneWidget);
        expect(find.byType(DraftingPage), findsNothing);
        // Agent was called with the params from the widget.
        expect(agent.capturedCaptureId, const CaptureId('cap_x'));
        expect(agent.capturedTaskIds, ['task_1']);
        expect(agent.capturedCaptureItemIds, ['parsed_1']);
        expect(agent.capturedDate, DateTime(2026, 5, 26));
      },
    );

    testWidgets(
      'draft failure after the first body keeps stale drafting content mounted',
      (tester) async {
        _setSurface(tester);
        final agent = _FakeAgent();
        await tester.pumpWidget(_wrap(_page(), agent: agent));
        await tester.pump();

        agent.learnings.complete([_card()]);
        await tester.pump();
        await tester.pump();

        agent.draft.completeError('drafting blew up');
        await tester.pump();
        await tester.pump();

        final messages = tester.element(find.byType(DraftingPage)).messages;
        expect(find.text(messages.dailyOsNextDraftingHeader), findsOneWidget);
        expect(find.byType(SkeletonAgenda), findsOneWidget);
        expect(find.textContaining('drafting blew up'), findsNothing);
      },
    );
  });
}
