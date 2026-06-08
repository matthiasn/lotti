part of 'my_daily_widgetbook.dart';

class _NowIndicator extends StatelessWidget {
  const _NowIndicator({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
      key: const Key('my-daily-now-indicator'),
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step2,
            vertical: tokens.spacing.step1 / 2,
          ),
          decoration: BoxDecoration(
            color: tokens.colors.alert.error.defaultColor,
            borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
          ),
          child: Text(
            _formatLocalizedPreviewTime(context, now),
            style: tokens.typography.styles.others.overline.copyWith(
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: Container(
            margin: EdgeInsets.only(left: tokens.spacing.step2),
            height: 2,
            color: tokens.colors.alert.error.defaultColor,
          ),
        ),
      ],
    );
  }
}

class _MyDailyActionButton extends StatelessWidget {
  const _MyDailyActionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Semantics(
      button: true,
      label: context.messages.designSystemNavigationNewLabel,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: tokens.colors.interactive.enabled,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: tokens.colors.interactive.enabled.withValues(alpha: 0.3),
                blurRadius: tokens.spacing.step4,
                offset: Offset(0, tokens.spacing.step2),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onPressed,
            child: Icon(
              Icons.add_rounded,
              color: tokens.colors.text.onInteractiveAlert,
              size: tokens.typography.lineHeight.subtitle1,
            ),
          ),
        ),
      ),
    );
  }
}

class _MyDailyBottomNavigation extends StatelessWidget {
  const _MyDailyBottomNavigation();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final items = widgetbookNavigationDestinations(context)
        .map(
          (destination) => DesignSystemNavigationTabBarItem(
            label: destination.label,
            icon: Icon(destination.icon),
            active: destination.active,
            onTap: widgetbookNoop,
          ),
        )
        .toList();

    return Column(
      children: [
        SizedBox(
          height: 68,
          child: Center(
            child: SizedBox(
              width: 354,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 278,
                    child: DesignSystemNavigationFrostedSurface(
                      borderRadius: BorderRadius.circular(
                        tokens.radii.badgesPills,
                      ),
                      padding: EdgeInsets.all(tokens.spacing.step2),
                      child: Row(
                        children: [
                          for (var index = 0; index < items.length; index++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: index == items.length - 1
                                      ? 0
                                      : tokens.spacing.step1,
                                ),
                                child: _MyDailyBottomNavigationItem(
                                  item: items[index],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label:
                        context.messages.designSystemMyDailyProfileActionLabel,
                    child: DesignSystemNavigationFrostedSurface(
                      borderRadius: BorderRadius.circular(
                        tokens.radii.badgesPills,
                      ),
                      child: SizedBox.square(
                        dimension: 60,
                        child: Center(
                          child: Icon(
                            Icons.person_outline_rounded,
                            size: tokens.typography.lineHeight.subtitle1,
                            color: tokens.colors.text.highEmphasis,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          height: 34,
          child: Center(
            child: Container(
              width: 134,
              height: 5,
              decoration: BoxDecoration(
                color: tokens.colors.text.mediumEmphasis,
                borderRadius: BorderRadius.circular(tokens.radii.xl),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MyDailyBottomNavigationItem extends StatelessWidget {
  const _MyDailyBottomNavigationItem({required this.item});

  final DesignSystemNavigationTabBarItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final iconColor = item.active
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.mediumEmphasis;
    final labelColor = item.active
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.highEmphasis;

    return Semantics(
      button: true,
      selected: item.active,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
          onTap: item.onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step1,
              vertical: tokens.spacing.step2,
            ),
            decoration: BoxDecoration(
              color: item.active
                  ? tokens.colors.background.level01
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconTheme.merge(
                  data: IconThemeData(
                    size: 20,
                    color: iconColor,
                  ),
                  child: item.icon,
                ),
                SizedBox(height: tokens.spacing.step1),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: labelColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
