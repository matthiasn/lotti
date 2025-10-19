import 'package:lotti/classes/journal_entities.dart';

/// Builds a GitHub-flavored Markdown checklist from the given items.
///
/// - Preserves input order.
/// - Filters out null or deleted items.
/// - Normalizes titles by trimming and collapsing newlines/tabs to spaces.
String checklistItemsToMarkdown(Iterable<ChecklistItem?> items) {
  final buffer = StringBuffer();
  for (final item in items) {
    if (item == null || item.isDeleted) continue;
    final rawTitle = item.data.title;
    final title = _sanitizeTitle(rawTitle);
    final checked = item.data.isChecked ? 'x' : ' ';
    buffer.writeln('- [$checked] $title');
  }
  return buffer.toString().trimRight();
}

String _sanitizeTitle(String title) {
  final collapsed = title.replaceAll(RegExp(r'[\n\r\t]+'), ' ');
  return collapsed.trim();
}

/// Builds a share-friendly checklist using emoji checkboxes for messenger apps.
///
/// Example line formats:
/// - Unchecked: '⬜ Task title'
/// - Checked:   '✅ Task title'
String checklistItemsToEmojiList(Iterable<ChecklistItem?> items) {
  final buffer = StringBuffer();
  for (final item in items) {
    if (item == null || item.isDeleted) continue;
    final title = _sanitizeTitle(item.data.title);
    final box = item.data.isChecked ? '✅' : '⬜';
    buffer.writeln('$box $title');
  }
  return buffer.toString().trimRight();
}
