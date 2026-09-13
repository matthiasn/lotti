import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/design_system/components/captions/ds_tiered_text.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

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
    this.trailingMeta,
    super.key,
  });

  final TaskAgentModelIdentityViewData data;
  final VoidCallback onSetupTap;

  /// A fact that rides the setup row after the route — the relationship
  /// briefing's token count — so `model · via provider · 18.4K tokens` is
  /// one line rather than two. Appended to every wording tier, and dropped
  /// from none, because it is the reader's cost rather than decoration.
  final String? trailingMeta;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final routeTiers = data.currentRoute == null
        ? null
        : inferenceRouteIdentityTiers(
            data.currentRoute!,
            viaLabel: messages.taskAgentRouteVia,
          );
    final meta = trailingMeta;
    final currentTiers = routeTiers == null || meta == null
        ? routeTiers
        : [for (final tier in routeTiers) '$tier · $meta'];
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
    // A quiet link, not a button: no hover fill (a rectangle washing over
    // the caption made the setup row read as a phantom button in the
    // footer). The link's own ink lifts a step on hover/focus/press —
    // meta → body on the neutral row, error.ink → error.hover on the error
    // rows — matching the card's other text links.
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Tooltip(
        // Names the action rather than repeating a route that is usually
        // fully visible; the full route lives in the semantics label.
        message: tooltip,
        excludeFromSemantics: true,
        child: DsQuietInk(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          builder: (context, highlighted) {
            final color = isError
                ? (highlighted
                      ? tokens.colors.alert.error.hover
                      : tokens.colors.alert.error.ink)
                : (highlighted ? ai.bodyText : ai.metaText);
            final glyphColor = isError
                ? tokens.colors.alert.error.defaultColor
                : color;
            // The visible label may be truncated or a tiered wording, so the
            // children stay silent and [semanticsLabel] speaks for the whole
            // control. Excluding *below* the ink keeps the tap and focus
            // actions a button must publish.
            return ExcludeSemantics(
              child: ConstrainedBox(
                // step6, not the step8 the inline-action tier pays: the
                // footer is a quiet settings zone and the taller box made it
                // claim more of the card than the summary it annotates.
                constraints: BoxConstraints(minHeight: tokens.spacing.step6),
                child: Padding(
                  // The inset lives inside the ink, so the rounded focus
                  // corners cannot clip the leading glyph — and every footer
                  // glyph keeps the shared leading edge.
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.step2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isError ? LottiIcons.error : LottiIcons.reasoning,
                        size: IconSizes.s,
                        color: glyphColor,
                      ),
                      SizedBox(width: tokens.spacing.step2),
                      Flexible(
                        child: DsTieredText(
                          tiers: tiers,
                          style: tokens.typography.styles.others.caption
                              .copyWith(color: color),
                        ),
                      ),
                      SizedBox(width: tokens.spacing.step2),
                      Icon(
                        LottiIcons.chevronRight,
                        size: IconSizes.s,
                        color: glyphColor,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
    // The same row box as the tappable row above: identical horizontal inset,
    // so both glyphs share a leading edge, and the identical `step6` minimum
    // height, so the air below the last line is the same whether or not this
    // row is present.
    //
    // Padding alone could not do that. An earlier revision paid top-only
    // vertical space to keep the *declared* geometry constant, but the
    // tappable row's ink box centres a ~`step5` glyph and so contributes
    // optical air below its text that a bare `Row` does not — making the
    // card's bottom margin visibly depend on whether the attribution
    // happened to exist. Spacing row boxes rather than text is what
    // actually holds.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step2),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: tokens.spacing.step6),
        // The full attribution lives in the tooltip; on screen the route
        // sheds segments rather than wrapping, so a long route cannot spill
        // a stray fragment onto a second line under the row it belongs to —
        // except at large text, where the route takes the line under its
        // label whole rather than shed the one fact the row exists for.
        //
        // One announcement, carrying the *untruncated* route. The visible text
        // sheds whole segments as space runs out, so leaving the children
        // audible would read the shortened route and then the tooltip would
        // read the full one — the same doubling `DesignSystemInlineAction`
        // avoids one row above, and with a different string each time.
        child: Semantics(
          label: '$label ${tiers.first}',
          child: Tooltip(
            message: '$label ${tiers.first}',
            excludeFromSemantics: true,
            child: ExcludeSemantics(
              child: _AttributionRow(
                icon: Icon(
                  LottiIcons.description,
                  size: IconSizes.s,
                  color: ai.metaText,
                ),
                // Not flexible: the label is short fixed vocabulary, and
                // "This rep…" tells the reader strictly less than nothing.
                // It costs a bounded ~60px, so only the route can be
                // squeezed.
                label: Text(
                  label,
                  maxLines: 1,
                  style: caption.copyWith(color: ai.metaText),
                ),
                separator: Text(
                  ' · ',
                  style: caption.copyWith(color: ai.metaText),
                ),
                // The route sheds whole segments rather than characters; the
                // label above it never gives ground.
                route: DsTieredText(
                  tiers: tiers,
                  style: caption.copyWith(color: ai.metaText),
                ),
                // On its own line the route has the whole column: it wraps
                // rather than sheds, so large text loses no attribution.
                stackedRoute: Text(
                  tiers.first,
                  style: caption.copyWith(color: ai.metaText),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The attribution row's cells: the glyph, then the fixed label and the
/// tiered route side by side — or, above the large-text bar where even the
/// bare route rarely fits beside the label, the route on its own line
/// beneath the label, still on the text column the glyph opens.
class _AttributionRow extends StatelessWidget {
  const _AttributionRow({
    required this.icon,
    required this.label,
    required this.separator,
    required this.route,
    required this.stackedRoute,
  });

  final Widget icon;
  final Widget label;
  final Widget separator;
  final Widget route;

  /// The route as rendered under the label at large text.
  final Widget stackedRoute;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final largeText =
        MediaQuery.textScalerOf(context).scale(1) > TextScales.large;
    // Centred on the one-line row so the row's ink height stays the
    // caption's; only the stacked form top-aligns the glyph to its label.
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: largeText
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (largeText)
          Padding(
            padding: EdgeInsets.only(top: tokens.spacing.step1),
            child: icon,
          )
        else
          icon,
        SizedBox(width: tokens.spacing.step2),
        Flexible(
          child: largeText
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [label, stackedRoute],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    label,
                    separator,
                    Flexible(child: route),
                  ],
                ),
        ),
      ],
    );
  }
}
