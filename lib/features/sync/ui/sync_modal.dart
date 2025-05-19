import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/controllers/sync_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';

class SyncModal extends ConsumerWidget {
  const SyncModal({super.key});

  static Future<void> show(BuildContext context) async {
    final confirmed = await showConfirmationModal(
      context: context,
      message: context.messages.syncEntitiesMessage,
      confirmLabel: context.messages.syncEntitiesConfirm,
      isDestructive: false,
    );

    if (confirmed && context.mounted) {
      final container = ProviderScope.containerOf(context);
      await container.read(syncControllerProvider.notifier).syncAll();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}
