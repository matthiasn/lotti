import 'package:flutter/material.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/animated_settings_cards.dart';
import 'package:lotti/features/sync/ui/re_sync_modal.dart';
import 'package:lotti/features/sync/ui/sequence_log_populate_modal.dart';
import 'package:lotti/features/sync/ui/sync_modal.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';

class MatrixSyncMaintenancePage extends StatelessWidget {
  const MatrixSyncMaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final maintenance = getIt<Maintenance>();

    return SyncFeatureGate(
      child: SliverBoxAdapterPage(
        title: context.messages.settingsMatrixMaintenanceTitle,
        subtitle: context.messages.settingsMatrixMaintenanceSubtitle,
        showBackButton: true,
        child: Column(
          children: [
            AnimatedModernSettingsCardWithIcon(
              title: context.messages.maintenanceDeleteSyncDb,
              subtitle: context.messages.maintenanceDeleteSyncDbDescription,
              icon: Icons.sync_rounded,
              onTap: () async {
                final confirmed = await showConfirmationModal(
                  context: context,
                  message: context.messages
                      .maintenanceDeleteDatabaseQuestion('Sync'),
                  confirmLabel:
                      context.messages.maintenanceDeleteDatabaseConfirm,
                );
                if (confirmed && context.mounted) {
                  await maintenance.deleteSyncDb();
                }
              },
            ),
            AnimatedModernSettingsCardWithIcon(
              title: context.messages.maintenanceSyncDefinitions,
              subtitle: context.messages.maintenanceSyncDefinitionsDescription,
              icon: Icons.sync_alt_rounded,
              onTap: () => SyncModal.show(context),
            ),
            AnimatedModernSettingsCardWithIcon(
              title: context.messages.maintenanceReSync,
              subtitle: context.messages.maintenanceReSyncDescription,
              icon: Icons.refresh_rounded,
              onTap: () => ReSyncModal.show(context),
            ),
            AnimatedModernSettingsCardWithIcon(
              title: context.messages.maintenancePopulateSequenceLog,
              subtitle:
                  context.messages.maintenancePopulateSequenceLogDescription,
              icon: Icons.playlist_add_check_rounded,
              onTap: () => SequenceLogPopulateModal.show(context),
            ),
          ],
        ),
      ),
    );
  }
}
