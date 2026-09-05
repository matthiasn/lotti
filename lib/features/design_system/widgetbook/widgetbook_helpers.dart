import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

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
      icon: LottiIcons.today,
    ),
    WidgetbookNavigationDestination(
      label: context.messages.navTabTitleTasks,
      icon: LottiIcons.checkAll,
    ),
    WidgetbookNavigationDestination(
      label: context.messages.designSystemBreadcrumbProjectsLabel,
      icon: LottiIcons.folder,
    ),
    WidgetbookNavigationDestination(
      label: context.messages.navTabTitleHabits,
      icon: LottiIcons.checkAll,
    ),
    WidgetbookNavigationDestination(
      label: context.messages.designSystemNavigationInsightsLabel,
      icon: LottiIcons.chart,
    ),
    WidgetbookNavigationDestination(
      label: context.messages.navTabTitleJournal,
      icon: LottiIcons.book,
    ),
  ];
}

void widgetbookNoop() {}

class WidgetbookPreviewCase extends StatelessWidget {
  const WidgetbookPreviewCase({
    required this.label,
    required this.child,
    super.key,
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

class WidgetbookViewport extends StatelessWidget {
  const WidgetbookViewport({
    required this.width,
    required this.child,
    super.key,
  });

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : width;

        return SizedBox(
          width: maxWidth,
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: width,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
