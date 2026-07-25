import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart'
    show DayAgentCaptureException;
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_parser.dart';

void main() {
  final day = DateTime(2026, 3, 16);

  Map<String, dynamic> rawBlock({
    String categoryId = 'cat-1',
    String title = 'Deep work',
    int startHour = 9,
    int endHour = 10,
    String? reason = 'morning focus',
    String? taskId,
    String? type,
  }) {
    return <String, dynamic>{
      'categoryId': categoryId,
      'title': title,
      'start': DateTime(2026, 3, 16, startHour).toIso8601String(),
      'end': DateTime(2026, 3, 16, endHour).toIso8601String(),
      'reason': ?reason,
      'taskId': ?taskId,
      'type': ?type,
    };
  }

  PlannedBlock parse(
    Map<String, dynamic>? raw, {
    Set<String> allowedCategoryIds = const {'cat-1'},
    Set<String> decidedTaskIds = const {},
    Set<String> allowedExistingTaskIds = const {},
    DateTime? earliestDraftStart,
    Map<String, PlannedBlock> baselineBlocks = const {},
  }) {
    return parsePlannedBlock(
      raw: raw,
      day: day,
      allowedCategoryIds: allowedCategoryIds,
      decidedTaskIds: decidedTaskIds,
      allowedExistingTaskIds: allowedExistingTaskIds,
      earliestDraftStart: earliestDraftStart,
      baselineBlocks: baselineBlocks,
    );
  }

  group('parsePlannedBlock', () {
    test('parses a valid ai block with reason and generates an id', () {
      final block = parse(rawBlock());

      expect(block.categoryId, 'cat-1');
      expect(block.title, 'Deep work');
      expect(block.type, PlannedBlockType.ai);
      expect(block.reason, 'morning focus');
      expect(block.id, isNotEmpty);
      expect(block.startTime, DateTime(2026, 3, 16, 9));
      expect(block.endTime, DateTime(2026, 3, 16, 10));
    });

    test('rejects non-map input, unknown category, and inverted times', () {
      expect(
        () => parsePlannedBlock(
          raw: 'nope',
          day: day,
          allowedCategoryIds: const {},
          decidedTaskIds: const {},
          allowedExistingTaskIds: const {},
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
      expect(
        () => parse(rawBlock(categoryId: 'unknown')),
        throwsA(isA<DayAgentCaptureException>()),
      );
      expect(
        () => parse(rawBlock(startHour: 11)),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('rejects blocks outside the day window', () {
      final raw = rawBlock()
        ..['end'] = DateTime(2026, 3, 17, 1).toIso8601String();
      expect(() => parse(raw), throwsA(isA<DayAgentCaptureException>()));
    });

    test('rejects ai blocks without a reason', () {
      expect(
        () => parse(rawBlock(reason: null)),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    group('earliestDraftStart guard', () {
      final earliest = DateTime(2026, 3, 16, 14);

      test('rejects past-starting drafted ai, manual, and buffer blocks', () {
        // Every agent-invented type is guarded — models were observed live
        // relabelling a past-starting block `buffer` to slip through an
        // ai/manual-only guard.
        for (final type in ['ai', 'manual', 'buffer']) {
          expect(
            () => parse(
              rawBlock(type: type),
              earliestDraftStart: earliest,
            ),
            throwsA(
              isA<DayAgentCaptureException>().having(
                (e) => e.message,
                'message',
                contains('must not start before current time'),
              ),
            ),
            reason: 'type=$type must be rejected',
          );
        }
      });

      test('exempts only states that record what already happened', () {
        // History a re-draft legitimately carries forward. These are records,
        // not plans, so they are allowed to sit in the past.
        for (final state in ['inProgress', 'completed', 'dropped']) {
          final block = parse(
            rawBlock()..['state'] = state,
            earliestDraftStart: earliest,
          );
          expect(block.startTime, DateTime(2026, 3, 16, 9), reason: state);
        }
      });

      test('guards committed blocks, not just drafted ones', () {
        // `committed` is a plan the user agreed to, not a record of something
        // that happened — and writing a new block as committed was the
        // remaining way to place work before the current time, the same
        // probing as relabelling a block `buffer`, one field over.
        expect(
          () => parse(
            rawBlock()..['state'] = 'committed',
            earliestDraftStart: earliest,
          ),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('must not start before current time'),
            ),
          ),
        );
      });

      test('carries forward a committed baseline block unchanged', () {
        // A legacy `agreed` plan can hold committed blocks the user already
        // approved. Once one has started, a redraft must still be able to
        // include it — rejecting the whole draft for faithfully repeating
        // what is already on the plan would punish the correct behaviour.
        final block = parse(
          rawBlock()
            ..['state'] = 'committed'
            ..['id'] = 'block-existing',
          earliestDraftStart: earliest,
          baselineBlocks: {
            'block-existing': _baselineBlock(
              id: 'block-existing',
              start: DateTime(2026, 3, 16, 9),
              state: PlannedBlockState.committed,
            ),
          },
        );

        expect(block.id, 'block-existing');
        expect(block.startTime, DateTime(2026, 3, 16, 9));
      });

      test('will not let a baseline id move approved work into the past', () {
        // The exemption keys on id *and* start, so reusing a known id with a
        // new time is still newly planning the past.
        expect(
          () => parse(
            rawBlock()
              ..['state'] = 'committed'
              ..['id'] = 'block-existing',
            earliestDraftStart: earliest,
            baselineBlocks: {
              'block-existing': _baselineBlock(
                id: 'block-existing',
                start: DateTime(2026, 3, 16, 11),
                state: PlannedBlockState.committed,
              ),
            },
          ),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('must not start before current time'),
            ),
          ),
        );
      });

      test('will not let a baseline id adopt a new plan state in the past', () {
        // The attack the id+start match alone allowed: reuse a known 09:00
        // block id and drop a brand-new committed block into that slot,
        // rewriting approved work without the refinement approval that
        // normally gates it.
        expect(
          () => parse(
            rawBlock()
              ..['state'] = 'committed'
              ..['id'] = 'block-existing',
            earliestDraftStart: earliest,
            baselineBlocks: {
              'block-existing': _baselineBlock(
                id: 'block-existing',
                start: DateTime(2026, 3, 16, 9),
                state: PlannedBlockState.drafted,
              ),
            },
          ),
          throwsA(isA<DayAgentCaptureException>()),
        );
      });

      test('a cal block is refused outright, guard or no guard', () {
        // `cal` means "imported calendar event" and this agent is shown none,
        // so the type can only ever assert an import that never happened —
        // and the plan editor then refuses to let the user edit the result.
        for (final earliestStart in [earliest, null]) {
          expect(
            () => parse(
              rawBlock(type: 'cal'),
              earliestDraftStart: earliestStart,
            ),
            throwsA(
              isA<DayAgentCaptureException>().having(
                (e) => e.message,
                'message',
                contains('none are available to this agent'),
              ),
            ),
            reason: 'earliestDraftStart=$earliestStart',
          );
        }
      });

      test('accepts drafted blocks starting at or after the boundary', () {
        final atBoundary = parse(
          rawBlock(startHour: 14, endHour: 15, type: 'buffer'),
          earliestDraftStart: earliest,
        );
        expect(atBoundary.startTime, earliest);

        final after = parse(
          rawBlock(startHour: 15, endHour: 16),
          earliestDraftStart: earliest,
        );
        expect(after.startTime, DateTime(2026, 3, 16, 15));
      });
    });

    test('rejects task ids that are neither decided nor existing', () {
      expect(
        () => parse(rawBlock(taskId: 'task-x')),
        throwsA(isA<DayAgentCaptureException>()),
      );
      final block = parse(
        rawBlock(taskId: 'task-x'),
        decidedTaskIds: const {'task-x'},
      );
      expect(block.taskId, 'task-x');
    });
  });

  group('selectIndices', () {
    test('returns the full range when indices are omitted', () {
      expect(selectIndices(itemIndices: null, itemCount: 3), [0, 1, 2]);
    });

    test('deduplicates, sorts, and bounds-checks explicit indices', () {
      expect(
        selectIndices(itemIndices: [2, 0, 2], itemCount: 3),
        [0, 2],
      );
      expect(
        () => selectIndices(itemIndices: [3], itemCount: 3),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });
  });

  group('day id helpers', () {
    test('dateFromDayId parses only dayplan-prefixed ids', () {
      expect(dateFromDayId('dayplan-2026-03-16'), DateTime(2026, 3, 16));
      expect(dateFromDayId('2026-03-16'), isNull);
    });

    test('dayIdFromPlanEntityId strips the agent plan prefix', () {
      expect(
        dayIdFromPlanEntityId('day_agent_plan:dayplan-2026-03-16'),
        'dayplan-2026-03-16',
      );
      expect(dayIdFromPlanEntityId('dayplan-x'), 'dayplan-x');
    });
  });

  group('categoryAllowed', () {
    test('null or empty allow-set permits everything', () {
      expect(categoryAllowed('cat-1', null), isTrue);
      expect(categoryAllowed('cat-1', const {}), isTrue);
      expect(categoryAllowed('cat-1', const {'cat-1'}), isTrue);
      expect(categoryAllowed('cat-2', const {'cat-1'}), isFalse);
      expect(categoryAllowed(null, const {'cat-1'}), isFalse);
    });
  });

  group('blankToNull', () {
    test('maps blank and null to null and trims the rest', () {
      expect(blankToNull('  '), isNull);
      expect(blankToNull(null), isNull);
      expect(blankToNull(' x '), 'x');
    });
  });
}

PlannedBlock _baselineBlock({
  required String id,
  required DateTime start,
  required PlannedBlockState state,
}) => PlannedBlock(
  id: id,
  categoryId: 'cat-1',
  startTime: start,
  endTime: start.add(const Duration(hours: 1)),
  title: id,
  state: state,
);
