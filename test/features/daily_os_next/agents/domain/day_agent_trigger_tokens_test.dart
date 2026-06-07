import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_trigger_tokens.dart';

void main() {
  group('token round-trips', () {
    test('dayAgentPlanningDayToken prefixes the day id', () {
      expect(
        dayAgentPlanningDayToken('dayplan-2026-05-25'),
        '${dayAgentPlanningDayPrefix}dayplan-2026-05-25',
      );
    });

    test('dayAgentCaptureSubmittedToken prefixes the capture id', () {
      expect(
        dayAgentCaptureSubmittedToken('capture-abc'),
        '${dayAgentCaptureSubmittedPrefix}capture-abc',
      );
    });

    test('dayAgentDraftingToken prefixes the day id', () {
      expect(
        dayAgentDraftingToken('dayplan-2026-05-25'),
        '${dayAgentDraftingPrefix}dayplan-2026-05-25',
      );
    });

    test('dayAgentRefineToken prefixes the day id', () {
      expect(
        dayAgentRefineToken('dayplan-2026-05-25'),
        '${dayAgentRefinePrefix}dayplan-2026-05-25',
      );
    });

    test('dayAgentDecidedTaskToken prefixes the task id', () {
      expect(
        dayAgentDecidedTaskToken('task-abc'),
        '${dayAgentDecidedTaskPrefix}task-abc',
      );
    });

    test('dayAgentDecidedCaptureItemToken prefixes the parsed item id', () {
      expect(
        dayAgentDecidedCaptureItemToken('parsed-abc'),
        '${dayAgentDecidedCaptureItemPrefix}parsed-abc',
      );
    });
  });

  group('hasDraftingTokenForDay', () {
    test('matches only the requested day workspace', () {
      final tokens = {
        dayAgentDraftingToken('dayplan-2026-05-25'),
        dayAgentDraftingToken('dayplan-2026-05-26'),
      };
      expect(hasDraftingTokenForDay(tokens, 'dayplan-2026-05-25'), isTrue);
      expect(hasDraftingTokenForDay(tokens, 'dayplan-2026-05-26'), isTrue);
      expect(hasDraftingTokenForDay(tokens, 'dayplan-2026-05-27'), isFalse);
    });

    test('returns false on an empty set', () {
      expect(hasDraftingTokenForDay(<String>{}, 'dayplan-2026-05-25'), isFalse);
    });
  });

  group('hasRefineTokenForDay', () {
    test('matches only the requested day workspace', () {
      final tokens = {
        dayAgentRefineToken('dayplan-2026-05-25'),
        dayAgentDraftingToken('dayplan-2026-05-26'),
      };
      expect(hasRefineTokenForDay(tokens, 'dayplan-2026-05-25'), isTrue);
      // A drafting token for another day must not read as a refine token.
      expect(hasRefineTokenForDay(tokens, 'dayplan-2026-05-26'), isFalse);
    });
  });

  group('captureIdsFromTriggerTokens', () {
    test('returns every capture id, sorted, deterministic under merge', () {
      final result = captureIdsFromTriggerTokens({
        dayAgentCaptureSubmittedToken('capture-b'),
        dayAgentCaptureSubmittedToken('capture-a'),
        dayAgentDraftingToken('dayplan-2026-05-25'),
      });
      // Sorted output is the determinism guarantee: a merged multi-capture
      // set always yields the same first element regardless of Set order.
      expect(result, ['capture-a', 'capture-b']);
    });

    test('skips prefix-only and whitespace-only capture tokens', () {
      expect(
        captureIdsFromTriggerTokens({
          dayAgentCaptureSubmittedPrefix,
          '$dayAgentCaptureSubmittedPrefix   ',
        }),
        isEmpty,
      );
    });

    test('trims surrounding whitespace from each capture id', () {
      expect(
        captureIdsFromTriggerTokens({
          '$dayAgentCaptureSubmittedPrefix  capture-1  ',
        }),
        ['capture-1'],
      );
    });

    test('returns empty on an empty set', () {
      expect(captureIdsFromTriggerTokens(<String>{}), isEmpty);
    });
  });

  group('decidedTaskIdsFromTriggerTokens', () {
    test('returns every decided-task id in the set', () {
      final result = decidedTaskIdsFromTriggerTokens({
        dayAgentDraftingToken('dayplan-2026-05-25'),
        dayAgentDecidedTaskToken('task-1'),
        dayAgentDecidedTaskToken('task-2'),
        'other',
      });
      expect(result, containsAll(['task-1', 'task-2']));
      expect(result, hasLength(2));
    });

    test('skips prefix-only and whitespace-only tokens', () {
      expect(
        decidedTaskIdsFromTriggerTokens({
          dayAgentDecidedTaskPrefix,
          '$dayAgentDecidedTaskPrefix   ',
        }),
        isEmpty,
      );
    });

    test('trims and sorts each task id for deterministic ordering', () {
      final result = decidedTaskIdsFromTriggerTokens({
        '$dayAgentDecidedTaskPrefix  task-b  ',
        '$dayAgentDecidedTaskPrefix task-a',
      });
      // Sorted output guarantees stable decided-task ordering in the prompt.
      expect(result, ['task-a', 'task-b']);
    });
  });

  group('decidedCaptureItemIdsFromTriggerTokens', () {
    test('returns every decided capture item id in the set', () {
      final result = decidedCaptureItemIdsFromTriggerTokens({
        dayAgentDraftingToken('dayplan-2026-05-25'),
        dayAgentDecidedCaptureItemToken('parsed-1'),
        dayAgentDecidedCaptureItemToken('parsed-2'),
        'other',
      });
      expect(result, containsAll(['parsed-1', 'parsed-2']));
      expect(result, hasLength(2));
    });

    test('skips prefix-only and whitespace-only tokens', () {
      expect(
        decidedCaptureItemIdsFromTriggerTokens({
          dayAgentDecidedCaptureItemPrefix,
          '$dayAgentDecidedCaptureItemPrefix   ',
        }),
        isEmpty,
      );
    });

    test('trims and sorts each parsed item id', () {
      final result = decidedCaptureItemIdsFromTriggerTokens({
        '$dayAgentDecidedCaptureItemPrefix  parsed-b  ',
        '$dayAgentDecidedCaptureItemPrefix parsed-a',
      });
      expect(result, ['parsed-a', 'parsed-b']);
    });
  });

  group('resolvePlannerWakeDay', () {
    test('resolves the day from a planning_day token', () {
      final resolution = resolvePlannerWakeDay({
        dayAgentPlanningDayToken('dayplan-2026-05-25'),
        dayAgentCaptureSubmittedToken('capture-1'),
      });
      expect(resolution.dayId, 'dayplan-2026-05-25');
      expect(resolution.isAmbiguous, isFalse);
    });

    test('resolves the day from a drafting token alone', () {
      final resolution = resolvePlannerWakeDay({
        dayAgentDraftingToken('dayplan-2026-05-25'),
      });
      expect(resolution.dayId, 'dayplan-2026-05-25');
    });

    test('agreeing tokens across families collapse to one day', () {
      final resolution = resolvePlannerWakeDay({
        dayAgentPlanningDayToken('dayplan-2026-05-25'),
        dayAgentDraftingToken('dayplan-2026-05-25'),
      });
      expect(resolution.candidates, {'dayplan-2026-05-25'});
      expect(resolution.dayId, 'dayplan-2026-05-25');
    });

    test('disagreeing day tokens are reported as ambiguous, not picked', () {
      final resolution = resolvePlannerWakeDay({
        dayAgentDraftingToken('dayplan-2026-05-25'),
        dayAgentRefineToken('dayplan-2026-05-26'),
      });
      expect(resolution.isAmbiguous, isTrue);
      expect(resolution.dayId, isNull);
      expect(resolution.candidates, {
        'dayplan-2026-05-25',
        'dayplan-2026-05-26',
      });
    });

    test('a capture-only token set resolves no day candidate', () {
      final resolution = resolvePlannerWakeDay({
        dayAgentCaptureSubmittedToken('capture-1'),
      });
      expect(resolution.candidates, isEmpty);
      expect(resolution.dayId, isNull);
      expect(resolution.isAmbiguous, isFalse);
    });
  });
}
