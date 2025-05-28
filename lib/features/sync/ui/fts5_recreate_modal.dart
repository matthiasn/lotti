import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/fts5_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/modals.dart';

class Fts5RecreateModal {
  const Fts5RecreateModal._();

  static Future<void> show(BuildContext context) async {
    final container = ProviderScope.containerOf(context);

    await ModalUtils.showConfirmationAndProgressModal(
      context: context,
      message: context.messages.maintenanceRecreateFts5Message,
      confirmLabel: context.messages.maintenanceRecreateFts5Confirm,
      operation: () =>
          container.read(fts5ControllerProvider.notifier).recreateFts5(),
      progressBuilder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final fts5State = ref.watch(fts5ControllerProvider);
            final progress = fts5State.progress;
            final isRecreating = fts5State.isRecreating;
            final error = fts5State.error;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                if (error != null)
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  )
                else if (progress == 1.0 && !isRecreating)
                  Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '100%',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 5,
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                if (error != null)
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  )
                else
                  Text(
                    context.messages.maintenanceRecreateFts5,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
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
