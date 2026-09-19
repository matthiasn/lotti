import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/day_agent_trigger_tokens.dart';

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

    test('dayIdFromWorkspaceKey inverts dayAgentWorkspaceKey', () {
      const dayId = 'dayplan-2026-05-25';
      expect(dayIdFromWorkspaceKey(dayAgentWorkspaceKey(dayId)), dayId);
    });

    test('dayIdFromWorkspaceKey returns null for a non-day workspace', () {
      // The coordinator digest lane is deliberately not a `day:` partition, so
      // the record reaper must not read a day out of it.
      expect(dayIdFromWorkspaceKey(coordinatorDigestWorkspaceKey), isNull);
      expect(dayIdFromWorkspaceKey('day:'), isNull);
      expect(dayIdFromWorkspaceKey(''), isNull);
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

    test('processing-job token round-trips the durable job id', () {
      const jobId = 'draft_dayplan-2026-05-25';
      final token = dayAgentProcessingJobToken(
        jobId,
        requestedAt: DateTime.utc(2026, 7, 22),
      );

      expect(
        token,
        '$dayAgentProcessingJobPrefix'
        '${dayAgentProcessingIntentId(
          jobId,
          requestedAt: DateTime.utc(2026, 7, 22),
        )}',
      );
      expect(
        processingJobIdFromTriggerTokens({token}),
        dayAgentProcessingIntentId(
          jobId,
          requestedAt: DateTime.utc(2026, 7, 22),
        ),
      );
    });

    test('processing intent is stable for retries and changes on re-arm', () {
      final firstRequest = DateTime.utc(2026, 7, 22, 8);
      final rearmedRequest = DateTime.utc(2026, 7, 22, 9);

      final firstAttempt = dayAgentProcessingJobToken(
        'draft_dayplan-2026-07-22',
        requestedAt: firstRequest,
      );
      final retry = dayAgentProcessingJobToken(
        'draft_dayplan-2026-07-22',
        requestedAt: firstRequest,
      );
      final rearmed = dayAgentProcessingJobToken(
        'draft_dayplan-2026-07-22',
        requestedAt: rearmedRequest,
      );

      expect(retry, firstAttempt);
      expect(rearmed, isNot(firstAttempt));
    });
  });

  group('processingJobIdFromTriggerTokens', () {
    test('returns null when no durable job token is present', () {
      expect(
        processingJobIdFromTriggerTokens({
          dayAgentDraftingToken('dayplan-2026-05-25'),
        }),
        isNull,
      );
    });

    test('rejects ambiguous merged durable job tokens', () {
      expect(
        () => processingJobIdFromTriggerTokens({
          dayAgentProcessingJobToken(
            'job-a',
            requestedAt: DateTime.utc(2026, 7, 22),
          ),
          dayAgentProcessingJobToken(
            'job-b',
            requestedAt: DateTime.utc(2026, 7, 22),
          ),
        }),
        throwsStateError,
      );
    });

    test('ignores empty job ids and trims the selected id', () {
      expect(
        processingJobIdFromTriggerTokens({
          dayAgentProcessingJobPrefix,
          '$dayAgentProcessingJobPrefix   ',
          '$dayAgentProcessingJobPrefix  job-a  ',
        }),
        'job-a',
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

    test('resolves the day from a digest token alone (ADR 0032)', () {
      final resolution = resolvePlannerWakeDay({
        dayAgentDigestToken('dayplan-2026-05-25'),
      });
      expect(resolution.dayId, 'dayplan-2026-05-25');
      expect(
        dayAgentDigestToken('dayplan-2026-05-25'),
        'digest:dayplan-2026-05-25',
      );
      // The digest lane is coordinator-scoped, never a day workspace, so a
      // digest can never coalesce with a day's plan work.
      expect(coordinatorDigestWorkspaceKey, 'coordinator:digest');
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

  group('token properties', () {
    List<String> kept(Iterable<String> ids) =>
        [for (final id in ids) id.trim()].where((id) => id.isNotEmpty).toList()
          ..sort();

    glados.Glados(
      glados.any.tokenFamilies,
      glados.ExploreConfig(numRuns: 400),
    ).test(
      'each extractor reads its own family, trimmed and sorted, and nothing else',
      (families) {
        final tokens = families.tokens;

        expect(captureIdsFromTriggerTokens(tokens), kept(families.captures));
        expect(
          decidedTaskIdsFromTriggerTokens(tokens),
          kept(families.decidedTasks),
        );
        expect(
          decidedCaptureItemIdsFromTriggerTokens(tokens),
          kept(families.decidedItems),
        );
        for (final ids in [
          captureIdsFromTriggerTokens(tokens),
          decidedTaskIdsFromTriggerTokens(tokens),
          decidedCaptureItemIdsFromTriggerTokens(tokens),
        ]) {
          for (final id in ids) {
            expect(id, isNotEmpty);
            expect(id.trim(), id);
          }
        }
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.tokenFamilies,
      glados.ExploreConfig(numRuns: 400),
    ).test(
      'a wake resolves to a day only when its day tokens agree on one',
      (families) {
        final tokens = families.tokens;
        final resolution = resolvePlannerWakeDay(tokens);
        final days = {...kept(families.days.values.expand((ids) => ids))};

        expect(resolution.candidates, days);
        expect(resolution.isAmbiguous, days.length >= 2);
        expect(resolution.dayId, days.length == 1 ? days.single : null);
        for (final day in families.days[_DayFamily.drafting]!) {
          expect(hasDraftingTokenForDay(tokens, day), isTrue);
        }
        for (final day in families.days[_DayFamily.refine]!) {
          expect(hasRefineTokenForDay(tokens, day), isTrue);
        }
        for (final day in families.days[_DayFamily.planning]!) {
          if (!families.days[_DayFamily.drafting]!.contains(day)) {
            expect(hasDraftingTokenForDay(tokens, day), isFalse);
          }
        }
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.nonEmptyLetterOrDigits,
      glados.any.letterOrDigits,
    ).test(
      'a day workspace key gives its day back; any other key gives none',
      (dayId, other) {
        expect(dayIdFromWorkspaceKey(dayAgentWorkspaceKey(dayId)), dayId);
        expect(dayIdFromWorkspaceKey('x$other'), isNull);
        expect(dayIdFromWorkspaceKey(coordinatorDigestWorkspaceKey), isNull);
      },
      tags: 'glados',
    );

    glados.Glados3(
      glados.any.nonEmptyLetterOrDigits,
      glados.any.nonEmptyLetterOrDigits,
      glados.IntAnys(glados.any).intInRange(0, 1 << 40),
    ).test(
      'one processing job reads back; two distinct jobs are refused',
      (jobA, jobB, micros) {
        final at = DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
        final tokenA = dayAgentProcessingJobToken(jobA, requestedAt: at);
        final tokenB = dayAgentProcessingJobToken(jobB, requestedAt: at);

        expect(
          processingJobIdFromTriggerTokens({
            tokenA,
            dayAgentPlanningDayToken(jobB),
          }),
          dayAgentProcessingIntentId(jobA, requestedAt: at),
        );
        if (jobA != jobB) {
          expect(
            () => processingJobIdFromTriggerTokens({tokenA, tokenB}),
            throwsStateError,
          );
        }
      },
      tags: 'glados',
    );
  });
}

enum _DayFamily { planning, drafting, refine, digest }

class _TokenFamilies {
  const _TokenFamilies({
    required this.captures,
    required this.decidedTasks,
    required this.decidedItems,
    required this.days,
  });

  final List<String> captures;
  final List<String> decidedTasks;
  final List<String> decidedItems;
  final Map<_DayFamily, List<String>> days;

  Set<String> get tokens => {
    ...captures.map(dayAgentCaptureSubmittedToken),
    ...decidedTasks.map(dayAgentDecidedTaskToken),
    ...decidedItems.map(dayAgentDecidedCaptureItemToken),
    ...days[_DayFamily.planning]!.map(dayAgentPlanningDayToken),
    ...days[_DayFamily.drafting]!.map(dayAgentDraftingToken),
    ...days[_DayFamily.refine]!.map(dayAgentRefineToken),
    ...days[_DayFamily.digest]!.map(dayAgentDigestToken),
    // Unrelated vocabulary riding on the same wake.
    'goal-cadence',
    'goal-escalation:2026-W32',
    coordinatorDigestWorkspaceKey,
  };

  @override
  String toString() =>
      '_TokenFamilies(captures: $captures, decidedTasks: $decidedTasks, '
      'decidedItems: $decidedItems, days: $days)';
}

extension _AnyTokenFamilies on glados.Any {
  /// Distinct raw ids per family; they may be blank, padded or contain a
  /// colon, as ids from an older peer might.
  glados.Generator<List<String>> get _ids => glados.ListAnys(this)
      .listWithLengthInRange(
        0,
        5,
        glados.AnyUtils(this).choose(const [
          'dayplan-2026-08-08',
          'dayplan-2026-08-09',
          'a',
          ' a',
          'a ',
          'b1',
          'a:b',
          '',
          ' ',
        ]),
      )
      .map((ids) => ids.toSet().toList());

  glados.Generator<_TokenFamilies> get tokenFamilies =>
      glados.CombinableAny(this).combine7(
        _ids,
        _ids,
        _ids,
        _ids,
        _ids,
        _ids,
        _ids,
        (
          List<String> captures,
          List<String> decidedTasks,
          List<String> decidedItems,
          List<String> planning,
          List<String> drafting,
          List<String> refine,
          List<String> digest,
        ) => _TokenFamilies(
          captures: captures,
          decidedTasks: decidedTasks,
          decidedItems: decidedItems,
          days: {
            _DayFamily.planning: planning,
            _DayFamily.drafting: drafting,
            _DayFamily.refine: refine,
            _DayFamily.digest: digest,
          },
        ),
      );
}
