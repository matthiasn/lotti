import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';

void main() {
  const source = QuerySourceRef(
    id: 'penguin-note',
    private: true,
    categoryPrivate: false,
    categoryId: 'penguin-operations',
  );
  final evidence = QueryEvidence(
    source: source,
    kind: QuerySourceKind.recording,
    label: 'Penguin launch review',
    sourceDate: DateTime(2026, 7, 17),
    textVersion: 'transcript:one',
    fingerprint: 'fingerprint',
    sourceText: 'Earlier. Keep the feeder. Later.',
    start: 9,
    end: 25,
    summary: 'Retain the feeder.',
  );

  test('a quote is an exact contiguous slice including punctuation', () {
    expect(evidence.quote, 'Keep the feeder.');
    expect(evidence.copyWith(start: -1).quote, isEmpty);
    expect(evidence.copyWith(end: 200).hasValidPassage, isFalse);
    expect(evidence.copyWith(end: evidence.start).hasValidPassage, isFalse);
  });

  test('answer round trip retains source text and privacy provenance', () {
    final answer = QueryChatEventData.answer(
      questionId: 'question',
      text: 'Keep the feeder [1].',
      coverage: const QueryCoverage(checked: 3, incomplete: true),
      evidence: [evidence],
      dependencies: [source],
      recalledMemoryIds: ['memory'],
      private: true,
    );
    final decoded = QueryChatEventData.fromJson(
      jsonDecode(jsonEncode(answer.toJson())) as Map<String, dynamic>,
    );
    expect(decoded, answer);
    expect((decoded as QueryChatAnswer).evidence.single.quote, evidence.quote);
    expect(decoded.dependencies.single.private, isTrue);
    expect(decoded.coverage.incomplete, isTrue);
  });

  test('delete choices and home scope survive serialization', () {
    for (final event in <QueryChatEventData>[
      const QueryChatEventData.created(
        scope: QueryScope(kind: QueryScopeKind.task, id: 'penguin-task'),
        title: 'Feeder',
      ),
      const QueryChatEventData.deleted(forget: true),
      const QueryChatEventData.deleted(forget: false),
      const QueryChatEventData.archived(archived: false),
      const QueryChatEventData.memory(
        questionId: 'question',
        text: 'Keep the feeder.',
        dependencies: [source],
      ),
    ]) {
      expect(
        QueryChatEventData.fromJson(
          jsonDecode(jsonEncode(event.toJson())) as Map<String, dynamic>,
        ),
        event,
      );
    }
  });
}
