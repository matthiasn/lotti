import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings/ui/confirmation_progress_modal.dart';
import 'package:lotti/features/sync/state/sequence_log_populate_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class SequenceLogPopulateModal {
  const SequenceLogPopulateModal._();

  static Future<void> show(BuildContext context) async {
    final container = ProviderScope.containerOf(context);

    await ConfirmationProgressModal.show(
      context: context,
      message: context.messages.maintenancePopulateSequenceLogMessage,
      confirmLabel: context.messages.maintenancePopulateSequenceLogConfirm,
      operation: () => container
          .read(sequenceLogPopulateControllerProvider.notifier)
          .populateSequenceLog(),
      progressBuilder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(sequenceLogPopulateControllerProvider);
            final progress = state.progress;
            final isRunning = state.isRunning;
            final error = state.error;
            final populatedCount = state.populatedCount;
            final populatedLinksCount = state.populatedLinksCount;
            final phase = state.phase;
            final totalPopulated =
                (populatedCount ?? 0) + (populatedLinksCount ?? 0);

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
                else if (progress == 1.0 && !isRunning)
                  Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.messages.maintenancePopulateSequenceLogComplete(
                          totalPopulated,
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isRunning)
                        Text(
                          phase == SequenceLogPopulatePhase.populatingJournal
                              ? 'Processing journal entries...'
                              : 'Processing entry links...',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      const SizedBox(height: 8),
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
                else if (!isRunning && progress < 1.0)
                  Text(
                    context.messages.maintenancePopulateSequenceLog,
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
