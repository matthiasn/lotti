import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/checklist_data.dart';

void main() {
  group('ChecklistData JSON round-trips — static examples', () {
    ChecklistData roundTrip(ChecklistData d) => ChecklistData.fromJson(
          jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>,
        );

    test('ChecklistData with empty lists survives JSON round-trip', () {
      const data = ChecklistData(
        title: 'Shopping',
        linkedChecklistItems: [],
        linkedTasks: [],
      );
      final decoded = roundTrip(data);
      expect(decoded, data, reason: 'empty lists round-trip');
      expect(decoded.title, 'Shopping');
      expect(decoded.linkedChecklistItems, isEmpty);
      expect(decoded.linkedTasks, isEmpty);
    });

    test('ChecklistData with items and tasks survives JSON round-trip', () {
      const data = ChecklistData(
        title: 'Weekly groceries',
        linkedChecklistItems: ['item-1', 'item-2', 'item-3'],
        linkedTasks: ['task-a', 'task-b'],
      );
      final decoded = roundTrip(data);
      expect(decoded, data, reason: 'full ChecklistData round-trip');
      expect(decoded.linkedChecklistItems, ['item-1', 'item-2', 'item-3']);
      expect(decoded.linkedTasks, ['task-a', 'task-b']);
    });

    test('ChecklistData preserves title with special characters', () {
      const data = ChecklistData(
        title: 'Shopping: "fresh" & organic — Berlin',
        linkedChecklistItems: [],
        linkedTasks: [],
      );
      final decoded = roundTrip(data);
      expect(decoded.title, 'Shopping: "fresh" & organic — Berlin',
          reason: 'special characters preserved');
      expect(decoded, data);
    });

    test('ChecklistData with only tasks and no checklist items round-trips',
        () {
      const data = ChecklistData(
        title: 'Project init',
        linkedChecklistItems: [],
        linkedTasks: ['task-main'],
      );
      final decoded = roundTrip(data);
      expect(decoded.linkedChecklistItems, isEmpty);
      expect(decoded.linkedTasks, ['task-main']);
    });

    test('ChecklistData toJson produces correct keys', () {
      const data = ChecklistData(
        title: 'My list',
        linkedChecklistItems: ['item-x'],
        linkedTasks: [],
      );
      final json = data.toJson();
      expect(json.containsKey('title'), isTrue,
          reason: 'title key must exist');
      expect(json.containsKey('linkedChecklistItems'), isTrue,
          reason: 'linkedChecklistItems key must exist');
      expect(json.containsKey('linkedTasks'), isTrue,
          reason: 'linkedTasks key must exist');
      expect(json['title'], 'My list');
      expect(json['linkedChecklistItems'], ['item-x']);
    });
  });

  group('ChecklistData equality', () {
    test('two ChecklistData with same fields are equal', () {
      const a = ChecklistData(
        title: 'List A',
        linkedChecklistItems: ['x', 'y'],
        linkedTasks: ['t1'],
      );
      const b = ChecklistData(
        title: 'List A',
        linkedChecklistItems: ['x', 'y'],
        linkedTasks: ['t1'],
      );
      expect(a, b);
    });

    test('ChecklistData with different titles are not equal', () {
      const a = ChecklistData(
        title: 'List A',
        linkedChecklistItems: [],
        linkedTasks: [],
      );
      const b = ChecklistData(
        title: 'List B',
        linkedChecklistItems: [],
        linkedTasks: [],
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('ChecklistData Glados round-trips', () {
    glados.Glados(
      glados.any.generatedChecklistData,
      glados.ExploreConfig(numRuns: 120),
    ).test('ChecklistData round-trips through JSON', (scenario) {
      final data = scenario.checklistData;
      final decoded = ChecklistData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, data, reason: '$scenario');
      expect(decoded.title, data.title, reason: 'title preserved');
      expect(
        decoded.linkedChecklistItems,
        data.linkedChecklistItems,
        reason: 'linkedChecklistItems preserved',
      );
      expect(
        decoded.linkedTasks,
        data.linkedTasks,
        reason: 'linkedTasks preserved',
      );
    }, tags: 'glados');
  });
}

// ---------------------------------------------------------------------------
// Glados generator helpers for ChecklistData.
// ---------------------------------------------------------------------------

class _GeneratedChecklistData {
  const _GeneratedChecklistData({
    required this.titleSlot,
    required this.itemCountSlot,
    required this.taskCountSlot,
  });

  final int titleSlot;
  final int itemCountSlot;
  final int taskCountSlot;

  ChecklistData get checklistData {
    final title = 'Checklist $titleSlot';
    final items = List.generate(
      itemCountSlot % 5,
      (i) => 'item-$titleSlot-$i',
    );
    final tasks = List.generate(
      taskCountSlot % 4,
      (i) => 'task-$titleSlot-$i',
    );
    return ChecklistData(
      title: title,
      linkedChecklistItems: items,
      linkedTasks: tasks,
    );
  }

  @override
  String toString() =>
      '_GeneratedChecklistData(titleSlot: $titleSlot, '
      'itemCountSlot: $itemCountSlot, taskCountSlot: $taskCountSlot)';
}

extension _AnyChecklistData on glados.Any {
  glados.Generator<_GeneratedChecklistData> get generatedChecklistData =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 50),
        glados.IntAnys(this).intInRange(0, 4),
        glados.IntAnys(this).intInRange(0, 3),
        (titleSlot, itemCountSlot, taskCountSlot) => _GeneratedChecklistData(
          titleSlot: titleSlot,
          itemCountSlot: itemCountSlot,
          taskCountSlot: taskCountSlot,
        ),
      );
}
