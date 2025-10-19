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

  group('checklistItemsToEmojiList', () {
    test('returns empty for empty input', () {
      expect(checklistItemsToEmojiList(const []), '');
    });

    test('uses emoji and preserves order', () {
      final text = checklistItemsToEmojiList([
        makeItem(id: '1', title: 'First', isChecked: false),
        makeItem(id: '2', title: 'Second', isChecked: true),
      ]);
      expect(text, '⬜ First\n✅ Second');
    });

    test('filters deleted items and sanitizes title', () {
      final text = checklistItemsToEmojiList([
        makeItem(id: '1', title: '  Keep\tThis  ', isChecked: false),
        makeItem(
          id: '2',
          title: 'Remove',
          isChecked: true,
          deletedAt: DateTime(2024),
        ),
      ]);
      expect(text, '⬜ Keep This');
    });
  });
}
