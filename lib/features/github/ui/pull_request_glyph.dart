import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// A pull request's state as the leading mark of its row: the state's own
/// glyph in its ink, on a faint wash of that ink.
///
/// Every surface that lists pull requests leads with it — the picker, the
/// task's card — so a state reads the same everywhere, by shape as well as
/// by colour: merged green, closed red, open and draft neutral.
/// [status] is null before the first read, which draws as open.
class PullRequestGlyph extends StatelessWidget {
  const PullRequestGlyph({required this.status, this.draft = false, super.key});

  final PullRequestStatus? status;
  final bool draft;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final (icon, ink) = switch (status) {
      PullRequestStatus.merged => (
        LottiIcons.pullRequestMerged,
        tokens.colors.alert.success.ink,
      ),
      PullRequestStatus.closed => (
        LottiIcons.pullRequestClosed,
        tokens.colors.alert.error.ink,
      ),
      PullRequestStatus.open || null when draft => (
        LottiIcons.pullRequestDraft,
        tokens.colors.text.lowEmphasis,
      ),
      // Neutral: still in flight, nothing decided. Teal on these surfaces
      // is the agent's voice and the actions; a teal open state made it
      // mean three things on one card.
      PullRequestStatus.open || null => (
        LottiIcons.pullRequest,
        tokens.colors.text.mediumEmphasis,
      ),
    };
    return Container(
      width: tokens.spacing.step7,
      height: tokens.spacing.step7,
      decoration: BoxDecoration(
        color: ink.withValues(alpha: SurfaceAlphas.tint),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: IconSizes.m, color: ink),
    );
  }
}

/// The title of a pull request in a list — the picker's and the task's
/// card alike: the one semibold line of its row, above the caption lines.
TextStyle pullRequestTitleStyle(BuildContext context) {
  final tokens = context.designTokens;
  return tokens.typography.styles.subtitle.subtitle2.copyWith(
    color: tokens.colors.text.highEmphasis,
  );
}

/// A pull request's number and title as one line of type: the number in
/// the quiet ink of metadata, so the eye lands on the title.
class PullRequestTitle extends StatelessWidget {
  const PullRequestTitle({
    required this.number,
    required this.title,
    required this.style,
    this.maxLines = 2,
    super.key,
  });

  /// Null for a pull request read before its title is known: [title] then
  /// is its whole reference.
  final int? number;
  final String title;
  final TextStyle style;

  /// Null lets a heading wrap as far as it needs.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Text.rich(
      TextSpan(
        children: [
          if (number != null)
            TextSpan(
              text: '#$number ',
              style: style.copyWith(color: tokens.colors.text.lowEmphasis),
            ),
          TextSpan(text: title),
        ],
      ),
      style: style,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}
