import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The summary line a report card shows collapsed: the report's own TLDR,
/// or its full text when the run produced no separate one.
///
/// Shared with [resolveReportAdditional] by every agent report card so the
/// task section, the goal read and the relationship briefing cannot drift
/// into answering "what goes behind Read more" differently.
String resolveReportTldr(AgentReportEntity? report) {
  if (report == null) return '';
  final explicit = report.tldr?.trim();
  if (explicit != null && explicit.isNotEmpty) return explicit;
  return report.content.trim();
}

/// What sits behind Read more, or null when there is nothing further to
/// read: no content, no separate TLDR, or a full text that merely repeats
/// the TLDR — all three would make the disclosure reveal the same paragraph
/// the reader has already read.
String? resolveReportAdditional(AgentReportEntity? report) {
  if (report == null) return null;
  final content = report.content.trim();
  if (content.isEmpty) return null;
  final explicit = report.tldr?.trim();
  if (explicit == null || explicit.isEmpty) return null;
  if (content == explicit) return null;
  return content;
}

/// Calm identity header for an agent report card — the task agent's section
/// on Task Details, the goal agent's read, and the relationship briefing all
/// wear it, so the sparkle badge, the title tier and the tap-to-internals
/// target are defined once.
///
/// Report freshness and wake controls live in the stale strip and the card
/// footer; the header keeps only the report identity and optional playback
/// control. The whole badge + title + agent-name block is one tap target that
/// opens the agent internals, so the name no longer needs its own oversized
/// touch area.
class TldrHeader extends StatelessWidget {
  const TldrHeader({
    required this.agentName,
    this.onAgentTap,
    this.title,
    this.trailing,
    super.key,
  });

  final String? agentName;
  final VoidCallback? onAgentTap;

  /// The card's own name, when it is not the task/goal agent's
  /// `aiCardTitle`. The relationship briefing is the same panel wearing a
  /// different noun ("Briefing"), so it passes its own title rather than
  /// growing a second header widget beside this one.
  final String? title;

