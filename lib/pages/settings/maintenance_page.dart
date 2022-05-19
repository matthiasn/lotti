import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({Key? key}) : super(key: key);

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
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return StreamBuilder<List<ConfigFlag>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<ConfigFlag>> snapshot,
      ) {
        List<ConfigFlag> items = snapshot.data ?? [];
        debugPrint('$items');
        return StreamBuilder<int>(
          stream: _db.watchTaggedCount(),
          builder: (
            BuildContext context,
            AsyncSnapshot<int> snapshot,
          ) {
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8.0),
              children: [
                MaintenanceCard(
                  title:
                      '${localizations.maintenanceDeleteTagged}, n = ${snapshot.data}',
                  onTap: () => _maintenance.deleteTaggedLinks(),
                ),
                MaintenanceCard(
                  title: localizations.maintenanceDeleteEditorDb,
                  onTap: () => _maintenance.deleteEditorDb(),
                ),
                MaintenanceCard(
                  title: localizations.maintenanceRecreateTagged,
                  onTap: () => _maintenance.recreateTaggedLinks(),
                ),
                MaintenanceCard(
                  title: localizations.maintenanceStories,
                  onTap: () => _maintenance.recreateStoryAssignment(),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class MaintenanceCard extends StatelessWidget {
  const MaintenanceCard({
    Key? key,
    required this.title,
    required this.onTap,
  }) : super(key: key);

  final String title;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.headerBgColor,
      elevation: 8.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
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
                color: AppColors.entryTextColor,
                fontFamily: 'Oswald',
                fontSize: 20.0,
              ),
            ),
          ],
        ),
        enabled: true,
        onTap: onTap,
      ),
    );
  }
}
