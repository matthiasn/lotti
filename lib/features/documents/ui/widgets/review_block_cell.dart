import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/documents/logic/markdown_block_diff.dart';
import 'package:lotti/widgets/markdown/agent_markdown_view.dart';
import 'package:material_ui/material_ui.dart';

/// One side of one review row (ADR 0166, direction B): a block rendered as
/// markdown on the surface its change calls for, or — where the other side
/// has a block and this one has none — a dashed empty slot saying so.
///
/// An unchanged block sits on no surface, in medium ink, so the changes are
/// what the eye finds. A removed block's current side, an added block's
/// proposed side and both sides of a rewritten one take the matching diff
/// surface; the row's gutter mark says which, so colour is never the only
/// signal.
class ReviewBlockCell extends StatelessWidget {
  const ReviewBlockCell({
    required this.kind,
    required this.block,
    required this.emptyLabel,
    super.key,
  });

  final MarkdownBlockChange kind;

  /// This side's block; null for the empty slot.
  final String? block;

  /// What the empty slot says: which version lacks the block.
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = tokens.radii.m;
    final padding = EdgeInsets.all(tokens.spacing.cardItemSpacing);
    final block = this.block;
    if (block == null) {
      return DsDashedBorder(
        color: tokens.colors.decorative.level03,
        radius: radius,
        child: Padding(
          padding: padding,
          child: Text(
            emptyLabel,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: padding,
        child: AgentMarkdownView(
          block,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: kind == MarkdownBlockChange.same
                ? tokens.colors.text.mediumEmphasis
                : tokens.colors.text.highEmphasis,
          ),
        ),
      ),
    );
  }
}
