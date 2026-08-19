import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

/// Widgetbook folder showcasing the settings list look — a static overview
/// page of the top-level settings rows ([SettingsIcon] + chevron) so the
/// row styling can be reviewed in isolation.
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
        icon: LottiIcons.reasoning,
      ),
      (
        title: messages.agentSettingsTitle,
        subtitle: messages.agentSettingsSubtitle,
        icon: LottiIcons.aiModel,
      ),
      (
        title: messages.settingsHabitsTitle,
        subtitle: messages.settingsHabitsSubtitle,
        icon: LottiIcons.repeat,
      ),
      (
        title: messages.settingsCategoriesTitle,
        subtitle: messages.settingsCategoriesSubtitle,
        icon: LottiIcons.category,
      ),
      (
        title: messages.settingsLabelsTitle,
        subtitle: messages.settingsLabelsSubtitle,
        icon: LottiIcons.label,
      ),
      (
        title: messages.settingsMatrixTitle,
        subtitle: messages.settingsSyncSubtitle,
        icon: LottiIcons.sync,
      ),
      (
        title: messages.settingsThemingTitle,
        subtitle: messages.settingsThemingSubtitle,
        icon: LottiIcons.palette,
      ),
      (
        title: messages.settingsFlagsTitle,
        subtitle: messages.settingsFlagsSubtitle,
        icon: LottiIcons.tune,
      ),
      (
        title: messages.settingsAdvancedTitle,
        subtitle: messages.settingsAdvancedSubtitle,
        icon: LottiIcons.settings,
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
                        trailing: SettingsIcon.trailingChevron(tokens),
                        showDivider: index < items.length - 1,
                        dividerIndent: SettingsIcon.dividerIndent(tokens),
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
