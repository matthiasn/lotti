import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/checklist_item_data.dart';

import '../features/agents/test_utils.dart' show makeTestChecklistApproval;

void main() {
  test('chat approval survives JSON and a rename but not a later toggle', () {
    final receipt = makeTestChecklistApproval();
    final data = ChecklistItemData(
      title: 'Inspect feeder',
      isChecked: true,
      linkedChecklists: ['checklist'],
      checkedAt: receipt.approvedAt,
      approvalHistory: [receipt],
    );
    final stored = ChecklistItemData.fromJson(
      jsonDecode(jsonEncode(data)) as Map<String, dynamic>,
    );
    expect(stored.approvalHistory.single, receipt);
    expect(stored.checkedStateApproval, receipt);
    expect(
      stored
          .copyWith(
            title: 'Inspect orbital feeder',
            approvalHistory: [
              receipt,
              receipt.copyWith(isChecked: null, decisionId: 'rename'),
            ],
          )
          .checkedStateApproval,
      receipt,
    );
    expect(stored.copyWith(isChecked: false).checkedStateApproval, isNull);
    expect(
      stored
          .copyWith(
            checkedAt: receipt.approvedAt.add(
              const Duration(minutes: 1),
            ),
          )
          .checkedStateApproval,
      isNull,
    );
    expect(
      stored.copyWith(checkedBy: ChangeSource.agent).checkedStateApproval,
      isNull,
    );
    expect(stored.copyWith(approvalHistory: []).checkedStateApproval, isNull);
  });
  group('title and archival approvals', () {
    final receipt = makeTestChecklistApproval(isChecked: null);
    final data = ChecklistItemData(
      title: 'Walk pressure seals A–F',
      isChecked: false,
      isArchived: true,
      linkedChecklists: const ['checklist'],
      approvalHistory: [
        receipt.copyWith(title: 'Walk pressure seals A–F'),
        receipt.copyWith(decisionId: 'archive', isArchived: true),
      ],
      titleSetAt: receipt.approvedAt,
      archivedSetAt: receipt.approvedAt,
    );

    test('survive JSON and back only the value they approved', () {
      final stored = ChecklistItemData.fromJson(
        jsonDecode(jsonEncode(data)) as Map<String, dynamic>,
      );
      expect(stored.titleApproval?.title, 'Walk pressure seals A–F');
      expect(stored.archivedStateApproval?.decisionId, 'archive');
      expect(stored.checkedStateApproval, isNull);
    });

    test('a later change of the value supersedes the approval', () {
      expect(data.copyWith(title: 'Walk the seals').titleApproval, isNull);
      expect(data.copyWith(isArchived: false).archivedStateApproval, isNull);
      // Unrelated fields keep each other's protection.
      expect(
        data.copyWith(title: 'Walk the seals').archivedStateApproval,
        isNotNull,
      );
    });

    test('the newest receipt naming a field decides it', () {
      final renamed = data.copyWith(
        approvalHistory: [
          ...data.approvalHistory,
          receipt.copyWith(decisionId: 'rename', title: 'Walk the seals'),
        ],
      );
      expect(renamed.titleApproval, isNull);
      expect(
        renamed
            .copyWith(title: 'Walk the seals')
            .stampedAfter(data, DateTime.utc(2030))
            .titleApproval
            ?.decisionId,
        'rename',
      );
    });

    test('only user-approved chat suggestions count', () {
      expect(
        data
            .copyWith(
              approvalHistory: [
                receipt.copyWith(title: data.title, source: 'imported'),
              ],
            )
            .titleApproval,
        isNull,
      );
      expect(
        data
            .copyWith(
              approvalHistory: [
                receipt.copyWith(isArchived: true, approvedBy: 'agent'),
              ],
            )
            .archivedStateApproval,
        isNull,
      );
    });

    test('an edit back to the approved value does not revive it', () {
      final now = DateTime.utc(2030);
      final away = data
          .copyWith(title: 'Walk the seals', isArchived: false)
          .stampedAfter(data, now);
      final back = away
          .copyWith(title: data.title, isArchived: true)
          .stampedAfter(away, now.add(const Duration(minutes: 1)));
      expect(back.title, data.title);
      expect(back.isArchived, data.isArchived);
      expect(back.titleApproval, isNull);
      expect(back.archivedStateApproval, isNull);
      expect(back.titleSetAt, now.add(const Duration(minutes: 1)));
    });

    test('stampedAfter times a field by the receipt that set it', () {
      final now = DateTime.utc(2030);
      const plain = ChecklistItemData(
        title: 'Seals',
        isChecked: false,
        linkedChecklists: [],
      );
      // Creation: the title is new, the archived state is not.
      final created = plain.stampedAfter(null, now);
      expect(created.titleSetAt, now);
      expect(created.archivedSetAt, isNull);
      // An unchanged write keeps both times.
      final later = now.add(const Duration(hours: 1));
      expect(created.stampedAfter(created, later).titleSetAt, now);
      // An approved rename takes the approval time, not the write time.
      final approved = created
          .copyWith(
            title: 'Walk seals',
            approvalHistory: [receipt.copyWith(title: 'Walk seals')],
          )
          .stampedAfter(created, later);
      expect(approved.titleSetAt, receipt.approvedAt);
      expect(approved.titleApproval, isNotNull);
      expect(approved.archivedSetAt, isNull);
      // An approved restore of an unarchived item still stamps intent.
      final restored = created
          .copyWith(approvalHistory: [receipt.copyWith(isArchived: false)])
          .stampedAfter(created, later);
      expect(restored.archivedSetAt, receipt.approvedAt);
      expect(restored.archivedStateApproval, isNotNull);
    });

    test('currentChatApproval is the newest one still standing', () {
      final later = receipt.approvedAt.add(const Duration(hours: 1));
      final checked = data.copyWith(
        isChecked: true,
        checkedAt: later,
        approvalHistory: [
          ...data.approvalHistory,
          receipt.copyWith(
            decisionId: 'check',
            approvedAt: later,
            isChecked: true,
          ),
        ],
      );
      expect(checked.currentChatApproval?.decisionId, 'check');
      // Toggled by hand since: the older title approval still stands.
      expect(
        checked.copyWith(isChecked: false).currentChatApproval?.approvedAt,
        receipt.approvedAt,
      );
      expect(
        checked
            .copyWith(isChecked: false, title: 'x', isArchived: false)
            .currentChatApproval,
        isNull,
      );
    });
  });

  for (final mode in ChecklistApprovalMode.values) {
    test('approval JSON uses stable ${mode.name} wire mode', () {
      final receipt = makeTestChecklistApproval(mode: mode);
      final json = receipt.toJson();
      expect(
        json['approvalMode'],
        mode == ChecklistApprovalMode.individual ? 'individual' : 'confirm_all',
      );
      expect(ChecklistItemProvenance.fromJson(json), receipt);
    });
  }

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
      // Assert the decoded object's field, not only the pre-encode value.
      expect(restored.checkedAt, data.checkedAt, reason: '$scenario');
      expect(restored.checkedBy, data.checkedBy, reason: '$scenario');
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
