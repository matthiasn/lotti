import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/pages/settings/outbox/outbox_badge.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/settings/settings_card.dart';
import 'package:lotti/widgets/settings/settings_icon.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class AdvancedSettingsPage extends StatelessWidget {
  const AdvancedSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: colorConfig().negspace,
      appBar: TitleAppBar(title: localizations.settingsAdvancedTitle),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SettingsDivider(),
          SettingsNavCard(
            title: localizations.settingsSyncCfgTitle,
            path: '/settings/advanced/sync_settings',
          ),
          const SettingsDivider(),
          SettingsNavCard(
            trailing: OutboxBadgeIcon(
              icon: const SettingsIcon(MdiIcons.mailboxOutline),
            ),
            title: localizations.settingsSyncOutboxTitle,
            path: '/settings/advanced/outbox_monitor',
          ),
          const SettingsDivider(),
          SettingsNavCard(
            title: localizations.settingsConflictsTitle,
            path: '/settings/advanced/conflicts',
          ),
          const SettingsDivider(),
          SettingsNavCard(
            title: localizations.settingsLogsTitle,
            path: '/settings/advanced/logging',
          ),
          const SettingsDivider(),
          SettingsNavCard(
            title: localizations.settingsMaintenanceTitle,
            path: '/settings/advanced/maintenance',
          ),
          const SettingsDivider(),
          SettingsNavCard(
            title: localizations.settingsAboutTitle,
            path: '/settings/advanced/about',
          ),
          const SettingsDivider(),
        ],
      ),
    );
  }
}
