import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/workflow/soul_evolution_context_builder.dart';

class GeneratedSoulContextCounts {
  const GeneratedSoulContextCounts({
    required this.templateCount,
    required this.versionCount,
    required this.noteCount,
    required this.feedbackTemplateCount,
    required this.feedbackItemsPerTemplate,
  });

  final int templateCount;
  final int versionCount;
  final int noteCount;
  final int feedbackTemplateCount;
  final int feedbackItemsPerTemplate;

  int get expectedTemplateOverflow =>
      templateCount > SoulEvolutionContextBuilder.maxCrossTemplateNames
      ? templateCount - SoulEvolutionContextBuilder.maxCrossTemplateNames
      : 0;

  int get expectedVersionHistoryCount =>
      versionCount - 1 > SoulEvolutionContextBuilder.maxVersionHistory
      ? SoulEvolutionContextBuilder.maxVersionHistory
      : versionCount - 1;

  int get expectedNoteCount =>
      noteCount > SoulEvolutionContextBuilder.maxPastNotes
      ? SoulEvolutionContextBuilder.maxPastNotes
      : noteCount;

  int get expectedFeedbackItems {
    var remaining = SoulEvolutionContextBuilder.maxTotalFeedbackItems;
    var written = 0;
    for (var i = 0; i < feedbackTemplateCount; i++) {
      if (remaining <= 0) break;
      final perTemplate =
          feedbackItemsPerTemplate >
              SoulEvolutionContextBuilder.maxFeedbackItemsPerTemplate
          ? SoulEvolutionContextBuilder.maxFeedbackItemsPerTemplate
          : feedbackItemsPerTemplate;
      final fromThisTemplate = perTemplate > remaining
          ? remaining
          : perTemplate;
      written += fromThisTemplate;
      remaining -= fromThisTemplate;
    }
    return written;
  }

  @override
  String toString() {
    return 'GeneratedSoulContextCounts('
        'templateCount: $templateCount, '
        'versionCount: $versionCount, '
        'noteCount: $noteCount, '
        'feedbackTemplateCount: $feedbackTemplateCount, '
        'feedbackItemsPerTemplate: $feedbackItemsPerTemplate)';
  }
}

extension AnyFeedbackSentiments on glados.Any {
  glados.Generator<FeedbackSentiment> get feedbackSentiment =>
      glados.AnyUtils(this).choose(FeedbackSentiment.values);

  /// A small list of sentiments (≤ 9) — kept under the per-template cap so the
  /// ordering invariant is observed without truncation interference.
  glados.Generator<List<FeedbackSentiment>> get feedbackSentimentList =>
      glados.ListAnys(this).listWithLengthInRange(1, 9, feedbackSentiment);
}

extension AnyGeneratedSoulContextCounts on glados.Any {
  glados.Generator<GeneratedSoulContextCounts> get soulContextCounts =>
      glados.CombinableAny(this).combine5(
        glados.IntAnys(this).intInRange(
          0,
          SoulEvolutionContextBuilder.maxCrossTemplateNames + 8,
        ),
        glados.IntAnys(this).intInRange(
          1,
          SoulEvolutionContextBuilder.maxVersionHistory + 8,
        ),
        glados.IntAnys(this).intInRange(
          0,
          SoulEvolutionContextBuilder.maxPastNotes + 8,
        ),
        glados.IntAnys(this).intInRange(0, 8),
        glados.IntAnys(this).intInRange(
          0,
          SoulEvolutionContextBuilder.maxFeedbackItemsPerTemplate + 8,
        ),
        (
          int templateCount,
          int versionCount,
          int noteCount,
          int feedbackTemplateCount,
          int feedbackItemsPerTemplate,
        ) => GeneratedSoulContextCounts(
          templateCount: templateCount,
          versionCount: versionCount,
          noteCount: noteCount,
          feedbackTemplateCount: feedbackTemplateCount,
          feedbackItemsPerTemplate: feedbackItemsPerTemplate,
        ),
      );
}
