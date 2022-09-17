import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/pages/settings/settings_card.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

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
      backgroundColor: Colors.white,
      appBar: TitleAppBar(
        title: localizations.navTabTitleSettings,
        showBackButton: false,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SettingsCard(
            title: localizations.settingsTagsTitle,
            path: '/settings/tags',
          ),
          const SettingsDivider(),
          SettingsCard(
            title: localizations.settingsDashboardsTitle,
            path: '/settings/dashboards',
          ),
          const SettingsDivider(),
          SettingsCard(
            title: localizations.settingsMeasurablesTitle,
            path: '/settings/measurables',
          ),
          const SettingsDivider(),
          SettingsCard(
            title: localizations.settingsHealthImportTitle,
            path: '/settings/health_import',
          ),
          const SettingsDivider(),
          SettingsCard(
            title: localizations.settingsFlagsTitle,
            path: '/settings/flags',
          ),
          const SettingsDivider(),
          SettingsCard(
            title: localizations.settingsAdvancedTitle,
            path: '/settings/advanced',
          ),
        ],
      ),
    );
  }
}
