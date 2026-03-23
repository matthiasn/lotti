import 'package:flutter/material.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/widgets/cards/modern_status_chip.dart';

class ProjectHealthIndicator extends StatelessWidget {
  const ProjectHealthIndicator({
    required this.metrics,
    this.showReason = true,
    super.key,
  });

  final ProjectHealthMetrics metrics;
  final bool showReason;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _healthBandAttributes(context, metrics.band);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModernStatusChip(
          label: label,
          color: color,
          icon: icon,
        ),
        if (showReason && metrics.rationale.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              metrics.rationale,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

(String, Color, IconData) _healthBandAttributes(
  BuildContext context,
  ProjectHealthBand band,
) {
  final messages = context.messages;
  final brightness = Theme.of(context).brightness;
  final isLight = brightness == Brightness.light;
  return switch (band) {
    ProjectHealthBand.surviving => (
      messages.projectHealthBandSurviving,
      isLight ? projectStatusDarkBlue : projectStatusBlue,
      Icons.sentiment_neutral_rounded,
    ),
    ProjectHealthBand.onTrack => (
      messages.projectHealthBandOnTrack,
      isLight ? projectStatusDarkGreen : projectStatusGreen,
      Icons.sentiment_satisfied_alt_rounded,
    ),
    ProjectHealthBand.watch => (
      messages.projectHealthBandWatch,
      Theme.of(context).colorScheme.tertiary,
      Icons.visibility_outlined,
    ),
    ProjectHealthBand.atRisk => (
      messages.projectHealthBandAtRisk,
      isLight ? projectStatusDarkOrange : projectStatusOrange,
      Icons.warning_amber_rounded,
    ),
    ProjectHealthBand.blocked => (
      messages.projectHealthBandBlocked,
      isLight ? taskStatusDarkRed : taskStatusRed,
      Icons.block_outlined,
    ),
  };
}
