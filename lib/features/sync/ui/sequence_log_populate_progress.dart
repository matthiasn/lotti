import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/sequence_log_populate_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Widget displaying the progress of sequence log population.
/// Extracted from SequenceLogPopulateModal to enable direct testing.
class SequenceLogPopulateProgress extends StatelessWidget {
  const SequenceLogPopulateProgress({
    required this.state,
    super.key,
  });

  final SequenceLogPopulateState state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final progress = state.progress;
    final isRunning = state.isRunning;
    final error = state.error;
    final populatedCount = state.populatedCount;
    final populatedLinksCount = state.populatedLinksCount;
    final phase = state.phase;
    final populatedAgentEntitiesCount = state.populatedAgentEntitiesCount;
    final populatedAgentLinksCount = state.populatedAgentLinksCount;
    final totalPopulated =
        (populatedCount ?? 0) +
        (populatedLinksCount ?? 0) +
        (populatedAgentEntitiesCount ?? 0) +
        (populatedAgentLinksCount ?? 0);
    final phaseLabel = isRunning
        ? switch (phase) {
            SequenceLogPopulatePhase.populatingJournal =>
              context.messages.maintenancePopulatePhaseJournal,
            SequenceLogPopulatePhase.populatingLinks =>
              context.messages.maintenancePopulatePhaseLinks,
            SequenceLogPopulatePhase.populatingAgentEntities =>
              context.messages.maintenancePopulatePhaseAgentEntities,
            SequenceLogPopulatePhase.populatingAgentLinks =>
              context.messages.maintenancePopulatePhaseAgentLinks,
            _ => '',
          }
        : '';
    final progressText = '${(progress * 100).round()}%';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: tokens.spacing.step5),
        if (error != null)
          Icon(
            LottiIcons.error,
            size: IconSizes.xxxl,
            color: tokens.colors.alert.error.defaultColor,
          )
        else if (progress == 1.0 && !isRunning)
          Column(
            children: [
              Icon(
                LottiIcons.confirmCircled,
                size: IconSizes.xxxl,
                color: tokens.colors.alert.success.defaultColor,
              ),
              SizedBox(height: tokens.spacing.step3),
              Text(
                context.messages.maintenancePopulateSequenceLogComplete(
                  totalPopulated,
                ),
                style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                  color: tokens.colors.alert.success.ink,
                  fontFeatures: const [
                    FontFeature.tabularFigures(),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          )
        else
          DesignSystemProgressBar(
            value: progress,
            label: phaseLabel.isEmpty ? null : phaseLabel,
            progressText: progressText,
            semanticsLabel: phaseLabel.isEmpty
                ? context.messages.maintenancePopulateSequenceLog
                : phaseLabel,
            semanticsValue: progressText,
          ),
        SizedBox(height: tokens.spacing.step5),
        if (error != null)
          Text(
            error,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: tokens.colors.alert.error.ink,
            ),
            textAlign: TextAlign.center,
          )
        else if (!isRunning && progress < 1.0)
          Text(
            context.messages.maintenancePopulateSequenceLog,
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
      ],
    );
  }
}
