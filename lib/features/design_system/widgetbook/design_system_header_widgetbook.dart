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

const _mobileHeaderWidth = 320.0;

class _MobileHeaderBoard extends StatelessWidget {
  const _MobileHeaderBoard({required this.messages});

  final AppLocalizations messages;

  static const boardWidth = 430.0;
  static const _boardHeight = 464.0;
  static const _componentSetWidth = 356.0;
  static const _componentSetHeight = 416.0;
  static const _componentSetTop = 24.0;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _HeaderOverviewPage._figmaCanvasBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SizedBox(
        width: boardWidth,
        height: _boardHeight,
        child: Stack(
          children: [
            Positioned(
              top: _componentSetTop,
              left: (boardWidth - _componentSetWidth) / 2,
              child: _MobileComponentSet(messages: messages),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileComponentSet extends StatelessWidget {
  const _MobileComponentSet({required this.messages});

  final AppLocalizations messages;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _MobileHeaderBoard._componentSetWidth,
      height: _MobileHeaderBoard._componentSetHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: _HeaderOverviewPage._figmaSelectionColor,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 19,
            child: _MobileVariantFrame(
              children: [
                Positioned(
                  left: 10,
                  top: 12,
                  child: _MobileBackLabel(
                    label: messages.designSystemHeaderBackActionLabel,
                  ),
                ),
                const Positioned(
                  left: 134.5,
                  top: 4,
                  child: _MobileIcon(icon: Icons.more_horiz_rounded),
                ),
                const Positioned(
                  left: 238,
                  top: 4,
                  child: _MobileActionStrip(
                    icons: [
                      Icons.more_horiz_rounded,
                      Icons.more_horiz_rounded,
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            top: 85,
            child: _MobileVariantFrame(
              children: [
                Positioned(
                  left: 10,
                  top: 12,
                  child: _MobileBackLabel(
                    label: messages.designSystemHeaderBackActionLabel,
                  ),
                ),
                const Positioned(
                  left: 278,
                  top: 6,
                  child: _MobileIcon(
                    icon: Icons.person_add_alt_1_outlined,
                    dimension: 32,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            top: 151,
            child: _MobileVariantFrame(
              children: [
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _MobileTitle(
                      label: messages.aiSettingsModalityText,
                    ),
                  ),
                ),
                Positioned(
                  left: 264,
                  top: 12,
                  child: _MobileLabel(label: messages.cancelButton),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            top: 217,
            child: _MobileVariantFrame(
              children: [
                const Positioned(
                  left: 10,
                  top: 6,
                  child: _MobileIcon(
                    icon: Icons.person_add_alt_1_outlined,
                    dimension: 32,
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _MobileTitle(
                      label: messages.aiSettingsModalityText,
                    ),
                  ),
                ),
                const Positioned(
                  left: 278,
                  top: 6,
                  child: _MobileIcon(
                    icon: Icons.person_add_alt_1_outlined,
                    dimension: 32,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            top: 283,
            child: _MobileVariantFrame(
              children: [
                const Positioned(
                  left: 10,
                  top: 4,
                  child: _MobileActionStrip(
                    icons: [
                      Icons.more_horiz_rounded,
                      Icons.more_horiz_rounded,
                    ],
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _MobileTitle(
                      label: messages.aiSettingsModalityText,
                    ),
                  ),
                ),
                const Positioned(
                  left: 238,
                  top: 4,
                  child: _MobileActionStrip(
                    icons: [
                      Icons.more_horiz_rounded,
                      Icons.more_horiz_rounded,
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            top: 349,
            child: _MobileVariantFrame(
              children: [
                Positioned(
                  left: 16,
                  top: 10,
                  child: _MobileTitle(
                    label: messages.aiSettingsModalityText,
                  ),
                ),
                const Positioned(
                  left: 228,
                  top: 4,
                  child: _MobileIcon(icon: Icons.notifications_none_rounded),
                ),
                const Positioned(
                  left: 272,
                  top: 6,
                  child: DesignSystemAvatar(
                    image: _HeaderOverviewPage._avatarImage,
                    size: DesignSystemAvatarSize.m32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileVariantFrame extends StatelessWidget {
  const _MobileVariantFrame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.designTokens.colors.background.level01,
      ),
      child: SizedBox(
        width: _mobileHeaderWidth,
        height: 44,
        child: Stack(children: children),
      ),
    );
  }
}

class _MobileBackLabel extends StatelessWidget {
  const _MobileBackLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: tokens.colors.text.highEmphasis,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
      ],
    );
  }
}

class _MobileLabel extends StatelessWidget {
  const _MobileLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Text(
      label,
      style: tokens.typography.styles.body.bodySmall.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
    );
  }
}

class _MobileTitle extends StatelessWidget {
  const _MobileTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Text(
      label,
      style: tokens.typography.styles.subtitle.subtitle2.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
    );
  }
}

class _MobileIcon extends StatelessWidget {
  const _MobileIcon({
    required this.icon,
    this.dimension = 36,
  });

  final IconData icon;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: dimension,
      child: Center(
        child: Icon(
          icon,
          size: 20,
          color: context.designTokens.colors.text.highEmphasis,
        ),
      ),
    );
  }
}

class _MobileActionStrip extends StatelessWidget {
  const _MobileActionStrip({required this.icons});

  final List<IconData> icons;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < icons.length; index++) ...[
          _MobileIcon(icon: icons[index]),
          if (index < icons.length - 1) const SizedBox(width: 0),
        ],
      ],
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
