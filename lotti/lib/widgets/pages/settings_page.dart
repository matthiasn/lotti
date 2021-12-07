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
                        color: AppColors.entryTextColor,
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
                      children: [
                        SettingsCard(
                          iconData: Icons.sync,
                          title: 'Synchronization',
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
                        SettingsCard(
                          iconData: MdiIcons.tapeMeasure,
                          title: 'Measurables',
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

class SettingsCard extends StatelessWidget {
  const SettingsCard({
    Key? key,
    required this.iconData,
    required this.title,
    required this.onTap,
  }) : super(key: key);

  final IconData iconData;
  final String title;
  final void Function() onTap;

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
            const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
        leading: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(8.0)),
          child: Icon(
            iconData,
            size: 40,
            color: AppColors.entryTextColor,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: AppColors.entryTextColor,
            fontFamily: 'Oswald',
            fontSize: 20.0,
          ),
        ),
        enabled: true,
        onTap: onTap,
      ),
    );
  }
}
