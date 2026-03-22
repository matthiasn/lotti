import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/widgetbook/widgetbook_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemNavigationTabBarWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Tab bar',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _NavigationTabBarOverviewPage(),
      ),
    ],
  );
}

class _NavigationTabBarOverviewPage extends StatelessWidget {
  const _NavigationTabBarOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          WidgetbookSection(
            title: context.messages.designSystemNavigationTabBarSectionTitle,
            child: const _TabBarShowcase(),
          ),
          const SizedBox(height: 32),
          WidgetbookSection(
            title: context
                .messages
                .designSystemNavigationSubComponentsSectionTitle,
            child: const _SubComponentsShowcase(),
          ),
        ],
      ),
    );
  }
}

class _TabBarShowcase extends StatelessWidget {
  const _TabBarShowcase();

  @override
  Widget build(BuildContext context) {
    final items = widgetbookNavigationDestinations(context);

    return _PreviewSurface(
      child: Wrap(
        spacing: 24,
        runSpacing: 24,
        children: [
          _NavigationTabBar(items: items),
          _NavigationTabBar(items: items.take(4).toList()),
          _NavigationTabBar(items: items.take(3).toList()),
          _NavigationTabBar(items: items.take(2).toList()),
          _NavigationTabBar(items: items.take(1).toList()),
          _NavigationTabBar(items: items.take(1).toList(), minimized: true),
        ],
      ),
    );
  }
}

class _NavigationTabBar extends StatelessWidget {
  const _NavigationTabBar({
    required this.items,
    this.minimized = false,
  });

  final List<WidgetbookNavigationDestination> items;
  final bool minimized;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FrostedSurface(
          borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
          padding: EdgeInsets.all(tokens.spacing.step2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < items.length; index++)
                Padding(
                  padding: EdgeInsets.only(
                    right: index == items.length - 1 ? 0 : 4,
                  ),
                  child: _NavigationTabItem(
                    label: items[index].label,
                    icon: items[index].icon,
                    active: items[index].active,
                    symbol: minimized,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        const _AccessoryCircleButton(),
      ],
    );
  }
}

class _NavigationTabItem extends StatelessWidget {
  const _NavigationTabItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.symbol,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool symbol;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final iconColor = active
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.mediumEmphasis;
    final labelColor = active
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.highEmphasis;

    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: Container(
        constraints: BoxConstraints(
          minWidth: symbol ? 44 : 56,
          minHeight: symbol ? 44 : 52,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: symbol ? 10 : 12,
          vertical: symbol ? 10 : 8,
        ),
        decoration: BoxDecoration(
          color: active ? tokens.colors.background.level01 : Colors.transparent,
          borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: iconColor),
            if (!symbol) ...[
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: labelColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubComponentsShowcase extends StatelessWidget {
  const _SubComponentsShowcase();

  @override
  Widget build(BuildContext context) {
    final myDaily = context.messages.designSystemNavigationMyDailyLabel;
    final placeholder = context.messages.designSystemNavigationPlaceholderLabel;

    return _PreviewSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              _NavigationTabItem(
                label: myDaily,
                icon: Icons.calendar_today_outlined,
                active: true,
                symbol: false,
              ),
              _NavigationTabItem(
                label: myDaily,
                icon: Icons.calendar_today_outlined,
                active: false,
                symbol: false,
              ),
              const _NavigationTabItem(
                label: 'Label',
                icon: Icons.account_circle_rounded,
                active: true,
                symbol: true,
              ),
              const _NavigationTabItem(
                label: 'Label',
                icon: Icons.account_circle_rounded,
                active: false,
                symbol: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _AccessoryField(label: placeholder),
        ],
      ),
    );
  }
}

class _AccessoryField extends StatelessWidget {
  const _AccessoryField({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 324),
      child: _FrostedSurface(
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
        child: SizedBox(
          width: double.infinity,
          height: tokens.spacing.step9,
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 20,
                color: tokens.colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ),
              Icon(
                Icons.close_rounded,
                size: 20,
                color: tokens.colors.text.mediumEmphasis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(tokens.spacing.step6),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
      ),
      child: child,
    );
  }
}

class _FrostedSurface extends StatelessWidget {
  const _FrostedSurface({
    required this.child,
    required this.borderRadius,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final brightness = Theme.of(context).brightness;
    final frostedFill = brightness == Brightness.dark
        ? tokens.colors.surface.hover
        : tokens.colors.background.level01.withValues(alpha: 0.72);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: tokens.spacing.step5,
          sigmaY: tokens.spacing.step5,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: frostedFill,
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: tokens.spacing.step5 + tokens.spacing.step2,
                offset: Offset(0, tokens.spacing.step1),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AccessoryCircleButton extends StatelessWidget {
  const _AccessoryCircleButton();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return _FrostedSurface(
      borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      child: SizedBox(
        width: 60,
        height: 60,
        child: Center(
          child: Icon(
            Icons.search_rounded,
            color: tokens.colors.text.mediumEmphasis,
            size: 20,
          ),
        ),
      ),
    );
  }
}
