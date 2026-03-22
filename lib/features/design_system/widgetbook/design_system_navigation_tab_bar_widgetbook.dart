import 'dart:ui';

import 'package:flutter/material.dart';
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
          _TabBarSection(
            title: context.messages.designSystemNavigationTabBarSectionTitle,
            child: const _TabBarShowcase(),
          ),
          const SizedBox(height: 32),
          _TabBarSection(
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

class _TabBarSection extends StatelessWidget {
  const _TabBarSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _TabBarShowcase extends StatelessWidget {
  const _TabBarShowcase();

  @override
  Widget build(BuildContext context) {
    final items = _navigationDestinations(context);

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

  final List<_NavigationDestination> items;
  final bool minimized;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FrostedSurface(
          borderRadius: BorderRadius.circular(9999),
          padding: const EdgeInsets.all(4),
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
    final iconColor = active
        ? const Color(0xFF2BA184)
        : Colors.black.withValues(alpha: 0.64);
    final labelColor = active
        ? const Color(0xFF2BA184)
        : Colors.black.withValues(alpha: 0.88);

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
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
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
    return _FrostedSurface(
      borderRadius: BorderRadius.circular(296),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: 324,
        height: 48,
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 20,
              color: Colors.black.withValues(alpha: 0.64),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: Colors.black.withValues(alpha: 0.88),
                ),
              ),
            ),
            Icon(
              Icons.close_rounded,
              size: 20,
              color: Colors.black.withValues(alpha: 0.64),
            ),
          ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16),
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
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 2),
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
    return _FrostedSurface(
      borderRadius: BorderRadius.circular(9999),
      child: SizedBox(
        width: 60,
        height: 60,
        child: Center(
          child: Icon(
            Icons.search_rounded,
            color: Colors.black.withValues(alpha: 0.64),
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _NavigationDestination {
  const _NavigationDestination({
    required this.label,
    required this.icon,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final bool active;
}

List<_NavigationDestination> _navigationDestinations(BuildContext context) {
  return [
    _NavigationDestination(
      label: context.messages.designSystemNavigationMyDailyLabel,
      icon: Icons.calendar_today_outlined,
      active: true,
    ),
    _NavigationDestination(
      label: context.messages.navTabTitleTasks,
      icon: Icons.format_list_bulleted_rounded,
    ),
    _NavigationDestination(
      label: context.messages.designSystemBreadcrumbProjectsLabel,
      icon: Icons.folder_rounded,
    ),
    _NavigationDestination(
      label: context.messages.designSystemNavigationInsightsLabel,
      icon: Icons.bar_chart_rounded,
    ),
  ];
}
