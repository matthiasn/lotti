import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/service/text_chunker.dart';
import 'package:lotti/features/goals/logic/goal_evidence_text.dart';

void main() {
  group('truncateGoalEvidenceText properties', () {
    final text = glados.any
        .listWithLengthInRange(
          0,
          60,
          glados.any.combine2(
            glados.any.choose(['Colony', 'count', 'krill', 'ice-shelf', '🐧']),
            glados.any.choose([' ', '  ', '\n', '\t']),
            (String word, String gap) => '$word$gap',
          ),
        )
        .map((pieces) => ' ${pieces.join()}');
    // Budgets from "only the ellipsis fits" upwards; a budget of one token
    // cannot hold even the ellipsis's estimate.
    final budget = glados.any.intInRange(2, 80);

    String kept(String out) =>
        out.endsWith('…') ? out.substring(0, out.length - 1) : out;

    glados.Glados3(
      text,
      budget,
      budget,
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'fits the budget, is the text or a prefix plus …, grows with budget',
      (input, a, b) {
        final trimmed = input.trim();
        final out = truncateGoalEvidenceText(input, a);

        expect(truncateGoalEvidenceText(input, 0), isEmpty);
        expect(TextChunker.estimateTokens(out), lessThanOrEqualTo(a));
        if (out != trimmed) {
          expect(out, endsWith('…'));
          expect(trimmed, startsWith(kept(out)));
        }

        final (small, large) = a <= b ? (a, b) : (b, a);
        expect(
          kept(truncateGoalEvidenceText(input, small)).length,
          lessThanOrEqualTo(
            kept(truncateGoalEvidenceText(input, large)).length,
          ),
        );
      },
      tags: 'glados',
    );
  });
}
