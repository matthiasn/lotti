import 'package:lotti/classes/dashboard_health_config.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/utils/entry_tools.dart';
import 'package:meta/meta.dart';

/// The text one journal entity contributes to the search index, by weight:
/// what it is called, what it says, and what else identifies it.
@immutable
class SearchDocument {
  const SearchDocument({
    required this.title,
    required this.body,
    required this.extra,
  });

  /// The name a user searches for first — a task's or project's title, a
  /// checklist item — ranked above every other column.
  final String title;

  /// The entity's own words: an entry's text, a recording's transcript, a
  /// model's response, a pull request's description.
  final String body;

  /// Everything else that identifies it: a measurement's name and value, a
  /// survey's scores, a pull request's `owner/repo#number`.
  final String extra;

  bool get isEmpty =>
      title.trim().isEmpty && body.trim().isEmpty && extra.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      other is SearchDocument &&
      other.title == title &&
      other.body == body &&
      other.extra == extra;

  @override
  int get hashCode => Object.hash(title, body, extra);

  @override
  String toString() => 'SearchDocument($title | $body | $extra)';
}

/// What [entity] contributes to the search index.
///
/// A measurement's name and value labels live on its definition, so
/// [measurableDataType] resolves it — the definition being indexed when a
/// definition edit reindexes its measurements, else the cached one.
SearchDocument searchDocumentFor(
  JournalEntity entity, {
  required MeasurableDataType? Function(String dataTypeId) measurableDataType,
}) {
  final text = entity.entryText?.plainText ?? '';
  return entity.maybeMap(
    task: (task) =>
        SearchDocument(title: task.data.title, body: text, extra: ''),
    project: (project) =>
        SearchDocument(title: project.data.title, body: text, extra: ''),
    relationship: (person) =>
        SearchDocument(title: person.data.title, body: text, extra: ''),
    // A spec snapshot is a version of its goal, which is found instead.
    goal: (goal) => goal.data.snapshotOf != null
        ? const SearchDocument(title: '', body: '', extra: '')
        : SearchDocument(
            title: goal.data.title,
            body: _joined([goal.data.statement, text]),
            extra: '',
          ),
    event: (event) =>
        SearchDocument(title: event.data.title, body: text, extra: ''),
    checklist: (checklist) =>
        SearchDocument(title: checklist.data.title, body: text, extra: ''),
    checklistItem: (item) =>
        SearchDocument(title: item.data.title, body: text, extra: ''),
    // The edited text when there is one, else what was transcribed last.
    journalAudio: (audio) => SearchDocument(
      title: '',
      body: text.trim().isNotEmpty
          ? text
          : audio.data.transcripts?.lastOrNull?.transcript ?? '',
      extra: '',
    ),
    aiResponse: (response) => SearchDocument(
      title: response.data.oneLiner ?? '',
      body: text.trim().isNotEmpty ? text : response.data.response,
      extra: '',
    ),
    pullRequest: (pr) => SearchDocument(
      title: pr.data.snapshot?.title ?? '',
      body: _joined([pr.data.snapshot?.body, text]),
      extra: pr.data.key,
    ),
    survey: (survey) => SearchDocument(
      title: survey.data.taskResult.identifier,
      body: text,
      extra: [
        for (final score in survey.data.calculatedScores.entries)
          '${score.key}: ${score.value}',
      ].join('\n'),
    ),
    // A check-in is found by what it was about and what to bring up next
    // time, not only by its note (ADR 0139).
    checkIn: (checkIn) => SearchDocument(
      title: _joined([
        ...checkIn.data.topics,
        checkIn.data.payAttentionTo,
        checkIn.data.avoid,
      ], separator: ' '),
      body: text,
      extra: '',
    ),
    // A choice recording indexes the choice's title, so searching for
    // "clear" finds the hydration entry; a number keeps value and unit.
    measurement: (m) {
      final dataType = measurableDataType(m.data.dataTypeId);
      final value = dataType == null
          ? '${m.data.value}'
          : measurementValueLabel(m.data, dataType);
      return SearchDocument(
        title: '',
        body: text,
        extra: _joined([dataType?.displayName, value], separator: ' '),
      );
    },
    quantitative: (q) {
      final healthType = healthTypes[q.data.dataType];
      final unit = healthType?.unit ?? q.data.unit;
      final displayName = healthType?.displayName ?? q.data.dataType;
      return SearchDocument(
        title: '',
        body: text,
        extra: '${q.data.value} $unit $displayName',
      );
    },
    orElse: () => SearchDocument(title: '', body: text, extra: ''),
  );
}

String _joined(Iterable<String?> parts, {String separator = '\n'}) => [
  for (final part in parts)
    if (part != null && part.trim().isNotEmpty) part,
].join(separator);
