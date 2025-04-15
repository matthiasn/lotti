import 'package:flutter/material.dart';
import 'package:lotti/features/manual/widget/showcase_text_style.dart';
import 'package:lotti/features/manual/widget/showcase_with_widget.dart';
import 'package:lotti/features/sync/ui/matrix_settings_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/outbox/outbox_badge.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/settings/settings_card.dart';
import 'package:lotti/widgets/settings/settings_icon.dart';
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
  final _maxtrixsyncKey = GlobalKey();
  final _syncoutBoxKey = GlobalKey();
  final _synConflictsKey = GlobalKey();
  final _logsKey = GlobalKey();
  final _healthImportKey = GlobalKey();
  final _maintainaceKey = GlobalKey();
  final _aboutLottiKey = GlobalKey();

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
              _maintainaceKey,
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
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            ShowcaseWithWidget(
              showcaseKey: _syncoutBoxKey,
              description: ShowcaseTextStyle(
                descriptionText:
                    context.messages.settingsAdvancedShowCaseSyncOutboxTooltip,
              ),
              child: SettingsNavCard(
                trailing: OutboxBadgeIcon(
                  icon: SettingsIcon(MdiIcons.mailboxOutline),
                ),
                title: context.messages.settingsSyncOutboxTitle,
                path: '/settings/advanced/outbox_monitor',
              ),
            ),
            ShowcaseWithWidget(
              showcaseKey: _synConflictsKey,
              description: ShowcaseTextStyle(
                descriptionText:
                    context.messages.settingsAdvancedShowCaseConflictsTooltip,
              ),
              child: SettingsNavCard(
                title: context.messages.settingsConflictsTitle,
                path: '/settings/advanced/conflicts',
              ),
            ),
            ShowcaseWithWidget(
              showcaseKey: _logsKey,
              description: ShowcaseTextStyle(
                descriptionText:
                    context.messages.settingsAdvancedShowCaseLogsTooltip,
              ),
              child: SettingsNavCard(
                title: context.messages.settingsLogsTitle,
                path: '/settings/advanced/logging',
              ),
            ),
            if (isMobile)
              ShowcaseWithWidget(
                showcaseKey: _healthImportKey,
                description: ShowcaseTextStyle(
                  descriptionText: context
                      .messages.settingsAdvancedShowCaseHealthImportTooltip,
                ),
                child: SettingsNavCard(
                  title: context.messages.settingsHealthImportTitle,
                  path: '/settings/health_import',
                ),
              ),
            ShowcaseWithWidget(
              showcaseKey: _maintainaceKey,
              description: ShowcaseTextStyle(
                descriptionText:
                    context.messages.settingsAdvancedShowCaseMaintenanceTooltip,
              ),
              child: SettingsNavCard(
                title: context.messages.settingsMaintenanceTitle,
                path: '/settings/advanced/maintenance',
              ),
            ),
            ShowcaseWithWidget(
              isTooltipTop: true,
              endNav: true,
              showcaseKey: _aboutLottiKey,
              description: ShowcaseTextStyle(
                descriptionText:
                    context.messages.settingsAdvancedShowCaseAboutLottiTooltip,
              ),
              child: SettingsNavCard(
                title: context.messages.settingsAboutTitle,
                path: '/settings/advanced/about',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
