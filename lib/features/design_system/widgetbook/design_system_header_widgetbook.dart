import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/avatars/design_system_avatar.dart';
import 'package:lotti/features/design_system/components/breadcrumbs/design_system_breadcrumbs.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/headers/design_system_header.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/widgetbook/widgetbook_helpers.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

part 'design_system_header_widgetbook_mobile.dart';

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
  static const _figmaCanvasBackground = Color(0xFF1F1F1F);
  static const _figmaSelectionColor = Color(0xFF7A5AF8);
  static const _desktopCanvasWidth = 1536.0;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WidgetbookSection(
              title: messages.designSystemHeaderDesktopSectionTitle,
              child: WidgetbookViewport(
                width: _desktopCanvasWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _figmaCanvasBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(48, 44, 48, 56),
                    child: SizedBox(
                      width: 1440,
                      child: DesignSystemHeader(
                        leading: _HeaderIconButton(
                          icon: Icons.settings_outlined,
                          semanticsLabel: messages.navTabTitleSettings,
                        ),
                        title: messages.designSystemBreadcrumbProjectsLabel,
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
                            semanticsLabel: messages
                                .designSystemHeaderNotificationsActionLabel,
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
                ),
              ),
            ),
            const SizedBox(height: 32),
            WidgetbookSection(
              title: messages.designSystemHeaderMobileSectionTitle,
              child: WidgetbookViewport(
                width: _MobileHeaderBoard.boardWidth,
                child: _MobileHeaderBoard(messages: messages),
              ),
            ),
          ],
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
          label: messages.designSystemBreadcrumbProjectsLabel,
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
