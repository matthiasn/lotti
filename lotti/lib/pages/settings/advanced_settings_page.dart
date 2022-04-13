import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/pages/settings/outbox_badge.dart';
import 'package:lotti/pages/settings/settings_card.dart';
import 'package:lotti/pages/settings/settings_icon.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class AdvancedSettingsPage extends StatelessWidget {
  const AdvancedSettingsPage({
    Key? key,
  }) : super(key: key);

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
            icon: const SettingsIcon(MdiIcons.emoticonConfusedOutline),
            title: localizations.settingsConflictsTitle,
            onTap: () {
              context.router.push(const ConflictsRoute());
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
            icon: const SettingsIcon(MdiIcons.broom),
            title: localizations.settingsMaintenanceTitle,
            onTap: () {
              context.router.push(const MaintenanceRoute());
            },
          ),
          SettingsCard(
            icon: const SettingsIcon(MdiIcons.broom),
            title: localizations.settingsPlaygroundTitle,
            onTap: () {
              context.router.push(const DevPlaygroundRoute());
            },
          ),
        ],
      ),
    );
  }
}
