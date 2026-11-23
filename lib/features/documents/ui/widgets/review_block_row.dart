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
/// added, − removed, ⇄ rewritten — in the diff colour, and a
/// label a screen reader says. A changed row is one band: its two cells — or
/// a block and the empty slot beside it — share a top and a bottom edge, the
/// shorter standing as tall as the other. An unchanged row is plain text and
/// keeps each side's own height.
///
/// [baseVersion] and [proposedVersion] name the empty slots ("Not in v3");
/// a null [baseVersion] means the document had no text, and its slot says
/// [noTextLabel] instead. A null [proposedVersion] is a draft that would not
/// become the next version — written over an older one — and its slot says
/// "Not in the draft".
///
/// [stacked] is the one-column form, for a pane too narrow for two: the
/// row's blocks one above the other in reading order, with no empty slots.
/// A rewritten block keeps the rewrite's surface on both halves — red and
/// green mean removed and added on every width — and its old text, quiet,
/// sits under "Current" above its new text under "Proposed".
class ReviewBlockRow extends StatelessWidget {
  const ReviewBlockRow({
    required this.pair,
    required this.baseVersion,
    required this.proposedVersion,
    required this.noTextLabel,
    this.stacked = false,
    this.stale = false,
    super.key,
  });

  final MarkdownBlockPair pair;
  final int? baseVersion;
  final int? proposedVersion;
  final String noTextLabel;
  final bool stacked;

  /// The draft was written over an older version than the document shows;
  /// a stacked rewrite then heads its old half "Drafted over".
  final bool stale;

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
        LottiIcons.compare,
        diff.replaced.color,
        messages.documentReviewRewritten,
      ),
    };
    final baseVersion = this.baseVersion;
    final proposedVersion = this.proposedVersion;
    final band = !stacked && pair.kind != MarkdownBlockChange.same;
    // Stacked, a rewrite opens with its "Current" caption: the mark sits
    // level with the first line of text below it.
    final caption = tokens.typography.styles.others.caption;
    final markTop = stacked && pair.kind == MarkdownBlockChange.rewritten
        ? (caption.fontSize! * (caption.height ?? 1)) +
              tokens.spacing.step1 +
              tokens.spacing.cardItemSpacing
        : tokens.spacing.cardItemSpacing;
    final Widget row = Row(
      crossAxisAlignment: band
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: IconSizes.m,
          child: mark == null
              ? null
              // Top-aligned in a stretched band too.
              : Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: markTop),
                    child: Icon(
                      mark.$1,
                      key: ReviewBlockRowKeys.gutter,
                      size: IconSizes.m,
                      color: mark.$2,
                    ),
                  ),
                ),
        ),
        SizedBox(width: tokens.spacing.step2),
        if (stacked)
          Expanded(child: _stackedCells(context, tokens))
        else ...[
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
              emptyLabel: proposedVersion == null
                  ? messages.documentReviewNotInDraft
                  : messages.documentReviewNotInVersion(proposedVersion),
            ),
          ),
        ],
      ],
    );
    final sized = band ? IntrinsicHeight(child: row) : row;
    if (mark == null) return sized;
    return Semantics(container: true, label: mark.$3, child: sized);
  }

  Widget _stackedCells(BuildContext context, DsTokens tokens) {
    final messages = context.messages;
    final kind = pair.kind;
    if (kind != MarkdownBlockChange.rewritten) {
      // One side only — or both the same, shown once.
      return ReviewBlockCell(
        kind: kind,
        block: kind == MarkdownBlockChange.removed ? pair.base : pair.proposed,
        emptyLabel: noTextLabel,
      );
    }
    final head = tokens.typography.styles.others.caption.copyWith(
      fontWeight: tokens.typography.weight.semiBold,
    );
    final accent = tokens.colors.aiCard.accent;
    final textEdge = EdgeInsets.only(left: tokens.spacing.cardItemSpacing);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: textEdge,
          // A stale draft's old half is the version it was written over,
          // not the document's current text.
          child: Text(
            stale
                ? messages.documentReviewBase
                : messages.documentReviewCurrent,
            style: head.copyWith(
              color: stale
                  ? tokens.colors.alert.warning.defaultColor
                  : tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.step1),
        ReviewBlockCell(
          kind: kind,
          block: pair.base,
          emptyLabel: noTextLabel,
          quiet: true,
        ),
        // More air above "Proposed" than below it: the caption belongs to
        // the block it heads.
        SizedBox(height: tokens.spacing.cardItemSpacing),
        Padding(
          padding: textEdge,
          child: Row(
            children: [
              Icon(LottiIcons.aiSpark, size: IconSizes.s, color: accent),
              SizedBox(width: tokens.spacing.step1),
              Text(
                messages.documentReviewProposed,
                style: head.copyWith(color: accent),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.step1),
        ReviewBlockCell(
          kind: kind,
          block: pair.proposed,
          emptyLabel: noTextLabel,
        ),
      ],
    );
  }
}
