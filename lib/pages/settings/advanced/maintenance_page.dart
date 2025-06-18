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
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            children: [
              MaintenanceCard(
                title: context.messages.maintenanceDeleteEditorDb,
                description:
                    context.messages.maintenanceDeleteEditorDbDescription,
                icon: Icons.edit_document,
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
              MaintenanceCard(
                title: context.messages.maintenanceDeleteLoggingDb,
                description:
                    context.messages.maintenanceDeleteLoggingDbDescription,
                icon: Icons.article,
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
              MaintenanceCard(
                title: context.messages.maintenanceDeleteSyncDb,
                description:
                    context.messages.maintenanceDeleteSyncDbDescription,
                icon: Icons.sync,
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
              MaintenanceCard(
                title: context.messages.maintenanceSyncDefinitions,
                description:
                    context.messages.maintenanceSyncDefinitionsDescription,
                icon: Icons.sync_alt,
                onTap: () => SyncModal.show(context),
              ),
              MaintenanceCard(
                title: context.messages.maintenancePurgeDeleted,
                description:
                    context.messages.maintenancePurgeDeletedDescription,
                icon: Icons.delete_forever,
                isDestructive: true,
                onTap: () => PurgeModal.show(context),
              ),
              MaintenanceCard(
                title: context.messages.maintenancePurgeAudioModels,
                description:
                    context.messages.maintenancePurgeAudioModelsDescription,
                icon: Icons.audio_file,
                isDestructive: true,
                onTap: () => AudioPurgeModal.show(context),
              ),
              MaintenanceCard(
                title: context.messages.maintenanceRecreateFts5,
                description:
                    context.messages.maintenanceRecreateFts5Description,
                icon: Icons.search,
                onTap: () => Fts5RecreateModal.show(context),
              ),
              MaintenanceCard(
                title: context.messages.maintenanceReSync,
                description: context.messages.maintenanceReSyncDescription,
                icon: Icons.refresh,
                onTap: () => ReSyncModal.show(context),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MaintenanceCard extends StatelessWidget {
  const MaintenanceCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? context.colorScheme.errorContainer
                      : context.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isDestructive
                      ? context.colorScheme.error
                      : context.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: (Theme.of(context).textTheme.titleMedium ??
                              const TextStyle())
                          .copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDestructive
                            ? context.colorScheme.error
                            : context.colorScheme.onSurface,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: (Theme.of(context).textTheme.bodyMedium ??
                              const TextStyle())
                          .copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: context.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
