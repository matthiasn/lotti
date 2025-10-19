import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/services/checklist_markdown_exporter.dart';

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
  });
}
