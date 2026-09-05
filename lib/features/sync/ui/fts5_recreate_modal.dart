import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/confirmation_progress_modal.dart';
import 'package:lotti/features/sync/state/fts5_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

class Fts5RecreateModal {
  const Fts5RecreateModal._();

  static Future<void> show(BuildContext context) async {
    final container = ProviderScope.containerOf(context);

    await ConfirmationProgressModal.show(
      context: context,
      message: context.messages.maintenanceRecreateFts5Message,
      confirmLabel: context.messages.maintenanceRecreateFts5Confirm,
      operation: () =>
          container.read(fts5ControllerProvider.notifier).recreateFts5(),
      progressBuilder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final tokens = context.designTokens;
            final fts5State = ref.watch(fts5ControllerProvider);
            final progress = fts5State.progress;
            final isRecreating = fts5State.isRecreating;
            final error = fts5State.error;
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
                else if (progress == 1.0 && !isRecreating)
                  Column(
                    children: [
                      Icon(
                        LottiIcons.confirmCircled,
                        size: IconSizes.xxxl,
                        color: tokens.colors.alert.success.defaultColor,
                      ),
                      SizedBox(height: tokens.spacing.step3),
                      Text(
                        '100%',
                        style: tokens.typography.styles.subtitle.subtitle1
                            .copyWith(
                              color: tokens.colors.alert.success.ink,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                    ],
                  )
                else
                  DesignSystemProgressBar(
                    value: progress,
                    progressText: progressText,
                    semanticsLabel: context.messages.maintenanceRecreateFts5,
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
                else
                  Text(
                    context.messages.maintenanceRecreateFts5,
                    style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
