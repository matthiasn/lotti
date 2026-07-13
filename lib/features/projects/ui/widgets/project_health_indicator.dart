import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/cards/modern_status_chip.dart';

/// Renders a project's health band as a colored [ModernStatusChip], optionally
/// followed by the agent's rationale text.
///
/// Set [showReason] to `false` for compact contexts where only the band chip
/// should appear. Visual attributes come from [projectHealthBandAttributes].
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
    final (label, color, icon) = projectHealthBandAttributes(
      context,
      metrics.band,
    );

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

/// Maps a [ProjectHealthBand] to its display triple of (label, color, icon).
///
/// Colors are brightness-aware (darker variants in light mode for contrast).
/// Shared by [ProjectHealthIndicator] and the `ProjectHealthBandTag` pill so the
/// band reads identically across surfaces.
(String, Color, IconData) projectHealthBandAttributes(
  BuildContext context,
  ProjectHealthBand band,
) {
  final messages = context.messages;
  // One traffic-light source: the health band draws from the SAME design-system
  // alert tokens as the task status dots/pills, so "good green" / "at-risk red"
  // mean the same hue everywhere on the page. Calm status glyphs (not sentiment
  // smileys) keep the verdict reading as a status, not an emoji.
  final alert = context.designTokens.colors.alert;
  return switch (band) {
    ProjectHealthBand.surviving => (
      messages.projectHealthBandSurviving,
      alert.info.defaultColor,
      Icons.trending_flat_rounded,
    ),
    ProjectHealthBand.onTrack => (
      messages.projectHealthBandOnTrack,
      alert.success.defaultColor,
      Icons.check_circle_outline_rounded,
    ),
    ProjectHealthBand.watch => (
      messages.projectHealthBandWatch,
      alert.info.defaultColor,
      Icons.visibility_outlined,
    ),
    ProjectHealthBand.atRisk => (
      messages.projectHealthBandAtRisk,
      alert.warning.defaultColor,
      Icons.warning_amber_rounded,
    ),
    ProjectHealthBand.blocked => (
      messages.projectHealthBandBlocked,
      alert.error.defaultColor,
      Icons.block_rounded,
    ),
  };
}
