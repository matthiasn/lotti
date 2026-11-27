import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_document_data.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/utils/relative_age_label.dart';

/// Who wrote [version], in words: the user by hand, the user restoring an
/// older version, or the agent (ADR 0167).
String taskDocumentAuthorship(
  AppLocalizations messages,
  TaskDocumentVersionEntry version,
) {
  if (version.data.restoredFromVersionId != null) {
    return messages.taskDocumentsRestoredByYou;
  }
  return switch (version.data.author) {
    TaskDocumentAuthor.user => messages.taskDocumentsWrittenByYou,
    TaskDocumentAuthor.agent => messages.taskDocumentsWrittenByAgent,
  };
}

/// One line about [version]: its number, who wrote it and how long ago —
/// "v3 · Written by you · 2 h ago".
String taskDocumentVersionLine(
  AppLocalizations messages,
  TaskDocumentVersionEntry version, {
  required DateTime now,
}) => [
  messages.taskDocumentsVersion(version.data.number),
  taskDocumentAuthorship(messages, version),
  relativeAgeOrDateLabel(messages, at: version.meta.createdAt, now: now),
].join(' · ');
