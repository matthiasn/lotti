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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SettingsNavCard(
                title: localizations.settingsHabitsTitle,
                semanticsLabel: 'Habit Management',
                path: '/settings/habits',
              ),
              SettingsNavCard(
                title: localizations.settingsCategoriesTitle,
                semanticsLabel: 'Category Management',
                path: '/settings/categories',
              ),
              SettingsNavCard(
                title: localizations.settingsTagsTitle,
                semanticsLabel: 'Tag Management',
                path: '/settings/tags',
              ),
              SettingsNavCard(
                title: localizations.settingsDashboardsTitle,
                semanticsLabel: 'Dashboard Management',
                path: '/settings/dashboards',
              ),
              SettingsNavCard(
                title: localizations.settingsMeasurablesTitle,
                semanticsLabel: 'Measurables Management',
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
        ),
      ),
    );
  }
}
