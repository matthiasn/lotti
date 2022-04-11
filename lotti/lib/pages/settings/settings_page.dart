import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/pages/settings/outbox_badge.dart';
import 'package:lotti/pages/settings/settings_card.dart';
import 'package:lotti/pages/settings/settings_icon.dart';
import 'package:lotti/routes/router.gr.dart';
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
    AppLocalizations localizations = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 8.0,
        horizontal: 8.0,
      ),
      child: ListView(
        children: [
          SettingsCard(
            icon: const SettingsIcon(MdiIcons.tagOutline),
            title: localizations.settingsTagsTitle,
            onTap: () {
              context.router.push(const TagsRoute());
            },
          ),
          SettingsCard(
            icon: const SettingsIcon(Icons.insights_outlined),
            title: localizations.settingsDashboardsTitle,
            onTap: () {
              context.router.push(const DashboardSettingsRoute());
            },
          ),
          SettingsCard(
            icon: const SettingsIcon(MdiIcons.tapeMeasure),
            title: localizations.settingsMeasurablesTitle,
            onTap: () {
              context.router.push(const MeasurablesRoute());
            },
          ),
          SettingsCard(
            icon: const SettingsIcon(MdiIcons.heartOutline),
            title: localizations.settingsHealthImportTitle,
            onTap: () {
              context.router.push(const HealthImportRoute());
            },
          ),
          SettingsCard(
            icon: const SettingsIcon(Icons.sync),
            title: localizations.settingsSyncCfgTitle,
            onTap: () {
              context.router.push(const SyncSettingsRoute());
            },
          ),
          SettingsCard(
            icon: OutboxBadgeIcon(
              icon: const SettingsIcon(MdiIcons.mailboxOutline),
            ),
            title: localizations.settingsSyncOutboxTitle,
            onTap: () {
              context.router.push(const OutboxMonitorRoute());
            },
          ),
          SettingsCard(
            icon: const SettingsIcon(MdiIcons.informationOutline),
            title: localizations.settingsLogsTitle,
            onTap: () {
              context.router.push(const LoggingRoute());
            },
          ),
          SettingsCard(
            icon: const SettingsIcon(MdiIcons.emoticonConfusedOutline),
            title: localizations.settingsConflictsTitle,
            onTap: () {
              context.router.push(const ConflictsRoute());
            },
          ),
          SettingsCard(
            icon: const SettingsIcon(MdiIcons.flagOutline),
            title: localizations.settingsFlagsTitle,
            onTap: () {
              context.router.push(const FlagsRoute());
            },
          ),
          SettingsCard(
            icon: const SettingsIcon(MdiIcons.broom),
            title: localizations.settingsMaintenanceTitle,
            onTap: () {
              context.router.push(const MaintenanceRoute());
            },
          ),
        ],
      ),
    );
  }
}
