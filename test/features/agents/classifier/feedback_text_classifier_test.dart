import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/classifier/feedback_text_classifier.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

void main() {
  group('classifyTextSentiment', () {
    test('canonical examples including the balanced-neutral path', () {
      expect(classifyTextSentiment(''), FeedbackSentiment.neutral);
      expect(
        classifyTextSentiment('task completed'),
        FeedbackSentiment.positive,
      );
      expect(
        classifyTextSentiment('hit a problem'),
        FeedbackSentiment.negative,
      );
      // Exactly one positive and one negative keyword: balanced -> neutral.
      expect(
        classifyTextSentiment('the error was resolved'),
        FeedbackSentiment.neutral,
      );
    });

    glados.Glados(
      glados.any.sentimentScenario,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'classification equals the sign of independently recomputed '
      'keyword-containment counts, case-insensitively',
      (scenario) {
        final text = scenario.text;

        // Recompute the score from the published keyword lists rather than
        // trusting the generator's intent: generated keyword combinations
        // can embed extra keywords as substrings (e.g. "fail" in "failed").
        final lower = text.toLowerCase();
        final positives = positiveSentimentKeywords
            .where(lower.contains)
            .length;
        final negatives = negativeSentimentKeywords
            .where(lower.contains)
            .length;
        final expected = positives > negatives
            ? FeedbackSentiment.positive
            : negatives > positives
            ? FeedbackSentiment.negative
            : FeedbackSentiment.neutral;

        expect(
          classifyTextSentiment(text),
          expected,
          reason: text,
        );
        // Case-insensitivity: shouting the same text changes nothing.
        expect(
          classifyTextSentiment(text.toUpperCase()),
          expected,
          reason: 'uppercased: $text',
        );
      },
      tags: 'glados',
    );
  });

  group('argsContainExplanatoryContext', () {
    test('canonical examples', () {
      expect(argsContainExplanatoryContext(null), isFalse);
      expect(argsContainExplanatoryContext(const {}), isFalse);
      expect(
        argsContainExplanatoryContext(const {
          'reason': 'too early in the flow',
        }),
        isTrue,
      );
      // Short values (<4 chars after trim) carry no meaningful signal.
      expect(
        argsContainExplanatoryContext(const {'reason': ' no '}),
        isFalse,
      );
      // Non-explanatory keys never classify, however long the value.
      expect(
        argsContainExplanatoryContext(const {
          'title': 'a perfectly long explanation that does not count',
        }),
        isFalse,
      );
      // Explanatory parent key propagates to nested string values.
      expect(
        argsContainExplanatoryContext(const {
          'feedback': {'text': 'too early'},
        }),
        isTrue,
      );
    });

    glados.Glados(
      glados.any.explanatoryArgsScenario,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'key-separator variants classify identically and the outcome matches '
      'value meaningfulness',
      (scenario) {
        final results = scenario.variantArgs
            .map(argsContainExplanatoryContext)
            .toList();

        // Normalisation invariance: rejection_reason / rejection-reason /
        // rejectionReason wrappings of the SAME payload agree.
        expect(
          results.toSet(),
          hasLength(1),
          reason: 'variants disagreed: $scenario',
        );
        // And the shared outcome is exactly "the explanatory value is
        // meaningful" (>=4 chars after trim), independent of nesting depth.
        expect(results.first, scenario.expectedOutcome, reason: '$scenario');
      },
      tags: 'glados',
    );
  });
}

/// Deterministic sentiment text built from the real keyword lists: picks
/// `positivePicks` / `negativePicks` distinct keywords by seed and joins them
/// with neutral filler, with seed-driven casing.
class _SentimentScenario {
  _SentimentScenario(int positivePicks, int negativePicks, int seed) {
    const positives = positiveSentimentKeywords;
    const negatives = negativeSentimentKeywords;
    final parts = <String>[
      for (var i = 0; i < positivePicks; i++)
        positives[(seed + i * 7) % positives.length],
      for (var i = 0; i < negativePicks; i++)
        negatives[(seed + i * 11) % negatives.length],
    ];
    // Seed-driven shuffle-by-rotation and mixed casing.
    final rotation = parts.isEmpty ? 0 : seed % parts.length;
    final rotated = [...parts.sublist(rotation), ...parts.sublist(0, rotation)];
    final styled = [
      for (var i = 0; i < rotated.length; i++)
        (seed + i).isEven ? rotated[i] : rotated[i].toUpperCase(),
    ];
    text = styled.isEmpty ? 'nothing to see here' : styled.join(' and then ');
  }

  late final String text;

  @override
  String toString() => '_SentimentScenario(text: $text)';
}

/// Builds the SAME explanatory payload wrapped under each key-separator
/// variant of one explanatory key, nested at a seed-chosen depth inside
/// maps/lists. The variants must classify identically.
class _ExplanatoryArgsScenario {
  _ExplanatoryArgsScenario(
    int keyPick,
    int depth,
    int seed, {
    required bool meaningful,
  }) {
    const baseKeys = [
      ['rejection_reason', 'rejection-reason', 'rejectionReason'],
      ['reason', 'REASON', 'Reason'],
      ['note_s', 'note-s', 'noteS'],
      ['feed_back', 'feed-back', 'feedBack'],
    ];
    final variants = baseKeys[keyPick % baseKeys.length];
    final value = meaningful ? 'because it was scheduled too early' : 'ok';
    expectedOutcome = meaningful;

    Map<String, dynamic> wrap(String key) {
      // Nest the explanatory entry under non-explanatory containers.
      var node = <String, dynamic>{key: value};
      for (var i = 0; i < depth % 3; i++) {
        node = (seed + i).isEven
            ? <String, dynamic>{'container$i': node}
            : <String, dynamic>{
                'list$i': <Object>[node, 'filler'],
              };
      }
      return node;
    }

    variantArgs = [for (final v in variants) wrap(v)];
  }

  late final List<Map<String, dynamic>> variantArgs;
  late final bool expectedOutcome;

  @override
  String toString() =>
      '_ExplanatoryArgsScenario(expected: $expectedOutcome, '
      'args: $variantArgs)';
}

extension _AnyFeedbackPureFunctionScenarios on glados.Any {
  glados.Generator<_SentimentScenario> get sentimentScenario =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 1 << 16),
        _SentimentScenario.new,
      );

  glados.Generator<_ExplanatoryArgsScenario> get explanatoryArgsScenario =>
      glados.CombinableAny(this).combine4(
        glados.IntAnys(this).intInRange(0, 16),
        glados.IntAnys(this).intInRange(0, 6),
        glados.IntAnys(this).intInRange(0, 1 << 16),
        glados.AnyUtils(this).choose([false, true]),
        (int keyPick, int depth, int seed, bool meaningful) =>
            _ExplanatoryArgsScenario(
              keyPick,
              depth,
              seed,
              meaningful: meaningful,
            ),
      );
}
