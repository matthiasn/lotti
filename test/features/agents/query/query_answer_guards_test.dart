import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/query/query_answer_guards.dart';

void main() {
  group('withKnownCitations', () {
    test('keeps every citation that names a piece of evidence', () {
      expect(
        withKnownCitations('Fed at noon [1], counted at dusk [2].', 2),
        'Fed at noon [1], counted at dusk [2].',
      );
    });

    test('drops a citation past the evidence, with the space before it', () {
      expect(
        withKnownCitations('Fed at noon [1], counted at dusk [3].', 2),
        'Fed at noon [1], counted at dusk.',
      );
    });

    test('drops a citation of zero: evidence is numbered from one', () {
      expect(withKnownCitations('Fed at noon [0].', 2), 'Fed at noon.');
    });

    test('without evidence, drops every citation and keeps the words', () {
      expect(
        withKnownCitations('Nothing was recorded [1] about it [2].', 0),
        'Nothing was recorded about it.',
      );
    });

    test('a leading citation leaves no leading space', () {
      expect(withKnownCitations('[4] Fed at noon.', 1), 'Fed at noon.');
    });

    test('an answer that was only a citation naming nothing is empty', () {
      expect(withKnownCitations('[9]', 2), isEmpty);
    });

    test('leaves brackets that are not citations alone', () {
      expect(
        withKnownCitations('Checklist [a] and step [2b] stay [1].', 1),
        'Checklist [a] and step [2b] stay [1].',
      );
    });

    glados.Glados2(
      glados.any.listWithLengthInRange(0, 8, glados.any.intInRange(0, 12)),
      glados.any.intInRange(0, 6),
      glados.ExploreConfig(numRuns: 200),
    ).test('every citation left names a piece of evidence, and every one '
        'that does is kept', (cited, evidenceCount) {
      final answer = cited.map((n) => 'Fact [$n].').join(' ');
      final result = withKnownCitations(answer, evidenceCount);
      final left = RegExp(
        r'\[(\d+)\]',
      ).allMatches(result).map((m) => int.parse(m.group(1)!)).toList();
      expect(left.every((n) => n >= 1 && n <= evidenceCount), isTrue);
      expect(left, [
        for (final n in cited)
          if (n >= 1 && n <= evidenceCount) n,
      ]);
    }, tags: 'glados');
  });
}
