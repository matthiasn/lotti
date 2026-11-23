import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/documents/logic/markdown_block_diff.dart';
import 'package:lotti/features/documents/logic/rewrite_word_marks.dart';
import 'package:lotti/widgets/markdown/agent_markdown_view.dart';
import 'package:material_ui/material_ui.dart';

/// One side of one review row (ADR 0167, direction B): a block rendered as
/// markdown on the surface its change calls for, or — where the other side
/// has a block and this one has none — a dashed empty slot saying so.
///
/// An unchanged block sits on no surface, in medium ink, with no vertical
/// padding — so plain text keeps its paragraph rhythm and the space gathers
/// around the changes, which are what the eye finds. Headings stay at the
/// body's size (`subordinateHeadings`), set apart by weight, so a document's
/// own heading never outranks the review's title. A removed block's current side, an added block's
/// proposed side and both sides of a rewritten one take the matching diff
/// surface; the row's gutter mark says which, so colour is never the only
/// signal.
///
/// Inside a rewritten block, the words [markRewrittenWords] marked sit on
/// [wordMark] — the removed surface on the current side, the added one on
/// the proposed side — so the eye finds the words that changed without
/// reading the paragraph twice.
class ReviewBlockCell extends StatelessWidget {
  const ReviewBlockCell({
    required this.kind,
    required this.block,
    required this.emptyLabel,
    this.quiet = false,
    this.wordMark,
    super.key,
  });

  /// Medium ink on a changed block: the old half of a rewrite stacked above
  /// its new half, which reads first.
  final bool quiet;

  /// The surface a marked word sits on; null leaves marked words plain.
  final Color? wordMark;

  final MarkdownBlockChange kind;

  /// This side's block; null for the empty slot.
  final String? block;

  /// What the empty slot says: which version lacks the block.
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = tokens.radii.m;
    final inset = tokens.spacing.cardItemSpacing;
    final block = this.block;
    if (block == null) {
      return DsDashedBorder(
        color: tokens.colors.decorative.level03,
        radius: radius,
        // A statement, not a field: centred in the slot, which stands as
        // tall as the block beside it.
        child: Padding(
          padding: EdgeInsets.all(inset),
          child: Center(
            child: Text(
              emptyLabel,
              textAlign: TextAlign.center,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        ),
      );
    }
    final diff = tokens.colors.diff;
    // A removed block has only a current side and an added one only a
    // proposed side, so the kind alone picks the surface.
    final surface = switch (kind) {
      MarkdownBlockChange.same => null,
      MarkdownBlockChange.rewritten => diff.replaced.surface,
      MarkdownBlockChange.removed => diff.removed.surface,
      MarkdownBlockChange.added => diff.added.surface,
    };
    final same = kind == MarkdownBlockChange.same;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        // The text edge stays where a surfaced block's text starts.
        padding: same
            ? EdgeInsets.symmetric(horizontal: inset)
            : EdgeInsets.all(inset),
        child: AgentMarkdownView(
          block,
          subordinateHeadings: true,
          inlineDirectives: [
            InlineDirective(
              open: rewriteWordMarkOpen,
              close: rewriteWordMarkClose,
              builder: (context, words, style) => TextSpan(
                text: words,
                style: style.copyWith(backgroundColor: wordMark),
              ),
            ),
          ],
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: same || quiet
                ? tokens.colors.text.mediumEmphasis
                : tokens.colors.text.highEmphasis,
          ),
        ),
      ),
    );
  }
}
