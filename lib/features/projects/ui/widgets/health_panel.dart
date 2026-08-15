import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/widgets/shared_tag_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Agent-authored project health, paired with factual task rollups.
///
/// The panel never invents a score. It leads with the report's categorical
/// band, rationale, and optional confidence, then shows completion and blocker
/// counts from the linked tasks. Callers render [ProjectHealthEmptyState]
/// instead when the agent has not produced parseable health metrics yet.
class HealthPanel extends StatelessWidget {
  const HealthPanel({
    required this.record,
    this.onViewBlockerPressed,
    super.key,
  });

  final ProjectRecord record;
  final VoidCallback? onViewBlockerPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final metrics = record.healthMetrics;
    assert(
      metrics != null,
      'HealthPanel requires agent-authored health metrics.',
    );
    if (metrics == null) {
      return const SizedBox.shrink();
    }

    final progressValue = record.totalTaskCount == 0
        ? 0.0
        : record.completedTaskCount / record.totalTaskCount;
    final confidence = metrics.confidence;
    final showBlockerAction =
        record.blockedTaskCount > 0 && onViewBlockerPressed != null;

    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    context.messages.projectHealthSectionTitle,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: ShowcasePalette.highText(context),
                    ),
                  ),
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              ProjectHealthBandTag(band: metrics.band),
            ],
          ),
          SizedBox(height: tokens.spacing.step4),
          Text(
            metrics.rationale,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: ShowcasePalette.highText(context),
            ),
          ),
          if (confidence != null) ...[
            SizedBox(height: tokens.spacing.step2),
            Text(
              context.messages.projectHealthConfidence(
                (confidence * 100).round(),
              ),
              style: tokens.typography.styles.others.caption.copyWith(
                color: ShowcasePalette.mediumText(context),
              ),
            ),
          ],
          if (record.blockedTaskCount > 0) ...[
            SizedBox(height: tokens.spacing.step4),
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: IconSizes.m,
                  color: tokens.colors.alert.error.defaultColor,
                ),
                SizedBox(width: tokens.spacing.step2),
                Expanded(
                  child: Text(
                    context.messages.projectShowcaseBlockedTaskCount(
                      record.blockedTaskCount,
                    ),
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: ShowcasePalette.mediumText(context),
                    ),
                  ),
                ),
                if (showBlockerAction) ...[
                  SizedBox(width: tokens.spacing.step3),
                  DesignSystemButton(
                    label: context.messages.projectShowcaseViewBlocker,
                    variant: DesignSystemButtonVariant.secondary,
                    size: DesignSystemButtonSize.dense,
                    tapTargetSize: MaterialTapTargetSize.padded,
                    onPressed: onViewBlockerPressed,
                  ),
                ],
              ],
            ),
          ],
          SizedBox(height: tokens.spacing.step5),
          const DesignSystemDivider(),
          SizedBox(height: tokens.spacing.step5),
          DesignSystemProgressBar(
            value: progressValue,
            label: context.messages.navTabTitleTasks,
            progressText: record.totalTaskCount == 0
                ? context.messages.projectTaskProgressNone
                : context.messages.projectShowcaseTasksCompleted(
                    record.completedTaskCount,
                    record.totalTaskCount,
                  ),
            labelColor: ShowcasePalette.highText(context),
            progressColor: ShowcasePalette.highText(context),
            fillColor: tokens.colors.interactive.enabled,
            trackColor: ShowcasePalette.border(context),
          ),
          SizedBox(height: tokens.spacing.step4),
          Wrap(
            spacing: tokens.spacing.step4,
            runSpacing: tokens.spacing.step3,
            children: [
              _LegendItem(
                color: tokens.colors.interactive.enabled,
                label: context.messages.projectShowcaseCompletedLegend(
                  record.completedTaskCount,
                ),
              ),
              if (record.blockedTaskCount > 0)
                _LegendItem(
                  color: tokens.colors.alert.error.defaultColor,
                  label: context.messages.projectShowcaseBlockedLegend(
                    record.blockedTaskCount,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Neutral placeholder shown until a project agent produces a health payload.
class ProjectHealthEmptyState extends StatelessWidget {
  const ProjectHealthEmptyState({
    this.onRunReport,
    this.isRunningReport = false,
    super.key,
  });

  final VoidCallback? onRunReport;
  final bool isRunningReport;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DesignSystemSectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.monitor_heart_outlined,
            size: IconSizes.l,
            color: tokens.colors.text.mediumEmphasis,
          ),
          SizedBox(width: tokens.spacing.step4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    context.messages.projectHealthEmptyTitle,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
                SizedBox(height: tokens.spacing.step2),
                Text(
                  context.messages.projectHealthEmptyBody,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
                if (onRunReport != null) ...[
                  SizedBox(height: tokens.spacing.step4),
                  DesignSystemButton(
                    label: context.messages.projectHealthRunNow,
                    leadingIcon: Icons.auto_awesome_rounded,
                    variant: DesignSystemButtonVariant.secondary,
                    size: DesignSystemButtonSize.dense,
                    tapTargetSize: MaterialTapTargetSize.padded,
                    onPressed: onRunReport,
                    isLoading: isRunningReport,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: IconSizes.xs,
          height: IconSizes.xs,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: tokens.spacing.step2),
        Text(
          label,
          style: tokens.typography.styles.others.caption.copyWith(
            color: ShowcasePalette.mediumText(context),
          ),
        ),
      ],
    );
  }
}
