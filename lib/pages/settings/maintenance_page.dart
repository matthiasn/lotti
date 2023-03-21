import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/settings/settings_card.dart';

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key});

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  final JournalDb _db = getIt<JournalDb>();
  final Maintenance _maintenance = getIt<Maintenance>();

  late final Stream<Set<ConfigFlag>> stream = _db.watchConfigFlags();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: styleConfig().negspace,
      appBar: TitleAppBar(title: localizations.settingsMaintenanceTitle),
      body: StreamBuilder<Set<ConfigFlag>>(
        stream: stream,
        builder: (
          BuildContext context,
          AsyncSnapshot<Set<ConfigFlag>> snapshot,
        ) {
          final items = snapshot.data?.toList() ?? [];
          debugPrint('$items');
          return StreamBuilder<int>(
            stream: _db.watchTaggedCount(),
            builder: (
              BuildContext context,
              AsyncSnapshot<int> snapshot,
            ) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SettingsCard(
                        title:
                            '${localizations.maintenanceDeleteTagged}, n = ${snapshot.data}',
                        onTap: _maintenance.deleteTaggedLinks,
                      ),
                      SettingsCard(
                        title: localizations.maintenanceDeleteEditorDb,
                        onTap: _maintenance.deleteEditorDb,
                      ),
                      SettingsCard(
                        title: localizations.maintenanceDeleteLoggingDb,
                        onTap: _maintenance.deleteLoggingDb,
                      ),
                      SettingsCard(
                        title: localizations.maintenanceRecreateTagged,
                        onTap: _maintenance.recreateTaggedLinks,
                      ),
                      SettingsCard(
                        title: localizations.maintenanceStories,
                        onTap: _maintenance.recreateStoryAssignment,
                      ),
                      SettingsCard(
                        title: localizations.maintenanceSyncDefinitions,
                        onTap: _maintenance.syncDefinitions,
                      ),
                      SettingsCard(
                        title: localizations.maintenancePurgeDeleted,
                        onTap: _db.purgeDeleted,
                      ),
                      SettingsCard(
                        title: localizations.maintenanceReprocessSync,
                        onTap: () => getIt<SyncConfigService>().resetOffset(),
                      ),
                      SettingsCard(
                        title: localizations.maintenanceResetHostId,
                        onTap: () => getIt<SyncConfigService>().resetHostId(),
                      ),
                      SettingsCard(
                        title: localizations.maintenanceCancelNotifications,
                        onTap: () => getIt<NotificationService>().cancelAll(),
                      ),
                      SettingsCard(
                        title: localizations.maintenanceRecreateFts5,
                        onTap: () => getIt<Maintenance>().recreateFts5(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
