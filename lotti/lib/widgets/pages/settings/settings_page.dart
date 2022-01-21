import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/blocs/journal/persistence_state.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/misc/app_bar_version.dart';
import 'package:lotti/widgets/pages/settings/conflicts.dart';
import 'package:lotti/widgets/pages/settings/flags_page.dart';
import 'package:lotti/widgets/pages/settings/insights_page.dart';
import 'package:lotti/widgets/pages/settings/measurables.dart';
import 'package:lotti/widgets/pages/settings/outbox_badge.dart';
import 'package:lotti/widgets/pages/settings/outbox_monitor.dart';
import 'package:lotti/widgets/pages/settings/settings_card.dart';
import 'package:lotti/widgets/pages/settings/settings_icon.dart';
import 'package:lotti/widgets/pages/settings/sync_settings.dart';
import 'package:lotti/widgets/pages/settings/tags_page.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    Key? key,
    this.navigatorKey,
  }) : super(key: key);

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
                  appBar: const VersionAppBar(title: 'Settings'),
                  backgroundColor: AppColors.bodyBgColor,
                  body: Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 8.0,
                    ),
                    child: ListView(
                      children: [
                        SettingsCard(
                          icon: const SettingsIcon(Icons.sync),
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
                          icon: const SettingsIcon(MdiIcons.tapeMeasure),
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
                        SettingsCard(
                          icon: OutboxBadgeIcon(),
                          title: 'Sync Outbox',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (BuildContext context) {
                                  return const OutboxMonitorPage();
                                },
                              ),
                            );
                          },
                        ),
                        SettingsCard(
                          icon: const SettingsIcon(MdiIcons.information),
                          title: 'Logs',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (BuildContext context) {
                                  return const InsightsPage();
                                },
                              ),
                            );
                          },
                        ),
                        SettingsCard(
                          icon: const SettingsIcon(MdiIcons.emoticonConfused),
                          title: 'Conflicts',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (BuildContext context) {
                                  return const ConflictsPage();
                                },
                              ),
                            );
                          },
                        ),
                        SettingsCard(
                          icon: const SettingsIcon(MdiIcons.flag),
                          title: 'Flags',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (BuildContext context) {
                                  return const FlagsPage();
                                },
                              ),
                            );
                          },
                        ),
                        SettingsCard(
                          icon: const SettingsIcon(MdiIcons.tag),
                          title: 'Tags',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (BuildContext context) {
                                  return const TagsPage();
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
