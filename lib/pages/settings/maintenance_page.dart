import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key});

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  final JournalDb _db = getIt<JournalDb>();
  final Maintenance _maintenance = getIt<Maintenance>();

  late final Stream<List<ConfigFlag>> stream = _db.watchConfigFlags();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: colorConfig().bodyBgColor,
      appBar: TitleAppBar(title: localizations.settingsMaintenanceTitle),
      body: StreamBuilder<List<ConfigFlag>>(
        stream: stream,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<ConfigFlag>> snapshot,
        ) {
          final items = snapshot.data ?? [];
          debugPrint('$items');
          return StreamBuilder<int>(
            stream: _db.watchTaggedCount(),
            builder: (
              BuildContext context,
              AsyncSnapshot<int> snapshot,
            ) {
              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                children: [
                  MaintenanceCard(
                    title:
                        '${localizations.maintenanceDeleteTagged}, n = ${snapshot.data}',
                    onTap: _maintenance.deleteTaggedLinks,
                  ),
                  MaintenanceCard(
                    title: localizations.maintenanceDeleteEditorDb,
                    onTap: _maintenance.deleteEditorDb,
                  ),
                  MaintenanceCard(
                    title: localizations.maintenanceDeleteLoggingDb,
                    onTap: _maintenance.deleteLoggingDb,
                  ),
                  MaintenanceCard(
                    title: localizations.maintenanceRecreateTagged,
                    onTap: _maintenance.recreateTaggedLinks,
                  ),
                  MaintenanceCard(
                    title: localizations.maintenanceStories,
                    onTap: _maintenance.recreateStoryAssignment,
                  ),
                  MaintenanceCard(
                    title: localizations.maintenancePurgeDeleted,
                    onTap: _db.purgeDeleted,
                  ),
                  MaintenanceCard(
                    title: localizations.maintenanceReprocessSync,
                    onTap: () => getIt<SyncConfigService>().resetOffset(),
                  ),
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
      color: colorConfig().headerBgColor,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.only(left: 16, top: 4, bottom: 8, right: 16),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colorConfig().entryTextColor,
                fontFamily: 'Oswald',
                fontSize: 20,
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
