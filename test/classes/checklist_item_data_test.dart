import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';

void main() {
  group('ChecklistItemData serialization', () {
    test('round-trips with all fields', () {
      final data = ChecklistItemData(
        title: 'Deploy to prod',
        isChecked: true,
        linkedChecklists: ['cl-1'],
        checkedBy: ChangeSource.agent,
        checkedAt: DateTime.utc(2026, 2, 28, 22),
      );

      final json = data.toJson();
      final restored = ChecklistItemData.fromJson(json);

      expect(restored.title, 'Deploy to prod');
      expect(restored.isChecked, true);
      expect(restored.linkedChecklists, ['cl-1']);
      expect(restored.checkedBy, ChangeSource.agent);
      expect(restored.checkedAt, DateTime.utc(2026, 2, 28, 22));
    });

    test('deserializes legacy JSON without provenance fields', () {
      final legacyJson = <String, dynamic>{
        'title': 'Old task',
        'isChecked': true,
        'linkedChecklists': <String>['cl-1'],
        'isArchived': false,
      };

      final data = ChecklistItemData.fromJson(legacyJson);

      expect(data.title, 'Old task');
      expect(data.isChecked, true);
      expect(data.checkedBy, ChangeSource.user);
      expect(data.checkedAt, isNull);
    });

    test('serializes checkedBy as string enum name', () {
      const data = ChecklistItemData(
        title: 'Test',
        isChecked: false,
        linkedChecklists: [],
        checkedBy: ChangeSource.agent,
      );

      final json = data.toJson();

      expect(json['checkedBy'], 'agent');
    });

    test('serializes checkedAt as ISO 8601 string', () {
      final data = ChecklistItemData(
        title: 'Test',
        isChecked: true,
        linkedChecklists: [],
        checkedAt: DateTime.utc(2026, 2, 28, 22, 30),
      );

      final json = data.toJson();

      expect(json['checkedAt'], '2026-02-28T22:30:00.000Z');
    });

    test('serializes null checkedAt as null', () {
      const data = ChecklistItemData(
        title: 'Test',
        isChecked: false,
        linkedChecklists: [],
      );

      final json = data.toJson();

      expect(json['checkedAt'], isNull);
    });

    test('defaults checkedBy to user', () {
      const data = ChecklistItemData(
        title: 'Test',
        isChecked: false,
        linkedChecklists: [],
      );

      expect(data.checkedBy, ChangeSource.user);
    });

    test('ChangeSource enum has expected values', () {
      expect(ChangeSource.values.length, 2);
      expect(ChangeSource.values, contains(ChangeSource.user));
      expect(ChangeSource.values, contains(ChangeSource.agent));
    });

    test('deserializes unknown checkedBy value as user', () {
      final json = <String, dynamic>{
        'title': 'Future item',
        'isChecked': false,
        'linkedChecklists': <String>[],
        'checkedBy': 'some_future_value',
      };

      final data = ChecklistItemData.fromJson(json);

      expect(data.checkedBy, ChangeSource.user);
    });
  });
}
