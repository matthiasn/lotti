import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/documents/logic/markdown_block_diff.dart';
import 'package:lotti/features/documents/ui/widgets/review_block_cell.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Keys the tests find a row's parts by.
abstract final class ReviewBlockRowKeys {
  static const gutter = Key('review-block-row-gutter');
}

/// One row of the side-by-side review (ADR 0166, direction B): the current
/// version's block on the left, the proposed one's on the right, each in
/// its own cell, with a mark in the leading gutter for a changed row — ＋
/// added, − removed, ~ rewritten — in the diff colour, and a label a screen
/// reader says. The cells are top-aligned and keep their own heights, so a
/// short block beside a long one leaves space rather than stretching.
///
/// [baseVersion] and [proposedVersion] name the empty slots ("Not in v3");
/// a null [baseVersion] means the document had no text, and its slot says
/// [noTextLabel] instead.
class ReviewBlockRow extends StatelessWidget {
  const ReviewBlockRow({
    required this.pair,
    required this.baseVersion,
    required this.proposedVersion,
    required this.noTextLabel,
    super.key,
  });

  final MarkdownBlockPair pair;
  final int? baseVersion;
  final int proposedVersion;
  final String noTextLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final diff = tokens.colors.diff;
    final mark = switch (pair.kind) {
      MarkdownBlockChange.same => null,
      MarkdownBlockChange.added => (
        LottiIcons.add,
        diff.added.color,
        messages.documentReviewAdded,
      ),
      MarkdownBlockChange.removed => (
        LottiIcons.remove,
        diff.removed.color,
        messages.documentReviewRemoved,
      ),
      MarkdownBlockChange.rewritten => (
        LottiIcons.edit,
        diff.replaced.color,
        messages.documentReviewRewritten,
      ),
    };
    final baseVersion = this.baseVersion;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: IconSizes.m,
          child: mark == null
              ? null
              : Padding(
                  padding: EdgeInsets.only(
                    top: tokens.spacing.cardItemSpacing,
                  ),
                  child: Icon(
                    mark.$1,
                    key: ReviewBlockRowKeys.gutter,
                    size: IconSizes.m,
                    color: mark.$2,
                  ),
                ),
        ),
        SizedBox(width: tokens.spacing.step2),
        Expanded(
          child: ReviewBlockCell(
            kind: pair.kind,
            block: pair.base,
            emptyLabel: baseVersion == null
                ? noTextLabel
                : messages.documentReviewNotInVersion(baseVersion),
          ),
        ),
        SizedBox(width: tokens.spacing.step6),
        Expanded(
          child: ReviewBlockCell(
            kind: pair.kind,
            block: pair.proposed,
            emptyLabel: messages.documentReviewNotInVersion(proposedVersion),
          ),
        ),
      ],
    );
    if (mark == null) return row;
    return Semantics(container: true, label: mark.$3, child: row);
  }
}
