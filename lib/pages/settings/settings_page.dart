import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/pages/settings/settings_card.dart';
import 'package:lotti/pages/settings/settings_icon.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    Key? key,
    this.navigatorKey,
  }) : super(key: key);

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
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 8.0,
        horizontal: 8.0,
      ),
      child: ListView(
        children: [
          SettingsCard(
            icon: const SettingsIcon(MdiIcons.tagOutline),
            title: localizations.settingsTagsTitle,
            onTap: () {
              pushNamedRoute('/settings/tags');
            },
          ),
          SettingsCard(
            icon: const SettingsIcon(Icons.dashboard_customize_outlined),
            title: localizations.settingsDashboardsTitle,
            onTap: () {
              pushNamedRoute('/settings/dashboards');
            },
          ),
          SettingsCard(
            icon: const SettingsIcon(Icons.insights),
            title: localizations.settingsMeasurablesTitle,
            onTap: () {
              pushNamedRoute('/settings/measurables');
            },
          ),
          SettingsCard(
            icon: const SettingsIcon(MdiIcons.heartOutline),
            title: localizations.settingsHealthImportTitle,
            onTap: () {
              pushNamedRoute('/settings/health_import');
            },
          ),
          SettingsCard(
            icon: const SettingsIcon(MdiIcons.flagOutline),
            title: localizations.settingsFlagsTitle,
            onTap: () {
              pushNamedRoute('/settings/flags');
            },
          ),
          SettingsCard(
            icon: const SettingsIcon(MdiIcons.alertRhombusOutline),
            title: localizations.settingsAdvancedTitle,
            onTap: () {
              pushNamedRoute('/settings/advanced');
            },
          ),
        ],
      ),
    );
  }
}
