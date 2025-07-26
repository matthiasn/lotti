import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings/ui/confirmation_progress_modal.dart';
import 'package:lotti/features/sync/state/action_item_suggestions_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class ActionItemSuggestionsRemovalModal {
  const ActionItemSuggestionsRemovalModal._();

  static Future<void> show(BuildContext context) async {
    final container = ProviderScope.containerOf(context);

    await ConfirmationProgressModal.show(
      context: context,
      message: context.messages.maintenanceRemoveActionItemSuggestionsMessage,
      confirmLabel:
          context.messages.maintenanceRemoveActionItemSuggestionsConfirm,
      operation: () => container
          .read(actionItemSuggestionsControllerProvider.notifier)
          .removeActionItemSuggestions(),
      progressBuilder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(actionItemSuggestionsControllerProvider);
            final progress = state.progress;
            final isRemoving = state.isRemoving;
            final error = state.error;

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
                else if (progress == 1.0 && !isRemoving)
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
                    context.messages.maintenanceRemoveActionItemSuggestions,
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
