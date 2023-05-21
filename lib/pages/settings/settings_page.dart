import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/settings/settings_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return SliverBoxAdapterPage(
      title: localizations.navTabTitleSettings,
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
              semanticsLabel: 'Measurable Data Types',
              path: '/settings/measurables',
            ),
            if (isMobile)
              SettingsNavCard(
                title: localizations.settingsHealthImportTitle,
                path: '/settings/health_import',
              ),
            SettingsNavCard(
              title: localizations.settingsFlagsTitle,
              path: '/settings/flags',
            ),
            if (Platform.isIOS || Platform.isMacOS)
              SettingsNavCard(
                title: localizations.settingsSpeechTitle,
                path: '/settings/speech_settings',
              ),
            SettingsNavCard(
              title: localizations.settingsAdvancedTitle,
              path: '/settings/advanced',
            ),
          ],
        ),
      ),
    );
  }
}
