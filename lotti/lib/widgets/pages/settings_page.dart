import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/blocs/journal/persistence_state.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/pages/measurables.dart';
import 'package:lotti/widgets/pages/sync_settings.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    Key? key,
    this.navigatorKey,
  });

  final GlobalKey? navigatorKey;

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: widget.navigatorKey,
      onGenerateRoute: (RouteSettings settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (BuildContext context) {
            return BlocBuilder<PersistenceCubit, PersistenceState>(
              builder: (BuildContext context, PersistenceState state) {
                return Scaffold(
                  appBar: AppBar(
                    backgroundColor: AppColors.headerBgColor,
                    title: Text(
                      'Settings',
                      style: TextStyle(
                        color: AppColors.entryBgColor,
                        fontFamily: 'Oswald',
                      ),
                    ),
                    centerTitle: true,
                  ),
                  backgroundColor: AppColors.bodyBgColor,
                  body: Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 8.0,
                    ),
                    child: ListView(
                      children: const [
                        SyncSettingsCard(),
                        MeasurablesSettingsCard(),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class SyncSettingsCard extends StatelessWidget {
  const SyncSettingsCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.headerBgColor,
      elevation: 8.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListTile(
          leading: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(8.0)),
            child: Icon(
              Icons.sync,
              size: 40,
              color: AppColors.entryBgColor,
            ),
          ),
          title: Text(
            'Synchronization',
            style: TextStyle(
              color: AppColors.entryBgColor,
              fontFamily: 'Oswald',
              fontSize: 20.0,
            ),
          ),
          enabled: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (BuildContext context) {
                  return const SyncSettingsPage();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class MeasurablesSettingsCard extends StatelessWidget {
  const MeasurablesSettingsCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.headerBgColor,
      elevation: 8.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListTile(
          leading: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(8.0)),
            child: Icon(
              MdiIcons.tapeMeasure,
              size: 40,
              color: AppColors.entryBgColor,
            ),
          ),
          title: Text(
            'Measurables',
            style: TextStyle(
              color: AppColors.entryBgColor,
              fontFamily: 'Oswald',
              fontSize: 20.0,
            ),
          ),
          enabled: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (BuildContext context) {
                  return const MeasurablesPage();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
