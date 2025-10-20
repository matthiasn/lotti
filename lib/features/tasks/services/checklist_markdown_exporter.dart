import 'package:lotti/classes/journal_entities.dart';

/// Builds a GitHub-flavored Markdown checklist from the given items.
///
/// - Preserves input order.
/// - Filters out null or deleted items.
/// - Normalizes titles by trimming and collapsing newlines/tabs to spaces.
String checklistItemsToMarkdown(Iterable<ChecklistItem?> items) =>
    _exportChecklistItems(items, (item) {
      final title = _sanitizeTitle(item.data.title);
      final checked = item.data.isChecked ? 'x' : ' ';
      return '- [$checked] $title';
    });

String _sanitizeTitle(String title) {
  final collapsed = title.replaceAll(RegExp(r'[\n\r\t]+'), ' ');
  return collapsed.trim();
}

/// Builds a share-friendly checklist using emoji checkboxes for messenger apps.
///
/// Example line formats:
/// - Unchecked: '⬜ Task title'
/// - Checked:   '✅ Task title'
String checklistItemsToEmojiList(Iterable<ChecklistItem?> items) =>
    _exportChecklistItems(items, (item) {
      final title = _sanitizeTitle(item.data.title);
      final box = item.data.isChecked ? '✅' : '⬜';
      return '$box $title';
    });

String _exportChecklistItems(
  Iterable<ChecklistItem?> items,
  String Function(ChecklistItem item) formatLine,
) {
  final buffer = StringBuffer();
  for (final item in items) {
    if (item == null || item.isDeleted) continue;
    buffer.writeln(formatLine(item));
  }
  return buffer.toString().trimRight();
}
