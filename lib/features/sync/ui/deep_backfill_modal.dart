import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/deep_backfill_controller.dart';
import 'package:lotti/features/sync/ui/deep_backfill_progress.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/confirmation_progress_modal.dart';
import 'package:material_ui/material_ui.dart';

/// Confirms, then runs, a deep-backfill round from the sync maintenance
/// page.
abstract final class DeepBackfillModal {
  static Future<void> show(BuildContext context) async {
    final container = ProviderScope.containerOf(context);

    await ConfirmationProgressModal.show(
      context: context,
      message: context.messages.maintenanceDeepBackfillMessage,
      confirmLabel: context.messages.maintenanceDeepBackfillConfirm,
      operation: () =>
          container.read(deepBackfillControllerProvider.notifier).runRound(),
      progressBuilder: (context) => Consumer(
        builder: (context, ref, _) => DeepBackfillProgress(
          state: ref.watch(deepBackfillControllerProvider),
        ),
      ),
    );
  }
}
