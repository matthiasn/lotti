import 'package:flutter/material.dart';
import 'package:lotti/features/sync/ui/matrix_settings_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/outbox/outbox_badge.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/settings/settings_card.dart';
import 'package:lotti/widgets/settings/settings_icon.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class AdvancedSettingsPage extends StatelessWidget {
  const AdvancedSettingsPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsAdvancedTitle,
      showBackButton: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MatrixSettingsCard(),
            SettingsNavCard(
              trailing: OutboxBadgeIcon(
                icon: SettingsIcon(MdiIcons.mailboxOutline),
              ),
              title: context.messages.settingsSyncOutboxTitle,
              path: '/settings/advanced/outbox_monitor',
            ),
            SettingsNavCard(
              title: context.messages.settingsConflictsTitle,
              path: '/settings/advanced/conflicts',
            ),
            SettingsNavCard(
              title: context.messages.settingsLogsTitle,
              path: '/settings/advanced/logging',
            ),
            if (isMobile)
              SettingsNavCard(
                title: context.messages.settingsHealthImportTitle,
                path: '/settings/health_import',
              ),
            SettingsNavCard(
              title: context.messages.settingsMaintenanceTitle,
              path: '/settings/advanced/maintenance',
            ),

            
            SettingsNavCard(
              title: context.messages.settingsAboutTitle,
              path: '/settings/advanced/about',
            ),
          ],
        ),
      ),
    );
  }
}
