import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/model/observation_record.dart';

/// The longest routine or notable task-agent observation, in characters.
///
/// Every observation stays verbatim in the task log until the next fold, so
/// it is re-sent on every request of every later wake. Critical notes are
/// exempt: they feed template evolution, where context is the point.
const taskObservationMaxChars = 280;

/// The most non-critical observations one `record_observations` call keeps.
const taskObservationMaxItems = 3;

/// What a task agent records as an observation, and what it never does.
///
/// Interpolated into both task scaffolds, so the full and the compact prompt
/// state one contract. The report's prose is withheld from the next wake on
/// purpose, which used to make observations carry the task's state from wake
/// to wake; the context shows that state fresh every time.
const taskObservationRule =
    '''
Record an observation only for what a later wake needs and cannot read from
the task log, the task state, the proposal ledger or the pull requests: why
you made a non-obvious decision, a preference or settled question of the
user's, an anomaly or a pattern across wakes, a blocker or a tool failure.
One fact per note, at most $taskObservationMaxChars characters. Never restate
the task's status, checklist, time entries or pull requests, never copy the
user's words (cite the entry as `(id: <entryId>)` instead), and never repeat
an observation already in the log: if it still holds, record nothing; if it
changed, record only the change and add `[[supersedes:<observationId>]]`.
Most wakes record nothing, and that is fine.''';

/// [records] after the task-agent observation contract, plus one reason per
/// note it dropped, for the tool reply.
///
/// Drops a routine or notable note longer than [taskObservationMaxChars],
/// one whose text matches [earlier] (the agent's recent observations and
/// this wake's) after normalising case, spacing and punctuation, and
/// non-critical notes past [taskObservationMaxItems]. Critical notes are
/// never dropped for length or count — a lost grievance costs more than its
/// tokens — but are for being a repeat.
({List<ObservationRecord> kept, List<String> skipped})
applyTaskObservationContract(
  List<ObservationRecord> records, {
  required Iterable<String> earlier,
}) {
  // shortcut: exact match after normalising only, upgrade to a similarity
  // score if near-duplicates still get through in the Observations tab.
  final seen = {for (final text in earlier) _normalise(text)};
  final kept = <ObservationRecord>[];
  final skipped = <String>[];
  var nonCritical = 0;
  for (final record in records) {
    final critical = record.priority == ObservationPriority.critical;
    final preview = _preview(record.text);
    final key = _normalise(record.text);
    if (seen.contains(key)) {
      skipped.add('"$preview" is already recorded');
    } else if (!critical && record.text.length > taskObservationMaxChars) {
      skipped.add(
        '"$preview" is ${record.text.length} characters; shorten it to '
        '$taskObservationMaxChars',
      );
    } else if (!critical && ++nonCritical > taskObservationMaxItems) {
      skipped.add('"$preview" is past the limit of $taskObservationMaxItems');
    } else {
      // Only a kept note counts as recorded: a dropped one may come back.
      seen.add(key);
      kept.add(record);
    }
  }
  return (kept: kept, skipped: skipped);
}

String _normalise(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();

String _preview(String text) =>
    text.length <= 40 ? text : '${text.substring(0, 40)}…';
