import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/features/front_agent/model/front_cited_answer.dart';

void main() {
  QueryEvidence evidence(
    String id, {
    QuerySourceKind kind = QuerySourceKind.text,
    String textVersion = 'entryText',
  }) => QueryEvidence(
    source: QuerySourceRef(
      id: id,
      private: false,
      categoryPrivate: false,
      categoryId: 'c',
    ),
    kind: kind,
    label: 'Label $id',
    sourceDate: DateTime.utc(2026, 10, 20, 7),
    textVersion: textVersion,
    fingerprint: id,
    sourceText: '  The hinge squeaks.  ',
    start: 0,
    end: 22,
    summary: '',
  );

  test('an answer becomes its points, each with the evidence it cites', () {
    final memo = evidence(
      'memo',
      kind: QuerySourceKind.recording,
      textVersion: 'transcript:whisper:t1',
    );
    final note = evidence('note');

    final points = FrontCitedPoint.fromAnswer(
      'Still squeaking [2] [1].\n\nNo plan.',
      [note, memo],
    );

    expect(points.map((p) => p.text), ['Still squeaking.', 'No plan.']);
    expect(points.first.sources.map((s) => s.id), ['memo', 'note']);
    final cited = points.first.sources.first;
    expect(cited.kind, QuerySourceKind.recording);
    expect(cited.label, 'Label memo');
    expect(cited.date, DateTime.utc(2026, 10, 20, 7));
    expect(cited.quote, 'The hinge squeaks.');
    expect(cited.transcript, isTrue);
    expect(points.first.sources.last.transcript, isFalse);
    expect(points.last.sources, isEmpty);
  });

  test('points survive being stored and read back', () {
    final points = FrontCitedPoint.fromAnswer('Squeaks [1].\n\nNo plan.', [
      evidence('note'),
    ]);

    final read = FrontCitedPoint.listFromJson([
      for (final point in points) point.toJson(),
    ]);

    expect(read.map((p) => p.text), ['Squeaks.', 'No plan.']);
    final source = read.first.sources.single;
    expect(source.id, 'note');
    expect(source.kind, QuerySourceKind.text);
    expect(source.date, DateTime.utc(2026, 10, 20, 7));
    expect(source.quote, 'The hinge squeaks.');
  });

  test('a stored shape this build does not know is dropped, never a reason '
      'to lose the rest', () {
    final read = FrontCitedPoint.listFromJson([
      {'text': 42},
      'not a point',
      {
        'text': 'Squeaks.',
        'sources': [
          {'id': 'e', 'kind': 'hologram', 'label': 'L', 'date': '2026-10-20'},
          {'id': 'e', 'kind': 'text', 'label': 'L', 'date': 'someday'},
          {'id': 'e', 'kind': 'text', 'label': 'L', 'date': '2026-10-20'},
        ],
      },
    ]);

    expect(read.single.text, 'Squeaks.');
    expect(read.single.sources.single.quote, isEmpty);
    expect(FrontCitedPoint.listFromJson('nope'), isEmpty);
  });
}
