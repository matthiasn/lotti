import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/avatars/design_system_avatar.dart';
import 'package:lotti/features/design_system/components/breadcrumbs/design_system_breadcrumbs.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/headers/design_system_header.dart';
import 'package:lotti/features/design_system/widgetbook/widgetbook_helpers.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemHeaderWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Header',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _HeaderOverviewPage(),
      ),
    ],
  );
}

class _HeaderOverviewPage extends StatelessWidget {
  const _HeaderOverviewPage();

  static const _avatarImage = AssetImage(
    'assets/design_system/avatar_placeholder.png',
  );

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: WidgetbookSection(
          title: messages.designSystemVariantMatrixTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WidgetbookPreviewCase(
                label: messages.designSystemHeaderFigmaDefaultLabel,
                child: WidgetbookViewport(
                  width: 1440,
                  child: DesignSystemHeader(
                    leading: _HeaderIconButton(
                      icon: Icons.settings_outlined,
                      semanticsLabel: messages.navTabTitleSettings,
                    ),
                    title: messages.designSystemHeaderApiConfigurationTitle,
                    breadcrumbs: _buildBreadcrumbs(messages),
                    primaryAction: _buildPrimaryAction(messages),
                    trailingActions: [
                      _HeaderIconButton(
                        icon: Icons.search_rounded,
                        semanticsLabel:
                            messages.designSystemHeaderSearchActionLabel,
                      ),
                      _HeaderIconButton(
                        icon: Icons.notifications_none_rounded,
                        semanticsLabel:
                            messages.designSystemHeaderNotificationsActionLabel,
                      ),
                      _HeaderIconButton(
                        icon: Icons.help_outline_rounded,
                        semanticsLabel:
                            messages.designSystemHeaderHelpActionLabel,
                      ),
                      _HeaderIconButton(
                        icon: Icons.settings_outlined,
                        semanticsLabel: messages.navTabTitleSettings,
                      ),
                    ],
                    trailingAvatar: const DesignSystemAvatar(
                      image: _avatarImage,
                      size: DesignSystemAvatarSize.m32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              WidgetbookPreviewCase(
                label: messages.designSystemHeaderLongTitleLabel,
                child: WidgetbookViewport(
                  width: 960,
                  child: DesignSystemHeader(
                    leading: _HeaderIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      semanticsLabel:
                          messages.designSystemHeaderBackActionLabel,
                    ),
                    title: messages.designSystemHeaderLongTitleExample,
                    breadcrumbs: _buildBreadcrumbs(messages),
                    primaryAction: _buildPrimaryAction(messages),
                    trailingActions: [
                      _HeaderIconButton(
                        icon: Icons.search_rounded,
                        semanticsLabel:
                            messages.designSystemHeaderSearchActionLabel,
                      ),
                      _HeaderIconButton(
                        icon: Icons.notifications_none_rounded,
                        semanticsLabel:
                            messages.designSystemHeaderNotificationsActionLabel,
                      ),
                    ],
                    trailingAvatar: const DesignSystemAvatar(
                      image: _avatarImage,
                      size: DesignSystemAvatarSize.m32,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DesignSystemBreadcrumbs _buildBreadcrumbs(AppLocalizations messages) {
    return DesignSystemBreadcrumbs(
      items: [
        DesignSystemBreadcrumbItem(
          label: messages.navTabTitleSettings,
          onPressed: widgetbookNoop,
        ),
        DesignSystemBreadcrumbItem(
          label: messages.designSystemHeaderApiConfigurationTitle,
          selected: true,
          showChevron: false,
        ),
      ],
    );
  }

  Widget _buildPrimaryAction(AppLocalizations messages) {
    return SizedBox(
      width: 179,
      height: 36,
      child: DesignSystemButton(
        label: messages.designSystemHeaderApiDocumentationLabel,
        variant: DesignSystemButtonVariant.secondary,
        trailingIcon: Icons.open_in_new_rounded,
        onPressed: widgetbookNoop,
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.semanticsLabel,
  });

  final IconData icon;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return DesignSystemButton(
      label: '',
      variant: DesignSystemButtonVariant.tertiary,
      leadingIcon: icon,
      semanticsLabel: semanticsLabel,
      onPressed: widgetbookNoop,
    );
  }
}
