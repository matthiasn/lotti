import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/avatars/design_system_avatar.dart';
import 'package:lotti/features/design_system/components/breadcrumbs/design_system_breadcrumbs.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/headers/design_system_header.dart';
import 'package:lotti/features/design_system/widgetbook/widgetbook_helpers.dart';
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: WidgetbookSection(
          title: context.messages.designSystemVariantMatrixTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderPreviewCase(
                label: context.messages.designSystemHeaderFigmaDefaultLabel,
                child: _HeaderViewport(
                  width: 1440,
                  child: DesignSystemHeader(
                    leading: _HeaderIconButton(
                      icon: Icons.settings_outlined,
                      semanticsLabel: context.messages.navTabTitleSettings,
                    ),
                    title: context
                        .messages
                        .designSystemHeaderApiConfigurationTitle,
                    breadcrumbs: DesignSystemBreadcrumbs(
                      items: [
                        DesignSystemBreadcrumbItem(
                          label: context.messages.navTabTitleSettings,
                          onPressed: widgetbookNoop,
                        ),
                        DesignSystemBreadcrumbItem(
                          label: context
                              .messages
                              .designSystemHeaderApiConfigurationTitle,
                          selected: true,
                          showChevron: false,
                        ),
                      ],
                    ),
                    primaryAction: SizedBox(
                      width: 179,
                      height: 36,
                      child: DesignSystemButton(
                        label: context
                            .messages
                            .designSystemHeaderApiDocumentationLabel,
                        variant: DesignSystemButtonVariant.secondary,
                        trailingIcon: Icons.open_in_new_rounded,
                        onPressed: widgetbookNoop,
                      ),
                    ),
                    trailingActions: [
                      _HeaderIconButton(
                        icon: Icons.search_rounded,
                        semanticsLabel: context
                            .messages
                            .designSystemHeaderSearchActionLabel,
                      ),
                      _HeaderIconButton(
                        icon: Icons.notifications_none_rounded,
                        semanticsLabel: context
                            .messages
                            .designSystemHeaderNotificationsActionLabel,
                      ),
                      _HeaderIconButton(
                        icon: Icons.help_outline_rounded,
                        semanticsLabel:
                            context.messages.designSystemHeaderHelpActionLabel,
                      ),
                      _HeaderIconButton(
                        icon: Icons.settings_outlined,
                        semanticsLabel: context.messages.navTabTitleSettings,
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
              _HeaderPreviewCase(
                label: context.messages.designSystemHeaderLongTitleLabel,
                child: _HeaderViewport(
                  width: 960,
                  child: DesignSystemHeader(
                    leading: _HeaderIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      semanticsLabel:
                          context.messages.designSystemHeaderBackActionLabel,
                    ),
                    title: context.messages.designSystemHeaderLongTitleExample,
                    breadcrumbs: DesignSystemBreadcrumbs(
                      items: [
                        DesignSystemBreadcrumbItem(
                          label: context.messages.navTabTitleSettings,
                          onPressed: widgetbookNoop,
                        ),
                        DesignSystemBreadcrumbItem(
                          label: context
                              .messages
                              .designSystemHeaderApiConfigurationTitle,
                          selected: true,
                          showChevron: false,
                        ),
                      ],
                    ),
                    primaryAction: SizedBox(
                      width: 179,
                      height: 36,
                      child: DesignSystemButton(
                        label: context
                            .messages
                            .designSystemHeaderApiDocumentationLabel,
                        variant: DesignSystemButtonVariant.secondary,
                        trailingIcon: Icons.open_in_new_rounded,
                        onPressed: widgetbookNoop,
                      ),
                    ),
                    trailingActions: [
                      _HeaderIconButton(
                        icon: Icons.search_rounded,
                        semanticsLabel: context
                            .messages
                            .designSystemHeaderSearchActionLabel,
                      ),
                      _HeaderIconButton(
                        icon: Icons.notifications_none_rounded,
                        semanticsLabel: context
                            .messages
                            .designSystemHeaderNotificationsActionLabel,
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
}

class _HeaderPreviewCase extends StatelessWidget {
  const _HeaderPreviewCase({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _HeaderViewport extends StatelessWidget {
  const _HeaderViewport({
    required this.width,
    required this.child,
  });

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        child: child,
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
