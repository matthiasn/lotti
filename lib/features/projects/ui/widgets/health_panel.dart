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
                    DesignSystemCircularProgress(
                      value: record.healthScore / 100,
                      size: DesignSystemCircularProgressSize.large,
                      progressColor: ShowcasePalette.amber(context),
                      trackColor: ShowcasePalette.border(context),
                      semanticsLabel:
                          context.messages.projectShowcaseHealthScoreTitle,
                      center: Text('${record.healthScore}'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _HealthSummary(
                        record: record,
                        tokens: tokens,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: DesignSystemButton(
                    label: context.messages.projectShowcaseViewBlocker,
                    variant: DesignSystemButtonVariant.secondary,
                    onPressed: onViewBlockerPressed,
                  ),
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DesignSystemCircularProgress(
                      value: record.healthScore / 100,
                      size: DesignSystemCircularProgressSize.large,
                      progressColor: ShowcasePalette.amber(context),
                      trackColor: ShowcasePalette.border(context),
                      semanticsLabel:
                          context.messages.projectShowcaseHealthScoreTitle,
                      center: Text('${record.healthScore}'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _HealthSummary(
                        record: record,
                        tokens: tokens,
                      ),
                    ),
                    const SizedBox(width: 12),
                    DesignSystemButton(
                      label: context.messages.projectShowcaseViewBlocker,
                      variant: DesignSystemButtonVariant.secondary,
                      onPressed: onViewBlockerPressed,
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              Divider(
                height: 1,
                thickness: 1,
                color: ShowcasePalette.border(context),
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
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
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: ShowcasePalette.infoBlue(context),
              ),
            ),
            const SizedBox(width: 4),
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
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: ShowcasePalette.error(context),
            ),
            const SizedBox(width: 4),
            Text(
              context.messages.projectShowcaseBlockedTaskCount(
                record.blockedTaskCount,
              ),
              style: tokens.typography.styles.others.caption.copyWith(
                color: ShowcasePalette.mediumText(context),
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
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: tokens.typography.styles.others.caption.copyWith(
            fontSize: 11,
            color: ShowcasePalette.mediumText(context),
          ),
        ),
      ],
    );
  }
}
