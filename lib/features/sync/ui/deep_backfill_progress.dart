import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/deep_backfill_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Progress of a deep-backfill round: a bar while records are listed, then
/// how many were listed for the other devices, or the error that stopped it.
class DeepBackfillProgress extends StatelessWidget {
  const DeepBackfillProgress({required this.state, super.key});

  final DeepBackfillState state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final error = state.error;
    final progressText = '${(state.progress * 100).round()}%';
    final label = context.messages.maintenanceDeepBackfillProgress(
      state.advertised,
      state.total,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: tokens.spacing.step5),
        if (error != null) ...[
          Icon(
            LottiIcons.error,
            size: IconSizes.xxxl,
            color: tokens.colors.alert.error.defaultColor,
          ),
          SizedBox(height: tokens.spacing.step3),
          Text(
            error,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: tokens.colors.alert.error.ink,
            ),
            textAlign: TextAlign.center,
          ),
        ] else if (state.isDone) ...[
          Icon(
            LottiIcons.confirmCircled,
            size: IconSizes.xxxl,
            color: tokens.colors.alert.success.defaultColor,
          ),
          SizedBox(height: tokens.spacing.step3),
          Text(
            context.messages.maintenanceDeepBackfillComplete(state.advertised),
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.alert.success.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.center,
          ),
        ] else
          DesignSystemProgressBar(
            value: state.progress,
            label: label,
            progressText: progressText,
            semanticsLabel: label,
            semanticsValue: progressText,
          ),
        SizedBox(height: tokens.spacing.step5),
      ],
    );
  }
}
