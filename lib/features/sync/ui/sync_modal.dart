import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings/ui/confirmation_progress_modal.dart';
import 'package:lotti/features/sync/models/sync_models.dart';
import 'package:lotti/features/sync/state/sync_maintenance_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';

class SyncModal extends ConsumerWidget {
  const SyncModal({super.key});

  static Future<void> show(BuildContext context) async {
    final container = ProviderScope.containerOf(context);
    const orderedSteps = <SyncStep>[
      SyncStep.tags,
      SyncStep.measurables,
      SyncStep.categories,
      SyncStep.dashboards,
      SyncStep.habits,
      SyncStep.aiSettings,
    ];
    final selectedStepsNotifier =
        ValueNotifier<Set<SyncStep>>(orderedSteps.toSet());

    bool hasSelection() => selectedStepsNotifier.value.isNotEmpty;

    await ConfirmationProgressModal.show(
      context: context,
      message: context.messages.syncEntitiesMessage,
      confirmLabel: context.messages.syncEntitiesConfirm,
      isDestructive: false,
      closeOnComplete: false,
      confirmationContent: ValueListenableBuilder<Set<SyncStep>>(
        valueListenable: selectedStepsNotifier,
        builder: (context, selectedSteps, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final step in orderedSteps)
                CheckboxListTile(
                  value: selectedSteps.contains(step),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.trailing,
                  title: Text(_getStepName(context, step)),
                  onChanged: (value) {
                    final updated =
                        Set<SyncStep>.from(selectedStepsNotifier.value);
                    if (value ?? false) {
                      updated.add(step);
                    } else {
                      updated.remove(step);
                    }
                    selectedStepsNotifier.value = updated;
                  },
                ),
            ],
          );
        },
      ),
      isConfirmEnabled: hasSelection,
      confirmEnabledListenable: selectedStepsNotifier,
      operation: () {
        final selection = Set<SyncStep>.from(selectedStepsNotifier.value);
        return container
            .read(syncControllerProvider.notifier)
            .syncAll(selectedSteps: selection);
      },
      progressBuilder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final syncState = ref.watch(syncControllerProvider);
            final currentStep = syncState.currentStep;
            final progress = syncState.progress;
            final isSyncing = syncState.isSyncing;
            final selectedSteps = syncState.selectedSteps.isEmpty
                ? selectedStepsNotifier.value
                : syncState.selectedSteps;
            final stepsToShow =
                orderedSteps.where(selectedSteps.contains).toList();

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (progress == 100 && !isSyncing) ...[
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.messages.syncEntitiesSuccessTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.messages.syncEntitiesSuccessDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: LottiPrimaryButton(
                      label: context.messages.doneButton.toUpperCase(),
                      onPressed: () {
                        if (context.mounted) {
                          container
                              .read(syncControllerProvider.notifier)
                              .reset();
                          Navigator.of(context).pop();
                        }
                      },
                      icon: Icons.check_circle_rounded,
                    ),
                  ),
                ] else
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
                for (final step in stepsToShow)
                  _buildStepIndicator(
                    context,
                    step,
                    currentStep,
                    isSyncing,
                    syncState.stepProgress[step],
                  ),
              ],
            );
          },
        );
      },
    );
    selectedStepsNotifier.dispose();
  }

  static Widget _buildStepIndicator(
    BuildContext context,
    SyncStep step,
    SyncStep currentStep,
    bool isSyncing,
    StepProgress? stepProgress,
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

    final processed = stepProgress?.processed ?? 0;
    final total = stepProgress?.total ?? 0;
    final countText = '$processed / $total';

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
          const Spacer(),
          Text(
            countText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
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
      case SyncStep.categories:
        return context.messages.syncStepCategories;
      case SyncStep.dashboards:
        return context.messages.syncStepDashboards;
      case SyncStep.habits:
        return context.messages.syncStepHabits;
      case SyncStep.aiSettings:
        return context.messages.syncStepAiSettings;
      case SyncStep.complete:
        return context.messages.syncStepComplete;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}
