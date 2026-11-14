import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/query/query_answer_points.dart';

void main() {
  QueryAnswerPoint point(String text, [List<int> sources = const []]) =>
      QueryAnswerPoint(text: text, sources: sources);

  test('a paragraph is a point, its citations lifted out as its sources, '
      'each once, in the order first cited', () {
    expect(
      queryAnswerPoints(
        'Due October 3 [2], still open [1][2].\n\n'
        'The note says "this week" [3].',
        3,
      ),
      [
        point('Due October 3, still open.', [2, 1]),
        point('The note says "this week".', [3]),
      ],
    );
  });

  test('a citation naming no evidence is no source', () {
    expect(queryAnswerPoints('Counted twice [1] [4] [0].', 2), [
      point('Counted twice.', [1]),
    ]);
  });

  test('a paragraph of citations alone adds them to the point before it', () {
    expect(queryAnswerPoints('Promised twice [1].\n\n[2] [1]', 2), [
      point('Promised twice.', [1, 2]),
    ]);
  });

  test('a paragraph without citations is a point without sources; one of '
      'citations alone with nothing before it is dropped', () {
    expect(queryAnswerPoints('[1]\n\nNothing says when.\n  \n', 1), [
      point('Nothing says when.'),
    ]);
  });

  test('lines of one paragraph stay one point', () {
    expect(queryAnswerPoints('- fed [1]\n- counted [2]', 2), [
      point('- fed\n- counted', [1, 2]),
    ]);
  });

  test('paragraphs split at Windows line endings too', () {
    expect(queryAnswerPoints('Fed [1].\r\n\r\nCounted [2].', 2), [
      point('Fed.', [1]),
      point('Counted.', [2]),
    ]);
  });
}
