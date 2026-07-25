import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Quiet model/provider identity lines for the task-agent card footer.
///
/// Renders the current inference setup as a single tappable caption row
/// (icon · "model · via provider" · chevron) that opens the model sheet, plus
/// an optional second line attributing the visible report when it was produced
/// by a different route. Error presentations (no setup selected, broken setup)
/// reuse the same row in the alert color. The "Current setup" wording lives in
/// the semantics label — visually the placement and glyph carry that meaning.
///
/// Both rows shrink-wrap: they never claim more width than their content, so
/// the tappable row's ink, tooltip and tap target stop at its chevron instead
/// of running the width of the footer. Both also truncate rather than wrap —
/// a route string that outgrows the row ellipsizes and stays reachable through
/// the tooltip and the semantics label.
class TaskAgentIdentityRegion extends StatelessWidget {
  const TaskAgentIdentityRegion({
    required this.data,
    required this.onSetupTap,
    super.key,
  });

  final TaskAgentModelIdentityViewData data;
  final VoidCallback onSetupTap;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final currentTiers = data.currentRoute == null
        ? null
        : inferenceRouteIdentityTiers(
            data.currentRoute!,
            viaLabel: messages.taskAgentRouteVia,
          );
    final currentIdentity = currentTiers?.first;
    final combined =
        data.presentation == TaskAgentIdentityPresentation.combined;
    final semanticsLabel = switch (data.presentation) {
      TaskAgentIdentityPresentation.broken =>
        '${messages.taskAgentCurrentSetupHeader}. '
            '${messages.taskAgentSetupBroken}',
      _ when currentIdentity == null =>
        '${messages.taskAgentNoProfileSelected}. '
            '${messages.taskAgentNoProfileSelectedDescription}',
      _ when combined => messages.taskAgentSetupAndReportSemantics(
        currentIdentity,
      ),
      _ => messages.taskAgentSetupSemantics(currentIdentity),
    };

    final rows = <Widget>[
      if (data.presentation == TaskAgentIdentityPresentation.disabled)
        _SetupIdentityRow(
          tiers: [messages.taskAgentNoProfileSelectedDescription],
          tooltip: messages.taskAgentChangeSetupTooltip,
          onTap: onSetupTap,
          semanticsLabel: semanticsLabel,
          isError: true,
        )
      else if (data.presentation == TaskAgentIdentityPresentation.broken)
        _SetupIdentityRow(
          tiers: [messages.taskAgentSetupBroken],
          tooltip: messages.taskAgentChangeSetupTooltip,
          onTap: onSetupTap,
          semanticsLabel: semanticsLabel,
          isError: true,
        )
      else if (currentTiers != null)
        _SetupIdentityRow(
          tiers: currentTiers,
          tooltip: messages.taskAgentChangeSetupTooltip,
          onTap: onSetupTap,
          semanticsLabel: semanticsLabel,
        ),
      if (data.presentation == TaskAgentIdentityPresentation.split ||
          ((data.presentation == TaskAgentIdentityPresentation.broken ||
                  data.presentation ==
                      TaskAgentIdentityPresentation.disabled) &&
              (data.reportRoute != null || data.reportAttributionUnavailable)))
        _ReportIdentityRow(
          label: messages.taskAgentThisReportHeader,
          tiers: (data.reportAttributionUnavailable || data.reportRoute == null)
              ? [messages.taskAgentAttributionUnavailable]
              : inferenceRouteIdentityTiers(
                  data.reportRoute!,
                  viaLabel: messages.taskAgentRouteVia,
                ),
        ),
    ];

    // `start`, never `stretch`: a stretching Column hands its children a tight
    // width, which silently defeats the `MainAxisSize.min` each row relies on
    // and inflates their ink/tooltip targets to the full reading measure.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
}

class _SetupIdentityRow extends StatelessWidget {
  const _SetupIdentityRow({
    required this.tiers,
    required this.onTap,
    required this.semanticsLabel,
    required this.tooltip,
    this.isError = false,
  });

  /// Wordings longest-first; the widest one that fits is shown.
  final List<String> tiers;
  final String tooltip;
  final VoidCallback onTap;
  final String semanticsLabel;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final color = isError ? tokens.colors.alert.error.ink : ai.metaText;
    final iconColor = isError
        ? tokens.colors.alert.error.defaultColor
        : ai.metaText;
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Tooltip(
        // Names the action rather than repeating a route that is usually
        // fully visible; the full route lives in the semantics label.
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(tokens.radii.s),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: tokens.spacing.step8),
              // The inset lives INSIDE the ink so the highlight has room
              // around the glyph and the chevron; painted flush, the rounded
              // ink corners cut into the glyph itself.
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step2,
                ),
                // Shrink-wrapped so the ink, the tooltip and the tap target
                // all stop at the chevron instead of running the full width
                // of the footer.
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isError
                          ? Icons.error_outline_rounded
                          : Icons.psychology_outlined,
                      size: tokens.spacing.step5,
                      color: iconColor,
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    Flexible(
                      child: _TieredIdentityText(
                        tiers: tiers,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: color,
                        ),
                      ),
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: tokens.spacing.step5,
                      color: iconColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportIdentityRow extends StatelessWidget {
  const _ReportIdentityRow({required this.label, required this.tiers});

  final String label;

  /// Wordings longest-first; the widest one that fits is shown.
  final List<String> tiers;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final caption = tokens.typography.styles.others.caption;
    // Matches the tappable row's inset so both glyphs share a leading edge.
    // Top-only vertical space: a symmetric inset made the card's bottom
    // margin depend on whether the attribution happened to be present.
    return Padding(
      padding: EdgeInsets.only(
        left: tokens.spacing.step2,
        right: tokens.spacing.step2,
        top: tokens.spacing.step2,
      ),
      // The full attribution lives in the tooltip; on screen it truncates
      // rather than wrapping, so a long route cannot spill a stray fragment
      // onto a second line under the row it belongs to.
      child: Tooltip(
        message: '$label ${tiers.first}',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: tokens.spacing.step5,
              color: ai.metaText,
            ),
            SizedBox(width: tokens.spacing.step2),
            // Not flexible: the label is short fixed vocabulary, and
            // "This rep…" tells the reader strictly less than nothing. It
            // costs a bounded ~60px, so only the route below can be squeezed.
            Text(
              label,
              maxLines: 1,
              style: caption.copyWith(color: ai.metaText),
            ),
            SizedBox(width: tokens.spacing.step2),
            // The route sheds whole segments rather than characters; the
            // label above it never gives ground.
            Flexible(
              child: _TieredIdentityText(
                tiers: tiers,
                style: caption.copyWith(color: ai.faintMeta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders the widest wording from [tiers] that fits the space it is given.
///
/// The strings are structured (model · publisher · via provider), so dropping
/// a whole segment keeps every remaining fact legible, where an ellipsis would
/// chop the serving provider mid-word and leave the connective "via" behind.
class _TieredIdentityText extends StatelessWidget {
  const _TieredIdentityText({required this.tiers, required this.style});

  final List<String> tiers;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        var chosen = tiers.last;
        for (final tier in tiers) {
          final painter = TextPainter(
            text: TextSpan(text: tier, style: style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          if (painter.width <= constraints.maxWidth) {
            chosen = tier;
            break;
          }
        }
        return Text(
          chosen,
          maxLines: 1,
          // The last tier is the bare model name; if even that will not fit,
          // an ellipsis is the honest end of the ladder.
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }
}
