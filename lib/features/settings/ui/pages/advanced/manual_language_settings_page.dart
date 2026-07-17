import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/radio_buttons/design_system_radio_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/state/manual_language_controller.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Mobile / Beamer wrapper for the Language setting.
class ManualLanguageSettingsPage extends StatelessWidget {
  const ManualLanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsManualLanguageTitle,
      showBackButton: true,
      child: const ManualLanguageSettingsBody(),
    );
  }
}

/// Lets the user choose whether manual links follow the system or use one of
/// the currently published manual translations.
class ManualLanguageSettingsBody extends ConsumerWidget {
  const ManualLanguageSettingsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final selectedOverride = ref.watch(manualLanguageControllerProvider);
    final controller = ref.read(manualLanguageControllerProvider.notifier);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step4),
      child: DesignSystemGroupedList(
        children: [
          _ManualLanguageOption(
            title: messages.settingsManualLanguageFollowSystemTitle,
            subtitle: messages.settingsManualLanguageFollowSystemSubtitle,
            selected: selectedOverride == null,
            onTap: () => unawaited(controller.setOverride(null)),
            showDivider: true,
          ),
          _ManualLanguageOption(
            title: messages.settingsManualLanguageEnglishTitle,
            selected: selectedOverride == ManualLanguage.english,
            onTap: () =>
                unawaited(controller.setOverride(ManualLanguage.english)),
            showDivider: true,
          ),
          _ManualLanguageOption(
            title: messages.settingsManualLanguageGermanTitle,
            selected: selectedOverride == ManualLanguage.german,
            onTap: () =>
                unawaited(controller.setOverride(ManualLanguage.german)),
            showDivider: true,
          ),
          _ManualLanguageOption(
            title: messages.settingsManualLanguageFrenchTitle,
            selected: selectedOverride == ManualLanguage.french,
            onTap: () =>
                unawaited(controller.setOverride(ManualLanguage.french)),
            showDivider: true,
          ),
          _ManualLanguageOption(
            title: messages.settingsManualLanguageCzechTitle,
            selected: selectedOverride == ManualLanguage.czech,
            onTap: () =>
                unawaited(controller.setOverride(ManualLanguage.czech)),
            showDivider: true,
          ),
          _ManualLanguageOption(
            title: messages.settingsManualLanguageRomanianTitle,
            selected: selectedOverride == ManualLanguage.romanian,
            onTap: () =>
                unawaited(controller.setOverride(ManualLanguage.romanian)),
            showDivider: true,
          ),
          _ManualLanguageOption(
            title: messages.settingsManualLanguagePortugueseTitle,
            selected: selectedOverride == ManualLanguage.portuguese,
            onTap: () =>
                unawaited(controller.setOverride(ManualLanguage.portuguese)),
          ),
        ],
      ),
    );
  }
}

/// One full-width, token-styled manual-language choice.
///
/// The outer semantics node represents the whole tappable row. The visual row
/// composes existing design-system list and radio components without adding a
/// second, duplicate accessibility action for its trailing control.
class _ManualLanguageOption extends StatelessWidget {
  const _ManualLanguageOption({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.showDivider = false,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      label: title,
      selected: selected,
      child: DesignSystemListItem(
        title: title,
        subtitle: subtitle,
        selected: selected,
        onTap: onTap,
        showDivider: showDivider,
        excludeFromSemantics: true,
        trailing: ExcludeSemantics(
          child: DesignSystemRadioButton(
            selected: selected,
            onPressed: onTap,
            semanticsLabel: title,
          ),
        ),
      ),
    );
  }
}
