import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/misc/app_bar_version.dart';

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({Key? key}) : super(key: key);

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  final JournalDb _db = getIt<JournalDb>();
  late final Stream<List<ConfigFlag>> stream = _db.watchConfigFlags();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConfigFlag>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<ConfigFlag>> snapshot,
      ) {
        List<ConfigFlag> items = snapshot.data ?? [];
        debugPrint('$items');

        return Scaffold(
          appBar: const VersionAppBar(title: 'Maintenance'),
          backgroundColor: AppColors.bodyBgColor,
          body: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(8.0),
            children: [
              Card(
                color: AppColors.headerBgColor,
                elevation: 8.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.only(
                      left: 16, top: 4, bottom: 8, right: 16),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recreate tagged',
                        style: TextStyle(
                          color: AppColors.entryTextColor,
                          fontFamily: 'Oswald',
                          fontSize: 20.0,
                        ),
                      ),
                    ],
                  ),
                  enabled: true,
                  onTap: () async {
                    _db.recreateTagged();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
