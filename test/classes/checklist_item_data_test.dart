import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

    glados.Glados(
      glados.any.generatedChecklistItemData,
      glados.ExploreConfig(numRuns: 160),
    ).test('round-trips generated checklist item data through JSON', (
      scenario,
    ) {
      final data = scenario.data;

      final json = data.toJson();
      final restored = ChecklistItemData.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );

      expect(restored, equals(data), reason: '$scenario');
      expect(json['checkedBy'], data.checkedBy.name, reason: '$scenario');
      expect(json['checkedAt'], data.checkedAt?.toIso8601String());
    }, tags: 'glados');
  });
}

class _GeneratedChecklistItemData {
  const _GeneratedChecklistItemData({
    required this.title,
    required this.isChecked,
    required this.linkedChecklists,
    required this.isArchived,
    required this.idSlot,
    required this.checkedBy,
    required this.checkedAtSlot,
  });

  final String title;
  final bool isChecked;
  final List<String> linkedChecklists;
  final bool isArchived;
  final int idSlot;
  final ChangeSource checkedBy;
  final int checkedAtSlot;

  ChecklistItemData get data => ChecklistItemData(
    title: title,
    isChecked: isChecked,
    linkedChecklists: linkedChecklists,
    isArchived: isArchived,
    id: idSlot.isEven ? null : 'item-$idSlot',
    checkedBy: checkedBy,
    checkedAt: checkedAtSlot.isEven
        ? null
        : DateTime.utc(
            2026,
            2,
            (checkedAtSlot % 28) + 1,
            checkedAtSlot % 24,
            checkedAtSlot % 60,
          ),
  );

  @override
  String toString() {
    return '_GeneratedChecklistItemData('
        'title: "$title", '
        'isChecked: $isChecked, '
        'linkedChecklists: $linkedChecklists, '
        'isArchived: $isArchived, '
        'idSlot: $idSlot, '
        'checkedBy: $checkedBy, '
        'checkedAtSlot: $checkedAtSlot)';
  }
}

extension _AnyChecklistItemData on glados.Any {
  glados.Generator<String> get _checklistText =>
      glados.AnyUtils(this).choose(const [
        '',
        'Plain item',
        'Needs "quotes"',
        r'Backslash \ item',
        'Line\nbreak',
        'Comma, colon: semicolon;',
      ]);

  glados.Generator<_GeneratedChecklistItemData>
  get generatedChecklistItemData => glados.CombinableAny(this).combine7(
    _checklistText,
    this.bool,
    glados.ListAnys(this).listWithLengthInRange(0, 5, _checklistText),
    this.bool,
    glados.IntAnys(this).intInRange(0, 40),
    glados.AnyUtils(this).choose(ChangeSource.values),
    glados.IntAnys(this).intInRange(0, 240),
    (
      String title,
      bool isChecked,
      List<String> linkedChecklists,
      bool isArchived,
      int idSlot,
      ChangeSource checkedBy,
      int checkedAtSlot,
    ) => _GeneratedChecklistItemData(
      title: title,
      isChecked: isChecked,
      linkedChecklists: linkedChecklists,
      isArchived: isArchived,
      idSlot: idSlot,
      checkedBy: checkedBy,
      checkedAtSlot: checkedAtSlot,
    ),
  );
}