  /// The header's trailing rail: whatever meta the host card wants beside
  /// its identity — a TTS playback control on a task, cost and freshness on
  /// a goal. Bounded to half the header, so pass something that can shrink.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final cardTitle = title ?? messages.aiCardTitle;
    final displayName = agentName?.trim();
    final hasName = displayName != null && displayName.isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.cardPadding,
        tokens.spacing.step4,
        tokens.spacing.cardPadding,
        tokens.spacing.step4,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            // `Expanded` keeps the slot so the playback control stays pinned to
            // the card's trailing edge, while `Align` hands the button loose
            // constraints — without it the ink target stretches across the whole
            // header instead of hugging the badge and the title.
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Semantics(
                  button: onAgentTap != null,
                  label: hasName ? '$cardTitle. $displayName' : cardTitle,
                  excludeSemantics: true,
                  // No hover fill: a rectangle washing over the badge + title
                  // block made the card's identity read as a phantom button.
                  // Hover/focus/press answers on the block's own ink — the
                  // badge border firms to the accent and the agent name
                  // brightens a step.
                  child: DsQuietInk(
                    onTap: onAgentTap,
                    borderRadius: BorderRadius.circular(tokens.radii.m),
                    builder: (context, highlighted) => ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: kMinInteractiveDimension,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: tokens.spacing.step8,
                            height: tokens.spacing.step8,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: ai.accentSoft,
                              borderRadius: BorderRadius.circular(
                                tokens.radii.m,
                              ),
                              border: Border.all(
                                color: highlighted ? ai.accent : ai.border,
                              ),
                            ),
                            child: Icon(
                              LottiIcons.aiSpark,
                              size: tokens.spacing.step6,
                              color: ai.accent,
                            ),
                          ),
                          SizedBox(width: tokens.spacing.step3),
                          // `Flexible` + single-line text is what makes the
                          // shrink-wrap real: text allowed to wrap would
                          // report the full available width straight back and
                          // re-inflate the row.
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _HeaderTitle(
                                  text: cardTitle,
                                  style: tokens
                                      .typography
                                      .styles
                                      .subtitle
                                      .subtitle1
                                      .copyWith(color: ai.titleText),
                                ),
                                if (hasName)
                                  Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tokens
                                        .typography
                                        .styles
                                        .others
                                        .caption
                                        .copyWith(
                                          color: highlighted
                                              ? ai.bodyText
                                              : ai.metaText,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (trailing case final control?) ...[
              SizedBox(width: tokens.spacing.step3),
              // Non-flex, so the identity block absorbs the slack and the
              // control stays flush to the trailing edge — but BOUNDED, because
              // a slot that carries text rather than a fixed-size button (a
              // freshness caption, an impact pill) grows with the locale and
              // the text scale, and an unbounded trailing child of a Row
              // overflows instead of shrinking.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
                child: control,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The card's own name — two lines where they help, one where they would not.
///
/// German compounds this title into a single unbreakable token
/// ("KI-Zusammenfassung"), and at 320 logical px with 1.3x text scale that
/// token is wider than the line the header can give it. Flutter's line breaker
/// then falls back to breaking *inside* the word — "KI-Zusammenf / assung" —
/// which reads as a typo rather than as shortening, because nothing marks it
/// as incomplete.
///
/// So the choice is measured rather than declared: if the widest run with no
/// break opportunity in it still fits, two lines are safe and every break will
/// land between words. If it cannot fit, no amount of lines will help, and one
/// line with an ellipsis is the honest form — it at least tells the reader
/// that something was left out.
class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        var widest = 0.0;
        // Flutter may break after whitespace or after a hyphen; whatever sits
        // between two such points has to fit on one line or be split mid-word.
        for (final run in text.split(RegExp(r'[\s\u00AD\u2010-\u2015-]+'))) {
          if (run.isEmpty) continue;
          final painter = TextPainter(
            text: TextSpan(text: run, style: style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          widest = widest > painter.width ? widest : painter.width;
        }
        return Text(
          text,
          maxLines: widest <= constraints.maxWidth ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }
}

/// Report body with its disclosure control placed after the content it owns.
///
/// Shared by every agent report surface that shows a summary with more
/// behind it — the task agent's card and the relationship briefing — so the
/// Markdown rendering, the reading-measure cap and the Read more / agent
/// internals pair stay one implementation rather than three lookalikes.
class TldrBody extends StatelessWidget {
  const TldrBody({
    required this.tldr,
    required this.expanded,
    required this.additionalReport,
    required this.onToggle,
    required this.disclosureKey,
    this.onOpenInternals,
    super.key,
  });

  final String tldr;
  final bool expanded;
  final String? additionalReport;
  final VoidCallback onToggle;
  final VoidCallback? onOpenInternals;

  /// Key on the Read more / Show less control. Required rather than
  /// defaulted: a default would hand a fourth surface the task card's key
  /// and make its failures name the wrong screen.
  final Key disclosureKey;

  /// Reading-measure cap for the report prose. The card itself stays
  /// full-width, but body lines must not — unbounded desktop widths produce
  /// 150+ character lines. A fixed layout constraint in the tradition of
  /// `SettingsPageLayout.maxContentWidth` / the Daily OS drafting modal;
  /// ~75 characters at the bodySmall size. Public so the freshness strip
  /// below the summary can share the same measure instead of stretching the
  /// full card width.
  ///
  /// Widened alongside kDetailContentMaxWidth (760 -> 960): at 720, the
  /// footer's wake status/countdown chip and the "Automatische
  /// Aktualisierungen" label + switch didn't have room to share one line in
  /// German, wrapping into an unbalanced two-row layout.
  static const double maxReadingWidth = 900;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    // Match entry-editor prose and compact card summaries; the header and
    // card treatment provide the hierarchy without enlarging report text.
    final bodyStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: ai.bodyText,
    );
    final hasMore = additionalReport?.trim().isNotEmpty ?? false;
    final hasDisclosure = hasMore || expanded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tldr.trim().isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxReadingWidth),
            child: SelectionArea(
              child: AgentMarkdownView(tldr, style: bodyStyle),
            ),
          ),
        if (expanded && hasMore) ...[
          SizedBox(height: tokens.spacing.sectionGap),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxReadingWidth),
            child: SelectionArea(
              child: AgentMarkdownView(additionalReport!, style: bodyStyle),
            ),
          ),
        ],
        // No spacer above the disclosure row: its 40-high tap target already
        // carries ~12 px of optical padding on each side, so an explicit gap
        // stacked a second one on top and left a dead band under the prose.
        // The target instead reaches up into the last line's descender area.
        if (hasDisclosure)
          Wrap(
            spacing: tokens.spacing.step4,
            runSpacing: tokens.spacing.step2,
            children: [
              if (hasMore)
                _QuietDisclosureLink(
                  key: disclosureKey,
                  label: expanded
                      ? messages.aiCardShowLess
                      : messages.aiCardReadMore,
                  icon: expanded ? LottiIcons.collapse : LottiIcons.expand,
                  expanded: expanded,
                  onPressed: onToggle,
                ),
              if (expanded && onOpenInternals != null)
                _QuietDisclosureLink(
                  label: messages.aiCardOpenAgentInternals,
                  icon: LottiIcons.tune,
                  onPressed: onOpenInternals!,
                ),
            ],
          ),
        // Without a disclosure row there is no tap target to supply the
        // trailing optical gap, so the body pays for it itself. The card gives
        // this block no bottom padding of its own.
        if (!hasDisclosure) SizedBox(height: tokens.spacing.step3),
      ],
    );
  }
}

/// Quiet text-link disclosure matching the proposals section's History
/// toggle: caption meta-gray with a leading glyph. Disclosures don't spend
/// the accent — the summary they reveal is the hero, not the link.
class _QuietDisclosureLink extends StatelessWidget {
  const _QuietDisclosureLink({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.expanded,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return MergeSemantics(
      child: Semantics(
        button: true,
        expanded: expanded,
        // A text link changes its own ink on hover/focus/press — no fill
        // behind it, which read as a phantom button around the quiet words.
        child: DsQuietInk(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          builder: (context, highlighted) {
            final ink = highlighted ? ai.bodyText : ai.metaText;
            return ConstrainedBox(
              constraints: BoxConstraints(minHeight: tokens.spacing.step8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: tokens.spacing.step5, color: ink),
                  SizedBox(width: tokens.spacing.step2),
                  Text(
                    label,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: ink,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
