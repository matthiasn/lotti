import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/pages/settings/outbox/outbox_badge.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/widgets/settings/settings_card.dart';
import 'package:lotti/widgets/settings/settings_icon.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class AdvancedSettingsPage extends StatelessWidget {
  const AdvancedSettingsPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return SliverBoxAdapterPage(
      title: localizations.settingsAdvancedTitle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SettingsNavCard(
              title: localizations.settingsSyncCfgTitle,
              path: '/settings/advanced/sync_settings',
            ),
            SettingsNavCard(
              trailing: OutboxBadgeIcon(
                icon: const SettingsIcon(MdiIcons.mailboxOutline),
              ),
              title: localizations.settingsSyncOutboxTitle,
              path: '/settings/advanced/outbox_monitor',
            ),
            SettingsNavCard(
              title: localizations.settingsConflictsTitle,
              path: '/settings/advanced/conflicts',
            ),
            SettingsNavCard(
              title: localizations.settingsLogsTitle,
              path: '/settings/advanced/logging',
            ),
            SettingsNavCard(
              title: localizations.settingsMaintenanceTitle,
              path: '/settings/advanced/maintenance',
            ),
            SettingsNavCard(
              title: localizations.settingsAboutTitle,
              path: '/settings/advanced/about',
            ),
          ],
        ),
      ),
    );
  }
}
