import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/manual/widget/showcase_text_style.dart';
import 'package:lotti/features/manual/widget/showcase_with_widget.dart';
import 'package:lotti/features/sync/ui/matrix_settings_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/outbox/outbox_badge.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/settings/modern_settings_cards.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:showcaseview/showcaseview.dart';

class AdvancedSettingsPage extends StatefulWidget {
  const AdvancedSettingsPage({
    super.key,
  });

  @override
  State<AdvancedSettingsPage> createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends State<AdvancedSettingsPage> {
  final GlobalKey<State<StatefulWidget>> _maxtrixsyncKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _syncoutBoxKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _synConflictsKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _logsKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _healthImportKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _maintenanceKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _aboutLottiKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterShowcasePage(
      showcaseIcon: IconButton(
        onPressed: () {
          ShowCaseWidget.of(context).startShowCase(
            [
              _maxtrixsyncKey,
              _syncoutBoxKey,
              _synConflictsKey,
              _logsKey,
              _healthImportKey,
              _maintenanceKey,
              _aboutLottiKey,
            ],
          );
        },
        icon: const Icon(
          Icons.info_outline_rounded,
        ),
      ),
      title: context.messages.settingsAdvancedTitle,
      showBackButton: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ShowcaseWithWidget(
              startNav: true,
              showcaseKey: _maxtrixsyncKey,
              description: ShowcaseTextStyle(
                descriptionText:
                    context.messages.settingsAdvancedShowCaseMatrixSyncTooltip,
              ),
              child: const MatrixSettingsCard(),
            ),
            const SizedBox(height: 8),
            ShowcaseWithWidget(
              showcaseKey: _syncoutBoxKey,
              description: ShowcaseTextStyle(
                descriptionText:
                    context.messages.settingsAdvancedShowCaseSyncOutboxTooltip,
              ),
              child: ModernSettingsCardWithIcon(
                title: context.messages.settingsSyncOutboxTitle,
                subtitle: 'Monitor sync outbox and pending messages',
                icon: Icons.mail,
                onTap: () =>
                    context.beamToNamed('/settings/advanced/outbox_monitor'),
                trailing: OutboxBadgeIcon(
                  icon: Icon(
                    MdiIcons.mailboxOutline,
                    color: context.colorScheme.primary.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ShowcaseWithWidget(
              showcaseKey: _synConflictsKey,
              description: ShowcaseTextStyle(
                descriptionText:
                    context.messages.settingsAdvancedShowCaseConflictsTooltip,
              ),
              child: ModernSettingsCardWithIcon(
                title: context.messages.settingsConflictsTitle,
                subtitle: 'Resolve sync conflicts and merge issues',
                icon: Icons.warning_rounded,
                onTap: () =>
                    context.beamToNamed('/settings/advanced/conflicts'),
              ),
            ),
            const SizedBox(height: 8),
            ShowcaseWithWidget(
              showcaseKey: _logsKey,
              description: ShowcaseTextStyle(
                descriptionText:
                    context.messages.settingsAdvancedShowCaseLogsTooltip,
              ),
              child: ModernSettingsCardWithIcon(
                title: context.messages.settingsLogsTitle,
                subtitle: 'View application logs and debug information',
                icon: Icons.article_rounded,
                onTap: () => context.beamToNamed('/settings/advanced/logging'),
              ),
            ),
            const SizedBox(height: 8),
            if (isMobile)
              ShowcaseWithWidget(
                showcaseKey: _healthImportKey,
                description: ShowcaseTextStyle(
                  descriptionText: context
                      .messages.settingsAdvancedShowCaseHealthImportTooltip,
                ),
                child: ModernSettingsCardWithIcon(
                  title: context.messages.settingsHealthImportTitle,
                  subtitle: 'Import health data from external sources',
                  icon: Icons.health_and_safety_rounded,
                  onTap: () => context.beamToNamed('/settings/health_import'),
                ),
              ),
            if (isMobile) const SizedBox(height: 8),
            ShowcaseWithWidget(
              showcaseKey: _maintenanceKey,
              description: ShowcaseTextStyle(
                descriptionText:
                    context.messages.settingsAdvancedShowCaseMaintenanceTooltip,
              ),
              child: ModernSettingsCardWithIcon(
                title: context.messages.settingsMaintenanceTitle,
                subtitle: 'Database maintenance and cleanup tools',
                icon: Icons.build_rounded,
                onTap: () =>
                    context.beamToNamed('/settings/advanced/maintenance'),
              ),
            ),
            const SizedBox(height: 8),
            ShowcaseWithWidget(
              isTooltipTop: true,
              endNav: true,
              showcaseKey: _aboutLottiKey,
              description: ShowcaseTextStyle(
                descriptionText:
                    context.messages.settingsAdvancedShowCaseAboutLottiTooltip,
              ),
              child: ModernSettingsCardWithIcon(
                title: context.messages.settingsAboutTitle,
                subtitle: 'App information and version details',
                icon: Icons.info_rounded,
                onTap: () => context.beamToNamed('/settings/advanced/about'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
