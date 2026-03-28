import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_circular_progress.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The health-score panel shown at the top of the detail pane.
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
    final progressValue = record.totalTaskCount == 0
        ? 0.0
        : record.completedTaskCount / record.totalTaskCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;

        final healthRing = DesignSystemCircularProgress(
          value: record.healthScore / 100,
          size: DesignSystemCircularProgressSize.large,
          progressColor: ShowcasePalette.amber(context),
          trackColor: ShowcasePalette.border(context),
          semanticsLabel: context.messages.projectShowcaseHealthScoreTitle,
          center: Text('${record.healthScore}'),
        );

        final summary = _HealthSummary(
          record: record,
          tokens: tokens,
        );

        final blockerButton = DesignSystemButton(
          label: context.messages.projectShowcaseViewBlocker,
          variant: DesignSystemButtonVariant.secondary,
          onPressed: onViewBlockerPressed,
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ShowcasePalette.healthSurface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ShowcasePalette.border(context)),
          ),
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
              SizedBox(height: tokens.spacing.step4 + tokens.spacing.step1),
              Divider(
                height: 1,
                thickness: 1,
                color: ShowcasePalette.border(context),
              ),
              SizedBox(height: tokens.spacing.step4 + tokens.spacing.step1),
              DesignSystemProgressBar(
                value: progressValue,
                label: context.messages.navTabTitleTasks,
                progressText: context.messages.projectShowcaseTasksCompleted(
                  record.completedTaskCount,
                  record.totalTaskCount,
                ),
                labelColor: ShowcasePalette.highText(context),
                progressColor: ShowcasePalette.highText(context),
                fillColor: ShowcasePalette.teal(context),
                trackColor: ShowcasePalette.border(context),
              ),
              SizedBox(height: tokens.spacing.step4 + tokens.spacing.step1),
              Wrap(
                spacing: tokens.spacing.step4,
                runSpacing: tokens.spacing.step3,
                children: [
                  _LegendItem(
                    color: ShowcasePalette.teal(context),
                    label: context.messages.projectShowcaseCompletedLegend(
                      record.completedTaskCount,
                    ),
                  ),
                  _LegendItem(
                    color: ShowcasePalette.error(context),
                    label: context.messages.projectShowcaseBlockedLegend(
                      record.blockedTaskCount,
                    ),
                  ),
                ],
              ),
            ],
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
  });

  final ProjectRecord record;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.projectShowcaseHealthScoreTitle,
          style: tokens.typography.styles.subtitle.subtitle2.copyWith(
            color: ShowcasePalette.highText(context),
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: tokens.spacing.step1),
              child: Icon(
                Icons.info_outline_rounded,
                size: tokens.typography.lineHeight.caption,
                color: ShowcasePalette.infoBlue(context),
              ),
            ),
            SizedBox(width: tokens.spacing.step1),
            Expanded(
              child: Text(
                context.messages.projectShowcaseHealthScoreDescription,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: ShowcasePalette.mediumText(context),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.step3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: tokens.spacing.step1),
              child: Icon(
                Icons.warning_amber_rounded,
                size: tokens.typography.lineHeight.caption,
                color: ShowcasePalette.error(context),
              ),
            ),
            SizedBox(width: tokens.spacing.step1),
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
          ],
        ),
      ],
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
          width: tokens.spacing.step2 + tokens.spacing.step1,
          height: tokens.spacing.step2 + tokens.spacing.step1,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: tokens.spacing.step1 + 1),
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
