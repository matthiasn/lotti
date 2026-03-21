import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/breadcrumbs/design_system_breadcrumbs.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemBreadcrumbsWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Breadcrumbs',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _BreadcrumbsOverviewPage(),
      ),
    ],
  );
}

class _BreadcrumbsOverviewPage extends StatelessWidget {
  const _BreadcrumbsOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _BreadcrumbSection(
            title: context.messages.designSystemStateMatrixTitle,
            child: const _BreadcrumbStateMatrix(),
          ),
          const SizedBox(height: 32),
          _BreadcrumbSection(
            title: context.messages.designSystemBreadcrumbTrailTitle,
            child: _BreadcrumbTrailExample(
              labels: [
                context.messages.designSystemBreadcrumbHomeLabel,
                context.messages.designSystemBreadcrumbProjectsLabel,
                context.messages.designSystemBreadcrumbMobileLabel,
                context.messages.designSystemBreadcrumbDesignSystemLabel,
                context.messages.designSystemBreadcrumbCurrentLabel,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BreadcrumbSection extends StatelessWidget {
  const _BreadcrumbSection({
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

class _BreadcrumbStateMatrix extends StatelessWidget {
  const _BreadcrumbStateMatrix();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BreadcrumbStateRow(
          title: context.messages.designSystemDefaultLabel,
          selected: false,
        ),
        const SizedBox(height: 24),
        _BreadcrumbStateRow(
          title: context.messages.designSystemSelectedLabel,
          selected: true,
        ),
      ],
    );
  }
}

class _BreadcrumbStateRow extends StatelessWidget {
  const _BreadcrumbStateRow({
    required this.title,
    required this.selected,
  });

  final String title;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final label = context.messages.designSystemBreadcrumbSampleLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 24,
          runSpacing: 16,
          children: [
            _BreadcrumbStateTile(
              label: context.messages.designSystemDefaultLabel,
              child: DesignSystemBreadcrumbs(
                items: [
                  DesignSystemBreadcrumbItem(
                    label: label,
                    selected: selected,
                    onPressed: _noop,
                  ),
                ],
              ),
            ),
            _BreadcrumbStateTile(
              label: context.messages.designSystemHoverLabel,
              child: DesignSystemBreadcrumbs(
                items: [
                  DesignSystemBreadcrumbItem(
                    label: label,
                    selected: selected,
                    onPressed: _noop,
                    forcedState: DesignSystemBreadcrumbVisualState.hover,
                  ),
                ],
              ),
            ),
            _BreadcrumbStateTile(
              label: context.messages.designSystemPressedLabel,
              child: DesignSystemBreadcrumbs(
                items: [
                  DesignSystemBreadcrumbItem(
                    label: label,
                    selected: selected,
                    onPressed: _noop,
                    forcedState: DesignSystemBreadcrumbVisualState.pressed,
                  ),
                ],
              ),
            ),
            _BreadcrumbStateTile(
              label: context.messages.designSystemDisabledLabel,
              child: DesignSystemBreadcrumbs(
                items: [
                  DesignSystemBreadcrumbItem(
                    label: label,
                    selected: selected,
                    enabled: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BreadcrumbStateTile extends StatelessWidget {
  const _BreadcrumbStateTile({
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
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _BreadcrumbTrailExample extends StatelessWidget {
  const _BreadcrumbTrailExample({
    required this.labels,
  });

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return DesignSystemBreadcrumbs(
      items: [
        for (var index = 0; index < labels.length; index++)
          DesignSystemBreadcrumbItem(
            label: labels[index],
            selected: index == labels.length - 1,
            showChevron: index != labels.length - 1,
            onPressed: index == labels.length - 1 ? null : _noop,
          ),
      ],
    );
  }
}

void _noop() {}
