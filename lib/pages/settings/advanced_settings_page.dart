import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/pages/settings/outbox_badge.dart';
import 'package:lotti/pages/settings/settings_card.dart';
import 'package:lotti/pages/settings/settings_icon.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class AdvancedSettingsPage extends StatelessWidget {
  const AdvancedSettingsPage({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.bodyBgColor,
      appBar: TitleAppBar(title: localizations.settingsAdvancedTitle),
      body: Container(
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
                pushNamedRoute('/settings/sync_settings');
              },
            ),
            SettingsCard(
              icon: OutboxBadgeIcon(
                icon: const SettingsIcon(MdiIcons.mailboxOutline),
              ),
              title: localizations.settingsSyncOutboxTitle,
              onTap: () {
                pushNamedRoute('/settings/outbox_monitor');
              },
            ),
            SettingsCard(
              icon: const SettingsIcon(MdiIcons.emoticonConfusedOutline),
              title: localizations.settingsConflictsTitle,
              onTap: () {
                pushNamedRoute('/settings/conflicts');
              },
            ),
            SettingsCard(
              icon: const SettingsIcon(MdiIcons.informationOutline),
              title: localizations.settingsLogsTitle,
              onTap: () {
                pushNamedRoute('/settings/logging');
              },
            ),
            SettingsCard(
              icon: const SettingsIcon(MdiIcons.broom),
              title: localizations.settingsMaintenanceTitle,
              onTap: () {
                pushNamedRoute('/settings/maintenance');
              },
            ),
            SettingsCard(
              icon: const SettingsIcon(MdiIcons.slide),
              title: localizations.settingsPlaygroundTitle,
              onTap: () {
                pushNamedRoute('/settings/playground');
              },
            ),
          ],
        ),
      ),
    );
  }
}
