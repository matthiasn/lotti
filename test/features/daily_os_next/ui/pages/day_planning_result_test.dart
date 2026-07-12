import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_planning_result.dart';

const _category = DayAgentCategory(
  id: 'work',
  name: 'Work',
  colorHex: '5ED4B7',
);

ParsedItem _item(
  String id, {
  required ParsedItemKind kind,
  String? matchedTaskId,
}) => ParsedItem(
  id: id,
  kind: kind,
  title: 'Item $id',
  category: _category,
  confidence: ParsedItemConfidence.high,
  matchedTaskId: matchedTaskId,
);

void main() {
  group('attributeCreatedTaskIds', () {
    test('returns empty when no capture items were decided', () {
      expect(
        attributeCreatedTaskIds(
          decidedCaptureItemIds: const [],
          reparsedItems: [
            _item('a', kind: ParsedItemKind.matched, matchedTaskId: 't1'),
          ],
        ),
        isEmpty,
      );
    });

    test('picks up decided items that gained a matchedTaskId', () {
      final ids = attributeCreatedTaskIds(
        decidedCaptureItemIds: const ['a', 'b'],
        reparsedItems: [
          // 'a' was materialized into task t1 during drafting.
          _item('a', kind: ParsedItemKind.matched, matchedTaskId: 't1'),
          // 'b' stayed unlinked (no task created for it).
          _item('b', kind: ParsedItemKind.newTask),
        ],
      );

      expect(ids, ['t1']);
    });

    test('ignores items that were not part of the decided set', () {
      final ids = attributeCreatedTaskIds(
        decidedCaptureItemIds: const ['a'],
        reparsedItems: [
          _item('a', kind: ParsedItemKind.matched, matchedTaskId: 't1'),
          // 'z' has a task but was not an approved capture item this run.
          _item('z', kind: ParsedItemKind.matched, matchedTaskId: 't2'),
        ],
      );

      expect(ids, ['t1']);
    });

    test('de-duplicates while preserving first-seen order', () {
      final ids = attributeCreatedTaskIds(
        decidedCaptureItemIds: const ['a', 'b', 'c'],
        reparsedItems: [
          _item('a', kind: ParsedItemKind.matched, matchedTaskId: 't1'),
          _item('b', kind: ParsedItemKind.matched, matchedTaskId: 't2'),
          // Two capture items resolved to the same task.
          _item('c', kind: ParsedItemKind.matched, matchedTaskId: 't1'),
        ],
      );

      expect(ids, ['t1', 't2']);
    });

    test('returns empty when a decided item is missing from the reparse', () {
      expect(
        attributeCreatedTaskIds(
          decidedCaptureItemIds: const ['a'],
          reparsedItems: const [],
        ),
        isEmpty,
      );
    });
  });

  group('DayPlanningResult variants', () {
    final draft = DraftPlan.emptyForDay(DateTime(2026, 7, 10));

    test('DayPlanningCreated defaults to no created task ids', () {
      final result = DayPlanningCreated(draft: draft);
      expect(result.createdTaskIds, isEmpty);
      expect(result.draft, same(draft));
    });

    test('DayPlanningCreated carries the attributed task ids', () {
      final result = DayPlanningCreated(
        draft: draft,
        createdTaskIds: const ['t1', 't2'],
      );
      expect(result.createdTaskIds, ['t1', 't2']);
    });

    test('DayPlanningAdapted carries the adapted plan', () {
      final result = DayPlanningAdapted(draft: draft);
      expect(result.draft, same(draft));
    });
  });
}
