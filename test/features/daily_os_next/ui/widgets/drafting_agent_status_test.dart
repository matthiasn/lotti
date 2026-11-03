import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_wake_progress.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/drafting_agent_status.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/test_app.dart';

const _dayId = 'dayplan-2026-11-04';
final _t0 = DateTime(2026, 11, 3, 21);
Duration _ms(int ms) => Duration(milliseconds: ms);

DayAgentWakeProgress _wake({
  DayAgentWakeStep step = DayAgentWakeStep.callingModel,
  DateTime? startedAt,
  DateTime? stepStartedAt,
  List<DayAgentWakeStepTiming> completedSteps = const [],
  List<DayAgentModelTurn> turns = const [],
  List<DayAgentToolCallTiming> toolCalls = const [],
  String? modelId = 'deepseek-v4-1-flash-1017',
}) => DayAgentWakeProgress(
  dayId: _dayId,
  runKey: 'run-1',
  step: step,
  startedAt: startedAt ?? _t0.add(_ms(1000)),
  stepStartedAt: stepStartedAt ?? _t0.add(_ms(9000)),
  modelId: modelId,
  completedSteps: completedSteps,
  turns: turns,
  toolCalls: toolCalls,
);

void main() {
  late DateTime now;
  late StreamController<DayAgentLiveStatus> statuses;

  setUp(() {
    now = _t0;
    statuses = StreamController<DayAgentLiveStatus>();
  });
  tearDown(() => unawaited(statuses.close()));

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    DayAgentLiveStatus? status,
    bool active = true,
  }) async {
    await withClock(Clock(() => now), () async {
      await tester.pumpWidget(
        makeTestableWidget2(
          Scaffold(
            body: DraftingAgentStatus(
              dayId: _dayId,
              requestedAt: _t0,
              active: active,
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(800, 900)),
          overrides: [
            dayAgentLiveStatusProvider.overrideWith(
              (ref, dayId) => statuses.stream,
            ),
          ],
        ),
      );
      if (status != null) statuses.add(status);
      await tester.pump();
    });
    return tester.element(find.byType(DraftingAgentStatus)).messages;
  }

  String statusLine(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(DraftingAgentStatus.statusLineKey)).data!;

  /// Advances the fake wall clock and lets the one-second ticker rebuild.
  Future<void> elapse(WidgetTester tester, Duration duration) =>
      withClock(Clock(() => now), () async {
        now = now.add(duration);
        await tester.pump(const Duration(seconds: 1));
      });

  testWidgets('says it is waiting, and for how long, before any wake', (
    tester,
  ) async {
    final messages = await pump(tester);

    expect(
      statusLine(tester),
      '${messages.dailyOsNextDraftingStepWaiting} · '
      '${messages.dailyOsNextDraftingSeconds('0')}',
    );
    expect(find.byKey(DraftingAgentStatus.internalsKey), findsNothing);

    await elapse(tester, const Duration(seconds: 42));

    expect(
      statusLine(tester),
      endsWith(messages.dailyOsNextDraftingSeconds('42')),
    );
  });

  testWidgets(
    'shows the real step, model, tokens, step times and tool calls',
    (tester) async {
      now = _t0.add(_ms(17000));
      final messages = await pump(
        tester,
        status: DayAgentLiveStatus(
          wake: _wake(
            completedSteps: [
              DayAgentWakeStepTiming(
                step: DayAgentWakeStep.preparingContext,
                elapsed: _ms(400),
              ),
              DayAgentWakeStepTiming(
                step: DayAgentWakeStep.callingModel,
                elapsed: _ms(6800),
              ),
              DayAgentWakeStepTiming(
                step: DayAgentWakeStep.runningTool,
                elapsed: _ms(100),
              ),
            ],
            turns: [
              DayAgentModelTurn(
                index: 0,
                elapsed: _ms(6800),
                inputTokens: 18240,
                outputTokens: 412,
              ),
              const DayAgentModelTurn(index: 1),
            ],
            toolCalls: [
              DayAgentToolCallTiming(
                name: 'search_memory',
                elapsed: _ms(100),
                succeeded: true,
              ),
              const DayAgentToolCallTiming(name: 'draft_day_plan'),
            ],
          ),
        ),
      );

      expect(
        statusLine(tester),
        '${messages.dailyOsNextDraftingStepModel(2)} · '
        '${messages.dailyOsNextDraftingSeconds('8')}',
      );
      final internals = find.byKey(DraftingAgentStatus.internalsKey);
      String rowText(String label) => tester
          .widgetList<Text>(
            find.descendant(of: internals, matching: find.byType(Text)),
          )
          .map((text) => text.textSpan!.toPlainText())
          .firstWhere((text) => text.startsWith(label));

      expect(
        rowText(messages.dailyOsNextDraftingInternalsModel),
        endsWith('deepseek-v4-1-flash-1017'),
      );
      expect(
        rowText(messages.dailyOsNextDraftingInternalsTokens),
        endsWith(
          messages.dailyOsNextDraftingInternalsTokensValue('18,240', '412'),
        ),
      );
      // Model time is the closed 6.8 s turn plus 8 s in the running one;
      // steps never entered (memory, prompt, saving) are left out.
      expect(
        rowText(messages.dailyOsNextDraftingInternalsTime),
        endsWith(
          '${messages.dailyOsNextDraftingTimingContext} '
          '${messages.dailyOsNextDraftingSeconds('0.4')} · '
          '${messages.dailyOsNextDraftingTimingModel} '
          '${messages.dailyOsNextDraftingSeconds('14.8')} · '
          '${messages.dailyOsNextDraftingTimingTools} '
          '${messages.dailyOsNextDraftingSeconds('0.1')}',
        ),
      );
      expect(
        rowText(messages.dailyOsNextDraftingInternalsTools),
        endsWith(
          'search_memory ${messages.dailyOsNextDraftingSeconds('0.1')}, '
          'draft_day_plan …',
        ),
      );
    },
  );

  testWidgets(
    'names each step before the model, so a wake stuck there says where',
    (tester) async {
      now = _t0.add(const Duration(minutes: 3));
      final messages = await pump(tester);
      for (final (step, label) in [
        (
          DayAgentWakeStep.preparingContext,
          messages.dailyOsNextDraftingStepContext,
        ),
        (
          DayAgentWakeStep.compactingMemory,
          messages.dailyOsNextDraftingStepMemory,
        ),
        (
          DayAgentWakeStep.assemblingPrompt,
          messages.dailyOsNextDraftingStepPrompt,
        ),
      ]) {
        await withClock(Clock(() => now), () async {
          statuses.add(
            DayAgentLiveStatus(
              wake: _wake(step: step, stepStartedAt: _t0),
            ),
          );
          await tester.pump();
          await tester.pump();
        });

        expect(
          statusLine(tester),
          '$label · ${messages.dailyOsNextDraftingSeconds('180')}',
          reason: step.name,
        );
      }
    },
  );

  testWidgets('times memory, prompt and saving steps under their own names', (
    tester,
  ) async {
    now = _t0.add(_ms(5000));
    final messages = await pump(
      tester,
      status: DayAgentLiveStatus(
        wake: _wake(
          step: DayAgentWakeStep.saving,
          stepStartedAt: _t0.add(_ms(4800)),
          completedSteps: [
            DayAgentWakeStepTiming(
              step: DayAgentWakeStep.compactingMemory,
              elapsed: _ms(1500),
            ),
            DayAgentWakeStepTiming(
              step: DayAgentWakeStep.assemblingPrompt,
              elapsed: _ms(300),
            ),
          ],
        ),
      ),
    );

    expect(
      statusLine(tester),
      startsWith(messages.dailyOsNextDraftingStepSaving),
    );
    expect(
      find.textContaining(
        '${messages.dailyOsNextDraftingTimingMemory} '
        '${messages.dailyOsNextDraftingSeconds('1.5')} · '
        '${messages.dailyOsNextDraftingTimingPrompt} '
        '${messages.dailyOsNextDraftingSeconds('0.3')} · '
        '${messages.dailyOsNextDraftingTimingSaving} '
        '${messages.dailyOsNextDraftingSeconds('0.2')}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('resumes ticking when drafting becomes active again', (
    tester,
  ) async {
    final messages = await pump(tester, active: false);
    await pump(tester);

    await elapse(tester, const Duration(seconds: 12));

    expect(
      statusLine(tester),
      endsWith(messages.dailyOsNextDraftingSeconds('12')),
    );
  });

  testWidgets('names the tool that is running', (tester) async {
    final messages = await pump(
      tester,
      status: DayAgentLiveStatus(
        wake: _wake(
          step: DayAgentWakeStep.runningTool,
          toolCalls: const [DayAgentToolCallTiming(name: 'draft_day_plan')],
          stepStartedAt: _t0,
        ),
      ),
    );

    expect(
      statusLine(tester),
      startsWith(messages.dailyOsNextDraftingStepTool('draft_day_plan')),
    );
  });

  testWidgets('progress from before this request is ignored', (tester) async {
    final messages = await pump(
      tester,
      status: DayAgentLiveStatus(
        wake: _wake(
          step: DayAgentWakeStep.completed,
          startedAt: _t0.subtract(const Duration(minutes: 10)),
        ),
        lastAttempt: DayAgentJobAttempt(
          dayId: _dayId,
          attempts: 4,
          maxAttempts: 5,
          updatedAt: _t0.subtract(const Duration(minutes: 9)),
          willRetry: false,
          lastError: 'old failure',
        ),
      ),
    );

    expect(
      statusLine(tester),
      startsWith(messages.dailyOsNextDraftingStepWaiting),
    );
    expect(find.byKey(DraftingAgentStatus.internalsKey), findsNothing);
    expect(find.textContaining('old failure'), findsNothing);
  });

  testWidgets(
    'a failed attempt awaiting retry counts down and shows the reason',
    (tester) async {
      now = _t0.add(const Duration(seconds: 35));
      final messages = await pump(
        tester,
        status: DayAgentLiveStatus(
          wake: _wake(
            step: DayAgentWakeStep.failed,
            completedSteps: [
              DayAgentWakeStepTiming(
                step: DayAgentWakeStep.callingModel,
                elapsed: _ms(30000),
              ),
            ],
          ),
          lastAttempt: DayAgentJobAttempt(
            dayId: _dayId,
            attempts: 1,
            maxAttempts: 5,
            updatedAt: _t0.add(const Duration(seconds: 32)),
            willRetry: true,
            nextAttemptAt: _t0.add(const Duration(seconds: 42)),
            lastError: 'draft inference exceeded its 30s deadline',
          ),
        ),
      );

      expect(statusLine(tester), messages.dailyOsNextDraftingStepRetrying('7'));
      expect(
        find.textContaining(messages.dailyOsNextDraftingInternalsAttempt(2, 5)),
        findsOneWidget,
      );
      expect(
        find.textContaining('draft inference exceeded its 30s deadline'),
        findsOneWidget,
      );

      await elapse(tester, const Duration(seconds: 10));
      expect(statusLine(tester), messages.dailyOsNextDraftingStepRetrying('0'));
    },
  );

  testWidgets('a settled failure and a completed wake say so plainly', (
    tester,
  ) async {
    final messages = await pump(
      tester,
      status: DayAgentLiveStatus(
        wake: _wake(step: DayAgentWakeStep.failed),
        lastAttempt: DayAgentJobAttempt(
          dayId: _dayId,
          attempts: 5,
          maxAttempts: 5,
          updatedAt: _t0.add(const Duration(seconds: 1)),
          willRetry: false,
          lastError: 'Gave up after 5 attempts: ${'x' * 300}',
        ),
      ),
    );
    expect(statusLine(tester), messages.dailyOsNextDraftingStepFailed);
    expect(
      find.textContaining(messages.dailyOsNextDraftingInternalsAttempt(5, 5)),
      findsOneWidget,
    );
    expect(
      find.textContaining('${'x' * 120}…'),
      findsOneWidget,
      reason: 'a long error is cut to one readable line',
    );

    await withClock(Clock(() => now), () async {
      statuses.add(
        DayAgentLiveStatus(wake: _wake(step: DayAgentWakeStep.completed)),
      );
      await tester.pump();
      await tester.pump();
    });
    expect(statusLine(tester), messages.dailyOsNextDraftingStepDone);
  });

  testWidgets('stops ticking once no longer active', (tester) async {
    final messages = await pump(tester);
    await pump(tester, active: false);

    await elapse(tester, const Duration(seconds: 30));

    expect(
      statusLine(tester),
      endsWith(messages.dailyOsNextDraftingSeconds('0')),
      reason: 'no ticker rebuilt the line after drafting stopped',
    );
  });

  group('stageIndexOf', () {
    test('maps real steps onto the four chips', () {
      expect(DraftingAgentStatus.stageIndexOf(null), 0);
      for (final (step, index) in [
        (DayAgentWakeStep.preparingContext, 1),
        (DayAgentWakeStep.compactingMemory, 1),
        (DayAgentWakeStep.assemblingPrompt, 1),
        (DayAgentWakeStep.callingModel, 2),
        (DayAgentWakeStep.runningTool, 2),
        (DayAgentWakeStep.saving, 3),
        (DayAgentWakeStep.completed, 4),
      ]) {
        expect(
          DraftingAgentStatus.stageIndexOf(_wake(step: step)),
          index,
          reason: step.name,
        );
      }
    });

    test('a failed wake stays on the stage it failed in', () {
      expect(
        DraftingAgentStatus.stageIndexOf(
          _wake(
            step: DayAgentWakeStep.failed,
            completedSteps: [
              DayAgentWakeStepTiming(
                step: DayAgentWakeStep.preparingContext,
                elapsed: _ms(10),
              ),
              DayAgentWakeStepTiming(
                step: DayAgentWakeStep.callingModel,
                elapsed: _ms(30000),
              ),
            ],
          ),
        ),
        2,
      );
      expect(
        DraftingAgentStatus.stageIndexOf(_wake(step: DayAgentWakeStep.failed)),
        1,
      );
    });
  });
}
