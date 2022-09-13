import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/settings_card.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

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
      //backgroundColor: colorConfig().bodyBgColor,
      backgroundColor: Colors.white,
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
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MaintenanceCard(
                    title:
                        '${localizations.maintenanceDeleteTagged}, n = ${snapshot.data}',
                    onTap: _maintenance.deleteTaggedLinks,
                  ),
                  const SettingsDivider(),
                  MaintenanceCard(
                    title: localizations.maintenanceDeleteEditorDb,
                    onTap: _maintenance.deleteEditorDb,
                  ),
                  const SettingsDivider(),
                  MaintenanceCard(
                    title: localizations.maintenanceDeleteLoggingDb,
                    onTap: _maintenance.deleteLoggingDb,
                  ),
                  const SettingsDivider(),
                  MaintenanceCard(
                    title: localizations.maintenanceRecreateTagged,
                    onTap: _maintenance.recreateTaggedLinks,
                  ),
                  const SettingsDivider(),
                  MaintenanceCard(
                    title: localizations.maintenanceStories,
                    onTap: _maintenance.recreateStoryAssignment,
                  ),
                  const SettingsDivider(),
                  MaintenanceCard(
                    title: localizations.maintenanceSyncDefinitions,
                    onTap: _maintenance.syncDefinitions,
                  ),
                  const SettingsDivider(),
                  MaintenanceCard(
                    title: localizations.maintenancePurgeDeleted,
                    onTap: _db.purgeDeleted,
                  ),
                  const SettingsDivider(),
                  MaintenanceCard(
                    title: localizations.maintenanceReprocessSync,
                    onTap: () => getIt<SyncConfigService>().resetOffset(),
                  ),
                  const SettingsDivider(),
                  MaintenanceCard(
                    title: localizations.maintenanceCancelNotifications,
                    onTap: () => getIt<NotificationService>().cancelAll(),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class MaintenanceCard extends StatelessWidget {
  const MaintenanceCard({
    super.key,
    required this.title,
    required this.onTap,
  });

  final String title;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      // color: colorConfig().headerBgColor,
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      child: ListTile(
        hoverColor: colorConfig().settingsHoverColor,
        contentPadding: const EdgeInsets.only(
          left: 16,
          top: 4,
          bottom: 8,
          right: 16,
        ),
        title: Text(
          title,
          softWrap: true,
          style: settingsCardTextStyle(),
        ),
        onTap: onTap,
      ),
    );
  }
}
