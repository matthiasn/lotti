import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/lists/hover_divider_index.dart';
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
import 'package:material_ui/material_ui.dart';

/// Mobile / legacy wrapper. Keeps the `SliverBoxAdapterPage` chrome
/// + `SyncFeatureGate` and delegates content to
/// [MatrixSyncMaintenanceBody] so the same widget can render inside
/// the Settings V2 detail pane (plan step 7).
class MatrixSyncMaintenancePage extends StatelessWidget {
  const MatrixSyncMaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SyncFeatureGate(
      child: SliverBoxAdapterPage(
        title: context.messages.settingsMatrixMaintenanceTitle,
        subtitle: context.messages.settingsMatrixMaintenanceSubtitle,
        showBackButton: true,
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step4),
        child: const MatrixSyncMaintenanceBody(),
      ),
    );
  }
}

/// Content body for the Matrix-maintenance page — a grouped list of
/// destructive / diagnostic actions: delete sync DB, re-sync
/// definitions, force re-sync, populate sequence log. Extracted so
/// the V2 detail pane can host the same list without the sliver
/// chrome.
/// Hovering a row fades the hairlines bracketing it, matching the
/// Advanced → Maintenance list this page mirrors — see
/// [HoverDividerIndex].
class MatrixSyncMaintenanceBody extends StatefulWidget {
  const MatrixSyncMaintenanceBody({super.key});

  @override
  State<MatrixSyncMaintenanceBody> createState() =>
      _MatrixSyncMaintenanceBodyState();
}

class _MatrixSyncMaintenanceBodyState extends State<MatrixSyncMaintenanceBody>
    with HoverDividerIndex<MatrixSyncMaintenanceBody> {
  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final maintenance = getIt<Maintenance>();

    final items =
        <({String title, String subtitle, IconData icon, VoidCallback onTap})>[
          (
            title: context.messages.maintenanceDeleteSyncDb,
            subtitle: context.messages.maintenanceDeleteSyncDbDescription,
            icon: LottiIcons.sync,
            onTap: () async {
              final confirmed = await showConfirmationModal(
                context: context,
                message: context.messages.maintenanceDeleteDatabaseQuestion(
                  'Sync',
                ),
                confirmLabel: context.messages.maintenanceDeleteDatabaseConfirm,
              );
              if (confirmed && context.mounted) {
                await maintenance.clearSyncDb();
              }
            },
          ),
          (
            title: context.messages.maintenanceSyncDefinitions,
            subtitle: context.messages.maintenanceSyncDefinitionsDescription,
            icon: LottiIcons.compare,
            onTap: () => SyncModal.show(context),
          ),
          (
            title: context.messages.maintenanceReSync,
            subtitle: context.messages.maintenanceReSyncDescription,
            icon: LottiIcons.refresh,
            onTap: () => ReSyncModal.show(context),
          ),
          (
            title: context.messages.maintenancePopulateSequenceLog,
            subtitle:
                context.messages.maintenancePopulateSequenceLogDescription,
            icon: LottiIcons.checkAll,
            onTap: () => SequenceLogPopulateModal.show(context),
          ),
          (
            title: context.messages.maintenancePurgeSentOutbox,
            subtitle: context.messages.maintenancePurgeSentOutboxDescription,
            icon: LottiIcons.clearAll,
            onTap: () async {
              final confirmed = await showConfirmationModal(
                context: context,
                message: context.messages.maintenancePurgeSentOutboxQuestion,
                confirmLabel:
                    context.messages.maintenancePurgeSentOutboxConfirm,
              );
              if (confirmed && context.mounted) {
                await maintenance.purgeSentOutboxItems();
              }
            },
          ),
        ];

    return DesignSystemGroupedList(
      children: [
        for (final (index, item) in items.indexed)
          DesignSystemListItem(
            title: item.title,
            subtitle: item.subtitle,
            leading: SettingsIcon(icon: item.icon),
            trailing: Icon(
              LottiIcons.chevronRight,
              size: IconSizes.l,
              color: tokens.colors.text.lowEmphasis,
            ),
            // Keep `showDivider` stable so hover never shifts layout
            // by 1 px; only the colour changes.
            showDivider: index < items.length - 1,
            dividerColor: hoverDividerColorFor(index),
            dividerIndent: SettingsIcon.dividerIndent(tokens),
            onHoverChanged: (hovered) =>
                onRowHoverChanged(index, hovered: hovered),
            onTap: item.onTap,
          ),
      ],
    );
  }
}
