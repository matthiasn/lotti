import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_circular_progress.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/widgets/project_health_indicator.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;

/// The health-score panel shown at the top of the detail pane.
class HealthPanel extends StatelessWidget {
  const HealthPanel({
    required this.record,
    required this.categoryColor,
    this.onViewBlockerPressed,
    super.key,
  });

  final ProjectRecord record;

  /// The owning category's colour, used to tint the card surface so the detail
  /// pane keeps the project's identity (matching the overview's card wash).
  final Color categoryColor;
  final VoidCallback? onViewBlockerPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final progressValue = record.totalTaskCount == 0
        ? 0.0
        : record.completedTaskCount / record.totalTaskCount;
    final band = record.healthMetrics?.band;
    // Drive the ring (and the verdict word) from the health band so the gauge's
    // most glanceable channel actually encodes health, consistent with the
    // overview's red/amber/green system. Falls back to amber when no band.
    final bandColor = band == null
        ? ShowcasePalette.amber(context)
        : projectHealthBandAttributes(context, band).$2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;

        // A soft band-coloured glow behind the ring gives the page's central
        // signal real visual mass and makes a healthy (green) state FEEL
        // different from a struggling (red) one — restrained, band-driven.
        final healthRing = DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: bandColor.withValues(alpha: 0.28),
                blurRadius: tokens.spacing.step4,
              ),
            ],
          ),
          child: DesignSystemCircularProgress(
            value: record.healthScore / 100,
            size: DesignSystemCircularProgressSize.large,
            progressColor: bandColor,
            // Neutral track: the ring is the HEALTH element, so its unfilled
            // remainder stays neutral — an arbitrary category hue here would
            // counterfeit a health state. Identity lives on the card edge/title.
            trackColor: ShowcasePalette.border(context),
            semanticsLabel: context.messages.projectShowcaseHealthScoreTitle,
            center: Text(
              '${record.healthScore}',
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: ShowcasePalette.highText(context),
                fontFeatures: numericBadgeFontFeatures,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        );

        final summary = _HealthSummary(
          record: record,
          tokens: tokens,
          band: band,
          bandColor: bandColor,
        );

        final blockerButton = DesignSystemButton(
          label: context.messages.projectShowcaseViewBlocker,
          variant: DesignSystemButtonVariant.secondary,
          onPressed: onViewBlockerPressed,
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            // The health card is the project's coloured HERO: a category LEFT
            // EDGE (a fill wash is imperceptible on dark) makes the page read as
            // "this project's place"; the task list stays neutral.
            color: ShowcasePalette.categoryCardSurfaceFaint(
              context,
              categoryColor,
            ),
            borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
            border: Border.all(color: ShowcasePalette.border(context)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.all(tokens.spacing.step5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isCompact) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            healthRing,
                            SizedBox(width: tokens.spacing.step5),
                            Expanded(child: summary),
                          ],
                        ),
                        SizedBox(height: tokens.spacing.step4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: blockerButton,
                        ),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            healthRing,
                            SizedBox(width: tokens.spacing.step5),
                            Expanded(child: summary),
                            SizedBox(width: tokens.spacing.step4),
                            blockerButton,
                          ],
                        ),
                      SizedBox(height: tokens.spacing.step4),
                      DesignSystemProgressBar(
                        value: progressValue,
                        label: context.messages.navTabTitleTasks,
                        progressText: context.messages
                            .projectShowcaseTasksCompleted(
                              record.completedTaskCount,
                              record.totalTaskCount,
                            ),
                        labelColor: ShowcasePalette.highText(context),
                        progressColor: ShowcasePalette.highText(context),
                        // The tasks bar fills in the CATEGORY colour, not teal —
                        // teal is reserved for the AI/agent channel, and this puts the
                        // project's identity on a real momentum element.
                        fillColor: categoryColor,
                        trackColor: ShowcasePalette.border(context),
                      ),
                    ],
                  ),
                ),
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  child: SizedBox(
                    width: tokens.spacing.step1 + tokens.spacing.step1,
                    child: ColoredBox(color: categoryColor),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HealthSummary extends StatelessWidget {
  const _HealthSummary({
    required this.record,
    required this.tokens,
    required this.band,
    required this.bandColor,
  });

  final ProjectRecord record;
  final DsTokens tokens;
  final ProjectHealthBand? band;
  final Color bandColor;

  @override
  Widget build(BuildContext context) {
    final band = this.band;
    final attributes = band == null
        ? null
        : projectHealthBandAttributes(context, band);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Verdict-first: the reassurance ("On Track") is the card's heading, so
        // a user reads "am I OK?" before the bare metric. The "Health Score"
        // label is demoted to a quiet caption that frames the ring's number.
        if (attributes != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                attributes.$3,
                size: tokens.typography.lineHeight.heading3,
                color: attributes.$2,
              ),
              SizedBox(width: tokens.spacing.step2),
              Text(
                attributes.$1,
                style: tokens.typography.styles.heading.heading3.copyWith(
                  color: attributes.$2,
                ),
              ),
            ],
          )
        else
          Text(
            context.messages.projectShowcaseHealthScoreTitle,
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: ShowcasePalette.highText(context),
            ),
          ),
        if (record.blockedTaskCount > 0) ...[
          SizedBox(height: tokens.spacing.step2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: tokens.spacing.step1),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: tokens.typography.lineHeight.bodySmall,
                  color: ShowcasePalette.error(context),
                ),
              ),
              SizedBox(width: tokens.spacing.step1),
              Expanded(
                child: Text(
                  context.messages.projectShowcaseBlockedTaskCount(
                    record.blockedTaskCount,
                  ),
                  // The single most actionable health fact reads in the error
                  // colour, not grey — it must not whisper under a green verdict.
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: ShowcasePalette.error(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
