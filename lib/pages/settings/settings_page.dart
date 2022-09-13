import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/pages/settings/settings_card.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/app_bar_version.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.navigatorKey,
  });

  final GlobalKey? navigatorKey;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: colorConfig().bodyBgColor,
      appBar: VersionAppBar(title: localizations.navTabTitleSettings),
      body: Container(
        margin: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 4,
        ),
        child: ListView(
          children: [
            SettingsCard(
              title: localizations.settingsTagsTitle,
              path: '/settings/tags',
            ),
            SettingsCard(
              title: localizations.settingsDashboardsTitle,
              path: '/settings/dashboards',
            ),
            SettingsCard(
              title: localizations.settingsMeasurablesTitle,
              path: '/settings/measurables',
            ),
            SettingsCard(
              title: localizations.settingsHealthImportTitle,
              path: '/settings/health_import',
            ),
            SettingsCard(
              title: localizations.settingsFlagsTitle,
              path: '/settings/flags',
            ),
            SettingsCard(
              title: localizations.settingsAdvancedTitle,
              path: '/settings/advanced',
            ),
          ],
        ),
      ),
    );
  }
}
