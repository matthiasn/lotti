import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/sync/ui/re_sync_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/widgets/settings/settings_card.dart';

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final maintenance = getIt<Maintenance>();
    final db = getIt<JournalDb>();

    return StreamBuilder<int>(
      stream: db.watchTaggedCount(),
      builder: (
        BuildContext context,
        AsyncSnapshot<int> snapshot,
      ) {
        return SliverBoxAdapterPage(
          title: context.messages.settingsMaintenanceTitle,
          showBackButton: true,
          child: Column(
            children: [
              SettingsCard(
                title:
                    '${context.messages.maintenanceDeleteTagged}, n = ${snapshot.data}',
                onTap: maintenance.deleteTaggedLinks,
              ),
              SettingsCard(
                title: context.messages.maintenanceDeleteEditorDb,
                onTap: maintenance.deleteEditorDb,
              ),
              SettingsCard(
                title: context.messages.maintenanceDeleteLoggingDb,
                onTap: maintenance.deleteLoggingDb,
              ),
              SettingsCard(
                title: context.messages.maintenanceDeleteSyncDb,
                onTap: maintenance.deleteSyncDb,
              ),
              SettingsCard(
                title: context.messages.maintenanceRecreateTagged,
                onTap: maintenance.recreateTaggedLinks,
              ),
              SettingsCard(
                title: context.messages.maintenanceStories,
                onTap: maintenance.recreateStoryAssignment,
              ),
              SettingsCard(
                title: context.messages.maintenanceSyncDefinitions,
                onTap: maintenance.syncDefinitions,
              ),
              SettingsCard(
                title: context.messages.maintenanceSyncCategories,
                onTap: maintenance.syncCategories,
              ),
              SettingsCard(
                title: context.messages.maintenancePurgeDeleted,
                onTap: db.purgeDeleted,
              ),
              SettingsCard(
                title: context.messages.maintenanceCancelNotifications,
                onTap: () => getIt<NotificationService>().cancelAll(),
              ),
              SettingsCard(
                title: context.messages.maintenanceRecreateFts5,
                onTap: () => getIt<Maintenance>().recreateFts5(),
              ),
              SettingsCard(
                title: context.messages.maintenancePersistTaskCategories,
                onTap: () => getIt<Maintenance>().persistTaskCategories(),
              ),
              SettingsCard(
                title: context.messages.maintenanceReSync,
                onTap: () => ReSyncModal.show(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
