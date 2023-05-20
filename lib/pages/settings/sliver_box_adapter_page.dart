import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/habits/habit_page_app_bar.dart';
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

class SliverBoxAdapterPage extends StatelessWidget {
  const SliverBoxAdapterPage({
    required this.child,
    required this.title,
    super.key,
  });

  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: styleConfig().negspace,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverTitleBar(title),
          SliverToBoxAdapter(
            child: child,
          )
        ],
      ),
    );
  }
}
