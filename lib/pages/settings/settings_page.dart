import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/widgets/settings/settings_card.dart';
import 'package:showcaseview/showcaseview.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    
    
    super.key,
  });

  

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final GlobalKey showcaseKey1 = GlobalKey();

  @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => ShowCaseWidget.of(context).startShowCase([showcaseKey1]),
  );
}


  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.navTabTitleSettings,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SettingsNavCard(
              title: context.messages.settingsHabitsTitle,
              semanticsLabel: 'Habit Management',
              path: '/settings/habits',
            ),
            SettingsNavCard(
              title: context.messages.settingsCategoriesTitle,
              semanticsLabel: 'Category Management',
              path: '/settings/categories',
            ),
            SettingsNavCard(
              title: context.messages.settingsTagsTitle,
              semanticsLabel: 'Tag Management',
              path: '/settings/tags',
            ),
            SettingsNavCard(
              title: context.messages.settingsDashboardsTitle,
              semanticsLabel: 'Dashboard Management',
              path: '/settings/dashboards',
            ),
            SettingsNavCard(
              title: context.messages.settingsMeasurablesTitle,
              semanticsLabel: 'Measurable Data Types',
              path: '/settings/measurables',
            ),
            SettingsNavCard(
              title: context.messages.settingsThemingTitle,
              path: '/settings/theming',
            ),
            SettingsNavCard(
              title: context.messages.settingsFlagsTitle,
              path: '/settings/flags',
            ),
            if (Platform.isIOS || Platform.isMacOS)
              SettingsNavCard(
                title: context.messages.settingsSpeechTitle,
                path: '/settings/speech_settings',
              ),

           Showcase(
                    key: showcaseKey1,
                    description: 'Learn more about this app.',
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
