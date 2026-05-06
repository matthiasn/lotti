import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    show
        Any,
        AnyUtils,
        BoolAny,
        CombinableAny,
        ExploreConfig,
        Generator,
        Glados,
        IntAnys,
        ListAnys,
        any;
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/services/checklist_markdown_exporter.dart';

enum _GeneratedChecklistRowKind { nullRow, active, deleted }

class _GeneratedChecklistRow {
  const _GeneratedChecklistRow({
    required this.kind,
    required this.checked,
    required this.titlePattern,
    required this.value,
  });

  final _GeneratedChecklistRowKind kind;
  final bool checked;
  final int titlePattern;
  final int value;

  String get id => 'generated_$value';

  String get rawTitle {
    return switch (titlePattern % 4) {
      0 => 'Task $value',
      1 => '  Task $value  ',
      2 => 'Task $value\nsecond\tpart',
      _ => 'Task\r$value\n\tfinal',
    };
  }

  String get sanitizedTitle {
    return rawTitle.replaceAll(RegExp(r'[\n\r\t]+'), ' ').trim();
  }

  @override
  String toString() {
    return '_GeneratedChecklistRow('
        'kind: $kind, '
        'checked: $checked, '
        'titlePattern: $titlePattern, '
        'value: $value)';
  }
}

extension _AnyChecklistRows on Any {
  Generator<_GeneratedChecklistRowKind> get checklistRowKind =>
      choose(_GeneratedChecklistRowKind.values);

  Generator<_GeneratedChecklistRow> get checklistRow => combine4(
    checklistRowKind,
    this.bool,
    intInRange(0, 4),
    intInRange(0, 10000),
    (
      _GeneratedChecklistRowKind kind,
      bool checked,
      int titlePattern,
      int value,
    ) => _GeneratedChecklistRow(
      kind: kind,
      checked: checked,
      titlePattern: titlePattern,
      value: value,
    ),
  );

  Generator<List<_GeneratedChecklistRow>> get checklistRows =>
      listWithLengthInRange(0, 24, checklistRow);
}

void main() {
  ChecklistItem makeItem({
    required String id,
    required String title,
    required bool isChecked,
    DateTime? deletedAt,
  }) {
    return ChecklistItem(
      meta: Metadata(
        id: id,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024),
        deletedAt: deletedAt,
      ),
      data: ChecklistItemData(
        title: title,
        isChecked: isChecked,
        linkedChecklists: const [],
      ),
    );
  }

  group('checklistItemsToMarkdown', () {
    test('returns empty for empty input', () {
      expect(checklistItemsToMarkdown(const []), '');
    });

    test('preserves order and checked state', () {
      final md = checklistItemsToMarkdown([
        makeItem(id: '1', title: 'First', isChecked: false),
        makeItem(id: '2', title: 'Second', isChecked: true),
        makeItem(id: '3', title: 'Third', isChecked: false),
      ]);

      expect(
        md,
        '- [ ] First\n- [x] Second\n- [ ] Third',
      );
    });

    test('filters deleted items and trims title', () {
      final md = checklistItemsToMarkdown([
        makeItem(id: '1', title: '  Keep  ', isChecked: false),
        makeItem(
          id: '2',
          title: 'Removed',
          isChecked: true,
          deletedAt: DateTime(2024),
        ),
      ]);

      expect(md, '- [ ] Keep');
    });

    test('collapses newlines and tabs', () {
      final md = checklistItemsToMarkdown([
        makeItem(id: '1', title: 'Line1\nLine2\tTab', isChecked: false),
        makeItem(id: '2', title: '\t\n Spaced ', isChecked: true),
      ]);

      expect(
        md,
        '- [ ] Line1 Line2 Tab\n- [x] Spaced',
      );
    });

    test('replaces carriage returns and filters nulls', () {
      final md = checklistItemsToMarkdown([
        null,
        makeItem(id: '1', title: 'CR\rSeparated', isChecked: true),
        null,
      ]);
      expect(md, '- [x] CR Separated');
    });

    Glados(any.checklistRows, ExploreConfig(numRuns: 160)).test(
      'matches the generated markdown export model',
      (rows) {
        final items = <ChecklistItem?>[
          for (final row in rows)
            switch (row.kind) {
              _GeneratedChecklistRowKind.nullRow => null,
              _GeneratedChecklistRowKind.active => makeItem(
                id: row.id,
                title: row.rawTitle,
                isChecked: row.checked,
              ),
              _GeneratedChecklistRowKind.deleted => makeItem(
                id: row.id,
                title: row.rawTitle,
                isChecked: row.checked,
                deletedAt: DateTime(2024),
              ),
            },
        ];

        final expectedLines = [
          for (final row in rows)
            if (row.kind == _GeneratedChecklistRowKind.active)
              '- [${row.checked ? 'x' : ' '}] ${row.sanitizedTitle}',
        ];

        expect(checklistItemsToMarkdown(items), expectedLines.join('\n'));
      },
    );
  });
}
