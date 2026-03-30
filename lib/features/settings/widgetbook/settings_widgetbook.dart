import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookFolder buildSettingsWidgetbookFolder() {
  return WidgetbookFolder(
    name: 'Settings',
    children: [
      WidgetbookComponent(
        name: 'Settings page',
        useCases: [
          WidgetbookUseCase(
            name: 'Overview',
            builder: (context) => const _SettingsShowcasePage(),
          ),
        ],
      ),
    ],
  );
}

class _SettingsShowcasePage extends StatelessWidget {
  const _SettingsShowcasePage();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    final items = [
      (
        title: messages.settingsAiTitle,
        subtitle: messages.settingsAiSubtitle,
        icon: Icons.psychology_rounded,
      ),
      (
        title: messages.agentSettingsTitle,
        subtitle: messages.agentSettingsSubtitle,
        icon: Icons.smart_toy_outlined,
      ),
      (
        title: messages.settingsHabitsTitle,
        subtitle: messages.settingsHabitsSubtitle,
        icon: Icons.repeat_rounded,
      ),
      (
        title: messages.settingsCategoriesTitle,
        subtitle: messages.settingsCategoriesSubtitle,
        icon: Icons.category_rounded,
      ),
      (
        title: messages.settingsLabelsTitle,
        subtitle: messages.settingsLabelsSubtitle,
        icon: Icons.label_rounded,
      ),
      (
        title: messages.settingsMatrixTitle,
        subtitle: messages.settingsSyncSubtitle,
        icon: Icons.sync,
      ),
      (
        title: messages.settingsThemingTitle,
        subtitle: messages.settingsThemingSubtitle,
        icon: Icons.palette_rounded,
      ),
      (
        title: messages.settingsFlagsTitle,
        subtitle: messages.settingsFlagsSubtitle,
        icon: Icons.tune_rounded,
      ),
      (
        title: messages.settingsAdvancedTitle,
        subtitle: messages.settingsAdvancedSubtitle,
        icon: Icons.settings_rounded,
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
      ),
      child: DesignSystemScrollbar(
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step5,
            vertical: tokens.spacing.step4,
          ),
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: tokens.spacing.step4,
                bottom: tokens.spacing.step4,
              ),
              child: Text(
                messages.navTabTitleSettings,
                style: tokens.typography.styles.heading.heading2.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.colors.background.level02,
                borderRadius: BorderRadius.circular(tokens.radii.m),
                border: Border.all(color: tokens.colors.decorative.level01),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radii.m),
                child: Column(
                  children: [
                    for (final (index, item) in items.indexed)
                      DesignSystemListItem(
                        title: item.title,
                        subtitle: item.subtitle,
                        leading: SettingsIcon(icon: item.icon),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          size: tokens.spacing.step6,
                          color: tokens.colors.text.lowEmphasis,
                        ),
                        showDivider: index < items.length - 1,
                        onTap: () {},
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
