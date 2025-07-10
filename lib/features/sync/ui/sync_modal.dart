import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings/ui/confirmation_progress_modal.dart';
import 'package:lotti/features/sync/models/sync_models.dart';
import 'package:lotti/features/sync/state/sync_maintenance_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class SyncModal extends ConsumerWidget {
  const SyncModal({super.key});

  static Future<void> show(BuildContext context) async {
    final container = ProviderScope.containerOf(context);

    await ConfirmationProgressModal.show(
      context: context,
      message: context.messages.syncEntitiesMessage,
      confirmLabel: context.messages.syncEntitiesConfirm,
      isDestructive: false,
      operation: () =>
          container.read(syncControllerProvider.notifier).syncAll(),
      progressBuilder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final syncState = ref.watch(syncControllerProvider);
            final currentStep = syncState.currentStep;
            final progress = syncState.progress;
            final isSyncing = syncState.isSyncing;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (progress == 100 && !isSyncing)
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 5,
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            borderRadius: BorderRadius.circular(8),
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
                        '$progress%',
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
                _buildStepIndicator(
                  context,
                  SyncStep.tags,
                  currentStep,
                  isSyncing,
                ),
                _buildStepIndicator(
                  context,
                  SyncStep.measurables,
                  currentStep,
                  isSyncing,
                ),
                _buildStepIndicator(
                  context,
                  SyncStep.categories,
                  currentStep,
                  isSyncing,
                ),
                _buildStepIndicator(
                  context,
                  SyncStep.dashboards,
                  currentStep,
                  isSyncing,
                ),
                _buildStepIndicator(
                  context,
                  SyncStep.habits,
                  currentStep,
                  isSyncing,
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Widget _buildStepIndicator(
    BuildContext context,
    SyncStep step,
    SyncStep currentStep,
    bool isSyncing,
  ) {
    final isCompleted = !isSyncing && currentStep.index > step.index;
    final isCurrent = currentStep == step;

    IconData icon;
    Color color;

    if (isCompleted) {
      icon = Icons.check_circle_outline;
      color = Theme.of(context).colorScheme.primary;
    } else if (isCurrent) {
      icon = Icons.sync;
      color = Theme.of(context).colorScheme.primary;
    } else {
      icon = Icons.circle_outlined;
      color = Theme.of(context).colorScheme.outline;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            _getStepName(context, step),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  static String _getStepName(BuildContext context, SyncStep step) {
    switch (step) {
      case SyncStep.tags:
        return context.messages.syncStepTags;
      case SyncStep.measurables:
        return context.messages.syncStepMeasurables;
      case SyncStep.dashboards:
        return context.messages.syncStepDashboards;
      case SyncStep.habits:
        return context.messages.syncStepHabits;
      case SyncStep.categories:
        return context.messages.syncStepCategories;
      case SyncStep.complete:
        return context.messages.syncStepComplete;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}
