import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/agents/domain/daily_os_planner_wake_context.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_trigger_tokens.dart';

void main() {
  const dayId = 'dayplan-2026-05-25';

  DailyOsPlannerWakeContext build(Set<String> tokens) {
    return DailyOsPlannerWakeContext.fromTokens(
      plannerAgentId: 'daily_os_planner',
      dayId: dayId,
      runKey: 'run-1',
      threadId: 'thread-1',
      triggerTokens: tokens,
    );
  }

  test('extracts payload ids deterministically from the token set', () {
    final ctx = build({
      dayAgentPlanningDayToken(dayId),
      dayAgentDraftingToken(dayId),
      dayAgentCaptureSubmittedToken('capture-b'),
      dayAgentCaptureSubmittedToken('capture-a'),
      dayAgentDecidedTaskToken('task-1'),
      dayAgentDecidedCaptureItemToken('parsed-1'),
    });

    expect(ctx.captureIds, ['capture-a', 'capture-b']);
    expect(ctx.decidedTaskIds, contains('task-1'));
    expect(ctx.decidedCaptureItemIds, contains('parsed-1'));
    expect(ctx.isDraftingWake, isTrue);
    expect(ctx.isRefineWake, isFalse);
  });

  test('classifies a refine wake for its own day only', () {
    final ctx = build({
      dayAgentPlanningDayToken(dayId),
      dayAgentRefineToken(dayId),
      // A drafting token for a different day must not flip this wake's mode.
      dayAgentDraftingToken('dayplan-2026-05-26'),
    });

    expect(ctx.isRefineWake, isTrue);
    expect(ctx.isDraftingWake, isFalse);
  });

  group('allowsToolDayId', () {
    final ctx = build({dayAgentPlanningDayToken(dayId)});

    test('accepts a matching day id', () {
      expect(ctx.allowsToolDayId(dayId), isTrue);
      expect(ctx.allowsToolDayId('  $dayId  '), isTrue);
    });

    test('rejects a mismatched day id', () {
      expect(ctx.allowsToolDayId('dayplan-2026-05-26'), isFalse);
    });

    test('treats null/blank as inherit-the-wake-day', () {
      expect(ctx.allowsToolDayId(null), isTrue);
      expect(ctx.allowsToolDayId('   '), isTrue);
    });
  });

  test('triggerTokens are stored unmodifiable', () {
    final ctx = build({dayAgentPlanningDayToken(dayId)});
    expect(() => ctx.triggerTokens.add('x'), throwsUnsupportedError);
  });
}
