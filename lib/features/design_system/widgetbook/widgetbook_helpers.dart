import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class WidgetbookSection extends StatelessWidget {
  const WidgetbookSection({
    required this.title,
    required this.child,
    super.key,
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

class WidgetbookNavigationDestination {
  const WidgetbookNavigationDestination({
    required this.label,
    required this.icon,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final bool active;
}

List<WidgetbookNavigationDestination> widgetbookNavigationDestinations(
  BuildContext context,
) {
  return [
    WidgetbookNavigationDestination(
      label: context.messages.designSystemNavigationMyDailyLabel,
      icon: Icons.calendar_today_outlined,
      active: true,
    ),
    WidgetbookNavigationDestination(
      label: context.messages.navTabTitleTasks,
      icon: Icons.format_list_bulleted_rounded,
    ),
    WidgetbookNavigationDestination(
      label: context.messages.designSystemBreadcrumbProjectsLabel,
      icon: Icons.folder_rounded,
    ),
    WidgetbookNavigationDestination(
      label: context.messages.designSystemNavigationInsightsLabel,
      icon: Icons.bar_chart_rounded,
    ),
  ];
}

void widgetbookNoop() {}
