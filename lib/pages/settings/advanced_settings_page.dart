import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/pages/settings/outbox/outbox_badge.dart';
import 'package:lotti/pages/settings/settings_card.dart';
import 'package:lotti/pages/settings/settings_icon.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class AdvancedSettingsPage extends StatelessWidget {
  const AdvancedSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: colorConfig().bodyBgColor,
      appBar: TitleAppBar(title: localizations.settingsAdvancedTitle),
      body: Container(
        margin: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 8,
        ),
        child: ListView(
          children: [
            SettingsCard(
              icon: const SettingsIcon(Icons.sync),
              title: localizations.settingsSyncCfgTitle,
              onTap: () {
                navigateNamedRoute('/settings/sync_settings');
              },
            ),
            SettingsCard(
              icon: OutboxBadgeIcon(
                icon: const SettingsIcon(MdiIcons.mailboxOutline),
              ),
              title: localizations.settingsSyncOutboxTitle,
              onTap: () {
                navigateNamedRoute('/settings/outbox_monitor');
              },
            ),
            SettingsCard(
              icon: const SettingsIcon(MdiIcons.emoticonConfusedOutline),
              title: localizations.settingsConflictsTitle,
              onTap: () {
                navigateNamedRoute('/settings/conflicts');
              },
            ),
            SettingsCard(
              icon: const SettingsIcon(MdiIcons.informationOutline),
              title: localizations.settingsLogsTitle,
              onTap: () {
                navigateNamedRoute('/settings/logging');
              },
            ),
            SettingsCard(
              icon: const SettingsIcon(MdiIcons.broom),
              title: localizations.settingsMaintenanceTitle,
              onTap: () {
                navigateNamedRoute('/settings/maintenance');
              },
            ),
          ],
        ),
      ),
    );
  }
}
