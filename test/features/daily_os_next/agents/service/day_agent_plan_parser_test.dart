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
  }) {
    return parsePlannedBlock(
      raw: raw,
      day: day,
      allowedCategoryIds: allowedCategoryIds,
      decidedTaskIds: decidedTaskIds,
      allowedExistingTaskIds: allowedExistingTaskIds,
      earliestDraftStart: earliestDraftStart,
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
