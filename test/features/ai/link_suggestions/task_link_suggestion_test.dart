import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/directed_relation.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/ai/link_suggestions/prior_work_mention.dart';
import 'package:lotti/features/ai/link_suggestions/task_link_suggestion.dart';

TaskLinkSuggestion _suggestion({
  String target = 'census',
  DirectedRelation relation = const DirectedRelation(EntryLinkType.followsUp),
  double distance = 0.25,
}) => TaskLinkSuggestion(
  sourceTaskId: 'current',
  targetTaskId: target,
  targetTitle: 'Colony census export',
  relation: relation,
  distance: distance,
  mention: const PriorWorkMention(
    sourceId: 'e1',
    sentence: 'Follow-up to the census export.',
    relation: DirectedRelation(EntryLinkType.followsUp),
    query: 'the census export',
  ),
  mentionedAt: DateTime(2024, 3, 15),
);

void main() {
  test('one key per pair of tasks, whatever relation it proposes', () {
    expect(_suggestion().key, 'current|census');
    expect(
      _suggestion(relation: const DirectedRelation(EntryLinkType.basic)).key,
      _suggestion().key,
    );
    expect(_suggestion(target: 'relay').key, isNot(_suggestion().key));
    expect(TaskLinkSuggestion.pairKey('current', 'census'), _suggestion().key);
  });

  test('is a value', () {
    expect(_suggestion(), _suggestion());
    expect(_suggestion().hashCode, _suggestion().hashCode);
    expect(_suggestion(distance: 0.3), isNot(_suggestion()));
    expect(
      _suggestion().toString(),
      'TaskLinkSuggestion(current follows_up_on census, distance 0.250)',
    );
  });
}
