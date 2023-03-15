import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/settings/settings_card.dart';

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
      backgroundColor: styleConfig().negspace,
      appBar: TitleAppBar(
        title: localizations.navTabTitleSettings,
        showBackButton: false,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SettingsNavCard(
            title: localizations.settingsHabitsTitle,
            path: '/settings/habits',
          ),
          SettingsNavCard(
            title: localizations.settingsTagsTitle,
            path: '/settings/tags',
          ),
          SettingsNavCard(
            title: localizations.settingsDashboardsTitle,
            path: '/settings/dashboards',
          ),
          SettingsNavCard(
            title: localizations.settingsMeasurablesTitle,
            path: '/settings/measurables',
          ),
          SettingsNavCard(
            title: localizations.settingsHealthImportTitle,
            path: '/settings/health_import',
          ),
          SettingsNavCard(
            title: localizations.settingsFlagsTitle,
            path: '/settings/flags',
          ),
          SettingsNavCard(
            title: localizations.settingsAdvancedTitle,
            path: '/settings/advanced',
          ),
        ],
      ),
    );
  }
}
