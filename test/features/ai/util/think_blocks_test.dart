import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/util/think_blocks.dart';

void main() {
  group('stripThinkBlocks — Glados properties', () {
    // Compose inputs from plain segments and think blocks; seed bit i
    // decides whether segment i is wrapped in a think block.
    glados.Glados2<List<int>, int>(
      glados.ListAnys(glados.any).listWithLengthInRange(
        0,
        6,
        glados.IntAnys(glados.any).intInRange(0, 1 << 16),
      ),
      glados.IntAnys(glados.any).intInRange(0, 1 << 6),
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'output never contains think tags; null iff every segment is a '
      'think block',
      (seeds, mask) {
        final plainParts = <String>[];
        final buffer = StringBuffer();
        for (final (i, seed) in seeds.indexed) {
          final text = 'seg$seed';
          if ((mask >> i) & 1 == 1) {
            final tag = seed.isEven ? 'think' : 'thinking';
            buffer.write('<$tag>hidden $text</$tag> ');
          } else {
            plainParts.add(text);
            buffer.write('$text ');
          }
        }

        final result = stripThinkBlocks(buffer.toString());

        if (plainParts.isEmpty) {
          expect(result, isNull, reason: 'input: $buffer');
        } else {
          expect(result, isNotNull, reason: 'input: $buffer');
          expect(result, isNot(contains('<think')));
          expect(result, isNot(contains('</think')));
          expect(result, isNot(contains('hidden')));
          for (final part in plainParts) {
            expect(result, contains(part), reason: 'input: $buffer');
          }
        }

        // Null propagates.
        expect(stripThinkBlocks(null), isNull);
      },
      tags: 'glados',
    );
  });

  test('drops an unclosed block through the end of input', () {
    expect(stripThinkBlocks('Answer <think>cut off mid-thought'), 'Answer');
    expect(stripThinkBlocks('<thinking>never closed'), isNull);
  });

  test('trims and returns null when only whitespace remains', () {
    expect(stripThinkBlocks('  <think>x</think>\n Answer  '), 'Answer');
    expect(stripThinkBlocks(' <THINKING a=1>x</THINKING> '), isNull);
  });
}
