import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/widgets/settings/settings_card.dart';

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final maintenance = getIt<Maintenance>();
    final db = getIt<JournalDb>();

    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<int>(
      stream: db.watchTaggedCount(),
      builder: (
        BuildContext context,
        AsyncSnapshot<int> snapshot,
      ) {
        return SliverBoxAdapterPage(
          title: localizations.settingsMaintenanceTitle,
          showBackButton: true,
          child: Column(
            children: [
              SettingsCard(
                title:
                    '${localizations.maintenanceDeleteTagged}, n = ${snapshot.data}',
                onTap: maintenance.deleteTaggedLinks,
              ),
              SettingsCard(
                title: localizations.maintenanceDeleteEditorDb,
                onTap: maintenance.deleteEditorDb,
              ),
              SettingsCard(
                title: localizations.maintenanceDeleteLoggingDb,
                onTap: maintenance.deleteLoggingDb,
              ),
              SettingsCard(
                title: localizations.maintenanceRecreateTagged,
                onTap: maintenance.recreateTaggedLinks,
              ),
              SettingsCard(
                title: localizations.maintenanceStories,
                onTap: maintenance.recreateStoryAssignment,
              ),
              SettingsCard(
                title: localizations.maintenanceSyncDefinitions,
                onTap: maintenance.syncDefinitions,
              ),
              SettingsCard(
                title: localizations.maintenancePurgeDeleted,
                onTap: db.purgeDeleted,
              ),
              SettingsCard(
                title: localizations.maintenanceCancelNotifications,
                onTap: () => getIt<NotificationService>().cancelAll(),
              ),
              SettingsCard(
                title: localizations.maintenanceRecreateFts5,
                onTap: () => getIt<Maintenance>().recreateFts5(),
              ),
              SettingsCard(
                title: localizations.maintenanceReSync1K,
                onTap: () => getIt<Maintenance>().reSyncLastMessages(1000),
              ),
              SettingsCard(
                title: localizations.maintenanceReSync10K,
                onTap: () => getIt<Maintenance>().reSyncLastMessages(10000),
              ),
            ],
          ),
        );
      },
    );
  }
}
