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
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:lotti/widgets/settings/animated_settings_cards.dart';

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
          child: Column(
            children: [
              AnimatedModernSettingsCardWithIcon(
                title: context.messages.maintenanceDeleteEditorDb,
                subtitle:
                    context.messages.maintenanceDeleteEditorDbDescription,
                icon: Icons.edit_note_rounded,
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
                margin: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLarge,
                  vertical: AppTheme.cardSpacing / 2,
                ),
              ),
              AnimatedModernSettingsCardWithIcon(
                title: context.messages.maintenanceDeleteLoggingDb,
                subtitle:
                    context.messages.maintenanceDeleteLoggingDbDescription,
                icon: Icons.article_rounded,
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
                margin: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLarge,
                  vertical: AppTheme.cardSpacing / 2,
                ),
              ),
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
                margin: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLarge,
                  vertical: AppTheme.cardSpacing / 2,
                ),
              ),
              AnimatedModernSettingsCardWithIcon(
                title: context.messages.maintenanceSyncDefinitions,
                subtitle:
                    context.messages.maintenanceSyncDefinitionsDescription,
                icon: Icons.sync_alt_rounded,
                onTap: () => SyncModal.show(context),
                margin: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLarge,
                  vertical: AppTheme.cardSpacing / 2,
                ),
              ),
              AnimatedModernSettingsCardWithIcon(
                title: context.messages.maintenancePurgeDeleted,
                subtitle: context.messages.maintenancePurgeDeletedDescription,
                icon: Icons.delete_forever_rounded,
                onTap: () => PurgeModal.show(context),
                margin: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLarge,
                  vertical: AppTheme.cardSpacing / 2,
                ),
              ),
              AnimatedModernSettingsCardWithIcon(
                title: context.messages.maintenancePurgeAudioModels,
                subtitle:
                    context.messages.maintenancePurgeAudioModelsDescription,
                icon: Icons.audio_file_rounded,
                onTap: () => AudioPurgeModal.show(context),
                margin: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLarge,
                  vertical: AppTheme.cardSpacing / 2,
                ),
              ),
              AnimatedModernSettingsCardWithIcon(
                title: context.messages.maintenanceRecreateFts5,
                subtitle: context.messages.maintenanceRecreateFts5Description,
                icon: Icons.search_rounded,
                onTap: () => Fts5RecreateModal.show(context),
                margin: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLarge,
                  vertical: AppTheme.cardSpacing / 2,
                ),
              ),
              AnimatedModernSettingsCardWithIcon(
                title: context.messages.maintenanceReSync,
                subtitle: context.messages.maintenanceReSyncDescription,
                icon: Icons.refresh_rounded,
                onTap: () => ReSyncModal.show(context),
                margin: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLarge,
                  vertical: AppTheme.cardSpacing / 2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
