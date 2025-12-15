import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings/ui/confirmation_progress_modal.dart';
import 'package:lotti/features/sync/state/sequence_log_populate_controller.dart';
import 'package:lotti/features/sync/ui/sequence_log_populate_progress.dart';
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
            return SequenceLogPopulateProgress(state: state);
          },
        );
      },
    );
  }
}
