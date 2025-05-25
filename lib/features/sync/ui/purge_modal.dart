import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/purge_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/modals.dart';

class PurgeModal {
  const PurgeModal._();

  static Future<void> show(BuildContext context) async {
    final container = ProviderScope.containerOf(context);

    await ModalUtils.showConfirmationAndProgressModal(
      context: context,
      message: context.messages.maintenancePurgeDeletedMessage,
      confirmLabel: context.messages.maintenancePurgeDeletedConfirm,
      operation: () =>
          container.read(purgeControllerProvider.notifier).purgeDeleted(),
      progressBuilder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final purgeState = ref.watch(purgeControllerProvider);
            final progress = purgeState.progress;
            final isPurging = purgeState.isPurging;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                if (progress == 1.0 && !isPurging)
                  Icon(
                    Icons.delete_forever_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
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
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Text(
                  context.messages.maintenancePurgeDeleted,
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
