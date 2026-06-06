part of 'design_system_header_widgetbook.dart';

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
