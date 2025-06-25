import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/sync/ui/audio_purge_modal.dart';
import 'package:lotti/features/sync/ui/fts5_recreate_modal.dart';
import 'package:lotti/features/sync/ui/purge_modal.dart';
import 'package:lotti/features/sync/ui/re_sync_modal.dart';
import 'package:lotti/features/sync/ui/sync_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:lotti/widgets/settings/modern_settings_cards.dart';

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final maintenance = getIt<Maintenance>();
    final db = getIt<JournalDb>();
    Theme.of(context);

    return FutureBuilder<int>(
      future: db.getTaggedCount(),
      builder: (
        BuildContext context,
        AsyncSnapshot<int> snapshot,
      ) {
        return SliverBoxAdapterPage(
          title: context.messages.settingsMaintenanceTitle,
          showBackButton: true,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ModernMaintenanceCard(
                  title: context.messages.maintenanceDeleteEditorDb,
                  subtitle:
                      context.messages.maintenanceDeleteEditorDbDescription,
                  icon: Icons.edit_note_rounded,
                  isDestructive: true,
                  onTap: () async {
                    final confirmed = await showConfirmationModal(
                      context: context,
                      message: context.messages
                          .maintenanceDeleteDatabaseQuestion('Editor'),
                      confirmLabel:
                          context.messages.maintenanceDeleteDatabaseConfirm,
                    );
                    if (confirmed && context.mounted) {
                      await maintenance.deleteEditorDb();
                    }
                  },
                ),
                const SizedBox(height: 8),
                ModernMaintenanceCard(
                  title: context.messages.maintenanceDeleteLoggingDb,
                  subtitle:
                      context.messages.maintenanceDeleteLoggingDbDescription,
                  icon: Icons.article_rounded,
                  isDestructive: true,
                  onTap: () async {
                    final confirmed = await showConfirmationModal(
                      context: context,
                      message: context.messages
                          .maintenanceDeleteDatabaseQuestion('Logging'),
                      confirmLabel:
                          context.messages.maintenanceDeleteDatabaseConfirm,
                    );
                    if (confirmed && context.mounted) {
                      await maintenance.deleteLoggingDb();
                    }
                  },
                ),
                const SizedBox(height: 8),
                ModernMaintenanceCard(
                  title: context.messages.maintenanceDeleteSyncDb,
                  subtitle: context.messages.maintenanceDeleteSyncDbDescription,
                  icon: Icons.sync_rounded,
                  isDestructive: true,
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
                const SizedBox(height: 8),
                ModernMaintenanceCard(
                  title: context.messages.maintenanceSyncDefinitions,
                  subtitle:
                      context.messages.maintenanceSyncDefinitionsDescription,
                  icon: Icons.sync_alt_rounded,
                  onTap: () => SyncModal.show(context),
                ),
                const SizedBox(height: 8),
                ModernMaintenanceCard(
                  title: context.messages.maintenancePurgeDeleted,
                  subtitle: context.messages.maintenancePurgeDeletedDescription,
                  icon: Icons.delete_forever_rounded,
                  isDestructive: true,
                  onTap: () => PurgeModal.show(context),
                ),
                const SizedBox(height: 8),
                ModernMaintenanceCard(
                  title: context.messages.maintenancePurgeAudioModels,
                  subtitle:
                      context.messages.maintenancePurgeAudioModelsDescription,
                  icon: Icons.audio_file_rounded,
                  isDestructive: true,
                  onTap: () => AudioPurgeModal.show(context),
                ),
                const SizedBox(height: 8),
                ModernMaintenanceCard(
                  title: context.messages.maintenanceRecreateFts5,
                  subtitle: context.messages.maintenanceRecreateFts5Description,
                  icon: Icons.search_rounded,
                  onTap: () => Fts5RecreateModal.show(context),
                ),
                const SizedBox(height: 8),
                ModernMaintenanceCard(
                  title: context.messages.maintenanceReSync,
                  subtitle: context.messages.maintenanceReSyncDescription,
                  icon: Icons.refresh_rounded,
                  onTap: () => ReSyncModal.show(context),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
