import 'package:flutter/material.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
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
    final tokens = context.designTokens;
    final maintenance = getIt<Maintenance>();

    final items =
        <({String title, String subtitle, IconData icon, VoidCallback onTap})>[
          (
            title: context.messages.maintenanceDeleteSyncDb,
            subtitle: context.messages.maintenanceDeleteSyncDbDescription,
            icon: Icons.sync_rounded,
            onTap: () async {
              final confirmed = await showConfirmationModal(
                context: context,
                message: context.messages.maintenanceDeleteDatabaseQuestion(
                  'Sync',
                ),
                confirmLabel: context.messages.maintenanceDeleteDatabaseConfirm,
              );
              if (confirmed && context.mounted) {
                await maintenance.deleteSyncDb();
              }
            },
          ),
          (
            title: context.messages.maintenanceSyncDefinitions,
            subtitle: context.messages.maintenanceSyncDefinitionsDescription,
            icon: Icons.sync_alt_rounded,
            onTap: () => SyncModal.show(context),
          ),
          (
            title: context.messages.maintenanceReSync,
            subtitle: context.messages.maintenanceReSyncDescription,
            icon: Icons.refresh_rounded,
            onTap: () => ReSyncModal.show(context),
          ),
          (
            title: context.messages.maintenancePopulateSequenceLog,
            subtitle:
                context.messages.maintenancePopulateSequenceLogDescription,
            icon: Icons.playlist_add_check_rounded,
            onTap: () => SequenceLogPopulateModal.show(context),
          ),
        ];

    return SyncFeatureGate(
      child: SliverBoxAdapterPage(
        title: context.messages.settingsMatrixMaintenanceTitle,
        subtitle: context.messages.settingsMatrixMaintenanceSubtitle,
        showBackButton: true,
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step4),
        child: DesignSystemGroupedList(
          children: [
            for (final (index, item) in items.indexed)
              DesignSystemListItem(
                title: item.title,
                subtitle: item.subtitle,
                leading: SettingsIcon(icon: item.icon),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: tokens.spacing.step6,
                  color: tokens.colors.text.lowEmphasis,
                ),
                showDivider: index < items.length - 1,
                dividerIndent: SettingsIcon.dividerIndent(tokens),
                onTap: item.onTap,
              ),
          ],
        ),
      ),
    );
  }
}
